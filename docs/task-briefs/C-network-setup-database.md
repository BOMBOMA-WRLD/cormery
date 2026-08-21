# Lot C — Réseau + Setup + Base de données
**IA responsable** : Mistral (support : Copilot pour complétion de code
bas niveau)
**Dépend de** : `00-master-coordination.md` (contrats obligatoires)

## Périmètre

1. **Topologie réseau** : infrastructure d'exécution complète (dev, staging,
   production)
2. **Fichiers de lancement** : docker-compose (dev local), Helm charts
   (Kubernetes prod), CI/CD
3. **Schéma de données canonique** (PostgreSQL 16 + TimescaleDB)
4. **Jeux de données de test**
5. **Connecteurs VENUS** (ingestion FX, douanes, sanctions, socio-éco)

## 0. Schéma de données canonique

Entités à modéliser (propriété exclusive de ce lot — les Lots A et B
consomment ce schéma, ne le modifient jamais unilatéralement) :

- `Tenant`, `Plan`, `Quota` — multi-tenancy (ADR 0002)
- `Zone` — référentiel géographique enrichi par VENUS (FX, douanes,
  sanctions, socio-éco)
- `SKUCanonical` — écrit par le Réconciliateur (Lot B), stocké/interrogé ici
- `PriceObservation` — série temporelle Timescale, alimentée par MERCURE
  (Lot B) via Kafka
- `TrackedProduct` — `popularity_score` et `refresh_interval_s` adaptatif
  (logique hybride, ADR 0004)
- `ArbitrageResult` — sortie d'OPTIMUS (Lot B), **event-sourcée**
  (jamais de colonne mutable "marge actuelle")
- `RawSignalEvent` — table de traçabilité des events consommés depuis
  MERCURE

Schéma exporté dans `shared/schemas/` pour consultation par les Lots A et B.

## 0bis. Connecteurs VENUS

Pipeline d'ingestion de contexte lent, distinct du pipeline MERCURE
(fréquence de mise à jour très différente — voir architecture globale) :
- FX live (API type exchangerate.host, Fixer)
- Droits de douane par HS code (bases tarifaires douanières, WTO Tariff
  Database)
- Sanctions/embargos (OFAC, listes UE)
- Données socio-économiques (démographie, pouvoir d'achat local)

Publication sur `cormery.venus.context.updated` (contrat Kafka, voir
document maître). Cache de contexte versionné : chaque calcul OPTIMUS
référence la version du référentiel utilisée (`context_version_id`), pour
traçabilité/audit — jamais de lecture directe non versionnée.

## 0ter. Jeux de données de test

- 500 `SKUCanonical` synthétiques couvrant 5 catégories de produits
- 20 `Zone` réalistes (mix zones économiquement contrastées : UE,
  Amérique du Nord, Asie du Sud-Est, zones sous sanctions partielles)
- Séries `PriceObservation` sur 90 jours glissants avec volatilité
  variable (SKU stables vs très volatils, pour tester
  `refresh_interval_s` adaptatif)
- Cas limites explicites : produit avec embargo total sur une paire de
  zones (`feasibility_score = 0` attendu), produit avec données VENUS
  manquantes (`confidence` dégradée attendue)

## 4.1 — Topologie réseau

Composants à orchestrer (déjà choisis, voir architecture globale) :
- PostgreSQL 16 + TimescaleDB (transactionnel + séries temporelles)
- Redpanda (bus d'événements, API Kafka)
- Redis (cache court terme)
- Qdrant (vector DB — Réconciliateur)
- MinIO/S3 (data lake brut — MERCURE)
- API Gateway (GraphQL + REST)
- Services applicatifs (Lot 1 backend, Lot 3 agents)
- Frontend Next.js (Lot 2)

### Contraintes réseau spécifiques
- **Isolation multi-tenant** au niveau réseau si possible (namespaces
  Kubernetes par tier de plan, pas seulement logique applicative) —
  cohérent avec ADR 0002
- **Fleet Command** doit pouvoir piloter deux flottes distinctes de
  nature différente : agents MERCURE (infra propriétaire, réseau interne
  contrôlé) et nœuds LEGION (machines externes, hors de votre réseau,
  communication exclusivement via API publique authentifiée — jamais
  d'accès réseau direct entrant vers l'infra centrale)
- **Scalabilité horizontale** : les workers MERCURE et les consommateurs
  Kafka doivent pouvoir scaler indépendamment selon la charge (HPA
  Kubernetes basé sur la profondeur de queue, pas seulement CPU)
- Communication interne services : gRPC ou HTTP interne selon pertinence,
  jamais d'exposition publique des ports internes (Postgres, Redis, etc.)

## 4.2 — Fichier de lancement (setup)

### Dev local (déjà initié — à compléter/enrichir)
- `infra/docker/docker-compose.yml` existant à étendre avec les services
  applicatifs (backend Lot 1, agents Lot 3, frontend Lot 2) une fois leur
  code livré
- `.env.example` à maintenir à jour avec toutes les variables requises
  par les 4 lots

### Production
- Helm charts (`infra/k8s/`) pour déploiement Kubernetes
- Gestion des secrets via intégration avec le vault défini par le Lot 3
  (jamais de secret en clair dans les manifests)
- CI/CD : pipeline de build/test/déploiement (GitHub Actions ou
  équivalent), avec étapes de scan de sécurité (dépendances, secrets
  accidentels) avant déploiement

### Exigence de robustesse
- Tout service doit avoir un healthcheck exploitable par l'orchestrateur
- Stratégie de rollback claire en cas d'échec de déploiement
- Documentation d'exploitation minimale : comment scaler un composant,
  comment lire les logs centralisés, comment déclencher un rollback

## Interfaces à fournir aux autres lots

- Liste exhaustive des variables d'environnement requises par service,
  documentée dans chaque `README.md` de service
- Schéma de la topologie réseau (diagramme) partagé avec les 3 autres
  lots pour validation des points d'intégration
