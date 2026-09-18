/**
 * @file Client Redis centralisé du backend CORMERY.
 *
 * Couche `infrastructure/redis` : bas niveau, sans logique métier, sans queue ni worker.
 *
 * ```text
 * process.env → config/env.ts → redis.client.ts → BullMQ / services → application
 * ```
 *
 * Principes :
 * - la configuration provient exclusivement de {@link envConfig} (ce fichier ne lit jamais `process.env`) ;
 * - aucun singleton global : {@link createRedisClient} est une fabrique, le cycle de vie
 *   (connexion, fermeture) appartient au bootstrap ;
 * - les credentials ne sortent jamais de ce module : les erreurs natives (dont le message peut
 *   contenir hôte, IP ou détails réseau) ne sont ni copiées ni chaînées, seul un code technique
 *   sûr est conservé ;
 * - le driver est `ioredis` (déjà déclaré dans package.json) : c'est le client dont BullMQ
 *   accepte les instances en `connection` (vérifié avec bullmq 6.3.4).
 */
import { Redis, type RedisOptions } from 'ioredis';

import { envConfig, type EnvConfig } from '../../config/env';

/* -------------------------------------------------------------------------- */
/* Politique de connexion                                                      */
/* -------------------------------------------------------------------------- */

/** Délai maximal d'établissement de la connexion TCP/TLS. */
const CONNECT_TIMEOUT_MS = 10_000;

/** Intervalle de keep-alive TCP : évite les coupures silencieuses par les NAT/load balancers managés. */
const KEEP_ALIVE_MS = 30_000;

/** Délai maximal d'un {@link RedisClient.ping}, pour qu'un health check ne reste jamais suspendu. */
const PING_TIMEOUT_MS = 3_000;

/**
 * Nombre de tentatives par commande avant échec, pour l'usage `command`.
 * Le défaut d'ioredis (20) bloquerait une requête HTTP pendant plusieurs minutes lors d'une coupure.
 */
const COMMAND_MAX_RETRIES_PER_REQUEST = 3;

/** Délai de reconnexion initial et plafond (backoff exponentiel avec gigue). */
const RECONNECT_BASE_DELAY_MS = 500;
const RECONNECT_MAX_DELAY_MS = 15_000;

/** Code d'avertissement émis par défaut pour les erreurs de connexion. */
const CONNECTION_WARNING_CODE = 'CORMERY_REDIS_ERROR';

/** Un code technique sûr : errno Node (`ECONNREFUSED`) ou mot d'erreur Redis (`WRONGPASS`). */
const SAFE_ERROR_CODE_PATTERN = /^[A-Za-z0-9_]{1,32}$/;

/* -------------------------------------------------------------------------- */
/* Types publics                                                               */
/* -------------------------------------------------------------------------- */

/** Sous-ensemble de la configuration validée dont ce module dépend. */
export type RedisConfig = Pick<EnvConfig, 'REDIS_URL' | 'REDIS_KEY_PREFIX'>;

/**
 * Usage prévu d'une connexion.
 *
 * - `command` : commandes applicatives (cache, verrous, compteurs). Échoue vite en cas de coupure
 *   (`maxRetriesPerRequest` borné).
 * - `bullmq` : connexion destinée à un `Worker` BullMQ. BullMQ impose `maxRetriesPerRequest: null`
 *   pour ses commandes bloquantes et refuse une connexion qui ne le respecte pas.
 */
export type RedisClientUsage = 'command' | 'bullmq';

/** Opération à l'origine d'une {@link RedisClientError}. */
export type RedisOperation = 'connect' | 'ping' | 'close' | 'connection';

/**
 * Erreur d'infrastructure Redis, garantie exempte de credentials.
 *
 * Le message est construit à partir de l'opération et d'un code technique uniquement ;
 * le message et la pile de l'erreur native ne sont volontairement pas propagés
 * (aucune propriété `cause`).
 */
export class RedisClientError extends Error {
  /** Opération qui a échoué. */
  public readonly operation: RedisOperation;

