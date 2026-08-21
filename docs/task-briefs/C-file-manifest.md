# Manifeste — Lot C : Réseau + Setup + Base de données (54 fichiers)
**IA responsable** : Mistral — brief complet dans `C-network-setup-database.md`

---

## Seed / jeux de test (5 fichiers)

### 19. `scripts/seed/generate_test_skus.py`
**Prompt** : "Écris un script Python générant 500 `SKUCanonical`
synthétiques sur 5 catégories, conforme au modèle
`shared/types/entities.py`. Sortie en JSON ou insertion directe SQL, au
choix, mais reproductible (seed aléatoire fixe)."

### 20. `scripts/seed/generate_test_zones.py`
**Prompt** : "Écris un script générant 20 `Zone` réalistes couvrant UE,
Amérique du Nord, Asie du Sud-Est, et au moins 2 zones sous sanctions
partielles (voir brief Lot C section 0ter pour les cas limites requis)."

### 21. `scripts/seed/generate_test_price_series.py`
**Prompt** : "Écris un script générant des séries `PriceObservation` sur
90 jours glissants, avec un mix explicite de SKU stables et de SKU très
volatils (pour tester le `refresh_interval_s` adaptatif d'OPTIMUS)."

### 22. `scripts/seed/generate_edge_cases.py`
**Prompt** : "Écris un script générant les cas limites explicites requis
par le brief Lot C : un produit avec embargo total sur une paire de
zones (feasibility_score=0 attendu), un produit avec données VENUS
manquantes (confidence dégradée attendue)."

### 23. `scripts/seed/README.md`
**Prompt** : "Documente comment exécuter l'ensemble des scripts de seed
dans le bon ordre, et comment les relancer pour régénérer un
environnement de test propre."

## Connecteurs VENUS (12 fichiers)

### 24. `services/venus/connectors/base_connector.py`
**Prompt** : "Écris une classe abstraite `BaseConnector` définissant
l'interface commune à tous les connecteurs VENUS (fetch, normalize,
publish). Gestion d'erreur et retry avec backoff exponentiel."

### 25. `services/venus/connectors/fx_connector.py`
**Prompt** : "Écris un connecteur FX live héritant de `BaseConnector`,
interrogeant une API de taux de change et publiant sur
`cormery.venus.context.updated` (voir contrat Kafka, document maître)."

### 26. `services/venus/connectors/tariff_connector.py`
**Prompt** : "Écris un connecteur pour les droits de douane par HS code
(source type WTO Tariff Database), même interface que `fx_connector.py`."

### 27. `services/venus/connectors/sanctions_connector.py`
**Prompt** : "Écris un connecteur pour les listes de sanctions/embargos
(OFAC, UE). Doit produire un flag booléen exploitable par le
`feasibility_score` d'OPTIMUS."

### 28. `services/venus/connectors/socioeconomic_connector.py`
**Prompt** : "Écris un connecteur pour les données démographiques et de
pouvoir d'achat local, alimentant l'indice socio-économique de `Zone`."

### 29. `services/venus/pipeline.py`
**Prompt** : "Écris l'orchestrateur exécutant les 4 connecteurs VENUS
selon leur fréquence propre (basse fréquence, contrairement à MERCURE),
et écrivant une nouvelle ligne dans `venus_context_versions` à chaque
cycle complet."

### 30. `services/venus/context_cache.py`
**Prompt** : "Écris le cache de contexte versionné consommé par OPTIMUS.
Chaque lecture doit retourner explicitement le `context_version_id`
utilisé, jamais un contexte non versionné."

### 31. `services/venus/kafka_producer.py`
**Prompt** : "Écris le producteur Kafka générique utilisé par les 4
connecteurs pour publier sur `cormery.venus.context.updated`, avec
sérialisation Pydantic et `schema_version`."

### 32. `services/venus/config.py`
**Prompt** : "Écris la configuration (Pydantic Settings) listant toutes
les clés d'API et endpoints requis par les connecteurs, lues depuis
variables d'environnement, jamais en dur."

### 33. `services/venus/README.md`
**Prompt** : "Documente comment lancer le pipeline VENUS isolément en
local, avec quelles variables d'environnement minimales."

