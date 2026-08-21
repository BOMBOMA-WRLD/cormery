# CORMERY — MASTER REFERENCE DOCUMENT
## Document directeur de référence — v1.0

**Date de consolidation : 13 août 2026**  
**Statut : Référence de travail principale**  
**Projet : CORMERY**

---

# 0. Objet du document

Ce document constitue la référence centrale pour la conception future de CORMERY. Il consolide les décisions, préférences, principes, contraintes, architecture, UX/UI, modules, flux, phases, règles de développement et éléments encore à préciser issus des discussions de conception et des documents de projet disponibles.

## Règle de priorité

Lorsqu'une décision plus récente contredit une ancienne proposition :

1. la décision explicite la plus récente du porteur de projet prévaut ;
2. le schéma déjà commencé doit rester intact, sauf décision explicite contraire ;
3. une ancienne proposition contradictoire doit être conservée comme historique, mais marquée comme **SUPERSEDED** ;
4. aucune IA de production ne doit « corriger » silencieusement une décision validée.

---

# 1. VISION DE CORMERY

CORMERY est conçu comme une plateforme mondiale d'intelligence commerciale et d'optimisation spatio-temporelle.

Le principe fondateur n'est pas simplement de comparer des prix.

## Principe fondateur

> **Pour un produit présent ou fabriqué dans une zone A, CORMERY doit déterminer où, quand et par quelles conditions commerciales et logistiques ce produit peut être vendu avec le meilleur bénéfice net réalisable.**

La question centrale du système est :

> **« Où, quand et comment ce produit peut-il générer le meilleur bénéfice net ? »**

Le système doit raisonner simultanément sur :

- produit ;
- origine ;
- destination ;
- fournisseur ;
- qualité ;
- prix d'achat ;
- prix de vente ;
- disponibilité ;
- demande ;
- transport ;
- taxes ;
- douanes ;
- change ;
- coûts opérationnels ;
- temps ;
- risques ;
- contexte économique ;
- contexte géopolitique ;
- contexte social ;
- faisabilité.

CORMERY doit donc être pensé comme un moteur d'optimisation du commerce mondial, et non comme un simple catalogue ou comparateur.

---

# 2. BOUCLE FONDAMENTALE

La boucle conceptuelle de CORMERY est :

```text
OBSERVER
   ↓
IDENTIFIER
   ↓
RÉCONCILIER
   ↓
COMPRENDRE LE CONTEXTE
   ↓
DÉTECTER / PRÉVOIR
   ↓
ÉVALUER LA RENTABILITÉ
   ↓
PRÉSENTER L'OPPORTUNITÉ
   ↓
OPTIMISER LES PARAMÈTRES
   ↓
PLANIFIER
   ↓
DROPSHIP
   ↓
EXÉCUTER
   ↓
MESURER
```

Version système :

```text
MERCURE + VENUS
       ↓
RÉCONCILIATEUR
       ↓
PRODUCT UNIVERSE
       ↓
ORACLE
       ↓
CORMERY CORE
       ↓
DROPSHIP
       ↓
OPTIMUS
       ↓
RÉSULTAT
```

---

# 3. PRINCIPES DE CONCEPTION NON NÉGOCIABLES

## 3.1 Le Globe est le centre de l'expérience

Le Workspace doit être centré sur un globe interactif.

Le globe n'est pas une décoration : il représente l'espace commercial mondial dans lequel CORMERY cherche les meilleures possibilités.

Il doit permettre de visualiser :

- origines ;
- destinations ;
- disponibilités ;
- opportunités ;
- itinéraires ;
- flux ;
- transport ;
- zones de rentabilité ;
- informations temporelles.

## 3.2 Trois informations prioritaires

L'interface doit privilégier :

```text
INDICE
BÉNÉFICE EN USD
TEMPS
```

Exemple :

```text
94
$427
7h42
```

Le montant et l'indice sont distincts : un indice élevé ne signifie pas nécessairement un bénéfice absolu élevé.

## 3.3 Couleur de l'opportunité

La couleur représente le niveau d'opportunité :

```text
BLANC  = inexistante
ROUGE  = minimale / très faible
ORANGE = faible
JAUNE  = intermédiaire
VERT   = élevée / maximale
```

La transition rouge → vert est contrôlée et lisible.

**Blanc ne signifie pas « faible ». Blanc signifie absence d'opportunité exploitable.**

## 3.4 Transport

Les itinéraires doivent être différenciés par leur type :

- aérien ;
- maritime ;
- terrestre.

La couleur de transport ne doit pas remplacer le système rouge → vert de l'indice. Les deux informations doivent rester visuellement distinctes.

## 3.5 Courbes de produits suivis

Les courbes des produits suivis doivent rester plus petites et secondaires par rapport au globe.

Le Workspace doit éviter la surcharge d'informations.

## 3.6 Actions

Les actions d'optimisation sont placées tout en bas du Workspace.

Elles doivent permettre notamment :

- changer de fournisseur ;
- changer la qualité du produit ;
- changer le moyen de transport ;
- changer le lieu cible / destination ;
- lancer Dropship.