  /** Code technique (errno, mot d'erreur Redis ou code interne), `undefined` s'il est absent ou non sûr. */
  public readonly code: string | undefined;

  /**
   * @param operation - Opération qui a échoué.
   * @param code - Code technique déjà assaini, ou `undefined`.
   */
  public constructor(operation: RedisOperation, code: string | undefined) {
    super(
      code === undefined
        ? `Redis ${operation} failed`
        : `Redis ${operation} failed (code: ${code})`,
    );
    this.name = 'RedisClientError';
    this.operation = operation;
    this.code = code;
  }
}

/** Options de {@link createRedisClient}. */
export interface RedisClientOptions {
  /** Usage prévu de la connexion ; `command` par défaut. Voir {@link RedisClientUsage}. */
  readonly usage?: RedisClientUsage;
  /** Configuration à utiliser ; par défaut {@link envConfig}. Utile pour les tests. */
  readonly config?: RedisConfig;
  /**
   * Appelé pour les erreurs de connexion asynchrones (coupure, reconnexion échouée…).
   * Déduplication : une même erreur (même code) n'est signalée qu'une fois jusqu'au prochain
   * rétablissement, afin de ne pas inonder les logs pendant une panne.
   * Par défaut, émet un avertissement de processus assaini. Ne doit pas lever d'exception.
   */
  readonly onError?: (error: RedisClientError) => void;
}

/**
 * Handle du client Redis, créé par {@link createRedisClient}.
 *
 * ### Compatibilité BullMQ
 * `redis` peut être passé en `connection` à BullMQ, avec ces contraintes :
 * - **`Worker`** : exige `maxRetriesPerRequest: null` → créer le client avec `usage: 'bullmq'` ;
 * - **Connexion bloquante** : un `Worker` émet des commandes bloquantes (`BZPOPMIN`…) qui
 *   monopolisent la connexion. BullMQ duplique donc l'instance reçue pour cet usage ; une même
 *   connexion ne doit pas servir simultanément de connexion « commandes » applicative et de
 *   connexion de worker. Un `QueueEvents` requiert lui aussi sa propre connexion ;
 * - **Namespace** : n'utilise PAS l'option `keyPrefix` d'ioredis (incompatible avec BullMQ).
 *   Passer {@link RedisClient.keyPrefix} à l'option `prefix` de BullMQ, et utiliser
 *   {@link RedisClient.key} pour les clés applicatives ;
 * - **Propriété** : BullMQ ne ferme pas une instance qu'il n'a pas créée. Fermer les queues et
 *   workers d'abord, puis appeler {@link RedisClient.close}.
 */
export interface RedisClient {
  /** Instance ioredis sous-jacente (non connectée tant que {@link RedisClient.connect} n'a pas été appelée). */
  readonly redis: Redis;
  /** Namespace logique CORMERY (`REDIS_KEY_PREFIX`), à passer à l'option `prefix` de BullMQ. */
  readonly keyPrefix: string;
  /**
   * Construit une clé applicative préfixée : `<REDIS_KEY_PREFIX>:<segment>:<segment>…`.
   *
   * @param segments - Segments de la clé.
   * @returns Clé complète, à utiliser telle quelle dans les commandes.
   */
  key(...segments: readonly string[]): string;
  /**
   * Établit la connexion et attend qu'elle soit prête. Idempotente (appels partagés).
   * En cas d'échec, la reconnexion automatique est arrêtée et le client est inutilisable :
   * le bootstrap doit échouer (fail fast) ou créer un nouveau client.
   *
   * @throws {RedisClientError} Si la connexion échoue ou si le client est déjà fermé.
   */
  connect(): Promise<void>;
  /**
   * Vérifie réellement la disponibilité : émet `PING` et exige `PONG`, avec un délai maximal.
   *
   * @throws {RedisClientError} Si Redis répond incorrectement, est injoignable ou dépasse le délai.
   */
  ping(): Promise<void>;
  /**
   * Ferme proprement la connexion (`QUIT` si prête, sinon fermeture immédiate) et stoppe toute
   * reconnexion. Idempotente — les appels multiples partagent la même promesse.
   *
   * @throws {RedisClientError} Si la fermeture échoue (la connexion est alors forcée à se fermer).
   */
  close(): Promise<void>;
}

