# Manifeste — Socle partagé & racine (18 fichiers)

Propriété : partagée, validée par Claude (direction de projet). Base
commune que les 3 lots consomment.

---

### 1. `shared/types/events.py`
**Prompt** : "En te basant sur `00-master-coordination.md` section 3
(contrat d'événements Kafka), écris les modèles Pydantic v2 pour chaque
event listé (`RawSignalEvent`, `ContextUpdateEvent`,
`ArbitrageResultEvent`, `LegionTaskEvent`, `AgentHeartbeatEvent`). Chaque
modèle doit inclure un champ `schema_version: int` et un `event_id: UUID`.
Typage strict, aucun champ optionnel non justifié."

### 2. `shared/types/entities.py`
**Prompt** : "Écris les modèles Pydantic v2 pour les entités métier
canoniques : `Tenant`, `Plan`, `Quota`, `Zone`, `SKUCanonical`,
`PriceObservation`, `TrackedProduct`, `ArbitrageResult`. Respecte les
conventions de nommage de `00-master-coordination.md` section 2 (UUID v7,
ISO 8601 UTC). Ces modèles doivent être importables par les 3 lots."

### 3. `shared/schemas/migrations/001_tenants.sql`
**Prompt** : "Écris la migration SQL PostgreSQL 16 pour la table
`tenants` (id UUID v7, name, created_at, is_active). Inclure les index
nécessaires et les contraintes NOT NULL pertinentes."

### 4. `shared/schemas/migrations/002_plans.sql`
**Prompt** : "Écris la migration SQL pour la table `plans` (id, name,
tier_level, max_tracked_products, min_refresh_interval_s,
legion_contributor_discount_pct). Prévoir les paliers Free/Pro/Enterprise
comme lignes de seed initiales."

### 5. `shared/schemas/migrations/003_quotas.sql`
**Prompt** : "Écris la migration SQL pour la table `quotas` liant
`tenant_id` à `plan_id`, avec compteurs d'usage courant
(`tracked_products_count`, `legion_contribution_score`). Contrainte
FK stricte vers `tenants` et `plans`."

### 6. `shared/schemas/migrations/004_zones.sql`
**Prompt** : "Écris la migration SQL pour la table `zones` (référentiel
géographique VENUS) : id, country_code, region_label, fx_rate_snapshot,
tariff_profile_ref, sanctions_flags (JSONB), socioeconomic_index. Prévoir
un index sur `country_code`."

### 7. `shared/schemas/migrations/005_sku_canonical.sql`
**Prompt** : "Écris la migration SQL pour la table `sku_canonical`
(id, canonical_name, category, embedding_ref_qdrant_id, created_at). Pas
de stockage du vecteur lui-même (réside dans Qdrant), seulement la
référence."

### 8. `shared/schemas/migrations/006_price_observations.sql`
**Prompt** : "Écris la migration SQL pour la table `price_observations`
en tant qu'hypertable TimescaleDB, partitionnée par `observed_at`. Champs :
sku_canonical_id, zone_id, actor_id, price_raw, currency, observed_at,
source_event_id. Inclure la commande `create_hypertable`."

### 9. `shared/schemas/migrations/007_tracked_products.sql`
**Prompt** : "Écris la migration SQL pour la table `tracked_products`
(sku_canonical_id, tenant_id, tracked_since, tracking_source,
popularity_score, refresh_interval_s, is_active). Voir ADR 0004 pour la
logique du refresh adaptatif."

### 10. `shared/schemas/migrations/008_arbitrage_results.sql`
**Prompt** : "Écris la migration SQL pour la table `arbitrage_results`,
event-sourcée (immuable, jamais d'UPDATE) : id, sku_canonical_id,
zone_a_id, zone_b_id, net_margin, feasibility_score, confidence,
context_version_id, computed_at, source_event_id. Voir brief Lot B section
0 pour le détail du modèle."

### 11. `shared/schemas/migrations/009_raw_signal_events.sql`
**Prompt** : "Écris la migration SQL pour la table de traçabilité
`raw_signal_events` (event_id, source, payload_hash, ingested_at,
processed_at). Sert à l'idempotence MERCURE."

### 12. `shared/schemas/migrations/010_venus_context_versions.sql`
**Prompt** : "Écris la migration SQL pour la table
`venus_context_versions` (id, snapshot_at, fx_source_version,
tariff_source_version, sanctions_source_version). Permet la traçabilité
du `context_version_id` référencé par `arbitrage_results`."

### 13. `shared/schemas/erd.md`
**Prompt** : "Génère un diagramme ERD (format Mermaid) représentant les
relations entre toutes les tables des migrations 001 à 010. Inclure les
cardinalités."

### 14. `.gitignore`
**Prompt** : "Écris un `.gitignore` couvrant Python (venv, __pycache__),
Node/Next.js (node_modules, .next), fichiers d'environnement (.env),
et artefacts Docker/Terraform (.terraform, *.tfstate)."

### 15. `LICENSE`
**Prompt** : "Ne pas générer automatiquement — nécessite une décision
humaine sur le type de licence (propriétaire vs open-core). En attente de
validation du porteur de projet."

### 16. `CONTRIBUTING.md`
**Prompt** : "Écris un guide de contribution résumant les conventions de
`00-master-coordination.md` (formatage, nommage, definition of done) pour
un futur contributeur humain rejoignant l'équipe."

### 17. `pyproject.toml` (racine)
**Prompt** : "Écris un `pyproject.toml` configurant `ruff`, `black`, et
`isort` selon les conventions de `00-master-coordination.md` section 2,
avec les règles de lint activées pour un monorepo Python multi-services."

### 18. `Makefile`
**Prompt** : "Écris un Makefile avec les cibles : `dev-up` (lance
docker-compose), `dev-down`, `test` (lance les tests de tous les
services), `lint`, `migrate` (applique les migrations SQL dans l'ordre)."
