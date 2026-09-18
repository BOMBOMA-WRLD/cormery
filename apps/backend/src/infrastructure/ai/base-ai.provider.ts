/**
 * @file base-ai.provider.ts
 *
 * Contrat abstrait commun à tous les fournisseurs d'intelligence artificielle
 * de CORMERY.
 *
 * Position dans l'architecture :
 *
 *   Services applicatifs → AI Provider Manager → BaseAIProvider → providers concrets
 *
 * Ce fichier est volontairement :
 * - indépendant de tout SDK ou fournisseur (Mistral, Qwen, DeepSeek, Claude, Hugging Face…),
 * - dépourvu d'appel réseau, de lecture d'environnement, de journalisation et de logique métier,
 * - sans import : il ne crée aucun couplage avec CORE, ILIADE, FUTURE ou l'infrastructure.
 *
 * Hypothèses d'architecture :
 * - Les credentials sont injectés dans les providers concrets par leur propre
 *   constructeur/configuration ; ils ne transitent JAMAIS par les types définis ici.
 * - Le Provider Manager (fichier ultérieur) porte le routage, le failover, les quotas
 *   et les retries. Ce contrat se limite à décrire et à exposer ce que fait un provider.
 * - Le type global `AbortSignal` est supposé disponible (Node.js LTS).
 */

/* -------------------------------------------------------------------------- */
/*  Types JSON utilitaires                                                    */
/* -------------------------------------------------------------------------- */

/**
 * Valeur JSON sérialisable.
 *
 * Remplace `any`/`unknown` pour les données structurées (schémas, arguments d'outils,
 * sorties structurées) afin de garder un typage strict sans dépendre d'une
 * bibliothèque de schéma (Zod, etc.) : le contrat reste neutre.
 */
export type JsonValue =
  | string
  | number
  | boolean
  | null
  | readonly JsonValue[]
  | { readonly [key: string]: JsonValue };

/**
 * Objet JSON sérialisable.
 */
export type JsonObject = { readonly [key: string]: JsonValue };

/**
 * Métadonnées techniques NON SENSIBLES associées à une requête, une réponse ou une erreur
 * (ex. identifiant de corrélation, nom de tâche, version de prompt).
 *
 * Pourquoi un type aussi restreint : limiter la surface où un secret pourrait être
 * transporté par inadvertance. Il est interdit d'y placer clé API, en-tête
 * d'autorisation, token ou donnée personnelle.
 */
export type AIMetadata = Readonly<Record<string, string | number | boolean>>;

/* -------------------------------------------------------------------------- */
/*  Identité, modèles et capacités                                            */
/* -------------------------------------------------------------------------- */

/**
 * Identifiant unique et stable d'un provider (ex. `"mistral"`, `"claude"`).
 *
 * Volontairement typé `string` et non comme union fermée : ajouter OpenAI, Gemini
 * ou un provider self-hosted ne doit pas obliger à modifier ce contrat fondamental.
 */
export type AIProviderId = string;

/**
 * Identifiant d'un modèle tel que compris par le provider (ex. nom de modèle commercial).
 * Opaque pour le contrat : seul le provider concret en connaît la sémantique.
 */
export type AIModelId = string;

/**
 * Liste exhaustive (à la date d'écriture) des capacités connues.
 * Source unique de vérité pour le type {@link AICapability}.
 *
 * Les capacités sont déclaratives : aucun provider n'est supposé toutes les supporter.
 */
export const AI_CAPABILITIES = [
  'text_generation',
  'chat',
  'structured_output',
  'embeddings',
  'vision',
  'tool_calling',
  'streaming',
] as const;

/**
 * Capacité fonctionnelle qu'un provider ou un modèle peut déclarer.
 *
 * Pourquoi une union de littéraux : le Provider Manager peut router selon les
 * capacités requises, et le compilateur détecte toute capacité inconnue.
 */
export type AICapability = (typeof AI_CAPABILITIES)[number];