Chaque modification doit être évaluée selon son impact sur la rentabilité.

---

# 4. DESIGN / IDENTITÉ VISUELLE

## 4.1 Direction artistique

Le Workspace doit utiliser le thème :

> **Liquid Glass — Carbon Blackout**

Caractéristiques attendues :

- fond noir carbone ;
- surfaces glassmorphism/liquid glass ;
- transparences maîtrisées ;
- profondeur ;
- bordures et reflets subtils ;
- hiérarchie visuelle très forte ;
- rendu premium ;
- design contemporain 2026 ;
- inspiration Apple pour la qualité de finition, sans copier une interface propriétaire.

## 4.2 Règle de sobriété

Le premier Workspace généré montrait trop d'informations.

Décision :

> **Réduire la densité visuelle et faire du globe interactif le centre absolu du Workspace.**

L'information secondaire doit être discrète.

---

# 5. WORKSPACE — STRUCTURE CONCEPTUELLE

Le Workspace constitue le poste de travail principal.

Structure conceptuelle :

```text
WORKSPACE
│
├── Header
│   ├── CORMERY
│   ├── Search
│   ├── Navigation
│   ├── Dropship
│   └── Account
│
├── Central Globe
│   ├── Opportunities
│   ├── Origins
│   ├── Destinations
│   ├── Routes
│   └── Transport
│
├── Primary Opportunity Information
│   ├── Index
│   ├── Profit USD
│   └── Time Window
│
├── Small Product Tracking Curves
│
└── Bottom Optimization Actions
    ├── Supplier
    ├── Quality
    ├── Transport
    ├── Target
    └── Dropship
```

Le Workspace doit répondre rapidement à :

> Où est l'opportunité ?  
> Combien peut-elle rapporter ?  
> Pendant combien de temps ?  
> Que faut-il modifier pour augmenter le bénéfice ?

---

# 6. PRODUCT UNIVERSE / CATALOGUE MONDIAL

Une nouvelle page du Workspace est officiellement prévue :

> **Products / Product Universe**

Objectif :

> permettre à l'utilisateur de retrouver les produits disponibles sur les plateformes commerciales du monde.

## 6.1 Modes de recherche

L'utilisateur peut rechercher par :

- nom ;
- marque ;
- modèle ;
- SKU ;
- GTIN ;
- EAN ;
- UPC ;
- URL d'un produit.

## 6.2 Recherche par URL

Flux :

```text
URL
 ↓
SOURCE DETECTION
 ↓
PRODUCT EXTRACTION
 ↓
RECONCILIATION
 ↓
CANONICAL PRODUCT
```

CORMERY doit tenter d'identifier :

- plateforme ;
- produit ;
- marque ;
- modèle ;
- SKU ;
- GTIN ;
- prix ;
- devise ;
- disponibilité ;
- vendeur.

## 6.3 Universal Product Universe

L'ambition est mondiale, mais le système doit construire progressivement son univers à partir des sources connectées et découvertes.

```text
WORLD
 ↓
SOURCES
 ↓
MERCURE
 ↓
RÉCONCILIATEUR
 ↓
PRODUCT UNIVERSE
```

## 6.4 Résultat produit

Une fiche peut présenter :

```text
CANONICAL PRODUCT
Universal ID
Sources
Marketplaces
Countries
Price Range
Best Buy
Best Sell
Potential Margin
```

Puis :

```text
ANALYZE OPPORTUNITY
```

## 6.5 Connexions

Depuis un produit :

```text
PRODUCT
 ├── Compare
 ├── Analyze
 └── Dropship
```

Parcours :

```text
Recherche
 ↓
Produit
 ↓
Opportunité
 ↓
Dropship
 ↓
OPTIMUS
```

---

# 7. RÉCONCILIATEUR

Le Réconciliateur est le système d'identité produit de CORMERY.

Mission :

> identifier une même entité produit malgré des représentations différentes selon les sources.

Exemple :

```text
Sony WH-1000XM6
Sony WH1000XM6
WH-1000XM6 Headphones
Sony XM6
```

peuvent être associés à :

```text
CORMERY-P-XXXXXX
```

## 7.1 Fonctions

- identification ;
- matching ;
- résolution d'entités ;
- validation ;
- canonicalisation ;
- mémorisation ;
- réutilisation des résolutions.

## 7.2 Mémoire cache

Le Réconciliateur possède une mémoire cache hiérarchique :

```text
L1 — Hot Cache
       ↓
L2 — Persistent Cache
       ↓
L3 — Canonical Database
```

La mémoire conserve notamment :

- identité externe ;
- identité canonique ;
- confiance ;
- champs ayant permis le match ;
- sources ;
- dernière observation ;
- dernière validation ;
- historique ;
- TTL / expiration.

## 7.3 Confiance

Exemple de logique :

```text
0.99 → presque certain
0.95 → très fiable
0.85 → fiable
0.70 → incertain
<0.70 → nouvelle réconciliation
```