/* -------------------------------------------------------------------------- */
/* Utilitaires                                                                 */
/* -------------------------------------------------------------------------- */

/**
 * Extrait un code technique SÛR d'une erreur native inconnue.
 *
 * Pourquoi : les messages natifs peuvent contenir hôte/IP (`connect ECONNREFUSED 10.0.0.5:6379`).
 * Sont retenus : `error.code` (errno Node) ou, pour une `ReplyError` du serveur, le premier mot
 * du message (`WRONGPASS`, `NOAUTH`, `READONLY`…). Tout le reste est écarté.
 *
 * @param error - Erreur native, de type inconnu.
 * @returns Code validé par {@link SAFE_ERROR_CODE_PATTERN}, sinon `undefined`.
 */
function extractSafeCode(error: unknown): string | undefined {
  if (typeof error !== 'object' || error === null) return undefined;
  let candidate: unknown;
  if ('code' in error) {
    candidate = error.code;
  } else if (error instanceof Error && error.name === 'ReplyError') {
    candidate = error.message.split(' ', 1)[0];
  }
  return typeof candidate === 'string' && SAFE_ERROR_CODE_PATTERN.test(candidate)
    ? candidate
    : undefined;
}

/**
 * Convertit une erreur native en {@link RedisClientError} sûre.
 *
 * @param operation - Opération à l'origine de l'erreur.
 * @param error - Erreur native, de type inconnu.
 * @returns Erreur assainie, sans message ni pile natifs.
 */
function toRedisClientError(operation: RedisOperation, error: unknown): RedisClientError {
  return new RedisClientError(operation, extractSafeCode(error));
}

/**
 * Gestionnaire par défaut des erreurs de connexion : avertissement de processus assaini.
 *
 * @param error - Erreur déjà assainie.
 */
function defaultErrorHandler(error: RedisClientError): void {
  process.emitWarning(error.message, { code: CONNECTION_WARNING_CODE });
}

/**
 * Délai avant la prochaine tentative de reconnexion : backoff exponentiel plafonné,
 * avec gigue (« equal jitter ») pour éviter que toutes les instances se reconnectent en même temps.
 *
 * @param attempt - Numéro de la tentative (commence à 1).
 * @returns Délai en millisecondes, jamais nul et plafonné à {@link RECONNECT_MAX_DELAY_MS}.
 */
function reconnectDelayMs(attempt: number): number {
  const ceiling = Math.min(RECONNECT_BASE_DELAY_MS * 2 ** (attempt - 1), RECONNECT_MAX_DELAY_MS);
  return Math.round(ceiling / 2 + Math.random() * (ceiling / 2));
}

/* -------------------------------------------------------------------------- */
/* Fabrique                                                                    */
/* -------------------------------------------------------------------------- */

/**
 * Crée un client Redis (ioredis) piloté par la configuration validée.
 *
 * Politique de connexion :
 * - source : `REDIS_URL` ; `rediss://` active TLS automatiquement (Redis managé) ;
 * - connexion paresseuse : rien n'est ouvert avant {@link RedisClient.connect} ;
 * - reconnexion : backoff exponentiel plafonné (500 ms → 15 s) avec gigue, sans limite de
 *   tentatives ; la connexion reste donc autonome après une panne, sans boucle agressive ;
 * - après un basculement (`READONLY`, ex. failover d'un Redis managé), la connexion est
 *   recréée et la commande rejouée ;
 * - `connectTimeout` et keep-alive TCP explicites ; aucun `commandTimeout` (il casserait les
 *   commandes bloquantes de BullMQ) — les health checks portent leur propre délai ;
 * - `keyPrefix` d'ioredis volontairement NON utilisé (incompatible BullMQ), voir {@link RedisClient.key}.
 *
 * Cycle de vie : l'appelant possède le client, l'ouvre avec {@link RedisClient.connect} et DOIT
 * le fermer avec {@link RedisClient.close} à l'arrêt de l'application.
 *
 * @param options - Usage, configuration et gestion d'erreur (toutes facultatives).
 * @returns Handle contenant l'instance ioredis, le namespace, `key()`, `connect()`, `ping()` et `close()`.
 */
