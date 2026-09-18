/**
 * @file deepseek.provider.ts
 *
 * Provider concret DeepSeek de CORMERY.
 *
 * Position dans l'architecture :
 *
 *   AI orchestration → AIProviderManager → DeepSeekProvider → API DeepSeek
 *
 * Ce fichier est le DERNIER niveau : transport et normalisation uniquement.
 * Il ne connaît ni CORE, ni ILIADE, ni FUTURE, ne sélectionne aucun provider,
 * n'implémente aucun failover ni retry (responsabilité du Provider Manager)
 * et ne persiste aucune donnée utilisateur ni logique métier CORMERY.
 *
 * Intégration retenue : l'API DeepSeek compatible OpenAI
 * (`https://api.deepseek.com/chat/completions`), en HTTP natif — le dépôt
 * n'installe aucun SDK DeepSeek et aucun n'est ajouté ici.
 *
 * Capacités réellement implémentées ici :
 * - `text_generation` et `chat` via `generate()` ;
 * - `tool_calling` : outils transmis et `tool_calls` normalisés, JAMAIS exécutés.
 *   `tool_choice` est limité aux valeurs officiellement documentées par DeepSeek
 *   (`auto` / `none` / `required`) ; un choix d'outil nommé (forme objet du
 *   contrat CORMERY) n'est PAS confirmé par la documentation officielle et est
 *   donc rejeté explicitement plutôt que supposé par analogie avec OpenAI ;
 * - `structured_output` limité à `json_object`. `json_schema` n'apparaît dans
 *   aucune documentation officielle DeepSeek et échoue explicitement en
 *   `unsupported_capability`.
 *
 * Contrainte officiellement documentée pour `json_object` (guide « JSON
 * Output ») : le prompt (système ou utilisateur) doit contenir le mot « json »
 * pour que la sortie structurée soit fiable. Cette exigence est VÉRIFIÉE avant
 * l'envoi (voir {@link DeepSeekProvider.ensureJsonInstructionPresent}) ; une
 * requête sans cette instruction échoue en `invalid_request` avant tout appel
 * réseau.
 *
 * Capacités volontairement NON implémentées : `streaming`, `embeddings`, `vision`.
 * `generateStream()` et `embed()` conservent le comportement `unsupported_capability`
 * hérité de {@link BaseAIProvider} ; un fragment de contenu `image` est refusé
 * explicitement plutôt que transmis en silence (aucune capacité vision n'est
 * documentée pour l'API chat DeepSeek).
 *
 * Statut de disponibilité : contrairement à Mistral et Qwen, DeepSeek documente
 * officiellement un endpoint de listage de modèles non générateur,
 * `GET /models` (« List Models »). `getStatus()` s'appuie dessus comme sonde
 * légère ; aucun endpoint n'est inventé, et aucune génération n'est jamais
 * déclenchée pour vérifier la disponibilité.
 *
 * Credentials : la clé API provient exclusivement de la configuration centralisée
 * validée (`config/env.ts`), à l'exception d'un mécanisme de test strictement
 * séparé (voir {@link DeepSeekProviderTestCredential}). Elle reste dans un champ
 * privé, n'est jamais retournée, ni placée dans une URL, un message d'erreur,
 * des métadonnées ou un log. Ce fichier n'émet aucun log.
 */

import { envConfig } from '../../../config/env';
import { AIProviderError, BaseAIProvider } from '../base-ai.provider';
import type {
  AICapability,
  AIFinishReason,
  AIGenerationRequest,
  AIGenerationResponse,
  AIMessage,
  AIModelId,
  AIProviderCapabilities,
  AIProviderId,
  AIProviderStatus,
  AIResponseFormat,
  AIToolCall,
  AIToolChoice,
  AIToolDefinition,
  AIUsage,
  JsonObject,
  JsonValue,
} from '../base-ai.provider';

/* -------------------------------------------------------------------------- */
/*  Constantes                                                                */
/* -------------------------------------------------------------------------- */

/** Identifiant stable du provider. */
const PROVIDER_ID: AIProviderId = 'deepseek';

/** Nom lisible du provider. */
const PROVIDER_NAME = 'DeepSeek API';

/**
 * Endpoint officiellement documenté, utilisé lorsque `DEEPSEEK_BASE_URL` n'est
 * pas configurée. Le suffixe `/v1` est optionnel côté DeepSeek (compatibilité
 * OpenAI uniquement) ; la forme sans suffixe, canonique dans la documentation
 * officielle, est retenue ici.
 */
const DEFAULT_BASE_URL = 'https://api.deepseek.com';

/** Chemin de génération conversationnelle. */
const CHAT_COMPLETIONS_PATH = '/chat/completions';

/**
 * Chemin de listage des modèles, officiellement documenté par DeepSeek
 * (« List Models », `GET /models`) — utilisé comme sonde de santé non
 * générative. Contrairement à d'autres providers, cet endpoint est confirmé
 * par la documentation officielle, pas supposé par convention.
 */
const MODELS_PATH = '/models';

/** Timeout appliqué à `generate()` lorsque la requête n'en fournit pas. */
const DEFAULT_TIMEOUT_MS = 60_000;

/** Timeout court du contrôle de santé : il ne doit jamais bloquer un appelant. */
const STATUS_TIMEOUT_MS = 5_000;

/** Longueur maximale d'un détail d'erreur repris de l'API (borne anti-fuite/anti-bruit). */
const MAX_ERROR_DETAIL_LENGTH = 200;