Flux :

```text
CACHE HIT
 ↓
Confidence >= threshold ?
 ├── YES → USE
 └── NO  → RECONCILE
```

## 7.4 Types de durée de cache

```text
Universal Product Identity → longue durée
Supplier SKU              → durée moyenne
Price                     → très courte
Stock                     → très courte
```

Le cache n'est pas la source de vérité : la base canonique reste la référence.

## 7.5 Principe mémoire

Le Réconciliateur doit pouvoir apprendre des associations validées :

```text
Observer
 → reconnaître
 → mémoriser
 → réutiliser
 → valider
```

---

# 8. ORACLE

## 8.1 Définition actuelle

ORACLE est le moteur interne de :

> **détection, évaluation et prédiction des opportunités.**

Il doit détecter :

1. les opportunités actuelles ;
2. les opportunités futures.

## 8.2 Current Opportunity Detection

ORACLE doit répondre :

> « Où ce produit est-il actuellement exploitable avec le meilleur bénéfice net ? »

Exemple :

```text
CURRENT OPPORTUNITY
Index: 94
Profit: $427
Window: 7h42
```

## 8.3 Future Opportunity Prediction

ORACLE doit également répondre :

> « Où et quand cette opportunité devrait-elle devenir intéressante ? »

Exemple :

```text
Current Index: 61
Expected Index: 89
Estimated Start: +18h
Estimated Peak: +31h
Estimated End: +46h
Confidence: 87%
```

## 8.4 Architecture

```text
ORACLE
│
├── NOW ENGINE
│   └── Current Opportunities
│
├── FORECAST ENGINE
│   └── Future Opportunities
│
└── OPPORTUNITY ENGINE
    └── Unified Opportunity
```

## 8.5 Rôle

ORACLE ne doit pas acheter, payer ou vendre.

Il produit une opportunité structurée.

---

# 9. CORMERY CORE

CORMERY Core :

- rassemble les informations ;
- présente les opportunités ;
- orchestre les flux ;
- permet l'analyse ;
- permet la planification ;
- relie Product Universe, ORACLE, Dropship et OPTIMUS.

Objet conceptuel :

```text
Opportunity
├── product
├── origin
├── destination
├── currentIndex
├── potentialProfit
├── currency
├── timeWindow
├── forecast
├── confidence
├── detectedAt
└── status
```

Statuts possibles :

```text
ACTIVE
FORECASTED
EXPIRING
EXPIRED
```

---

# 10. PRINCIPE DE RENTABILITÉ

CORMERY ne doit pas optimiser uniquement le prix de vente.

Conceptuellement :

```text
NET PROFIT =
SALE PRICE
- PURCHASE PRICE
- TRANSPORT
- INSURANCE
- TAXES
- CUSTOMS
- FX COSTS
- PLATFORM FEES
- OPERATING COSTS
- TIME COST
- RISK COST
```

La décision doit intégrer les paramètres spatio-temporels.

## 10.1 Origine → destination

Exemple :

```text
Zone A
 ↓
Zone B
Profit $180

Zone A
 ↓
Zone C
Profit $210

Zone A
 ↓
Zone D
Profit $165

Zone A
 ↓
Zone E
Profit $240
```

Mais Zone E n'est pas automatiquement optimale : tous les coûts et risques doivent être intégrés.

## 10.2 Actions d'optimisation

Une action doit recalculer la rentabilité.

Exemple :

```text
Supplier A → $427
Supplier B → $516
Supplier C → $381
```

Même logique pour :

- qualité ;
- transport ;
- destination.

---

# 11. INDICE D'OPPORTUNITÉ

L'indice est distinct du bénéfice.

Exemple :

```text
Opportunity A
Index: 95
Profit: $40

Opportunity B
Index: 72
Profit: $1,850
```

L'indice mesure l'attractivité globale selon les critères du système ; le bénéfice mesure le montant potentiel.

## Facteurs conceptuels

- bénéfice potentiel ;
- faisabilité logistique ;
- fenêtre temporelle ;
- demande ;
- disponibilité ;
- risque ;
- contexte économique ;
- contexte géopolitique ;
- contexte social ;
- autres paramètres métier validés.

---

# 12. ACTIONS PROGRAMMÉES

CORMERY doit permettre d'enregistrer des actions futures.

Flux :

```text
PRODUIT
 ↓
OPPORTUNITÉ
 ↓
ACTION FUTURE
 ↓
DATE / HEURE
 ↓
CONDITIONS
 ↓
EXÉCUTION
 ↓
RÉSULTAT
```

Exemple :

```text
Produit: X
Action: Acheter
Date: 18 août 2026
Heure: 18:40 UTC
Condition: Index >= 90
```

## 12.1 Actions conditionnelles

Exemple :

```text
WHEN
Date >= 18/08/2026 18:40

AND
Opportunity Index >= 90

AND
Potential Profit >= $300

THEN
Execute Action
```

## 12.2 États

```text
CREATED
QUEUED
AUTHORIZED
EXECUTING
COMPLETED
FAILED
CANCELLED
EXPIRED
RETRYING
BLOCKED
```

