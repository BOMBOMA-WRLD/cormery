/**
 * @file Configuration d'environnement du backend CORMERY.
 *
 * Frontière de sécurité unique entre `process.env` et l'application :
 *
 * ```text
 * process.env → validation Zod → configuration typée et gelée → services
 * ```
 *
 * Règles d'architecture :
 * - ce module est la SEULE porte d'entrée vers `process.env` ; aucun service ne doit le lire ;
 * - il n'importe aucun module métier ni SDK d'infrastructure (couche feuille, pas de cycle) ;
 * - il ne charge pas de fichier `.env` : le chargement (`node --env-file`, Docker, Supabase, CI…)
 *   relève du bootstrap, afin que ce module reste pur et testable ;
 * - la validation est exécutée une seule fois à l'initialisation du module (fail fast) ;
 * - aucune valeur secrète n'apparaît jamais dans les erreurs ni dans les résumés destinés aux logs.
 */
import { z } from 'zod';

/* -------------------------------------------------------------------------- */
/* Constantes                                                                  */
/* -------------------------------------------------------------------------- */

/** Environnements d'exécution autorisés. Toute autre valeur est rejetée. */
export const NODE_ENVIRONMENTS = ['development', 'test', 'production'] as const;

/** Niveaux de log autorisés (alignés sur les niveaux usuels de pino). */
export const LOG_LEVELS = ['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'] as const;

/** Environnement d'exécution validé. */
export type NodeEnvironment = (typeof NODE_ENVIRONMENTS)[number];

/** Niveau de log validé. */
export type LogLevel = (typeof LOG_LEVELS)[number];

/**
 * Source de variables d'environnement. Découplée de `process.env` pour rendre
 * {@link loadEnv} testable avec des jeux de variables arbitraires.
 */
export type EnvSource = Readonly<Record<string, string | undefined>>;

/** Redis local, utilisé uniquement hors production lorsque `REDIS_URL` est absent (aucun credential). */
const DEFAULT_LOCAL_REDIS_URL = 'redis://127.0.0.1:6379';

/** Longueur minimale du secret JWT en production (≥ 256 bits d'entropie potentielle en hex/base64). */
const MIN_PRODUCTION_JWT_SECRET_LENGTH = 32;

/** Valeurs de secret manifestement factices, refusées en production. */
const PLACEHOLDER_SECRET_PATTERN =
  /^(changeme|change[-_]?me|replace[-_]?me|your[-_].*|secret|password|default|example|todo|x{4,})$/i;

/** Modes SSL PostgreSQL qui désactivent ou rendent facultatif le chiffrement. */
const INSECURE_SSL_MODES: ReadonlySet<string> = new Set(['disable', 'allow']);

/** Format d'une durée : entier + unité optionnelle (secondes par défaut). */
const DURATION_PATTERN = /^(\d+)([smhdw])?$/;

/** Multiplicateurs de durée vers les secondes. */
const DURATION_UNIT_SECONDS: Readonly<Record<string, number>> = {
  s: 1,
  m: 60,
  h: 3_600,
  d: 86_400,
  w: 604_800,
};

/* -------------------------------------------------------------------------- */
/* Utilitaires de parsing (purs, sans effet de bord)                           */
/* -------------------------------------------------------------------------- */

/**
 * Normalise une chaîne vide ou blanche en `undefined`.
 *
 * Pourquoi : les orchestrateurs (Docker, CI) exportent fréquemment `VAR=` ;
 * une valeur vide doit être traitée comme « non définie » et non comme une valeur valide.
 *
 * @param value - Valeur brute issue de l'environnement.
 * @returns `undefined` si la valeur est une chaîne vide/blanche, sinon la valeur inchangée.
 */
function emptyToUndefined(value: unknown): unknown {
  return typeof value === 'string' && value.trim() === '' ? undefined : value;
}