/**
 * Description d'un modèle exposé par un provider.
 *
 * Les capacités sont déclarées PAR MODÈLE car, chez un même fournisseur,
 * tous les modèles ne supportent pas les mêmes fonctions (ex. vision, embeddings).
 */
export interface AIModelDescriptor {
  /** Identifiant du modèle utilisable dans une requête. */
  readonly id: AIModelId;
  /** Nom lisible, si différent de l'identifiant. */
  readonly displayName?: string;
  /** Capacités précisément supportées par ce modèle. */
  readonly capabilities: readonly AICapability[];
  /** Taille maximale de contexte en tokens, si connue. */
  readonly contextWindowTokens?: number;
  /** Nombre maximal de tokens de sortie, si connu. */
  readonly maxOutputTokens?: number;
  /** Indique un modèle en fin de vie, à éviter pour de nouveaux usages. */
  readonly deprecated?: boolean;
}

/**
 * Limites opérationnelles déclarées par un provider (toutes optionnelles).
 *
 * Elles sont informatives : le Provider Manager décide de leur application
 * (quotas, back-pressure, timeouts). Aucune limite n'est appliquée ici.
 */
export interface AIProviderLimits {
  readonly maxRequestsPerMinute?: number;
  readonly maxTokensPerMinute?: number;
  readonly maxConcurrentRequests?: number;
  /** Timeout par défaut recommandé, en millisecondes. */
  readonly defaultTimeoutMs?: number;
}

/**
 * Photographie déclarative de ce qu'un provider supporte.
 */
export interface AIProviderCapabilities {
  /** Identifiant du provider concerné. */
  readonly providerId: AIProviderId;
  /** Modèles supportés, avec leurs capacités propres. */
  readonly models: readonly AIModelDescriptor[];
  /** Union des capacités de tous les modèles (vue rapide pour le routage). */
  readonly capabilities: readonly AICapability[];
  /** Limites opérationnelles éventuelles. */
  readonly limits?: AIProviderLimits;
}

/* -------------------------------------------------------------------------- */
/*  Statut de disponibilité                                                   */
/* -------------------------------------------------------------------------- */

/**
 * État de disponibilité d'un provider.
 *
 * - `available` : opérationnel.
 * - `degraded` : utilisable mais dégradé (latence, erreurs partielles).
 * - `unavailable` : à ne pas utiliser.
 * - `unknown` : pas d'information fiable (ex. provider jamais sondé).
 */
export type AIProviderState = 'available' | 'degraded' | 'unavailable' | 'unknown';

/**
 * Résultat d'un contrôle de santé.
 *
 * `reason` est un texte court destiné à l'observabilité ; il ne doit contenir
 * aucun secret ni contenu de requête.
 */
export interface AIProviderStatus {
  readonly providerId: AIProviderId;
  readonly state: AIProviderState;
  /** Horodatage ISO 8601 du contrôle. */
  readonly checkedAt: string;
  /** Latence du contrôle en millisecondes, si mesurée. */
  readonly latencyMs?: number;
  /** Explication courte et non sensible. */
  readonly reason?: string;
}

/* -------------------------------------------------------------------------- */
/*  Messages et contenu                                                       */
/* -------------------------------------------------------------------------- */

/**
 * Rôle d'un message dans une conversation.
 * `tool` porte le résultat d'un appel d'outil renvoyé au modèle.
 */
export type AIMessageRole = 'system' | 'user' | 'assistant' | 'tool';

/**
 * Source d'une image (capacité `vision`).
 * Union discriminée : URL distante ou données encodées en base64.
 */
export type AIImageSource =
  | { readonly kind: 'url'; readonly url: string }
  | { readonly kind: 'base64'; readonly mediaType: string; readonly data: string };

/**
 * Appel d'outil demandé par le modèle.
 * Ce contrat ne fait que le représenter : AUCUN outil n'est exécuté ici.
 */
export interface AIToolCall {
  /** Identifiant de l'appel, utilisé pour corréler le résultat. */
  readonly id: string;
  /** Nom de l'outil demandé. */
  readonly name: string;
  /** Arguments décodés (JSON). */
  readonly arguments: JsonObject;
}