## 12.3 Niveaux d'automatisation

```text
OBSERVATION
PREPARATION
AUTOMATIC
```

Pour les actions à impact réel, permissions, limites, politiques et audit doivent être appliqués.

---

# 13. DROPSHIP

Dropship est l'outil commercial de CORMERY.

Principe :

> l'utilisateur peut acheter avec CORMERY comme intermédiaire et vendre avec CORMERY comme intermédiaire, entièrement dans la plateforme, selon les capacités effectivement intégrées.

Dropship gère :

- produits ;
- fournisseurs ;
- achats ;
- paiements ;
- commandes ;
- ventes ;
- clients ;
- prix ;
- marge ;
- historique.

## 13.1 Flux

```text
Opportunity
 ↓
Dropship
 ↓
Purchase
 ↓
Payment
 ↓
Tracking
 ↓
Sale
 ↓
Profit
```

## 13.2 Dropship ne doit pas devenir le moteur d'exécution

Il crée / orchestre les opérations commerciales et transmet les tâches au moteur d'exécution.

---

# 14. OPTIMUS

## 14.1 Définition actuelle

Décision récente du projet :

> **OPTIMUS est l'outil / moteur d'exécution des tâches opérationnelles.**

Il exécute notamment :

- achat ;
- paiement ;
- suivi ;
- vente.

## 14.2 Architecture

```text
Dropship
 ↓
TASK
 ↓
OPTIMUS
 ├── Purchase Execution
 ├── Payment Execution
 ├── Tracking Execution
 └── Sale Execution
```

## 14.3 Task

Chaque opération doit être représentée par une tâche structurée :

```text
Task
├── id
├── type
├── status
├── priority
├── source
├── target
├── parameters
├── conditions
├── schedule
├── permissions
├── attempts
├── result
└── audit
```

Types initiaux :

```text
PURCHASE
PAYMENT
TRACKING
SALE
```

## 14.4 Séparation décision / exécution

```text
ORACLE
= détecte / prévoit

CORMERY
= analyse / orchestre

DROPSHIP
= gère l'opération commerciale

OPTIMUS
= exécute
```

Cette séparation est fondamentale.

---

# 15. PAIEMENTS ET AGENTS

Une direction de conception prévoit l'intégration d'un système de paiement permettant à des agents IA d'effectuer des paiements pour Dropship, avec l'écosystème de paiement Cloudflare évoqué pendant les discussions.

Cette intégration doit être traitée comme une couche contrôlée par OPTIMUS :

```text
Dropship
 ↓
Payment Task
 ↓
OPTIMUS
 ↓
Policy / Permission / Limit
 ↓
Payment Engine
 ↓
Payment Provider
 ↓
Confirmation
```

L'agent ne doit pas contourner OPTIMUS pour effectuer directement une opération sensible.

**Le fournisseur exact, le protocole exact, les limites et les conditions juridiques restent à valider avant production.**

---

# 16. MERCURE

MERCURE est une partie distincte de CORMERY avec sa propre structure et ses propres fonctions.

Rôle établi dans l'architecture :

> essaim d'agents d'extraction et ingestion haute fréquence.

Données typiques :

- prix ;
- stock ;
- ad velocity ;
- observations de marché ;
- autres données rapides.

Flux :

```text
SOURCES
 ↓
MERCURE
 ↓
RAW OBSERVATIONS
 ↓
RÉCONCILIATEUR / PIPELINES
```

Le scraping externe reste porté par l'infrastructure contrôlée par CORMERY, et non par les machines des utilisateurs via LEGION en V1.

---

# 17. VENUS

VENUS est une partie distincte de CORMERY avec sa propre structure et ses propres fonctions.

Rôle :

> ingestion et traitement du contexte lent.

Exemples :

- FX ;
- douanes ;
- sanctions ;
- contexte socio-économique ;
- facteurs géopolitiques ;
- autres données contextuelles.

Flux :

```text
SOURCES CONTEXTUELLES
 ↓
VENUS
 ↓
CONTEXT
 ↓
CORMERY / ORACLE / ANALYTICS
```

---

# 18. LEGION

LEGION est une partie distincte de CORMERY.

## 18.1 Rôle

Réseau de calcul distribué communautaire.

## 18.2 V1

LEGION réalise uniquement du **calcul pur vérifiable**.

Exemples :

- génération d'embeddings ;
- calculs de matching pour le Réconciliateur ;
- scoring sur des données déjà autorisées ;
- calculs de modèles de prédiction ;
- autres tâches de calcul bornées.

## 18.3 Exclusion V1

LEGION ne doit pas être utilisé pour le scraping distribué des plateformes tierces.

Motif :

- risque juridique ;
- difficulté de vérification ;
- exposition des IP/utilisateurs ;
- complexité de sandboxing ;
- responsabilité vis-à-vis des CGU de tiers.

Le scraping reste sous contrôle de MERCURE.

---

# 19. FLEET COMMAND