/**
 * Convertit explicitement un littéral booléen textuel.
 *
 * Pourquoi : `Boolean("false") === true`. Seuls `true|1|yes|on` et `false|0|no|off`
 * (insensibles à la casse) sont reconnus ; toute autre chaîne reste telle quelle
 * et sera rejetée par `z.boolean()`.
 *
 * @param value - Valeur brute issue de l'environnement.
 * @returns Un booléen, `undefined` si vide, ou la valeur d'origine si non reconnue.
 */
function parseBooleanLiteral(value: unknown): unknown {
  if (typeof value !== 'string') return value;
  const normalized = value.trim().toLowerCase();
  if (normalized === '') return undefined;
  if (normalized === 'true' || normalized === '1' || normalized === 'yes' || normalized === 'on') {
    return true;
  }
  if (normalized === 'false' || normalized === '0' || normalized === 'no' || normalized === 'off') {
    return false;
  }
  return value;
}

/**
 * Convertit strictement un entier décimal textuel.
 *
 * Pourquoi : `Number("0x10")` ou `Number("1e3")` produisent des valeurs surprenantes ;
 * seuls les entiers décimaux positifs sont acceptés.
 *
 * @param value - Valeur brute issue de l'environnement.
 * @returns Un nombre, `undefined` si vide, ou la valeur d'origine si non conforme.
 */
function parseIntegerLiteral(value: unknown): unknown {
  if (typeof value !== 'string') return value;
  const trimmed = value.trim();
  if (trimmed === '') return undefined;
  return /^\d+$/.test(trimmed) ? Number(trimmed) : value;
}

/**
 * Convertit une durée (`900`, `15m`, `1h`, `7d`, `2w`) en secondes.
 *
 * Pourquoi : les futurs modules d'authentification consomment une valeur numérique
 * et ne doivent pas réimplémenter ce parsing. Le format est validé en amont par regex.
 *
 * @param value - Durée textuelle déjà validée par {@link DURATION_PATTERN}.
 * @returns Durée en secondes (0 si le format est invalide, cas rejeté ensuite par le schéma).
 */
function parseDurationToSeconds(value: string): number {
  const match = DURATION_PATTERN.exec(value);
  const amount = Number(match?.[1] ?? '0');
  const multiplier = DURATION_UNIT_SECONDS[match?.[2] ?? 's'] ?? 1;
  return amount * multiplier;
}

/**
 * Découpe une liste séparée par des virgules.
 *
 * @param raw - Chaîne brute ou `undefined`.
 * @returns Entrées nettoyées et non vides, ou `undefined` si la variable n'est pas définie.
 */
function splitCommaList(raw: string | undefined): string[] | undefined {
  if (raw === undefined) return undefined;
  return raw
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry !== '');
}

/**
 * Indique si une chaîne est une URL valide dont le protocole fait partie de la liste.
 *
 * @param value - URL à tester.
 * @param protocols - Protocoles acceptés, avec deux-points final (ex. `https:`).
 * @returns `true` si l'URL est parsable et son protocole autorisé.
 */
function hasProtocol(value: string, protocols: ReadonlyArray<string>): boolean {
  try {
    return protocols.includes(new URL(value).protocol);
  } catch {
    return false;
  }
}

/**
 * Indique si une entrée CORS est une origine canonique (`scheme://host[:port]`,
 * minuscules, sans chemin ni slash final).
 *
 * @param entry - Entrée de la liste `CORS_ORIGIN`.
 * @returns `true` si l'entrée est une origine http(s) canonique.
 */
function isCanonicalOrigin(entry: string): boolean {
  try {
    const url = new URL(entry);
    return (url.protocol === 'http:' || url.protocol === 'https:') && url.origin === entry;
  } catch {
    return false;
  }
}

/**
 * Lit un paramètre de query d'une URL sans jamais exposer l'URL.
 *
 * @param value - URL (potentiellement porteuse de credentials).
 * @param name - Nom du paramètre.
 * @returns La valeur du paramètre en minuscules, ou `undefined`.
 */