/**
 * Fragment de contenu d'un message (union discriminée sur `type`).
 *
 * Pourquoi des fragments plutôt qu'une simple chaîne : permettre le multimodal
 * et les tools sans changer le contrat pour chaque nouveau fournisseur.
 */
export type AIContentPart =
  | { readonly type: 'text'; readonly text: string }
  | { readonly type: 'image'; readonly source: AIImageSource }
  | { readonly type: 'tool_call'; readonly toolCall: AIToolCall }
  | {
      readonly type: 'tool_result';
      readonly toolCallId: string;
      readonly content: string;
      readonly isError?: boolean;
    };

/**
 * Message d'une conversation.
 */
export interface AIMessage {
  readonly role: AIMessageRole;
  readonly content: readonly AIContentPart[];
}

/* -------------------------------------------------------------------------- */
/*  Sortie structurée et outils                                               */
/* -------------------------------------------------------------------------- */

/**
 * Format de réponse demandé (capacité `structured_output` pour les variantes JSON).
 *
 * Le schéma est un objet JSON générique : le contrat n'impose aucune
 * bibliothèque de validation.
 */
export type AIResponseFormat =
  | { readonly type: 'text' }
  | { readonly type: 'json_object' }
  | {
      readonly type: 'json_schema';
      readonly name: string;
      readonly schema: JsonObject;
    };

/**
 * Définition d'un outil que le modèle peut demander d'appeler
 * (capacité `tool_calling`). Description seulement : pas d'exécution.
 */
export interface AIToolDefinition {
  readonly name: string;
  readonly description: string;
  /** Schéma JSON des paramètres. */
  readonly parametersSchema: JsonObject;
}

/**
 * Politique de choix d'outil.
 */
export type AIToolChoice =
  | 'auto'
  | 'none'
  | 'required'
  | { readonly type: 'tool'; readonly name: string };

/* -------------------------------------------------------------------------- */
/*  Requêtes                                                                  */
/* -------------------------------------------------------------------------- */

/**
 * Options communes à toutes les requêtes AI.
 *
 * SÉCURITÉ : aucun champ ne doit transporter de secret ou de credential.
 * Les credentials appartiennent à la configuration interne du provider concret.
 */
export interface AIRequestOptions {
  /** Modèle ciblé. */
  readonly model: AIModelId;
  /** Timeout en millisecondes ; la valeur par défaut relève du provider/manager. */
  readonly timeoutMs?: number;
  /** Signal d'annulation coopératif. */
  readonly signal?: AbortSignal;
  /** Métadonnées techniques non sensibles (corrélation, traçabilité). */
  readonly metadata?: AIMetadata;
}

/**
 * Requête de génération (capacités `text_generation` / `chat`).
 *
 * `messages` est le mode conversationnel canonique : un simple prompt s'exprime
 * par un message `user` contenant un fragment `text`.
 */
export interface AIGenerationRequest extends AIRequestOptions {
  readonly messages: readonly AIMessage[];
  /** Instruction système, séparée des messages car certains providers la traitent à part. */
  readonly systemInstruction?: string;
  /** Température d'échantillonnage, si applicable. */
  readonly temperature?: number;
  /** Nombre maximal de tokens générés, si applicable. */
  readonly maxTokens?: number;
  /** Format de sortie souhaité (structured output). */
  readonly responseFormat?: AIResponseFormat;
  /** Outils disponibles pour le modèle (tool calling). */
  readonly tools?: readonly AIToolDefinition[];
  /** Politique de choix d'outil. */
  readonly toolChoice?: AIToolChoice;
  /** Demande de streaming ; pertinent pour {@link BaseAIProvider.generateStream}. */
  readonly stream?: boolean;
}

/**
 * Requête d'embeddings (capacité `embeddings`).
 */