Fleet Command est le centre de commandement interne / C2.

Il pilote :

```text
MERCURE
LEGION
```

C'est le plan de contrôle des deux flottes.

Il peut gérer :

- nœuds ;
- agents ;
- tâches ;
- santé ;
- capacité ;
- quotas ;
- distribution ;
- monitoring ;
- sécurité opérationnelle.

---

# 20. MODÈLE DE DÉPLOIEMENT

Décision d'architecture enregistrée :

> **CORMERY est un SaaS managé à paliers, pas un produit self-hosted du Core en V1.**

CORMERY est hébergé et opéré par l'éditeur.

LEGION permet toutefois de déléguer une partie du calcul à un réseau distribué communautaire.

## 20.1 Plans / quotas

Le système doit pouvoir gérer :

- nombre de produits suivis ;
- fréquence de rafraîchissement ;
- profondeur d'analyse VENUS ;
- priorité des files de calcul ;
- puissance de calcul ;
- autres limites métier.

Le modèle de plans peut évoluer comme les plateformes d'IA / API à différents niveaux de puissance.

## 20.2 Multi-tenancy

Le multi-tenant doit être intégré dès le schéma.

Les entités pertinentes doivent pouvoir être rattachées à :

```text
tenant_id
plan_id
```

---

# 21. ARCHITECTURE TECHNIQUE ACTUELLE DE RÉFÉRENCE

Le socle documenté utilise un monorepo avec des services distincts.

Conceptuellement :

```text
cormery/
├── services/
│   ├── mercure/
│   ├── venus/
│   ├── optimus/
│   ├── legion/
│   ├── fleet-command/
│   ├── reconciliator/
│   └── oracle/
│
├── shared/
│   └── schemas/
│
├── infra/
│   └── docker/
│
└── docs/
    └── adr/
```

Infrastructure locale précédemment prévue :

- PostgreSQL / TimescaleDB ;
- Redpanda / Kafka ;
- Redis ;
- Qdrant ;
- MinIO.

Cette architecture sert de base de référence et ne doit pas être modifiée arbitrairement.

---

# 22. DONNÉES CANONIQUES

Le schéma de données discuté couvre notamment :

- `Zone` ;
- `PriceObservation` ;
- `SKUCanonical` ;
- `TrackedProduct` ;
- `ArbitrageResult` ;
- `RawSignalEvent`.

## 22.1 Règle importante

Le schéma commencé par le porteur du projet doit rester intact.

Les évolutions doivent être faites par extension contrôlée, pas par réécriture silencieuse.

---

# 23. FRONTEND

Le Frontend doit être conçu avec une exigence de qualité 2026.

Direction :

- Liquid Glass ;
- Carbon Blackout ;
- inspiration Apple ;
- rendu premium ;
- globe central ;
- faible surcharge ;
- interactions fluides ;
- informations essentielles visibles immédiatement.

## Priorités UI

1. Globe ;
2. Opportunité ;
3. Indice ;
4. Bénéfice USD ;
5. Temps ;
6. itinéraires ;
7. petites courbes ;
8. actions d'optimisation en bas ;
9. Dropship accessible.

---

# 24. NOMMAGE INTERNE VS CLIENT

Une décision d'architecture documentée distingue les noms internes et les noms exposés au client.

## Engineering

Noms internes :

- MERCURE ;
- VENUS ;
- OPTIMUS ;
- LEGION ;
- Fleet Command ;
- Oracle ;
- Réconciliateur.

## Client-facing

Une couche de traduction doit exister pour les interfaces publiques.

Une décision documentée proposait :

| Interne | Client-facing |
|---|---|
| MERCURE | Radar Prix |
| VENUS | Boussole Marché |
| OPTIMUS | Score Delta |
| Oracle | Éclaireur |
| LEGION | Réseau Cormery / CormeryBoost |
| Fleet Command | Console Cormery |
| Réconciliateur | Fusion Produit |

**Important : cette table est une décision documentée antérieure et doit être considérée comme à appliquer uniquement si elle reste validée au moment de l'exposition publique.**

Les noms internes ne doivent pas être hardcodés dans les composants UI.

---

# 25. PROPRIÉTÉ INTELLECTUELLE / NOMMAGE

La documentation d'architecture a signalé un risque de collision autour des noms « OPTIMUS » et « Oracle ».

Décision de conception :

> conserver ces noms comme noms internes d'ingénierie et éviter de les exposer dans les éléments publics tant qu'un choix client-facing n'est pas validé juridiquement.

Une recherche d'antériorité doit être réalisée avant tout dépôt officiel.

---

# 26. PHASAGE GLOBAL DU PROJET

Le programme directeur retenu est :

```text
PHASE 0  Vision & cadrage
PHASE 1  Architecture fonctionnelle
PHASE 2  UX
PHASE 3  Design System
PHASE 4  Design UI complet
PHASE 5  Architecture technique
PHASE 6  Frontend
PHASE 7  Backend
PHASE 8  Data & Intelligence
PHASE 9  MERCURE / VENUS / LEGION / ORACLE
PHASE 10 DROPSHIP
PHASE 11 Agents & automatisation
PHASE 12 Sécurité & paiements
PHASE 13 Intégration & tests
PHASE 14 Déploiement
```