### 34. `services/venus/tests/test_fx_connector.py`
**Prompt** : "Écris des tests unitaires pour `fx_connector.py`, avec
mock de l'API externe, couvrant le cas nominal et le cas d'échec réseau."

### 35. `services/venus/tests/test_context_cache.py`
**Prompt** : "Écris des tests vérifiant que le cache de contexte retourne
toujours un `context_version_id` cohérent et qu'une lecture ne peut
jamais retourner un contexte partiellement mis à jour."

## Infra dev (5 fichiers)

### 36. `infra/docker/docker-compose.yml` (mise à jour)
**Prompt** : "Étends le docker-compose existant (déjà fourni) en
ajoutant les services applicatifs des Lots A et B une fois leur code
livré : api-gateway, frontend, optimus, mercure, fleet-command."

### 37. `infra/docker/docker-compose.prod.yml`
**Prompt** : "Écris une variante docker-compose adaptée à un déploiement
mono-serveur simplifié (hors Kubernetes), pour des tests de charge ou un
environnement de démo."

### 38. `infra/docker/.env.example` (mise à jour)
**Prompt** : "Complète le fichier .env.example existant avec toutes les
variables requises par VENUS (clés API FX, douanes, sanctions) et par les
services applicatifs des Lots A/B une fois connus."

### 39. `infra/docker/Dockerfile.backend-base`
**Prompt** : "Écris une image Docker de base Python 3.12 partagée par
tous les services backend (VENUS, OPTIMUS, MERCURE, etc.), avec les
dépendances communes préinstallées."

### 40. `infra/docker/Dockerfile.frontend`
**Prompt** : "Écris le Dockerfile multi-stage pour le frontend Next.js
(build + runtime allégé)."

## Infra Kubernetes / Terraform / CI (30 fichiers)

### 41. `infra/k8s/namespace.yaml`
**Prompt** : "Écris les namespaces Kubernetes séparant les environnements
(dev/staging/prod) et, si possible, les tiers de plan (voir brief Lot C
section 4.1, isolation multi-tenant réseau)."

### 42. `infra/k8s/postgres-statefulset.yaml`
**Prompt** : "Écris le StatefulSet Kubernetes pour PostgreSQL/TimescaleDB
avec PersistentVolumeClaim, healthcheck, et limites de ressources."

### 43. `infra/k8s/redpanda-statefulset.yaml`
**Prompt** : "Écris le StatefulSet Kubernetes pour Redpanda, en mode
cluster minimal viable pour la prod."

### 44. `infra/k8s/redis-deployment.yaml`
**Prompt** : "Écris le Deployment Kubernetes pour Redis avec persistence
optionnelle selon l'usage (cache pur, pas de durabilité stricte requise)."

### 45. `infra/k8s/qdrant-statefulset.yaml`
**Prompt** : "Écris le StatefulSet Kubernetes pour Qdrant avec
PersistentVolumeClaim dimensionné pour plusieurs millions de vecteurs."

### 46. `infra/k8s/minio-statefulset.yaml`
**Prompt** : "Écris le StatefulSet Kubernetes pour MinIO en mode
distribué si le volume de données brutes MERCURE le justifie."

### 47. `infra/k8s/network-policies.yaml`
**Prompt** : "Écris les NetworkPolicy Kubernetes empêchant tout accès
entrant direct aux ports internes (Postgres, Redis, Qdrant) depuis
l'extérieur du cluster, et isolant les namespaces par tenant/tier si
applicable (voir brief Lot C section 4.1)."

### 48. `infra/k8s/secrets-vault-integration.yaml`
**Prompt** : "Écris l'intégration Kubernetes avec le vault de secrets
défini par le Lot B (External Secrets Operator ou équivalent), jamais de
secret en clair dans les manifests."

### 49. `infra/k8s/helm/cormery/Chart.yaml`
**Prompt** : "Écris le Chart.yaml racine du chart Helm CORMERY, listant
toutes les dépendances (sous-charts éventuels)."

### 50. `infra/k8s/helm/cormery/values.yaml`
**Prompt** : "Écris les values par défaut du chart Helm (dev), couvrant
tous les services applicatifs et d'infra."

### 51. `infra/k8s/helm/cormery/values-staging.yaml`
**Prompt** : "Écris l'override de values pour l'environnement staging
(ressources réduites vs prod, mais représentatif)."