export interface AIEmbeddingRequest extends AIRequestOptions {
  /** Textes à vectoriser. */
  readonly input: readonly string[];
  /** Dimension souhaitée, si le modèle la supporte. */
  readonly dimensions?: number;
}

/* -------------------------------------------------------------------------- */
/*  Usage et réponses                                                         */
/* -------------------------------------------------------------------------- */

/**
 * Consommation en tokens.
 *
 * Tous les champs sont optionnels : un provider qui ne les fournit pas peut
 * retourner un usage vide (ou omettre `usage`) sans casser le contrat.
 */
export interface AIUsage {
  readonly inputTokens?: number;
  readonly outputTokens?: number;
  readonly totalTokens?: number;
}

/**
 * Raison de fin de génération, normalisée entre providers.
 * `other` couvre les valeurs propres à un fournisseur (voir `rawFinishReason`).
 */
export type AIFinishReason =
  | 'stop'
  | 'length'
  | 'tool_calls'
  | 'content_filter'
  | 'error'
  | 'other';

/**
 * Réponse de génération commune.
 */
export interface AIGenerationResponse {
  readonly providerId: AIProviderId;
  readonly model: AIModelId;
  /** Identifiant de requête côté provider, si disponible. */
  readonly requestId?: string;
  /** Texte généré (chaîne vide si la réponse ne contient que des appels d'outil). */
  readonly content: string;
  /** Données structurées décodées, si un format structuré a été demandé. */
  readonly structured?: JsonValue;
  /** Appels d'outil demandés par le modèle (non exécutés ici). */
  readonly toolCalls?: readonly AIToolCall[];
  readonly finishReason: AIFinishReason;
  /** Valeur brute de fin de génération chez le provider, si utile au diagnostic. */
  readonly rawFinishReason?: string;
  readonly usage?: AIUsage;
  /** Durée totale de la requête en millisecondes, si mesurée. */
  readonly latencyMs?: number;
  readonly metadata?: AIMetadata;
}

/**
 * Réponse d'embeddings.
 */
export interface AIEmbeddingResponse {
  readonly providerId: AIProviderId;
  readonly model: AIModelId;
  readonly requestId?: string;
  /** Un vecteur par élément de `input`, dans le même ordre. */
  readonly embeddings: readonly (readonly number[])[];
  readonly usage?: AIUsage;
  readonly latencyMs?: number;
}

/* -------------------------------------------------------------------------- */
/*  Streaming                                                                 */
/* -------------------------------------------------------------------------- */

/**
 * Évènement de streaming (union discriminée sur `type`).
 *
 * Le contrat définit uniquement la forme des évènements : le transport réseau
 * est du ressort des providers concrets.
 */
export type AIStreamEvent =
  | {
      readonly type: 'start';
      readonly providerId: AIProviderId;
      readonly model: AIModelId;
      readonly requestId?: string;
    }
  | { readonly type: 'text_delta'; readonly text: string }
  | {
      readonly type: 'tool_call_delta';
      readonly toolCallId: string;
      readonly name?: string;
      /** Fragment partiel d'arguments JSON sérialisés. */
      readonly argumentsDelta?: string;
    }
  | { readonly type: 'usage'; readonly usage: AIUsage }
  | {
      readonly type: 'end';
      readonly finishReason: AIFinishReason;
      readonly usage?: AIUsage;
    }
  | { readonly type: 'error'; readonly code: AIErrorCode; readonly message: string };

/* -------------------------------------------------------------------------- */
/*  Erreurs                                                                   */
/* -------------------------------------------------------------------------- */

/**
 * Codes d'erreur AI normalisés.
 *
 * Permettent au Provider Manager de décider (retry, failover, abandon) sans
 * connaître les erreurs propres à chaque fournisseur.
 */
export type AIErrorCode =
  | 'configuration_error'
  | 'authentication_error'
  | 'authorization_error'
  | 'rate_limit'
  | 'timeout'
  | 'provider_unavailable'
  | 'invalid_request'
  | 'unsupported_capability'
  | 'model_unavailable'
  | 'provider_error';