/**
 * Motif de détection d'une instruction JSON dans le prompt.
 *
 * Pourquoi : le guide officiel « JSON Output » de DeepSeek exige que le prompt
 * contienne le mot « json » pour que `response_format: json_object` produise
 * une sortie fiable. Détection volontairement simple (mot entier, insensible à
 * la casse) : vérification d'une exigence documentée, pas une compréhension du prompt.
 */
const JSON_INSTRUCTION_PATTERN = /\bjson\b/i;

/** Capacités effectivement implémentées par CE fichier. */
const IMPLEMENTED_CAPABILITIES: readonly AICapability[] = [
  'text_generation',
  'chat',
  'structured_output',
  'tool_calling',
];

/* -------------------------------------------------------------------------- */
/*  Types de la charge utile DeepSeek (sortants)                              */
/* -------------------------------------------------------------------------- */

type DeepSeekRole = 'system' | 'user' | 'assistant' | 'tool';

interface DeepSeekToolCallPayload {
  readonly id: string;
  readonly type: 'function';
  readonly function: { readonly name: string; readonly arguments: string };
}

interface DeepSeekMessagePayload {
  readonly role: DeepSeekRole;
  readonly content: string;
  readonly tool_calls?: readonly DeepSeekToolCallPayload[];
  readonly tool_call_id?: string;
}

interface DeepSeekToolPayload {
  readonly type: 'function';
  readonly function: {
    readonly name: string;
    readonly description: string;
    readonly parameters: JsonObject;
  };
}

/**
 * Valeurs de `tool_choice` officiellement documentées par DeepSeek. Aucune
 * forme objet (choix d'un outil nommé) n'est confirmée par la documentation ;
 * elle n'est donc pas représentée ici (voir {@link DeepSeekProvider.mapToolChoice}).
 */
type DeepSeekToolChoicePayload = 'auto' | 'none' | 'required';

/** Uniquement `json_object` : `json_schema` n'est documenté par aucune source officielle DeepSeek. */
type DeepSeekResponseFormatPayload = { readonly type: 'json_object' };

interface DeepSeekChatRequestPayload {
  readonly model: string;
  readonly messages: readonly DeepSeekMessagePayload[];
  readonly stream: false;
  readonly temperature?: number;
  readonly max_tokens?: number;
  readonly tools?: readonly DeepSeekToolPayload[];
  readonly tool_choice?: DeepSeekToolChoicePayload;
  readonly response_format?: DeepSeekResponseFormatPayload;
}

/* -------------------------------------------------------------------------- */
/*  Options de construction                                                   */
/* -------------------------------------------------------------------------- */

/**
 * Signature minimale du transport HTTP attendu.
 *
 * Pourquoi un alias plutôt que `typeof fetch` imposé : permettre l'injection d'un
 * double en test sans dépendance supplémentaire ni mock global.
 */
export type DeepSeekFetch = (input: string, init: RequestInit) => Promise<Response>;

/**
 * Options de construction du provider, utilisables en production.
 *
 * Volontairement SANS champ de credential : la clé API provient exclusivement
 * de `config/env.ts`. Un credential de test s'injecte uniquement via le second
 * paramètre distinct du constructeur, {@link DeepSeekProviderTestCredential} —
 * jamais via ce type, afin qu'aucun appelant de production ne puisse
 * contourner la configuration centralisée.
 */
export interface DeepSeekProviderOptions {
  /** Base URL ; par défaut `envConfig.DEEPSEEK_BASE_URL`, sinon l'endpoint officiel. */
  readonly baseUrl?: string;
  /** Timeout appliqué quand la requête n'en précise pas. */
  readonly defaultTimeoutMs?: number;
  /** Transport HTTP ; par défaut le `fetch` global de Node.js. */
  readonly fetchImpl?: DeepSeekFetch;
}

/**
 * Credential réservé aux tests, structurellement séparé de
 * {@link DeepSeekProviderOptions}.
 *
 * RÉSERVÉ AUX TESTS UNITAIRES. Ce type existe pour permettre de tester le
 * provider sans dépendre de `config/env.ts` ni de variables d'environnement
 * réelles. Aucune couche de production de CORMERY ne doit construire un
 * provider avec ce second paramètre ; le Provider Manager doit toujours
 * appeler `new DeepSeekProvider(options)` à un seul argument, laissant le
 * credential provenir exclusivement d'`envConfig`.
 */
export interface DeepSeekProviderTestCredential {
  readonly apiKey: string;
}

/* -------------------------------------------------------------------------- */
/*  Utilitaires de lecture défensive (aucun `any`)                            */
/* -------------------------------------------------------------------------- */

/**
 * Convertit une valeur inconnue en enregistrement exploitable.
 *
 * @param value - Valeur issue du JSON de réponse.
 * @returns L'enregistrement, ou `undefined` si la valeur n'en est pas un.
 */
