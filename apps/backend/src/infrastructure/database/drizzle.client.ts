/**
 * @file Client PostgreSQL / Drizzle centralisé du backend CORMERY.
 *
 * Couche `infrastructure/database` : bas niveau, sans logique métier.
 *
 * ```text
 * process.env → config/env.ts → drizzle.client.ts → repositories → application/domain
 * ```
 *
 * Principes :
 * - la configuration provient exclusivement de {@link envConfig} (ce fichier ne lit jamais `process.env`) ;
 * - aucun singleton global : {@link createDatabaseClient} est une fabrique, le cycle de vie
 *   (création, fermeture) appartient au bootstrap (ex. provider NestJS) ;
 * - les credentials ne sortent jamais de ce module : les erreurs natives de `pg` (dont le message
 *   peut contenir hôte, utilisateur ou IP) ne sont ni copiées ni chaînées, seul leur code
 *   technique (SQLSTATE / errno) est conservé.
 */
import { drizzle, type NodePgDatabase } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';

import { envConfig, type EnvConfig } from '../../config/env';

/* -------------------------------------------------------------------------- */
/* Politique de connexion                                                      */
/* -------------------------------------------------------------------------- */

/**
 * Délai maximal pour obtenir une connexion (établissement TCP/TLS + attente dans le pool).
 * Borné pour échouer vite plutôt que de suspendre une requête HTTP indéfiniment.
 */
const CONNECTION_TIMEOUT_MS = 10_000;

/**
 * Durée d'inactivité avant fermeture d'une connexion du pool. Volontairement courte :
 * Neon (auto-suspend), Supabase (pooler) et les NAT cloud coupent les connexions inactives.
 */
const IDLE_TIMEOUT_MS = 30_000;

/** Code d'avertissement émis par défaut lorsqu'une connexion inactive du pool échoue. */
const POOL_ERROR_WARNING_CODE = 'CORMERY_DB_POOL_ERROR';

/** Un code technique sûr : SQLSTATE (`28P01`) ou errno Node (`ECONNREFUSED`). */
const SAFE_ERROR_CODE_PATTERN = /^[A-Za-z0-9_]{1,32}$/;

/* -------------------------------------------------------------------------- */
/* Types publics                                                               */
/* -------------------------------------------------------------------------- */

/** Sous-ensemble de la configuration validée dont ce module dépend. */
export type DatabaseConfig = Pick<EnvConfig, 'DATABASE_URL' | 'DATABASE_POOL_MAX' | 'APP_NAME'>;

/** Contrainte du schéma Drizzle (objet d'exports de tables/relations). */
export type DatabaseSchema = Record<string, unknown>;

/** Opération à l'origine d'une {@link DatabaseClientError}. */
export type DatabaseOperation = 'ping' | 'close' | 'pool';

/**
 * Instance Drizzle typée pour PostgreSQL (driver `node-postgres`).
 *
 * @typeParam TSchema - Schéma Drizzle ; `Record<string, never>` tant qu'aucun schéma n'est fourni.
 */
export type DrizzleDatabase<TSchema extends DatabaseSchema = Record<string, never>> =
  NodePgDatabase<TSchema>;

/**
 * Erreur d'infrastructure de base de données, garantie exempte de credentials.
 *
 * Le message est construit à partir de l'opération et d'un code technique uniquement ;
 * le message et la pile de l'erreur native ne sont volontairement pas propagés
 * (aucune propriété `cause`).
 */
export class DatabaseClientError extends Error {
  /** Opération qui a échoué. */
  public readonly operation: DatabaseOperation;

  /** Code technique natif (SQLSTATE ou errno), `undefined` s'il est absent ou non sûr. */
  public readonly code: string | undefined;

  /**
   * @param operation - Opération qui a échoué.
   * @param code - Code technique déjà assaini, ou `undefined`.
   */
  public constructor(operation: DatabaseOperation, code: string | undefined) {
    super(
      code === undefined
        ? `Database ${operation} failed`
        : `Database ${operation} failed (code: ${code})`,
    );
    this.name = 'DatabaseClientError';
    this.operation = operation;
    this.code = code;
  }
}

/** Options de {@link createDatabaseClient}. */
export interface DatabaseClientOptions<TSchema extends DatabaseSchema = Record<string, never>> {
  /**
   * Schéma Drizzle (tables et relations), requis pour l'API relationnelle (`db.query.*`).
   * Explicite et typé : ce module ne connaît aucun schéma métier ; passer `{}` en l'absence de schéma.
   */
  readonly schema: TSchema;
  /** Configuration à utiliser ; par défaut {@link envConfig}. Utile pour les tests. */
  readonly config?: DatabaseConfig;
  /**
   * Appelé lorsqu'une connexion INACTIVE du pool échoue (coupure réseau, auto-suspend Neon…).
   * Le pool émet alors un événement `error` : sans écouteur, Node terminerait le processus.
   * Par défaut, émet un avertissement de processus assaini. Ne doit pas lever d'exception.
   */
  readonly onPoolError?: (error: DatabaseClientError) => void;
}

/**
 * Handle du client base de données, créé par {@link createDatabaseClient}.
 *
 * @typeParam TSchema - Schéma Drizzle associé à `db`.
 */