Planning indicatif précédemment proposé : environ 32 semaines, avec parallélisation après validation des contrats.

---

# 27. PHASE 1 — RÈGLE DE TRAVAIL

La Phase 1 doit être réalisée de manière détaillée avant le développement massif.

Elle doit couvrir :

```text
A. Architecture fonctionnelle
B. Modules
C. Pages
D. User flows
E. Data flows
F. Actions
G. Globe
H. Opportunity Engine
I. Dropship
J. Contrats entre systèmes
```

La partie Frontend est prioritaire dans le travail actuellement engagé, mais elle doit respecter le schéma déjà commencé.

---

# 28. RÉPARTITION DE LA PRODUCTION ENTRE IA

Une organisation de production par plusieurs IA a été prévue.

Domaines :

- conception intégrale du Backend ;
- conception intégrale du Frontend ;
- conception intégrale des agents IA ;
- bases de données / tests ;
- réseau ;
- sécurité ;
- fichier de lancement / setup.

IA mentionnées comme pouvant participer :

- ChatGPT ;
- DeepSeek ;
- Mistral ;
- Claude ;
- Copilot ;
- Cursor ;
- Hugging Face.

## Règle

Les IA sont des exécutants spécialisés.

Elles doivent toutes travailler à partir de la présente documentation et des contrats validés.

Aucune IA ne doit modifier seule :

- le principe fondateur ;
- le schéma de données ;
- le nombre de fichiers décidé ;
- la séparation des sous-systèmes ;
- les responsabilités des modules.

---

# 29. STRUCTURE DE FICHIERS ET CONTRAINTE DE STABILITÉ

Une planification précédente a abouti à un manifeste de **168 fichiers** :

```text
18 + 54 + 64 + 32 = 168
```

Répartition documentée :

- `docs/task-briefs/00-file-manifest-shared.md` — 18 fichiers ;
- `docs/task-briefs/C-file-manifest.md` — 54 fichiers ;
- `docs/task-briefs/B-file-manifest.md` — 64 fichiers ;
- `docs/task-briefs/A-file-manifest.md` — 32 fichiers ;
- `docs/task-briefs/INDEX-file-manifests.md` — index.

**Décision du porteur du projet : ne pas modifier le nombre de fichiers et ne pas modifier le schéma déjà commencé sans instruction explicite.**

Le chiffre 168 doit donc être traité comme la référence du manifeste existant, jusqu'à nouvelle décision.

---

# 30. TESTS

La validation doit couvrir :

- unit ;
- integration ;
- API ;
- E2E ;
- sécurité ;
- charge ;
- stress ;
- récupération après incident ;
- paiements ;
- agents ;
- multi-tenant ;
- cohérence des données ;
- réconciliation ;
- scoring ;
- opportunités ;
- actions programmées ;
- Dropship ;
- OPTIMUS.

Test fonctionnel critique :

```text
Produit
 ↓
Origine
 ↓
Destinations possibles
 ↓
Calcul bénéfice
 ↓
Indice
 ↓
Fenêtre temporelle
 ↓
Dropship
 ↓
OPTIMUS
 ↓
Achat
 ↓
Paiement
 ↓
Suivi
 ↓
Vente
 ↓
Profit
```

---

# 31. SÉCURITÉ

Les actions ayant un impact réel doivent respecter :

- authentification ;
- autorisation ;
- RBAC ;
- isolation tenant ;
- permissions ;
- limites ;
- politiques ;
- audit ;
- gestion des secrets ;
- chiffrement ;
- rate limiting ;
- logs ;
- monitoring ;
- contrôles de paiement.

Flux :

```text
REQUEST
 ↓
AUTH
 ↓
PERMISSION
 ↓
POLICY
 ↓
LIMIT
 ↓
EXECUTION
 ↓
AUDIT
```

---

# 32. OBSERVABILITÉ

Le système doit être observable sur :

- services ;
- agents ;
- pipelines ;
- files ;
- calcul ;
- cache ;
- base ;
- événements ;
- paiements ;
- tâches ;
- nœuds LEGION ;
- Fleet Command.

---

# 33. RÈGLES DE DÉVELOPPEMENT FUTUR

Toute nouvelle fonctionnalité doit répondre à :

1. Quel problème fondateur résout-elle ?
2. À quel sous-système appartient-elle ?
3. Quel est son contrat ?
4. Quel est son propriétaire ?
5. Quelles données consomme-t-elle ?
6. Quelles données produit-elle ?
7. A-t-elle un impact sur le schéma ?
8. A-t-elle un impact sur le nombre de fichiers ?
9. Est-elle client-facing ou interne ?
10. Comment est-elle testée ?
11. Comment est-elle sécurisée ?
12. Comment est-elle observée ?
13. Comment se comporte-t-elle en cas d'échec ?

---