function readUrlParameter(value: string, name: string): string | undefined {
  try {
    return new URL(value).searchParams.get(name)?.toLowerCase() ?? undefined;
  } catch {
    return undefined;
  }
}

/**
 * Indique si une valeur d'environnement est présente (non vide).
 *
 * @param value - Valeur brute.
 * @returns `true` si la valeur est une chaîne non blanche.
 */
function isPresent(value: string | undefined): boolean {
  return value !== undefined && value.trim() !== '';
}

/**
 * Niveau de log par défaut selon l'environnement (silencieux en test).
 *
 * @param nodeEnv - Environnement validé.
 * @returns Niveau de log par défaut.
 */
function defaultLogLevel(nodeEnv: NodeEnvironment): LogLevel {
  return nodeEnv === 'test' ? 'silent' : 'info';
}

/**
 * Activation Prometheus par défaut : désactivée en test pour éviter les conflits
 * de port entre suites parallèles, activée sinon.
 *
 * @param nodeEnv - Environnement validé.
 * @returns `true` si Prometheus doit être actif par défaut.
 */
function defaultPrometheusEnabled(nodeEnv: NodeEnvironment): boolean {
  return nodeEnv !== 'test';
}

/* -------------------------------------------------------------------------- */
/* Fabriques de schémas Zod                                                    */
/* -------------------------------------------------------------------------- */

/**
 * Entier borné avec valeur par défaut, lu depuis une chaîne d'environnement.
 *
 * @param min - Borne minimale incluse.
 * @param max - Borne maximale incluse.
 * @param fallback - Valeur appliquée si la variable est absente ou vide.
 * @returns Schéma Zod produisant un `number`.
 */
function boundedInteger(min: number, max: number, fallback: number) {
  return z.preprocess(parseIntegerLiteral, z.number().int().min(min).max(max).default(fallback));
}

/**
 * Chaîne secrète optionnelle (API keys, clés Supabase, secret JWT).
 * Les règles de présence/force dépendant de l'environnement sont appliquées
 * par {@link validateEnvironmentRules}.
 *
 * @returns Schéma Zod produisant `string | undefined`.
 */
function optionalSecret() {
  return z.preprocess(emptyToUndefined, z.string().trim().min(1).optional());
}

/**
 * URL http(s) valide. Les autres protocoles (`javascript:`, `file:`…) sont refusés.
 *
 * @returns Schéma Zod produisant une `string`.
 */
function httpUrl() {
  return z
    .string()
    .trim()
    .refine((value) => hasProtocol(value, ['http:', 'https:']), 'must be a valid http(s) URL');
}

/**
 * URL http(s) optionnelle (endpoints configurables des fournisseurs IA, Supabase).
 *
 * @returns Schéma Zod produisant `string | undefined`.
 */
function optionalHttpUrl() {
  return z.preprocess(emptyToUndefined, httpUrl().optional());
}

/**
 * Booléen optionnel avec conversion explicite et sûre.
 *
 * @returns Schéma Zod produisant `boolean | undefined`.
 */
function optionalBoolean() {
  return z.preprocess(parseBooleanLiteral, z.boolean().optional());
}

/* -------------------------------------------------------------------------- */
/* Schéma                                                                      */
/* -------------------------------------------------------------------------- */

/**
 * Forme brute du schéma : une entrée par variable d'environnement lue par le backend.
 * C'est l'unique endroit qui déclare les noms de variables (source de vérité).
 *
 * Les défauts ne portent jamais sur un secret. `NODE_ENV` vaut `production` par défaut :
 * l'absence de la variable ne doit jamais assouplir silencieusement la sécurité.
 */