export interface DatabaseClient<TSchema extends DatabaseSchema = Record<string, never>> {
  /** Instance Drizzle à injecter dans les repositories. */
  readonly db: DrizzleDatabase<TSchema>;
  /**
   * Pool `pg` sous-jacent, exposé pour l'observabilité (`totalCount`, `idleCount`, `waitingCount`)
   * et les besoins bas niveau. Ne pas appeler `pool.end()` : utiliser {@link DatabaseClient.close}.
   */
  readonly pool: Pool;
  /**
   * Vérifie la connectivité (`SELECT 1`). À utiliser au démarrage (fail fast) ou en readiness probe.
   *
   * @throws {DatabaseClientError} Si la base est injoignable ; l'erreur ne contient aucun credential.
   */
  ping(): Promise<void>;
  /**
   * Ferme proprement le pool : attend la restitution des connexions empruntées puis les ferme.
   * Idempotente — les appels multiples partagent la même promesse.
   *
   * @throws {DatabaseClientError} Si la fermeture échoue.
   */
  close(): Promise<void>;
}

/* -------------------------------------------------------------------------- */
/* Assainissement des erreurs                                                  */
/* -------------------------------------------------------------------------- */

/**
 * Convertit une erreur native inconnue en {@link DatabaseClientError} sûre.
 *
 * Pourquoi : les messages de `pg` peuvent inclure l'utilisateur
 * (`password authentication failed for user "…"`), l'hôte ou l'IP
 * (`connect ECONNREFUSED 10.0.0.5:5432`). Seul le `code` technique, validé par
 * {@link SAFE_ERROR_CODE_PATTERN}, est conservé.
 *
 * @param operation - Opération à l'origine de l'erreur.
 * @param error - Erreur native, de type inconnu.
 * @returns Erreur assainie, sans message ni pile natifs.
 */
function toDatabaseClientError(operation: DatabaseOperation, error: unknown): DatabaseClientError {
  const code =
    typeof error === 'object' && error !== null && 'code' in error ? error.code : undefined;
  const safeCode =
    typeof code === 'string' && SAFE_ERROR_CODE_PATTERN.test(code) ? code : undefined;
  return new DatabaseClientError(operation, safeCode);
}

/**
 * Gestionnaire par défaut des erreurs de connexions inactives : avertissement de processus assaini.
 *
 * @param error - Erreur déjà assainie.
 */
function defaultPoolErrorHandler(error: DatabaseClientError): void {
  process.emitWarning(error.message, { code: POOL_ERROR_WARNING_CODE });
}

/* -------------------------------------------------------------------------- */
/* Fabrique                                                                    */
/* -------------------------------------------------------------------------- */

/**
 * Crée un client PostgreSQL/Drizzle avec son pool de connexions.
 *
 * Politique de connexion :
 * - taille maximale : `DATABASE_POOL_MAX` (jamais de valeur codée en dur) ;
 * - connexions établies paresseusement : la création du client n'ouvre aucune connexion ;
 * - TLS piloté par la chaîne de connexion (`sslmode=…`), tel que fourni par Neon et Supabase ;
 *   ce module n'impose ni ne désactive rien pour rester compatible avec un PostgreSQL local ;
 * - `keepAlive` actif et timeout d'inactivité court pour survivre aux coupures des infrastructures managées ;
 * - `application_name` = `APP_NAME`, pour identifier CORMERY dans `pg_stat_activity` ;
 * - le logger Drizzle est désactivé : son logger par défaut imprimerait les paramètres des requêtes.
 *
 * Compatibilité : aucune requête nommée (prepared statements) n'est émise implicitement,
 * ce qui reste compatible avec les poolers en mode transaction (Supabase, Neon pooled).
 *
 * Cycle de vie : l'appelant possède le client et DOIT appeler {@link DatabaseClient.close}
 * à l'arrêt de l'application (ex. `OnApplicationShutdown` NestJS).
 *
 * @typeParam TSchema - Schéma Drizzle, déduit de `options.schema`.
 * @param options - Schéma Drizzle (obligatoire), configuration et gestion d'erreur du pool (facultatives).
 * @returns Handle contenant l'instance Drizzle, le pool, `ping()` et `close()`.
 */
export function createDatabaseClient<TSchema extends DatabaseSchema>(
  options: DatabaseClientOptions<TSchema>,
): DatabaseClient<TSchema> {
  const config = options.config ?? envConfig;
  const onPoolError = options.onPoolError ?? defaultPoolErrorHandler;

  const pool = new Pool({
    connectionString: config.DATABASE_URL,
    max: config.DATABASE_POOL_MAX,
    connectionTimeoutMillis: CONNECTION_TIMEOUT_MS,
    idleTimeoutMillis: IDLE_TIMEOUT_MS,
    keepAlive: true,
    application_name: config.APP_NAME,
  });

  // Un événement `error` sans écouteur ferait tomber le processus : l'écouteur est obligatoire.
  pool.on('error', (error: Error) => {
    onPoolError(toDatabaseClientError('pool', error));
  });

  const db = drizzle({ client: pool, schema: options.schema });

  let closing: Promise<void> | undefined;

  return {
    db,
    pool,
    async ping(): Promise<void> {
      try {
        await pool.query('SELECT 1');
      } catch (error: unknown) {
        throw toDatabaseClientError('ping', error);
      }
    },
    close(): Promise<void> {
      // `pool.end()` lève si appelé deux fois : la promesse est mémorisée.
      closing ??= pool.end().catch((error: unknown) => {
        throw toDatabaseClientError('close', error);
      });
      return closing;
    },
  };
}