/**
 * Paramètres de construction d'une {@link AIProviderError}.
 *
 * Volontairement SANS champ `cause` ni `headers` : une erreur brute de SDK ou de
 * HTTP peut contenir des secrets (en-tête Authorization, clé API). Le provider
 * concret doit extraire uniquement des informations sûres.
 */
export interface AIProviderErrorParams {
  readonly code: AIErrorCode;
  readonly providerId: AIProviderId;
  readonly message: string;
  readonly model?: AIModelId;
  /** Indique si un nouvel essai a un sens (indication pour le manager). */
  readonly retryable?: boolean;
  /** Code de statut HTTP éventuel (information non sensible). */
  readonly httpStatus?: number;
  /** Délai conseillé avant nouvel essai, en millisecondes. */
  readonly retryAfterMs?: number;
  /** Détails techniques non sensibles. */
  readonly details?: AIMetadata;
}

/**
 * Motifs de secrets courants masqués en dernier recours dans les messages d'erreur.
 * Défense en profondeur : elle ne remplace pas la discipline des providers,
 * qui ne doivent jamais injecter de secret dans le message.
 */
const SECRET_PATTERNS: readonly RegExp[] = [
  /Bearer\s+[A-Za-z0-9._~+/=-]+/gi,
  /\b(?:sk|pk|hf|key|tok|token)[-_][A-Za-z0-9_-]{8,}/gi,
  /(?:api[_-]?key|authorization|secret|token|password)\s*[:=]\s*\S+/gi,
];

/**
 * Masque les motifs de secrets courants dans un texte.
 *
 * @param text - Texte à assainir.
 * @returns Texte dans lequel les motifs reconnus sont remplacés par `[REDACTED]`.
 */
function redactSecrets(text: string): string {
  return SECRET_PATTERNS.reduce<string>(
    (current, pattern) => current.replace(pattern, '[REDACTED]'),
    text,
  );
}

/**
 * Erreur AI commune à tous les providers.
 *
 * Pourquoi une classe unique avec un code discriminant : le manager traite
 * toutes les erreurs de façon uniforme, quel que soit le fournisseur.
 *
 * SÉCURITÉ : le message est masqué de tout motif de secret connu, et aucune
 * propriété ne référence l'erreur d'origine (`cause`) ni d'en-têtes.
 */
export class AIProviderError extends Error {
  public readonly code: AIErrorCode;
  public readonly providerId: AIProviderId;
  public readonly model?: AIModelId;
  public readonly retryable: boolean;
  public readonly httpStatus?: number;
  public readonly retryAfterMs?: number;
  public readonly details?: AIMetadata;

  /**
   * @param params - Informations sûres décrivant l'erreur.
   */
  public constructor(params: AIProviderErrorParams) {
    super(redactSecrets(params.message));
    Object.setPrototypeOf(this, new.target.prototype);
    this.name = 'AIProviderError';
    this.code = params.code;
    this.providerId = params.providerId;
    this.model = params.model;
    this.retryable = params.retryable ?? false;
    this.httpStatus = params.httpStatus;
    this.retryAfterMs = params.retryAfterMs;
    this.details = params.details;
  }
}

/* -------------------------------------------------------------------------- */
/*  Contrat du provider                                                       */
/* -------------------------------------------------------------------------- */

/**
 * Contrat minimal qu'un provider AI expose au Provider Manager.
 *
 * Les erreurs doivent être signalées par des {@link AIProviderError}.
 */
export interface AIProvider {
  /** Identifiant unique et stable. */
  readonly id: AIProviderId;
  /** Nom lisible. */
  readonly name: string;
  getStatus(signal?: AbortSignal): Promise<AIProviderStatus>;
  getCapabilities(): Promise<AIProviderCapabilities>;
  generate(request: AIGenerationRequest): Promise<AIGenerationResponse>;
  generateStream(request: AIGenerationRequest): Promise<AsyncIterable<AIStreamEvent>>;
  embed(request: AIEmbeddingRequest): Promise<AIEmbeddingResponse>;
  close(): Promise<void>;
}

