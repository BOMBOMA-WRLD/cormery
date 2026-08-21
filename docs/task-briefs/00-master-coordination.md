# 00 — Coordination maîtresse multi-IA — CORMERY

**Rôle de ce document** : contrat non négociable entre les 3 IA productrices.
Chaque lot DOIT respecter ces conventions à la lettre. Toute divergence
casse l'intégration entre les lots.

**Répartition** (3 lots de production — Claude n'exécute pas de lot,
rôle de direction de projet/architecture uniquement, voir section 0) :

| Lot | IA | Domaines |
|---|---|---|
| A | ChatGPT | Frontend (design Apple 2026) + API Gateway |
| B | DeepSeek | Agents IA + Sécurité + OPTIMUS + Réconciliateur |
| C | Mistral | Réseau + Setup + Base de données + connecteurs VENUS |

## 0. Rôle de Claude — direction de projet, pas production

Claude ne produit pas de code applicatif sur un lot dédié. Son rôle se
limite à :
- Maintenir ce document et les ADR (`docs/adr/`)
- Valider la cohérence d'architecture entre les 3 lots avant intégration
- Arbitrer les conflits de contrat d'interface (ex: divergence de schéma
  d'événement entre deux lots)
- Revue ponctuelle de cohérence, pas d'implémentation ligne à ligne

---

## 1. Nomenclature — rappel obligatoire (voir ADR 0001 et 0005)

- **Couche interne** (code, DB, events) : `MERCURE`, `VENUS`, `OPTIMUS`,
  `LEGION`, `FLEET_COMMAND`, `ORACLE`, `RECONCILIATOR` — snake_case ou
  PascalCase selon le langage, jamais francisé dans le code.
- **Couche client-facing** (UI uniquement, lot Frontend) : traduction
  obligatoire selon la table de l'ADR 0005 (`OPTIMUS` → "Score Delta",
  `ORACLE` → "Éclaireur", etc.). **Aucun nom interne dans l'UI visible.**
- **Interdiction absolue** : `OPTIMUS` et `ORACLE` ne doivent jamais
  apparaître dans du texte destiné au client final, un dépôt de marque, ou
  une CGU (risque de collision avec Tesla/Hasbro et Oracle Corp).

## 2. Conventions de code partagées

| Aspect | Règle |
|---|---|
| Langage backend | Python 3.12+ (FastAPI), typage strict (Pydantic v2) |
| Langage frontend | TypeScript strict, Next.js 15+ (App Router) |
| Langage agents/IA | Python 3.12+ pour la logique, Go autorisé uniquement si profiling prouve un besoin de débit I/O (à justifier) |
| Formatage Python | `ruff` + `black`, imports triés (`isort`) |
| Formatage TS/JS | `eslint` + `prettier` |
| Nommage DB | `snake_case`, tables au pluriel (`price_observations`) |
| Nommage API REST | `/v1/kebab-case-resources` |
| Nommage champs JSON/API | `camelCase` en sortie API, `snake_case` en DB |
| IDs | UUID v7 partout (triable temporellement), jamais d'auto-increment int exposé en API |
| Dates | ISO 8601 UTC strict, jamais de timestamp naïf |

## 3. Contrat d'événements Kafka/Redpanda (OBLIGATOIRE — tous les lots)

Tous les topics suivent le format : `cormery.<domaine>.<entité>.<action>`

| Topic | Producteur | Consommateurs | Schéma |
|---|---|---|---|
| `cormery.mercure.raw-signal.ingested` | MERCURE (Lot B) | Base de données (Lot C) | `RawSignalEvent` |
| `cormery.venus.context.updated` | VENUS (Lot C) | OPTIMUS (Lot B) | `ContextUpdateEvent` |
| `cormery.optimus.arbitrage.computed` | OPTIMUS (Lot B) | API Gateway (Lot A), Fleet Command (Lot B) | `ArbitrageResultEvent` |
| `cormery.legion.task.assigned` / `.completed` | Fleet Command (Lot B) | LEGION nodes, Base de données (Lot C) | `LegionTaskEvent` |
| `cormery.fleet.agent.heartbeat` | Agents MERCURE/LEGION (Lot B) | Fleet Command (Lot B) | `AgentHeartbeatEvent` |

**Règle stricte** : tout schéma d'event doit être défini en Pydantic
(`shared/types/events.py`) et versionné (`schema_version` obligatoire dans
chaque payload). Aucun lot ne peut modifier un schéma existant sans mise à
jour de version + notification aux 3 autres lots via ce document.

## 4. Contrat multi-tenant (OBLIGATOIRE — Backend, DB, Sécurité, Frontend)

- Toute table/entité métier possède un champ `tenant_id` (UUID) non
  nullable.
- Toute requête API doit être scopée par `tenant_id` extrait du token
  d'authentification — **jamais** passé en paramètre libre côté client
  (risque d'IDOR — voir Lot 3 Sécurité).
- Les plans/quotas (`plan_id`) déterminent : nombre de `TrackedProduct`,
  `refresh_interval_s` minimum autorisé, accès LEGION en tant que
  contributeur vs bénéficiaire.

## 5. Frontières de responsabilité strictes entre lots

- **Lot C (Réseau/Setup/DB)** possède le schéma de données canonique et
  les connecteurs VENUS. Les Lots A et B consomment ce schéma, ne le
  modifient jamais unilatéralement.
- **Lot A (Frontend/API Gateway)** ne calcule jamais de logique métier
  (arbitrage, scoring) côté client ni dans le Gateway — pur agrégateur/
  proxy vers OPTIMUS (Lot B) et le schéma de données (Lot C).
- **Lot B (Agents IA/Sécurité/OPTIMUS/Réconciliateur)** ne définit pas le
  schéma DB final, mais fournit ses besoins de stockage au Lot C sous
  forme de spécification écrite (jamais de migration DB imposée
  unilatéralement).
- Toute modification d'un contrat partagé (schéma DB, événement Kafka,
  endpoint API) doit être proposée dans ce document et validée par Claude
  (direction de projet) avant implémentation par les lots concernés.

## 6. Definition of Done commune

Chaque lot livre :
1. Code source dans son dossier `services/` dédié
2. Un `README.md` de service expliquant comment le lancer isolément
3. Des tests (couverture minimale : chemins critiques, pas 100% obligatoire)
4. Une mise à jour de ce document si un contrat d'interface évolue
5. Aucune référence en dur à un secret/clé API (voir brief Sécurité, Lot 3)