# 34. RÈGLES DE RESPONSABILITÉ DES SOUS-SYSTÈMES

| Système | Responsabilité principale |
|---|---|
| MERCURE | Observer / collecter les données rapides |
| VENUS | Fournir le contexte lent |
| Réconciliateur | Identifier, réconcilier, mémoriser les entités |
| ORACLE | Détecter les opportunités actuelles et futures |
| CORMERY Core | Présenter, analyser, orchestrer |
| Dropship | Gérer l'opération commerciale |
| OPTIMUS | Exécuter les tâches |
| LEGION | Fournir du calcul distribué pur |
| Fleet Command | Piloter les flottes MERCURE et LEGION |

Cette table est une référence conceptuelle actuelle.

---

# 35. PARCOURS UTILISATEUR PRINCIPAL

Le parcours cible est :

```text
1. Ouvrir CORMERY
        ↓
2. Voir le globe
        ↓
3. Sélectionner une opportunité
        ↓
4. Voir :
      - indice
      - bénéfice USD
      - temps
        ↓
5. Comprendre :
      - origine
      - destination
      - fournisseur
      - transport
        ↓
6. Optimiser :
      - fournisseur
      - qualité
      - transport
      - destination
        ↓
7. Créer / lancer Dropship
        ↓
8. OPTIMUS exécute
        ↓
9. Suivre
        ↓
10. Vendre
        ↓
11. Mesurer le bénéfice réel
```

---

# 36. PARCOURS PRODUIT

```text
Recherche produit
       ↓
Nom / SKU / GTIN / URL
       ↓
Réconciliateur
       ↓
Universal Product ID
       ↓
Toutes les occurrences connues
       ↓
ORACLE
       ↓
Opportunité
       ↓
Dropship
       ↓
OPTIMUS
```

---

# 37. PARCOURS D'OPTIMISATION

```text
OPPORTUNITY
   ↓
CHANGE SUPPLIER
   ↓
RECALCUL
   ↓
CHANGE QUALITY
   ↓
RECALCUL
   ↓
CHANGE TRANSPORT
   ↓
RECALCUL
   ↓
CHANGE TARGET
   ↓
RECALCUL
   ↓
BEST NET PROFIT
```

CORMERY doit montrer l'effet de chaque décision.

---

# 38. PARCOURS D'OPPORTUNITÉ FUTURE

```text
ORACLE
 ↓
FORECAST
 ↓
Opportunity Future
 ↓
Schedule Action
 ↓
Condition
 ↓
Condition satisfied
 ↓
Dropship
 ↓
OPTIMUS
 ↓
Execution
```

---

# 39. PRINCIPES DE PERFORMANCE

L'ambition est un fonctionnement à échelle industrielle, capable de traiter des millions de produits selon les capacités de calcul disponibles.

Cela implique :

- architecture distribuée ;
- files de tâches ;
- cache ;
- calcul parallèle ;
- TimescaleDB pour séries temporelles ;
- Qdrant pour certains usages de matching/vector search ;
- Redis pour cache / état rapide ;
- Redpanda/Kafka pour événements ;
- LEGION pour certaines charges de calcul pur ;
- plans et quotas.

L'objectif est de proposer différents niveaux de puissance de calcul.

---

# 40. PRINCIPES DE DONNÉES

Une donnée doit être :

- identifiable ;
- datée ;
- localisée quand pertinent ;
- sourcée ;
- versionnée quand nécessaire ;
- réconciliable ;
- observable ;
- auditable.

Une observation de prix ne doit pas être considérée comme une simple valeur isolée.

Conceptuellement :

```text
PriceObservation
=
Product
+
Zone
+
Timestamp
+
Source
+
Price
+
Currency
+
Availability
+
Metadata
```

---

# 41. CACHE ET FRAÎCHEUR

Le système doit distinguer les données stables et volatiles.

Stables :

- identité produit ;
- certaines caractéristiques ;
- associations canoniques.

Volatiles :

- prix ;
- stock ;
- disponibilité ;
- transport ;
- certaines conditions de marché.

La fraîcheur doit être adaptée à la nature de la donnée.

---

# 42. CE QUI EST ACTÉ

Les éléments suivants sont considérés comme décisions fortes :

- CORMERY est le projet central ;
- principe fondateur = trouver où/quand/comment maximiser le bénéfice net ;
- Globe central du Workspace ;
- indice + bénéfice USD + temps comme informations prioritaires ;
- rouge → vert pour l'opportunité ;
- blanc = inexistante ;
- itinéraires aérien / maritime / terrestre différenciés ;
- petites courbes de suivi ;
- actions d'optimisation en bas ;
- Products / Product Universe ;
- recherche par URL ;
- Réconciliateur avec cache/mémoire ;
- ORACLE détecte le présent et le futur ;
- Dropship est l'outil commercial ;
- OPTIMUS exécute les tâches ;
- MERCURE, VENUS et LEGION sont des parties distinctes avec leur propre structure/fonctions ;
- LEGION V1 = calcul pur, pas scraping distribué ;
- SaaS managé à paliers ;
- multi-tenancy ;
- design Liquid Glass Carbon Blackout ;
- schéma existant intact ;
- nombre de fichiers existant à préserver ;
- développement par plusieurs IA spécialisées ;
- documentation et ADR comme mécanismes de contrôle.

