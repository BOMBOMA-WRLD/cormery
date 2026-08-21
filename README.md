# CORMERY

Plateforme d'intelligence économique industrielle pour le e-commerce et
l'arbitrage financier spatio-temporel.

## Sous-systèmes

| Nom | Rôle |
|---|---|
| **MERCURE** | Essaim d'agents d'extraction — ingestion haute fréquence (prix, stock, ad velocity) |
| **VENUS** | Pipeline de contexte lent — FX, douanes, sanctions, socio-économique |
| **OPTIMUS** | Moteur de scoring d'arbitrage spatio-temporel (marge nette + faisabilité géopolitique) |
| **LEGION** | Réseau de calcul distribué communautaire (calcul pur uniquement) |
| **Fleet Command** | Centre de commandement (C2) — pilote MERCURE et LEGION |
| **Réconciliateur** | Résolution d'entités multimodale (Universal SKU) |
| **Oracle** | Détection précoce de tendances / winning products |

Voir `docs/adr/` pour l'historique complet des décisions d'architecture.

## Structure du monorepo

```
cormery/
├── apps/                    # Applications exposées
├── packages/                # Contrats et bibliothèques partagés
├── services/                # Services métier Iliade et Future
├── workers/                 # Traitements asynchrones
├── infrastructure/          # Docker, Terraform, monitoring et déploiement
├── docs/                    # Références et décisions d'architecture
├── scripts/                 # Automatisation du dépôt
├── tests/                   # Tests transverses
└── .github/                 # Workflows et configuration GitHub
```

## Démarrage de l'environnement local

```bash
cp .env.example .env
docker compose up -d
```

Ou depuis le dossier Docker:

```bash
cd infrastructure/docker
cp .env.example .env
docker compose up -d
```

Services exposés :
- PostgreSQL/TimescaleDB : `localhost:5432`
- Redpanda (Kafka API)  : `localhost:9092`
- Redpanda Console      : `localhost:8080`
- Redis                 : `localhost:6379`
- Qdrant                : `localhost:6333`
- MinIO (S3 API)        : `localhost:9000` / Console : `localhost:9001`

## État d'avancement

- [x] Nomenclature et architecture globale validées (ADR 0001–0004)
- [x] Séparation nommage interne / client-facing + alerte marque (ADR 0005)
- [x] Modèle de distribution (SaaS à paliers + LEGION) tranché
- [x] Répartition multi-IA en 3 lots de production + contrats d'interface (`docs/task-briefs/`)
- [ ] Schéma de données canonique + connecteurs VENUS (Lot C — Mistral)
- [ ] Frontend + API Gateway (Lot A — ChatGPT)
- [ ] Agents IA + Sécurité + OPTIMUS + Réconciliateur (Lot B — DeepSeek)

## Production multi-IA

Le projet est produit en 3 lots parallèles, chacun assigné à une IA
différente. Claude assure la direction de projet et l'architecture
(ADR, contrats d'interface, arbitrage) sans lot de production dédié.
Voir `docs/task-briefs/00-master-coordination.md` pour les contrats
d'interface obligatoires (nomenclature, events Kafka, multi-tenancy) que
chaque lot doit respecter pour garantir l'intégration.

| Lot | IA | Domaines | Brief | Manifeste de fichiers |
|---|---|---|---|---|
| A | ChatGPT | Frontend (Apple 2026) + API Gateway | `A-frontend-api-gateway.md` | `A-file-manifest.md` (32 fichiers) |
| B | DeepSeek | Agents IA + Sécurité + OPTIMUS + Réconciliateur | `B-agents-security-optimus.md` | `B-file-manifest.md` (64 fichiers) |
| C | Mistral | Réseau + Setup + Base de données + VENUS | `C-network-setup-database.md` | `C-file-manifest.md` (54 fichiers) |

Socle partagé (18 fichiers) : `00-file-manifest-shared.md`
Index complet : `docs/task-briefs/INDEX-file-manifests.md` (168 fichiers au total)