### 52. `infra/k8s/helm/cormery/values-production.yaml`
**Prompt** : "Écris l'override de values pour la production
(ressources dimensionnées, réplication activée, autoscaling activé)."

### 53. `infra/k8s/helm/cormery/templates/deployment-api-gateway.yaml`
**Prompt** : "Écris le template Helm de Deployment pour l'API Gateway
(Lot A), avec probes de santé et variables d'environnement injectées."

### 54. `infra/k8s/helm/cormery/templates/deployment-optimus.yaml`
**Prompt** : "Écris le template Helm de Deployment pour le service
OPTIMUS (Lot B)."

### 55. `infra/k8s/helm/cormery/templates/deployment-mercure-agents.yaml`
**Prompt** : "Écris le template Helm de Deployment/Job pour les agents
MERCURE, conçu pour être scalé horizontalement."

### 56. `infra/k8s/helm/cormery/templates/hpa-mercure.yaml`
**Prompt** : "Écris un HorizontalPodAutoscaler basé sur la profondeur de
la queue Kafka (pas seulement le CPU) pour les workers MERCURE — voir
brief Lot C section 4.1."

### 57. `infra/k8s/helm/cormery/templates/deployment-fleet-command.yaml`
**Prompt** : "Écris le template Helm de Deployment pour Fleet Command
(Lot B), avec exposition contrôlée de l'API publique pour les nœuds
LEGION externes."

### 58. `infra/k8s/helm/cormery/templates/deployment-frontend.yaml`
**Prompt** : "Écris le template Helm de Deployment pour le frontend
Next.js (Lot A)."

### 59. `infra/k8s/helm/cormery/templates/ingress.yaml`
**Prompt** : "Écris l'Ingress Kubernetes exposant l'API Gateway et le
frontend publiquement, avec TLS."

### 60. `infra/terraform/main.tf`
**Prompt** : "Écris le fichier Terraform principal provisionnant le
cluster Kubernetes managé (EKS/GKE/AKS au choix, à documenter)."

### 61. `infra/terraform/variables.tf`
**Prompt** : "Écris les variables Terraform paramétrables (région,
taille de cluster, environnement)."

### 62. `infra/terraform/vpc.tf`
**Prompt** : "Écris le provisioning réseau (VPC, sous-réseaux publics/
privés) isolant la base de données et les composants internes du trafic
public."

### 63. `infra/terraform/cluster.tf`
**Prompt** : "Écris le provisioning du cluster Kubernetes managé et de
ses node pools (séparer un pool pour les workers MERCURE, potentiellement
plus volatil, des services stables)."

### 64. `infra/terraform/outputs.tf`
**Prompt** : "Écris les outputs Terraform nécessaires (endpoint cluster,
kubeconfig) pour l'intégration CI/CD."

### 65. `.github/workflows/ci.yml`
**Prompt** : "Écris le pipeline CI : lint, tests unitaires de tous les
services, build des images Docker, à chaque pull request."

### 66. `.github/workflows/cd-staging.yml`
**Prompt** : "Écris le pipeline de déploiement automatique en staging
sur merge dans la branche principale."

### 67. `.github/workflows/cd-production.yml`
**Prompt** : "Écris le pipeline de déploiement en production, avec étape
d'approbation manuelle obligatoire avant application."

### 68. `.github/workflows/security-scan.yml`
**Prompt** : "Écris un pipeline de scan de sécurité (dépendances
vulnérables, secrets accidentellement commités) exécuté avant tout
déploiement — voir brief Lot C exigence de robustesse."

### 69. `infra/README.md`
**Prompt** : "Documente la procédure complète de déploiement, du
provisioning Terraform jusqu'à l'application du chart Helm."

### 70. `docs/runbook-scaling.md`
**Prompt** : "Écris un runbook d'exploitation expliquant comment scaler
manuellement chaque composant en cas de pic de charge imprévu."

### 71. `docs/runbook-rollback.md`
**Prompt** : "Écris un runbook expliquant la procédure de rollback en
cas d'échec de déploiement, pour chaque composant."

### 72. `docs/network-topology-diagram.md`
**Prompt** : "Génère un diagramme (Mermaid) de la topologie réseau
complète, à partager avec les Lots A et B pour validation des points
d'intégration — voir brief Lot C, interfaces à fournir."