const envShape = {
  /* Application */
  NODE_ENV: z.preprocess(emptyToUndefined, z.enum(NODE_ENVIRONMENTS).default('production')),
  PORT: boundedInteger(1, 65_535, 3_000),
  HOST: z.preprocess(
    emptyToUndefined,
    z.string().trim().regex(/^\S+$/, 'must not contain whitespace').default('127.0.0.1'),
  ),
  APP_NAME: z.preprocess(
    emptyToUndefined,
    z.string().trim().min(1).max(64).default('cormery-backend'),
  ),
  APP_VERSION: z.preprocess(
    emptyToUndefined,
    z
      .string()
      .trim()
      .regex(/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.+-]+)?$/, 'must follow semantic versioning (e.g. 1.2.3)')
      .default('0.0.0'),
  ),
  LOG_LEVEL: z.preprocess(emptyToUndefined, z.enum(LOG_LEVELS).optional()),

  /* PostgreSQL / Drizzle */
  DATABASE_URL: z.preprocess(
    emptyToUndefined,
    z
      .string()
      .trim()
      .refine(
        (value) => hasProtocol(value, ['postgres:', 'postgresql:']),
        'must be a valid postgres:// or postgresql:// URL',
      ),
  ),
  DATABASE_POOL_MAX: boundedInteger(1, 100, 10),

  /* Redis / BullMQ */
  REDIS_URL: z.preprocess(
    emptyToUndefined,
    z
      .string()
      .trim()
      .refine(
        (value) => hasProtocol(value, ['redis:', 'rediss:']),
        'must be a valid redis:// or rediss:// URL',
      )
      .optional(),
  ),
  REDIS_KEY_PREFIX: z.preprocess(
    emptyToUndefined,
    z
      .string()
      .trim()
      .regex(/^[A-Za-z0-9:_-]{1,64}$/, 'must match [A-Za-z0-9:_-] (1-64 chars)')
      .default('cormery'),
  ),

  /* Supabase (côté serveur uniquement) */
  SUPABASE_URL: optionalHttpUrl(),
  SUPABASE_ANON_KEY: optionalSecret(),
  SUPABASE_SERVICE_ROLE_KEY: optionalSecret(),

  /* Authentification */
  JWT_SECRET: optionalSecret(),
  JWT_EXPIRES_IN: z.preprocess(
    emptyToUndefined,
    z
      .string()
      .trim()
      .regex(DURATION_PATTERN, 'must be a duration such as 900, 15m, 1h or 7d')
      .default('1h')
      .transform(parseDurationToSeconds)
      .refine((seconds) => seconds > 0 && Number.isSafeInteger(seconds), 'must be a positive duration'),
  ),

  /* CORS : liste séparée par des virgules ; absente = aucune origine cross-origin autorisée */
  CORS_ORIGIN: z
    .preprocess(emptyToUndefined, z.string().trim().optional())
    .transform(splitCommaList),

  /* Fournisseurs IA : tous optionnels, le Provider Manager déterminera les disponibles */
  MISTRAL_API_KEY: optionalSecret(),
  MISTRAL_BASE_URL: optionalHttpUrl(),
  DEEPSEEK_API_KEY: optionalSecret(),
  DEEPSEEK_BASE_URL: optionalHttpUrl(),
  ANTHROPIC_API_KEY: optionalSecret(),
  ANTHROPIC_BASE_URL: optionalHttpUrl(),
  QWEN_API_KEY: optionalSecret(),
  QWEN_BASE_URL: optionalHttpUrl(),
  HUGGINGFACE_API_KEY: optionalSecret(),
  HUGGINGFACE_BASE_URL: optionalHttpUrl(),

  /* Observabilité */
  PROMETHEUS_ENABLED: optionalBoolean(),
  PROMETHEUS_PORT: boundedInteger(1, 65_535, 9_464),
} as const;

const envObjectSchema = z.object(envShape);

/** Sortie du schéma avant règles inter-champs et résolution des valeurs par défaut dépendantes de l'environnement. */
type RawEnv = z.output<typeof envObjectSchema>;

/**
 * Variables dont la valeur ne doit JAMAIS apparaître dans un log ou une erreur.
 * `DATABASE_URL` et `REDIS_URL` y figurent car elles embarquent des credentials.
 */