---

# 43. CE QUI RESTE À DÉCIDER

Les éléments suivants ne doivent pas être inventés prématurément :

- liste finale des fournisseurs de données ;
- liste exhaustive des marketplaces ;
- choix définitif des modèles IA ;
- architecture exacte de paiement agentique ;
- règles juridiques détaillées de chaque marché ;
- formule mathématique finale de l'indice ;
- formule finale du bénéfice net selon chaque catégorie ;
- seuils définitifs de confiance ;
- TTL définitifs ;
- SLA définitifs ;
- plans tarifaires définitifs ;
- noms client-facing définitifs ;
- architecture finale de production cloud ;
- stratégie commerciale finale.

Ces points doivent être traités dans les phases correspondantes.

---

# 44. RÈGLE CONTRE LA DÉRIVE DU PROJET

Avant toute modification majeure, vérifier :

```text
Cette décision :
    ↓
Respecte-t-elle le principe fondateur ?
    ↓
Respecte-t-elle le schéma ?
    ↓
Respecte-t-elle la séparation des systèmes ?
    ↓
Respecte-t-elle le rôle du Globe ?
    ↓
Respecte-t-elle la séparation ORACLE / Dropship / OPTIMUS ?
    ↓
Respecte-t-elle la sécurité ?
```

Si non : ne pas implémenter directement.

---

# 45. ARCHITECTURE CONCEPTUELLE FINALE

```text
                           CORMERY
                              │
                 ┌────────────┴────────────┐
                 │                         │
              WORKSPACE                 CORE
                 │                         │
                 ▼                         ▼
              GLOBE                  ORCHESTRATION
                 │                         │
        ┌────────┼────────┐                │
        │        │        │                │
     ORIGIN    ROUTES   DESTINATION        │
        │        │        │                │
        └────────┼────────┘                │
                 ▼                         │
             OPPORTUNITY ◄─────────────────┘
                 │
       ┌─────────┼─────────┐
       │         │         │
     INDEX     PROFIT     TIME
       │         │         │
       └─────────┼─────────┘
                 │
                 ▼
              DROPSHIP
                 │
                 ▼
              OPTIMUS
                 │
       ┌─────────┼─────────┐
       │         │         │
     ACHAT    PAIEMENT   SUIVI
       │         │         │
       └─────────┼─────────┘
                 │
                VENTE
```

En amont :

```text
MERCURE ─────────────┐
                     │
VENUS ───────────────┤
                     ▼
              RÉCONCILIATEUR
                     │
                     ▼
              PRODUCT UNIVERSE
                     │
                     ▼
                  ORACLE
                     │
                     ▼
                  CORMERY
```

En parallèle :

```text
                    FLEET COMMAND
                    /            \
                   /              \
              MERCURE            LEGION
                                   │
                              CALCUL PUR
```

---

# 46. FORMULE CONCEPTUELLE DE CORMERY

La logique globale peut être résumée par :

```text
CORMERY
=
GLOBAL DATA
+
PRODUCT IDENTITY
+
CONTEXT
+
OPPORTUNITY DETECTION
+
SPATIO-TEMPORAL OPTIMIZATION
+
COMMERCIAL EXECUTION
```

Ou plus simplement :

> **Observer → comprendre → trouver la meilleure opportunité → l'optimiser → l'exécuter → mesurer.**

---

# 47. RÈGLE FINALE POUR LES FUTURES IA

Toute IA travaillant sur CORMERY doit recevoir ce document comme contexte de référence.

Elle doit :

- respecter les décisions actées ;
- signaler les contradictions ;
- ne pas modifier le schéma silencieusement ;
- ne pas changer le nombre de fichiers silencieusement ;
- ne pas fusionner MERCURE, VENUS ou LEGION ;
- ne pas transformer ORACLE en moteur d'exécution ;
- ne pas transformer OPTIMUS en moteur de décision ;
- ne pas transformer Dropship en moteur d'intelligence ;
- ne pas utiliser LEGION pour du scraping tiers en V1 ;
- respecter le rôle central du Globe ;
- respecter la hiérarchie visuelle ;
- respecter Liquid Glass Carbon Blackout ;
- respecter le principe fondateur de maximisation du bénéfice net ;
- produire des tests et de la documentation ;
- conserver les ADR et décisions comme historique.

---

# 48. STATUT DE CE DOCUMENT

**Version : 1.0**

Ce document doit être considéré comme le **Master Reference Document** de CORMERY.

Toute nouvelle décision importante doit :

1. être explicitement validée ;
2. être ajoutée à ce document ;
3. préciser si elle crée, modifie ou remplace une décision précédente ;
4. mettre à jour les sections concernées ;
5. conserver l'historique de la décision précédente.

**Fin du document.**