function asRecord(value: unknown): Record<string, unknown> | undefined {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

/**
 * @param value - Valeur issue du JSON de réponse.
 * @returns La chaîne non vide, ou `undefined`.
 */
function asNonEmptyString(value: unknown): string | undefined {
  return typeof value === 'string' && value !== '' ? value : undefined;
}

/**
 * @param value - Valeur issue du JSON de réponse.
 * @returns Le nombre fini, ou `undefined` (jamais d'estimation de substitution).
 */
function asFiniteNumber(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

/**
 * Valide récursivement qu'une valeur est un JSON sérialisable.
 *
 * @param value - Valeur à valider.
 * @returns La valeur typée `JsonValue`, ou `undefined` si elle n'est pas sérialisable.
 */
function toJsonValue(value: unknown): JsonValue | undefined {
  if (value === null || typeof value === 'string' || typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : undefined;
  }
  if (Array.isArray(value)) {
    const items: JsonValue[] = [];
    for (const item of value) {
      const converted = toJsonValue(item);
      if (converted === undefined) return undefined;
      items.push(converted);
    }
    return items;
  }
  const record = asRecord(value);
  if (record === undefined) return undefined;
  const result: Record<string, JsonValue> = {};
  for (const [key, entry] of Object.entries(record)) {
    const converted = toJsonValue(entry);
    if (converted === undefined) return undefined;
    result[key] = converted;
  }
  return result;
}

/**
 * @param value - Valeur à valider.
 * @returns L'objet JSON, ou `undefined` si la valeur n'est pas un objet sérialisable.
 */
function toJsonObject(value: unknown): JsonObject | undefined {
  const converted = toJsonValue(value);
  return converted !== null &&
    typeof converted === 'object' &&
    !Array.isArray(converted)
    ? converted
    : undefined;
}

/**
 * Tronque un détail d'erreur repris de l'API.
 *
 * @param text - Texte d'origine.
 * @returns Texte borné, sans saut de ligne (le masquage des secrets est assuré
 *          par {@link AIProviderError}).
 */
function truncateDetail(text: string): string {
  const flattened = text.replace(/\s+/g, ' ').trim();
  return flattened.length > MAX_ERROR_DETAIL_LENGTH
    ? `${flattened.slice(0, MAX_ERROR_DETAIL_LENGTH)}…`
    : flattened;
}

/* -------------------------------------------------------------------------- */
/*  Provider                                                                  */
/* -------------------------------------------------------------------------- */

/**
 * Provider DeepSeek.
 *
 * Comportement de `generate()` : valide le modèle et, pour `json_object`,
 * l'instruction JSON du prompt (exigence officiellement documentée) ; traduit
 * la requête en appel `POST /chat/completions` ; applique le timeout et
 * l'`AbortSignal` fournis ; normalise la réponse. Toute erreur — validation,
 * réseau, HTTP, contenu inattendu — est convertie en {@link AIProviderError}
 * avec un code normalisé ; aucune erreur brute de transport ne remonte.
 *
 * Comportement de `getStatus()` : sonde légère `GET /models` — endpoint
 * officiellement documenté par DeepSeek, jamais générateur — avec un timeout
 * court. Aucune boucle de health checking permanente n'est démarrée ici, et
 * aucun credential n'apparaît dans le statut retourné.
 *
 * Concurrence : l'instance est réutilisable par des requêtes simultanées ;
 * aucun état propre à une génération n'est conservé dans un champ.
 */
export class DeepSeekProvider extends BaseAIProvider {
  public readonly id: AIProviderId = PROVIDER_ID;

  public readonly name: string = PROVIDER_NAME;

  /**
   * Credential, confiné à l'instance. Jamais lu par une méthode publique.
   * Provient d'`envConfig` sauf si un {@link DeepSeekProviderTestCredential} a
   * été fourni au constructeur (usage de test exclusivement).
   */
  private readonly apiKey: string | undefined;

  /** Racine de l'API, normalisée sans slash final. */
  private readonly baseUrl: string;

  private readonly defaultTimeoutMs: number;

  private readonly fetchImpl: DeepSeekFetch;

  /**
   * @param options - Options de production ; la configuration centralisée fait foi par défaut.
   * @param testCredential - RÉSERVÉ AUX TESTS. Voir {@link DeepSeekProviderTestCredential}.
   *   Absent en usage normal : le Provider Manager ne doit jamais fournir ce paramètre.
   */
  public constructor(
    options: DeepSeekProviderOptions = {},
    testCredential?: DeepSeekProviderTestCredential,
  ) {
    super();
    this.apiKey = testCredential?.apiKey ?? envConfig.DEEPSEEK_API_KEY;
    this.baseUrl = (options.baseUrl ?? envConfig.DEEPSEEK_BASE_URL ?? DEFAULT_BASE_URL).replace(
      /\/+$/,
      '',
    );
    this.defaultTimeoutMs = options.defaultTimeoutMs ?? DEFAULT_TIMEOUT_MS;
    this.fetchImpl = options.fetchImpl ?? ((input, init) => fetch(input, init));
  }

  /* ------------------------------------------------------------------ */
  /*  Contrat public                                                     */
  /* ------------------------------------------------------------------ */

  /**
   * Déclare les capacités réellement supportées par cette implémentation.
   *
   * La liste `models` est volontairement vide : bien que DeepSeek documente un
   * endpoint de listage (`GET /models`), celui-ci est dynamique et dépendant du
   * compte ; en faire une source figée dans ce fichier reviendrait à prétendre
   * une autorité que ce fichier n'a pas. Le modèle est donc toujours celui
   * transmis par la requête.
   *
   * @returns Capacités déclarées, sans aucune donnée sensible.
   */
  public getCapabilities(): Promise<AIProviderCapabilities> {
    return Promise.resolve({
      providerId: this.id,
      models: [],
      capabilities: IMPLEMENTED_CAPABILITIES,
      limits: { defaultTimeoutMs: this.defaultTimeoutMs },
    });
  }

  /**
   * Contrôle l'état de disponibilité du provider via l'endpoint officiel
   * `GET /models`, sans jamais déclencher de génération.
   *
   * @param signal - Signal d'annulation optionnel.
   * @returns Statut observé.
   */
  public async getStatus(signal?: AbortSignal): Promise<AIProviderStatus> {
    const checkedAt = new Date().toISOString();

    if (this.apiKey === undefined) {
      return {
        providerId: this.id,
        state: 'unavailable',
        checkedAt,
        reason: 'DeepSeek API credential is not configured.',
      };
    }

    const startedAt = performance.now();
    try {
      const response = await this.send(
        MODELS_PATH,
        { method: 'GET', headers: this.buildHeaders(this.apiKey, false) },
        STATUS_TIMEOUT_MS,
        signal,
      );
      const latencyMs = Math.round(performance.now() - startedAt);

      if (response.ok) {
        return { providerId: this.id, state: 'available', checkedAt, latencyMs };
      }
      if (response.status === 429) {
        return {
          providerId: this.id,
          state: 'degraded',
          checkedAt,
          latencyMs,
          reason: 'Rate limited by the DeepSeek API.',
        };
      }
      return {
        providerId: this.id,
        state: 'unavailable',
        checkedAt,
        latencyMs,
        reason: `Health check returned HTTP ${String(response.status)}.`,
      };
    } catch (error) {
      const latencyMs = Math.round(performance.now() - startedAt);
      const reason =
        error instanceof AIProviderError && error.code === 'timeout'
          ? 'Health check timed out.'
          : 'Health check could not reach the DeepSeek API.';
      return { providerId: this.id, state: 'unavailable', checkedAt, latencyMs, reason };
    }
  }

  /**
   * Génère une réponse complète (non streamée).
   *
   * @param request - Requête normalisée CORMERY.
   * @returns Réponse normalisée CORMERY.
   * @throws {AIProviderError} Configuration absente, requête invalide (modèle
   *         manquant, instruction JSON absente pour `json_object`, ou choix
   *         d'outil non confirmé), capacité non supportée, erreur HTTP,
   *         timeout, annulation ou réponse inexploitable.
   */
  public async generate(request: AIGenerationRequest): Promise<AIGenerationResponse> {
    const apiKey = this.requireApiKey(request.model);
    const model = asNonEmptyString(request.model);
    if (model === undefined) {
      throw new AIProviderError({
        code: 'invalid_request',
        providerId: this.id,
        message: 'A non-empty model identifier is required.',
        retryable: false,
      });
    }

    const payload = this.buildChatPayload(request, model);
    const startedAt = performance.now();

    const response = await this.send(
      CHAT_COMPLETIONS_PATH,
      {
        method: 'POST',
        headers: this.buildHeaders(apiKey, true),
        body: JSON.stringify(payload),
      },
      request.timeoutMs ?? this.defaultTimeoutMs,
      request.signal,
      model,
    );

    if (!response.ok) {
      throw await this.errorFromResponse(response, model);
    }

    const body = await this.readJson(response, model);
    const latencyMs = Math.round(performance.now() - startedAt);
    return this.normalizeGeneration(body, request, model, latencyMs);
  }

  /* ------------------------------------------------------------------ */
  /*  Construction de la requête                                         */
  /* ------------------------------------------------------------------ */

  /**
   * Vérifie la présence du credential.
   *
   * @param model - Modèle concerné, pour le diagnostic.
   * @returns La clé API.
   * @throws {AIProviderError} `configuration_error` si la clé n'est pas configurée.
   */
  private requireApiKey(model?: AIModelId): string {
    if (this.apiKey === undefined) {
      throw new AIProviderError({
        code: 'configuration_error',
        providerId: this.id,
        message: 'DeepSeek API credential is not configured.',
        model,
        retryable: false,
      });
    }
    return this.apiKey;
  }

  /**
   * Construit les en-têtes de la requête.
   *
   * @param apiKey - Credential.
   * @param withBody - `true` si un corps JSON est envoyé.
   * @returns En-têtes minimaux requis par l'API.
   */
  private buildHeaders(apiKey: string, withBody: boolean): Record<string, string> {
    const headers: Record<string, string> = {
      accept: 'application/json',
      authorization: `Bearer ${apiKey}`,
    };
    if (withBody) {
      headers['content-type'] = 'application/json';
    }
    return headers;
  }

  /**
   * Transforme la requête CORMERY en charge utile DeepSeek.
   *
   * @param request - Requête normalisée.
   * @param model - Modèle validé.
   * @returns Charge utile prête à sérialiser.
   * @throws {AIProviderError} `invalid_request` si `json_object` est demandé
   *         sans instruction JSON explicite, ou si un choix d'outil nommé est
   *         demandé (non confirmé par la documentation officielle) ;
   *         `unsupported_capability` si `json_schema` est demandé.
   */
  private buildChatPayload(request: AIGenerationRequest, model: string): DeepSeekChatRequestPayload {
    const messages: DeepSeekMessagePayload[] = [];
    if (request.systemInstruction !== undefined && request.systemInstruction !== '') {
      messages.push({ role: 'system', content: request.systemInstruction });
    }
    for (const message of request.messages) {
      messages.push(...this.toDeepSeekMessages(message));
    }

    const responseFormat = this.mapResponseFormat(request.responseFormat);
    if (responseFormat !== undefined) {
      this.ensureJsonInstructionPresent(request);
    }

    const tools = this.mapTools(request.tools);
    const toolChoice = this.mapToolChoice(request.toolChoice, request.model);

    return {
      model,
      messages,
      stream: false,
      ...(request.temperature !== undefined ? { temperature: request.temperature } : {}),
      ...(request.maxTokens !== undefined ? { max_tokens: request.maxTokens } : {}),
      ...(tools !== undefined ? { tools } : {}),
      ...(toolChoice !== undefined ? { tool_choice: toolChoice } : {}),
      ...(responseFormat !== undefined ? { response_format: responseFormat } : {}),
    };
  }

  /**
   * Vérifie qu'une instruction JSON explicite figure dans le prompt, comme
   * l'exige le guide officiel « JSON Output » de DeepSeek pour `json_object`.
   *
   * @param request - Requête d'origine.
   * @throws {AIProviderError} `invalid_request` si aucune instruction JSON n'est trouvée.
   */
  private ensureJsonInstructionPresent(request: AIGenerationRequest): void {
    const systemHasJson =
      request.systemInstruction !== undefined &&
      JSON_INSTRUCTION_PATTERN.test(request.systemInstruction);

    const messagesHaveJson = request.messages.some((message) =>
      message.content.some(
        (part) => part.type === 'text' && JSON_INSTRUCTION_PATTERN.test(part.text),
      ),
    );

    if (!systemHasJson && !messagesHaveJson) {
      throw new AIProviderError({
        code: 'invalid_request',
        providerId: this.id,
        message:
          'DeepSeek requires the prompt to explicitly instruct the model to output JSON ' +
          '(the word "json" must appear in the system or user prompt) when response_format is "json_object".',
        model: request.model,
        retryable: false,
      });
    }
  }

  /**
   * Convertit un message CORMERY en un ou plusieurs messages DeepSeek.
   *
   * @param message - Message normalisé.
   * @returns Messages DeepSeek équivalents.
   * @throws {AIProviderError} Si le message contient une image (`vision` non supporté).
   */
  private toDeepSeekMessages(message: AIMessage): DeepSeekMessagePayload[] {
    const texts: string[] = [];
    const toolCalls: DeepSeekToolCallPayload[] = [];
    const toolResults: DeepSeekMessagePayload[] = [];

    for (const part of message.content) {
      switch (part.type) {
        case 'text':
          texts.push(part.text);
          break;
        case 'tool_call':
          toolCalls.push({
            id: part.toolCall.id,
            type: 'function',
            function: {
              name: part.toolCall.name,
              arguments: JSON.stringify(part.toolCall.arguments),
            },
          });
          break;
        case 'tool_result':
          toolResults.push({
            role: 'tool',
            content: part.content,
            tool_call_id: part.toolCallId,
          });
          break;
        case 'image':
          throw this.unsupportedCapability('vision');
        default:
          throw this.unexpectedContentPart(part);
      }
    }

    const messages: DeepSeekMessagePayload[] = [];
    const content = texts.join('\n');
    if (content !== '' || toolCalls.length > 0) {
      messages.push({
        role: this.toDeepSeekRole(message.role),
        content,
        ...(toolCalls.length > 0 ? { tool_calls: toolCalls } : {}),
      });
    }
    messages.push(...toolResults);
    return messages;
  }

  /**
   * @param role - Rôle CORMERY.
   * @returns Rôle DeepSeek équivalent (correspondance exacte, un à un).
   */
  private toDeepSeekRole(role: AIMessage['role']): DeepSeekRole {
    return role;
  }

  /**
   * Erreur de garde pour un fragment de contenu inconnu.
   *
   * @param part - Fragment non reconnu.
   * @returns Erreur normalisée.
   */
  private unexpectedContentPart(part: never): AIProviderError {
    const descriptor = asRecord(part);
    const type = descriptor === undefined ? 'unknown' : String(descriptor['type']);
    return new AIProviderError({
      code: 'invalid_request',
      providerId: this.id,
      message: `Unsupported content part type "${type}".`,
      retryable: false,
    });
  }

  /**
   * @param tools - Définitions d'outils CORMERY.
   * @returns Outils au format DeepSeek (type `function` uniquement), ou
   *          `undefined` si aucun outil n'est fourni.
   */
  private mapTools(
    tools: readonly AIToolDefinition[] | undefined,
  ): readonly DeepSeekToolPayload[] | undefined {
    if (tools === undefined || tools.length === 0) return undefined;
    return tools.map((tool) => ({
      type: 'function',
      function: {
        name: tool.name,
        description: tool.description,
        parameters: tool.parametersSchema,
      },
    }));
  }

  /**
   * @param choice - Politique CORMERY.
   * @param model - Modèle concerné, pour le diagnostic de l'erreur.
   * @returns Politique DeepSeek équivalente, limitée aux valeurs officiellement documentées.
   * @throws {AIProviderError} `invalid_request` si un choix d'outil nommé est
   *         demandé : cette forme n'est confirmée par aucune documentation
   *         officielle DeepSeek (seules `auto` / `none` / `required` le sont).
   */
  private mapToolChoice(
    choice: AIToolChoice | undefined,
    model: AIModelId,
  ): DeepSeekToolChoicePayload | undefined {
    if (choice === undefined) return undefined;
    if (choice === 'auto' || choice === 'none' || choice === 'required') return choice;
    throw new AIProviderError({
      code: 'invalid_request',
      providerId: this.id,
      message:
        'DeepSeek does not have a documented named-tool tool_choice format; ' +
        'only "auto", "none" and "required" are supported by this provider.',
      model,
      retryable: false,
    });
  }

  /**
   * @param format - Format demandé.
   * @returns Format DeepSeek équivalent, ou `undefined` pour le format textuel implicite.
   * @throws {AIProviderError} `unsupported_capability` pour `json_schema`.
   */
  private mapResponseFormat(
    format: AIResponseFormat | undefined,
  ): DeepSeekResponseFormatPayload | undefined {
    if (format === undefined || format.type === 'text') return undefined;
    if (format.type === 'json_object') return { type: 'json_object' };
    throw this.unsupportedCapability('structured_output');
  }

  /* ------------------------------------------------------------------ */
  /*  Transport                                                          */
  /* ------------------------------------------------------------------ */

  /**
   * Exécute une requête HTTP en appliquant timeout et annulation coopérative.
   *
   * @param path - Chemin relatif à la base configurée.
   * @param init - Méthode, en-têtes et corps.
   * @param timeoutMs - Timeout effectif.
   * @param signal - Signal de l'appelant.
   * @param model - Modèle concerné, pour le diagnostic.
   * @returns Réponse HTTP brute (statut non interprété).
   * @throws {AIProviderError} Timeout, annulation ou indisponibilité réseau.
   */
  private async send(
    path: string,
    init: { method: string; headers: Record<string, string>; body?: string },
    timeoutMs: number,
    signal: AbortSignal | undefined,
    model?: AIModelId,
  ): Promise<Response> {
    const controller = new AbortController();
    let timedOut = false;

    const timer = setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, timeoutMs);
    const forwardAbort = (): void => {
      controller.abort();
    };

    if (signal !== undefined) {
      if (signal.aborted) {
        controller.abort();
      } else {
        signal.addEventListener('abort', forwardAbort, { once: true });
      }
    }

    try {
      return await this.fetchImpl(`${this.baseUrl}${path}`, {
        method: init.method,
        headers: init.headers,
        ...(init.body !== undefined ? { body: init.body } : {}),
        signal: controller.signal,
      });
    } catch (error) {
      throw this.transportError(error, timedOut, signal?.aborted === true, timeoutMs, model);
    } finally {
      clearTimeout(timer);
      signal?.removeEventListener('abort', forwardAbort);
    }
  }

  /**
   * Normalise une défaillance de transport. L'erreur d'origine n'est jamais
   * relayée (`DOMException`/`AbortError` bruts inclus) : elle peut contenir
   * l'URL, les en-têtes ou le corps de la requête.
   *
   * @param error - Erreur brute (ignorée volontairement).
   * @param timedOut - `true` si le timeout interne a déclenché l'annulation.
   * @param callerAborted - `true` si l'appelant a annulé.
   * @param timeoutMs - Timeout appliqué, pour le diagnostic.
   * @param model - Modèle concerné.
   * @returns Erreur normalisée.
   */
  private transportError(
    error: unknown,
    timedOut: boolean,
    callerAborted: boolean,
    timeoutMs: number,
    model?: AIModelId,
  ): AIProviderError {
    void error;
    if (timedOut) {
      return new AIProviderError({
        code: 'timeout',
        providerId: this.id,
        message: `DeepSeek API request exceeded the ${String(timeoutMs)} ms timeout.`,
        model,
        retryable: true,
      });
    }
    if (callerAborted) {
      return new AIProviderError({
        code: 'provider_error',
        providerId: this.id,
        message: 'DeepSeek API request was aborted by the caller.',
        model,
        retryable: false,
      });
    }
    return new AIProviderError({
      code: 'provider_unavailable',
      providerId: this.id,
      message: 'Network failure while contacting the DeepSeek API.',
      model,
      retryable: true,
    });
  }

  /**
   * Décode le corps JSON d'une réponse.
   *
   * @param response - Réponse HTTP.
   * @param model - Modèle concerné.
   * @returns Corps décodé, non typé.
   * @throws {AIProviderError} Si le corps n'est pas un JSON exploitable.
   */
  private async readJson(response: Response, model?: AIModelId): Promise<unknown> {
    try {
      return await response.json();
    } catch {
      throw new AIProviderError({
        code: 'provider_error',
        providerId: this.id,
        message: 'DeepSeek API returned a malformed JSON payload.',
        model,
        httpStatus: response.status,
        retryable: false,
      });
    }
  }

  /* ------------------------------------------------------------------ */
  /*  Erreurs HTTP                                                       */
  /* ------------------------------------------------------------------ */

  /**
   * Convertit une réponse HTTP en échec normalisé.
   *
   * @param response - Réponse en échec.
   * @param model - Modèle concerné.
   * @returns Erreur normalisée.
   */
  private async errorFromResponse(response: Response, model: AIModelId): Promise<AIProviderError> {
    const detail = await this.extractErrorDetail(response);
    const { code, retryable } = this.classifyStatus(response.status);
    const retryAfterMs = this.parseRetryAfter(response.headers.get('retry-after'));

    return new AIProviderError({
      code,
      providerId: this.id,
      message:
        detail === undefined
          ? `DeepSeek API request failed with HTTP ${String(response.status)}.`
          : `DeepSeek API request failed with HTTP ${String(response.status)}: ${detail}`,
      model,
      retryable,
      httpStatus: response.status,
      ...(retryAfterMs !== undefined ? { retryAfterMs } : {}),
    });
  }

  /**
   * Extrait un détail lisible du corps d'erreur, sans jamais le retourner en entier.
   *
   * @param response - Réponse en échec.
   * @returns Détail borné, ou `undefined` si le corps n'est pas exploitable.
   */
  private async extractErrorDetail(response: Response): Promise<string | undefined> {
    let raw: string;
    try {
      raw = await response.text();
    } catch {
      return undefined;
    }
    if (raw === '') return undefined;

    try {
      const parsed: unknown = JSON.parse(raw);
      const record = asRecord(parsed);
      const message =
        asNonEmptyString(record?.['message']) ??
        asNonEmptyString(asRecord(record?.['error'])?.['message']) ??
        asNonEmptyString(record?.['detail']);
      return message === undefined ? undefined : truncateDetail(message);
    } catch {
      return truncateDetail(raw);
    }
  }

  /**
   * Classe un statut HTTP dans le vocabulaire d'erreurs du contrat, à partir
   * de la page officielle « Error Codes » de DeepSeek (400, 401, 402, 422,
   * 429, 500, 503). Les codes non documentés par DeepSeek pour cet endpoint
   * (ex. 403, 404) reçoivent un repli générique fondé sur la sémantique HTTP
   * standard, sans supposer une cause DeepSeek spécifique.
   *
   * @param status - Statut HTTP.
   * @returns Code normalisé et indication de réessai.
   */
  private classifyStatus(status: number): {
    code:
      | 'authentication_error'
      | 'authorization_error'
      | 'rate_limit'
      | 'timeout'
      | 'provider_unavailable'
      | 'invalid_request'
      | 'model_unavailable'
      | 'provider_error';
    retryable: boolean;
  } {
    // Codes officiellement documentés par DeepSeek.
    if (status === 400) return { code: 'invalid_request', retryable: false };
    if (status === 401) return { code: 'authentication_error', retryable: false };
    // 402 (solde insuffisant) : accès refusé pour une raison de compte, non transitoire.
    if (status === 402) return { code: 'authorization_error', retryable: false };
    if (status === 422) return { code: 'invalid_request', retryable: false };
    if (status === 429) return { code: 'rate_limit', retryable: true };
    if (status === 500) return { code: 'provider_unavailable', retryable: true };
    if (status === 503) return { code: 'provider_unavailable', retryable: true };

    // Repli générique pour tout code non documenté par DeepSeek pour cet endpoint.
    if (status === 403) return { code: 'authorization_error', retryable: false };
    if (status === 404) return { code: 'model_unavailable', retryable: false };
    if (status === 408) return { code: 'timeout', retryable: true };
    if (status >= 500) return { code: 'provider_unavailable', retryable: true };
    if (status >= 400) return { code: 'invalid_request', retryable: false };
    return { code: 'provider_error', retryable: false };
  }

  /**
   * @param header - Valeur brute de l'en-tête `Retry-After` (secondes).
   * @returns Délai conseillé en millisecondes, ou `undefined`.
   */
  private parseRetryAfter(header: string | null): number | undefined {
    if (header === null) return undefined;
    const seconds = Number(header.trim());
    return Number.isFinite(seconds) && seconds >= 0 ? Math.round(seconds * 1_000) : undefined;
  }

  /* ------------------------------------------------------------------ */
  /*  Normalisation de la réponse                                        */
  /* ------------------------------------------------------------------ */

  /**
   * Normalise la réponse DeepSeek dans le contrat CORMERY.
   *
   * @param body - Corps décodé.
   * @param request - Requête d'origine (format de sortie demandé).
   * @param model - Modèle demandé, utilisé en repli.
   * @param latencyMs - Durée mesurée de l'appel.
   * @returns Réponse normalisée.
   * @throws {AIProviderError} Si la réponse ne contient pas de choix exploitable.
   */
  private normalizeGeneration(
    body: unknown,
    request: AIGenerationRequest,
    model: AIModelId,
    latencyMs: number,
  ): AIGenerationResponse {
    const root = asRecord(body);
    const choices = root?.['choices'];
    const firstChoice = Array.isArray(choices) ? asRecord(choices[0]) : undefined;
    const message = asRecord(firstChoice?.['message']);

    if (message === undefined) {
      throw new AIProviderError({
        code: 'provider_error',
        providerId: this.id,
        message: 'DeepSeek API response did not contain a usable choice.',
        model,
        retryable: false,
      });
    }

    const content = this.extractContent(message['content']);
    const toolCalls = this.extractToolCalls(message['tool_calls'], model);
    const rawFinishReason = asNonEmptyString(firstChoice?.['finish_reason']);
    const usage = this.extractUsage(root?.['usage']);
    const structured = this.extractStructured(content, request.responseFormat);

    return {
      providerId: this.id,
      model: asNonEmptyString(root?.['model']) ?? model,
      content,
      finishReason: this.mapFinishReason(rawFinishReason),
      latencyMs,
      ...(asNonEmptyString(root?.['id']) !== undefined
        ? { requestId: asNonEmptyString(root?.['id']) }
        : {}),
      ...(structured !== undefined ? { structured } : {}),
      ...(toolCalls !== undefined ? { toolCalls } : {}),
      ...(rawFinishReason !== undefined ? { rawFinishReason } : {}),
      ...(usage !== undefined ? { usage } : {}),
    };
  }

  /**
   * Extrait le texte généré, que le fournisseur retourne une chaîne ou des fragments.
   *
   * @param content - Champ `content` brut.
   * @returns Texte concaténé (chaîne vide si la réponse ne porte que des outils).
   */
  private extractContent(content: unknown): string {
    if (typeof content === 'string') return content;
    if (!Array.isArray(content)) return '';
    const chunks: string[] = [];
    for (const part of content) {
      const record = asRecord(part);
      const text = asNonEmptyString(record?.['text']);
      if (text !== undefined) chunks.push(text);
    }
    return chunks.join('');
  }

  /**
   * Normalise les appels d'outil demandés par le modèle. Les arguments
   * arrivent sous forme de chaîne JSON (documenté officiellement) et doivent
   * être validés — ce provider les décode et les valide, sans jamais les exécuter.
   *
   * @param toolCalls - Champ `tool_calls` brut.
   * @param model - Modèle concerné.
   * @returns Appels normalisés, ou `undefined` si aucun.
   * @throws {AIProviderError} Si les arguments ne sont pas un objet JSON valide.
   */
  private extractToolCalls(toolCalls: unknown, model: AIModelId): readonly AIToolCall[] | undefined {
    if (!Array.isArray(toolCalls) || toolCalls.length === 0) return undefined;

    const normalized: AIToolCall[] = [];
    for (const entry of toolCalls) {
      const record = asRecord(entry);
      const fn = asRecord(record?.['function']);
      const id = asNonEmptyString(record?.['id']);
      const name = asNonEmptyString(fn?.['name']);
      const rawArguments = fn?.['arguments'];

      if (id === undefined || name === undefined) {
        throw new AIProviderError({
          code: 'provider_error',
          providerId: this.id,
          message: 'DeepSeek API returned an incomplete tool call.',
          model,
          retryable: false,
        });
      }

      normalized.push({ id, name, arguments: this.parseToolArguments(rawArguments, model) });
    }
    return normalized;
  }

  /**
   * @param rawArguments - Arguments bruts (chaîne JSON, documentée par DeepSeek).
   * @param model - Modèle concerné.
   * @returns Arguments décodés.
   * @throws {AIProviderError} Si les arguments ne sont pas décodables en objet JSON.
   */
  private parseToolArguments(rawArguments: unknown, model: AIModelId): JsonObject {
    if (rawArguments === undefined || rawArguments === null || rawArguments === '') {
      return {};
    }
    const candidate: unknown =
      typeof rawArguments === 'string' ? this.tryParseJson(rawArguments) : rawArguments;
    const decoded = toJsonObject(candidate);
    if (decoded === undefined) {
      throw new AIProviderError({
        code: 'provider_error',
        providerId: this.id,
        message: 'DeepSeek API returned tool call arguments that are not a JSON object.',
        model,
        retryable: false,
      });
    }
    return decoded;
  }

  /**
   * Décode le contenu comme sortie structurée lorsqu'un format `json_object` a
   * été demandé.
   *
   * Note : la documentation officielle signale qu'en mode JSON Output, l'API
   * peut occasionnellement retourner un `content` vide. Ce cas se traduit
   * naturellement par l'absence de `structured` ci-dessous, sans échec —
   * `content` reste disponible pour diagnostic par la couche appelante.
   *
   * @param content - Texte généré.
   * @param format - Format demandé.
   * @returns Valeur structurée, ou `undefined`.
   */
  private extractStructured(
    content: string,
    format: AIResponseFormat | undefined,
  ): JsonValue | undefined {
    if (format === undefined || format.type !== 'json_object' || content === '') return undefined;
    const parsed = this.tryParseJson(content);
    return parsed === undefined ? undefined : toJsonValue(parsed);
  }

  /**
   * @param raw - Texte à décoder.
   * @returns Valeur décodée, ou `undefined` si le texte n'est pas du JSON.
   */
  private tryParseJson(raw: string): unknown {
    try {
      return JSON.parse(raw);
    } catch {
      return undefined;
    }
  }

  /**
   * Normalise la consommation en tokens.
   *
   * @param usage - Champ `usage` brut.
   * @returns Usage normalisé, ou `undefined` si aucune donnée exploitable.
   */
  private extractUsage(usage: unknown): AIUsage | undefined {
    const record = asRecord(usage);
    if (record === undefined) return undefined;

    const inputTokens = asFiniteNumber(record['prompt_tokens']);
    const outputTokens = asFiniteNumber(record['completion_tokens']);
    const totalTokens = asFiniteNumber(record['total_tokens']);

    if (inputTokens === undefined && outputTokens === undefined && totalTokens === undefined) {
      return undefined;
    }
    return {
      ...(inputTokens !== undefined ? { inputTokens } : {}),
      ...(outputTokens !== undefined ? { outputTokens } : {}),
      ...(totalTokens !== undefined ? { totalTokens } : {}),
    };
  }

  /**
   * @param reason - Raison brute du fournisseur.
   * @returns Raison normalisée (`other` pour toute valeur propre au fournisseur).
   */
  private mapFinishReason(reason: string | undefined): AIFinishReason {
    switch (reason) {
      case 'stop':
        return 'stop';
      case 'length':
        return 'length';
      case 'tool_calls':
        return 'tool_calls';
      case 'content_filter':
        return 'content_filter';
      case 'error':
        return 'error';
      default:
        return 'other';
    }
  }
}