export const SECRET_ENV_KEYS = [
  'DATABASE_URL',
  'REDIS_URL',
  'SUPABASE_ANON_KEY',
  'SUPABASE_SERVICE_ROLE_KEY',
  'JWT_SECRET',
  'MISTRAL_API_KEY',
  'DEEPSEEK_API_KEY',
  'ANTHROPIC_API_KEY',
  'QWEN_API_KEY',
  'HUGGINGFACE_API_KEY',
] as const satisfies ReadonlyArray<keyof typeof envShape>;

const SECRET_KEY_SET: ReadonlySet<string> = new Set<string>(SECRET_ENV_KEYS);

/** Noms de toutes les variables d'environnement lues par le backend (source unique de vérité). */
export const ENV_VARIABLE_NAMES: readonly string[] = Object.freeze(Object.keys(envShape));

/** Endpoints des fournisseurs IA, contraints à https en production. */
const AI_BASE_URL_KEYS = [
  'MISTRAL_BASE_URL',
  'DEEPSEEK_BASE_URL',
  'ANTHROPIC_BASE_URL',
  'QWEN_BASE_URL',
  'HUGGINGFACE_BASE_URL',
] as const satisfies ReadonlyArray<keyof RawEnv>;

/** Callback de signalement d'un problème de configuration (sans jamais transmettre de valeur). */
type IssueReporter = (key: keyof RawEnv, message: string) => void;

/**
 * Applique les règles inter-champs et la politique par environnement.
 *
 * Politique : `development` flexible, `test` contrôlé (silencieux, sans Prometheus par défaut),
 * `production` stricte (secrets obligatoires, configurations dangereuses refusées).
 * Les messages ne contiennent jamais de valeur de variable.
 *
 * @param env - Variables déjà validées individuellement.
 * @param report - Callback de signalement d'un problème.
 */
function validateEnvironmentRules(env: RawEnv, report: IssueReporter): void {
  const production = env.NODE_ENV === 'production';

  // Observabilité : le endpoint de métriques ne doit pas entrer en collision avec l'API.
  const prometheusEnabled = env.PROMETHEUS_ENABLED ?? defaultPrometheusEnabled(env.NODE_ENV);
  if (prometheusEnabled && env.PROMETHEUS_PORT === env.PORT) {
    report('PROMETHEUS_PORT', 'must differ from PORT when Prometheus is enabled');
  }

  // Base de données : chiffrement explicitement désactivé interdit en production.
  if (production) {
    const sslMode = readUrlParameter(env.DATABASE_URL, 'sslmode');
    if (sslMode !== undefined && INSECURE_SSL_MODES.has(sslMode)) {
      report('DATABASE_URL', 'sslmode must not disable or make TLS optional in production');
    }
  }

  // Redis : pas de défaut implicite en production.
  if (production && env.REDIS_URL === undefined) {
    report('REDIS_URL', 'is required in production');
  }

  // Supabase : URL et clé service-role vont de pair ; obligatoires en production.
  const hasSupabaseUrl = env.SUPABASE_URL !== undefined;
  const hasServiceRoleKey = env.SUPABASE_SERVICE_ROLE_KEY !== undefined;
  if (production) {
    if (!hasSupabaseUrl) report('SUPABASE_URL', 'is required in production');
    if (!hasServiceRoleKey) report('SUPABASE_SERVICE_ROLE_KEY', 'is required in production');
    if (env.SUPABASE_URL !== undefined && !hasProtocol(env.SUPABASE_URL, ['https:'])) {
      report('SUPABASE_URL', 'must use https in production');
    }
  } else if (hasSupabaseUrl !== hasServiceRoleKey) {
    report(
      hasSupabaseUrl ? 'SUPABASE_SERVICE_ROLE_KEY' : 'SUPABASE_URL',
      'must be provided together with the other Supabase server variable',
    );
  }

  // JWT : obligatoire, long et non factice en production.
  if (production) {
    const secret = env.JWT_SECRET;
    if (secret === undefined) {
      report('JWT_SECRET', 'is required in production');
    } else if (secret.length < MIN_PRODUCTION_JWT_SECRET_LENGTH) {
      report(
        'JWT_SECRET',
        `must contain at least ${String(MIN_PRODUCTION_JWT_SECRET_LENGTH)} characters in production`,
      );
    } else if (PLACEHOLDER_SECRET_PATTERN.test(secret)) {
      report('JWT_SECRET', 'must not be a placeholder value in production');
    }
  }

  // CORS : liste explicite ; wildcard et http refusés en production.
  if (env.CORS_ORIGIN !== undefined) {
    if (env.CORS_ORIGIN.length === 0) {
      report('CORS_ORIGIN', 'must contain at least one origin when set');
    }
    for (const origin of env.CORS_ORIGIN) {
      if (origin === '*') {
        if (production) report('CORS_ORIGIN', 'wildcard "*" is forbidden in production');
      } else if (!isCanonicalOrigin(origin)) {
        report(
          'CORS_ORIGIN',
          'entries must be canonical origins (scheme://host[:port], lowercase, no path or trailing slash)',
        );
      } else if (production && !origin.startsWith('https://')) {
        report('CORS_ORIGIN', 'entries must use https in production');
      }
    }
  }

  // Endpoints IA : https obligatoire en production (les clés y transitent).
  if (production) {
    for (const key of AI_BASE_URL_KEYS) {
      const value = env[key];
      if (value !== undefined && !hasProtocol(value, ['https:'])) {
        report(key, 'must use https in production');
      }
    }
  }
}