/**
 * Classe de base abstraite de tous les providers AI.
 *
 * Pourquoi une classe abstraite en plus de l'interface : fournir des
 * comportements par défaut sûrs pour les capacités optionnelles (streaming,
 * embeddings, fermeture), afin qu'un provider n'implémente que ce qu'il supporte
 * réellement, sans modifier ce contrat central.
 *
 * Ce que cette classe NE fait pas : appel réseau, lecture d'environnement,
 * journalisation, gestion de credentials, exécution d'outils, retries ou failover.
 */
export abstract class BaseAIProvider implements AIProvider {
  /** Identifiant unique et stable du provider (ex. `"mistral"`). */
  public abstract readonly id: AIProviderId;

  /** Nom lisible du provider. */
  public abstract readonly name: string;

  /**
   * Contrôle l'état de disponibilité du provider.
   *
   * @param signal - Signal d'annulation optionnel.
   * @returns Statut courant ; ne doit contenir aucune donnée sensible.
   */
  public abstract getStatus(signal?: AbortSignal): Promise<AIProviderStatus>;

  /**
   * Déclare précisément modèles, capacités et limites supportés.
   *
   * Asynchrone pour permettre à un provider de découvrir dynamiquement ses modèles.
   */
  public abstract getCapabilities(): Promise<AIProviderCapabilities>;

  /**
   * Génère une réponse AI complète (non streamée).
   *
   * @param request - Requête de génération.
   * @returns Réponse normalisée.
   * @throws {AIProviderError} En cas d'échec, avec un code normalisé.
   */
  public abstract generate(request: AIGenerationRequest): Promise<AIGenerationResponse>;

  /**
   * Génère une réponse sous forme de flux d'évènements.
   *
   * Implémentation par défaut : rejette avec `unsupported_capability`.
   * Les providers supportant `streaming` doivent la surcharger.
   *
   * @param _request - Requête de génération.
   * @returns Flux d'évènements de génération.
   */
  public generateStream(_request: AIGenerationRequest): Promise<AsyncIterable<AIStreamEvent>> {
    return Promise.reject(this.unsupportedCapability('streaming'));
  }

  /**
   * Calcule des embeddings.
   *
   * Implémentation par défaut : rejette avec `unsupported_capability`.
   * Les providers supportant `embeddings` doivent la surcharger.
   *
   * @param _request - Requête d'embeddings.
   * @returns Vecteurs normalisés.
   */
  public embed(_request: AIEmbeddingRequest): Promise<AIEmbeddingResponse> {
    return Promise.reject(this.unsupportedCapability('embeddings'));
  }

  /**
   * Libère les ressources détenues par le provider (connexions, timers).
   * Implémentation par défaut : aucune action. Doit être idempotente.
   */
  public close(): Promise<void> {
    return Promise.resolve();
  }

  /**
   * Indique si le provider (ou un modèle précis) déclare une capacité.
   *
   * @param capability - Capacité recherchée.
   * @param model - Modèle ciblé ; à défaut, tout modèle du provider est pris en compte.
   * @returns `true` si la capacité est déclarée.
   */
  public async supportsCapability(capability: AICapability, model?: AIModelId): Promise<boolean> {
    const declared = await this.getCapabilities();
    if (model === undefined) {
      return declared.capabilities.includes(capability);
    }
    const descriptor = declared.models.find((candidate) => candidate.id === model);
    return descriptor !== undefined && descriptor.capabilities.includes(capability);
  }

  /**
   * Construit une erreur normalisée pour une capacité non supportée.
   *
   * @param capability - Capacité demandée mais non supportée.
   * @returns Erreur `unsupported_capability` sans donnée sensible.
   */
  protected unsupportedCapability(capability: AICapability): AIProviderError {
    return new AIProviderError({
      code: 'unsupported_capability',
      providerId: this.id,
      message: `Capability "${capability}" is not supported by provider "${this.id}".`,
      retryable: false,
    });
  }
}