export function createRedisClient(options: RedisClientOptions = {}): RedisClient {
  const config = options.config ?? envConfig;
  const usage = options.usage ?? 'command';
  const onError = options.onError ?? defaultErrorHandler;

  // Littéral non annoté (`satisfies`) : typer la variable en `RedisOptions` casserait la surcharge du
  // constructeur d'ioredis sous `exactOptionalPropertyTypes` (propriété `replyMapping`).
  const redisOptions = {
    lazyConnect: true,
    connectTimeout: CONNECT_TIMEOUT_MS,
    keepAlive: KEEP_ALIVE_MS,
    maxRetriesPerRequest: usage === 'bullmq' ? null : COMMAND_MAX_RETRIES_PER_REQUEST,
    retryStrategy: reconnectDelayMs,
    reconnectOnError: (error: Error) => (error.message.startsWith('READONLY') ? 2 : false),
  } satisfies RedisOptions;
  const redis = new Redis(config.REDIS_URL, redisOptions);

  // Dernier code d'erreur observé, réutilisé pour un échec de connect() dont l'erreur native est générique.
  let lastErrorCode: string | undefined;
  // Signature de la dernière erreur signalée ; `null` = rien à dédupliquer (état sain).
  let reportedSignature: string | null = null;

  // Sans écouteur `error`, ioredis imprimerait l'erreur brute (potentiellement sensible) sur stderr.
  redis.on('error', (error: unknown) => {
    const sanitized = toRedisClientError('connection', error);
    lastErrorCode = sanitized.code;
    const signature = sanitized.code ?? '';
    if (signature !== reportedSignature) {
      reportedSignature = signature;
      onError(sanitized);
    }
  });
  redis.on('ready', () => {
    lastErrorCode = undefined;
    reportedSignature = null;
  });

  let connecting: Promise<void> | undefined;
  let closing: Promise<void> | undefined;

  const openConnection = async (): Promise<void> => {
    try {
      await redis.connect();
    } catch (error: unknown) {
      // ioredis rejette au premier `close` mais continuerait à se reconnecter : on l'arrête.
      redis.disconnect();
      throw new RedisClientError('connect', lastErrorCode ?? extractSafeCode(error));
    }
  };

  const closeConnection = async (): Promise<void> => {
    try {
      if (redis.status === 'ready') {
        await redis.quit();
      } else {
        redis.disconnect();
      }
    } catch (error: unknown) {
      redis.disconnect();
      throw toRedisClientError('close', error);
    }
  };

  return {
    redis,
    keyPrefix: config.REDIS_KEY_PREFIX,
    key(...segments: readonly string[]): string {
      return [config.REDIS_KEY_PREFIX, ...segments].join(':');
    },
    connect(): Promise<void> {
      if (closing !== undefined) {
        return Promise.reject(new RedisClientError('connect', 'CLIENT_CLOSED'));
      }
      connecting ??= openConnection();
      return connecting;
    },
    async ping(): Promise<void> {
      let timer: ReturnType<typeof setTimeout> | undefined;
      const timeout = new Promise<never>((_, reject) => {
        timer = setTimeout(() => {
          reject(new RedisClientError('ping', 'PING_TIMEOUT'));
        }, PING_TIMEOUT_MS);
      });
      try {
        const reply = await Promise.race([redis.ping(), timeout]);
        if (reply !== 'PONG') throw new RedisClientError('ping', 'BAD_REPLY');
      } catch (error: unknown) {
        throw error instanceof RedisClientError ? error : toRedisClientError('ping', error);
      } finally {
        clearTimeout(timer);
      }
    },
    close(): Promise<void> {
      closing ??= closeConnection();
      return closing;
    },
  };
}