/**
 * Schéma Zod complet de la configuration backend CORMERY.
 *
 * Enchaîne : validation/coercition champ par champ → règles inter-champs et production →
 * résolution des valeurs par défaut dépendantes de l'environnement (log, Prometheus, Redis local)
 * → ajout des indicateurs `IS_*`. Les clés inconnues de `process.env` sont ignorées.
 *
 * Note : Zod n'exécute les règles inter-champs qu'une fois tous les champs individuellement
 * valides ; les erreurs peuvent donc apparaître en deux passes.
 */
export const envSchema = envObjectSchema
  .superRefine((env, ctx) => {
    validateEnvironmentRules(env, (key, message) => {
      ctx.addIssue({ code: 'custom', path: [key], message });
    });
  })
  .transform((env) => ({
    ...env,
    LOG_LEVEL: env.LOG_LEVEL ?? defaultLogLevel(env.NODE_ENV),
    PROMETHEUS_ENABLED: env.PROMETHEUS_ENABLED ?? defaultPrometheusEnabled(env.NODE_ENV),
    REDIS_URL: env.REDIS_URL ?? DEFAULT_LOCAL_REDIS_URL,
    CORS_ORIGIN: Object.freeze([...new Set(env.CORS_ORIGIN ?? [])]),
    IS_PRODUCTION: env.NODE_ENV === 'production',
    IS_DEVELOPMENT: env.NODE_ENV === 'development',
    IS_TEST: env.NODE_ENV === 'test',
  }));

/**
 * Configuration validée et immuable du backend.
 *
 * Particularités : `JWT_EXPIRES_IN` est exprimé en secondes ; `CORS_ORIGIN` est une liste
 * d'origines dédupliquée (vide = aucune origine cross-origin) ; `LOG_LEVEL`, `PROMETHEUS_ENABLED`
 * et `REDIS_URL` sont toujours résolus ; `IS_PRODUCTION | IS_DEVELOPMENT | IS_TEST` sont dérivés de `NODE_ENV`.
 */
export type EnvConfig = Readonly<z.output<typeof envSchema>>;

/* -------------------------------------------------------------------------- */
/* Erreurs                                                                     */
/* -------------------------------------------------------------------------- */

/** Forme minimale d'un problème Zod, indépendante de la version majeure de Zod. */
interface IssueLike {
  readonly code: string;
  readonly message: string;
  readonly path: ReadonlyArray<PropertyKey>;
}

/**
 * Erreur levée lorsque l'environnement est invalide.
 * Le message liste les variables en cause, sans jamais inclure de valeur.
 */
export class EnvValidationError extends Error {
  /** Problèmes détectés, une ligne par variable (ex. `DATABASE_URL: missing`). */
  public readonly issues: readonly string[];

  /**
   * @param issues - Descriptions déjà masquées des problèmes détectés.
   */
  public constructor(issues: readonly string[]) {
    super(
      `Invalid environment configuration:\n${issues.map((issue) => `  - ${issue}`).join('\n')}`,
    );
    this.name = 'EnvValidationError';
    this.issues = Object.freeze([...issues]);
  }
}

/**
 * Décrit un problème Zod sans jamais révéler de valeur.
 *
 * Pourquoi : les messages par défaut de Zod peuvent citer la valeur reçue ; pour les variables
 * secrètes on n'expose donc que présence/absence ou un motif générique. Les messages `custom`
 * sont ceux rédigés dans ce fichier et ne contiennent aucune valeur.
 *
 * @param issue - Problème Zod.
 * @param source - Source d'environnement (utilisée uniquement pour tester la présence).
 * @returns Ligne de diagnostic masquée.
 */
function describeIssue(issue: IssueLike, source: EnvSource): string {
  const first = issue.path[0];
  const key = typeof first === 'string' ? first : '(root)';
  if (issue.code === 'custom') return `${key}: ${issue.message}`;
  if (key !== '(root)' && !isPresent(source[key])) return `${key}: missing`;
  if (SECRET_KEY_SET.has(key)) {
    return issue.code === 'too_small'
      ? `${key}: too short (value masked)`
      : `${key}: invalid (value masked)`;
  }
  return `${key}: ${issue.message}`;
}

/* -------------------------------------------------------------------------- */
/* API publique                                                                */
/* -------------------------------------------------------------------------- */

/**
 * Valide une source d'environnement et retourne la configuration typée et gelée.
 *
 * Exportée pour les tests unitaires (Vitest) ; le code applicatif doit utiliser {@link envConfig}.
 *
 * @param source - Variables à valider (par défaut `process.env`).
 * @returns Configuration validée, immuable (gel superficiel ; les listes sont elles-mêmes gelées).
 * @throws {EnvValidationError} Si au moins une variable est manquante ou invalide.
 */
export function loadEnv(source: EnvSource = process.env): EnvConfig {
  const result = envSchema.safeParse(source);
  if (!result.success) {
    const lines = result.error.issues.map((issue) => describeIssue(issue, source));
    throw new EnvValidationError([...new Set(lines)]);
  }
  return Object.freeze(result.data);
}

/**
 * Produit un résumé de configuration sûr pour les logs : les secrets sont remplacés
 * par `[REDACTED]` (ou `unset`), les autres valeurs sont converties en texte.
 *
 * @param config - Configuration validée.
 * @returns Dictionnaire nom → valeur textuelle, sans aucun secret.
 */
export function describeEnvForLogs(config: EnvConfig): Readonly<Record<string, string>> {
  const summary: Record<string, string> = {};
  const entries: ReadonlyArray<readonly [string, unknown]> = Object.entries(config);
  for (const [key, value] of entries) {
    if (SECRET_KEY_SET.has(key)) {
      summary[key] = value === undefined ? 'unset' : '[REDACTED]';
    } else {
      summary[key] = Array.isArray(value) ? JSON.stringify(value) : String(value);
    }
  }
  return Object.freeze(summary);
}

/**
 * Configuration validée du backend, calculée UNE SEULE fois à l'import du module.
 * Si l'environnement est invalide, l'import lève {@link EnvValidationError} (fail fast).
 */
export const envConfig: EnvConfig = loadEnv();