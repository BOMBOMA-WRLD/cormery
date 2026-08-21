# Lot A — Frontend intégral + API Gateway
**IA responsable** : ChatGPT (support : Cursor pour l'édition assistée)
**Dépend de** : `00-master-coordination.md` (contrats obligatoires),
schéma DB du Lot C (à consommer, jamais à redéfinir)

## Périmètre

1. Interface complète CORMERY : dashboard client, Console Cormery (vue
   utilisateur de Fleet Command), flow d'onboarding Réseau Cormery
   (LEGION), visualisation cartographique des écarts de prix par zone.
2. **API Gateway** : GraphQL (lecture composée) + REST (commandes) —
   couche d'exposition entre le frontend et les services métier (OPTIMUS
   du Lot B, données du Lot C).

## 0. API Gateway — spécification

- **GraphQL** pour les vues composées (ex: fiche produit = SKU + offres +
  score delta + zones) — évite l'over-fetching pour le dashboard.
- **REST** pour les commandes (ex: déclencher un calcul à la demande,
  piloter un agent depuis la Console Cormery).
- Scoping strict par `tenant_id` extrait du token d'authentification sur
  **toutes** les requêtes (voir contrat multi-tenant, document maître
  section 4) — jamais de `tenant_id` accepté en paramètre libre côté
  client (risque IDOR, coordonné avec le volet Sécurité du Lot B).
- Le Gateway est un agrégateur/proxy, il ne contient **aucune logique
  métier** (pas de calcul de marge, pas de scoring) — délégation stricte
  vers le service OPTIMUS (Lot B) et le schéma de données (Lot C).
- Rate limiting par tenant et par IP (coordination avec Lot B — Sécurité).
- Schéma OpenAPI (REST) + schéma GraphQL exportés dans `shared/schemas/`
  pour consultation par les Lots B et C.

## Stack imposée

- Next.js 15+ (App Router), TypeScript strict
- TanStack Query (gestion des requêtes/cache serveur)
- WebSocket pour le temps réel (Fleet Command, mises à jour de prix)
- Cartographie : MapLibre GL ou Deck.gl (écarts de prix géographiques)
- Visualisation temporelle : Recharts ou Visx (timeline de marge projetée)

## Direction artistique — "Apple 2026" (obligatoire, non négociable)

L'objectif n'est pas un pastiche superficiel (pas de simple fond blanc et
police système) mais l'application rigoureuse des principes de design
Apple les plus récents :

### Principes à respecter
1. **Profondeur spatiale plutôt que plate** — usage de calques translucides
   (effet "verre dépoli"/glassmorphism maîtrisé), ombres douces et
   diffuses, hiérarchie visuelle par la profondeur plutôt que par la
   couleur criarde.
2. **Typographie comme structure** — une police système native
   (SF Pro / -apple-system en fallback web, ou équivalent premium type
   Inter/General Sans si contrainte web), hiérarchie forte par le poids
   et l'espacement, jamais par la taille seule.
3. **Espace négatif généreux** — pas de densité d'information excessive
   même si CORMERY manipule des données financières denses ; privilégier
   la progressive disclosure (drill-down) plutôt que tout afficher d'un
   coup.
4. **Micro-interactions intentionnelles** — animations courtes (150-300ms),
   easing naturel (spring physics plutôt que linear), jamais gratuites :
   chaque animation doit clarifier un changement d'état, pas décorer.
5. **Mode clair/sombre adaptatif natif**, pas un simple toggle de couleurs
   inversées — palette pensée pour les deux modes dès la conception.
6. **Iconographie cohérente et symbolique** — système d'icônes unifié
   (type SF Symbols en inspiration), pas de mélange de styles d'icônes.
7. **Couleur fonctionnelle, pas décorative** — la couleur porte du sens
   (ex: vert = opportunité d'arbitrage favorable, rouge = infaisabilité
   géopolitique) plutôt que d'être un simple habillage de marque.

### Contrainte spécifique métier
Le dashboard doit rendre lisible une information complexe (marge nette
multi-facteurs) sans jamais donner l'impression d'un tableau Excel. Le
"Score Delta" (nom client d'OPTIMUS) doit être le point focal visuel de
chaque fiche produit — traitement typographique et spatial dédié, à la
manière dont Apple traite une métrique clé (ex: niveau de batterie,
fréquence cardiaque).

## Nommage client-facing obligatoire (voir ADR 0005)

**Jamais de nom interne dans l'UI.** Utiliser exclusivement :
- OPTIMUS → "Score Delta"
- Oracle → "Éclaireur"
- LEGION → "Réseau Cormery"
- Fleet Command (vue client) → "Console Cormery"
- Réconciliateur → "Fusion Produit"
- MERCURE / VENUS → invisibles, jamais mentionnés dans l'UI

## Écrans à livrer (V1)

1. Dashboard principal — vue d'ensemble des produits suivis
2. Fiche produit — détail Score Delta, carte des zones, timeline de marge
3. Recherche libre — résultat à la demande avec indicateur de
   fraîcheur du calcul
4. Console Cormery — vue restreinte de suivi des agents/tâches liées au
   tenant du client
5. Onboarding Réseau Cormery — flow de consentement clair et rassurant
   pour l'installation du client de calcul distribué (pédagogie
   obligatoire sur ce qui est délégué, voir ADR 0003 : jamais de scraping,
   uniquement du calcul)
6. Gestion de plan/quota — visualisation claire de la consommation vs
   limite du palier souscrit

## Interdictions strictes

- Aucun calcul métier côté client (consommation API uniquement)
- Aucune référence aux noms internes (MERCURE, VENUS, OPTIMUS, LEGION,
  Oracle) dans le code UI visible, les textes, ou les noms de composants
  exposés dans le DOM/accessibilité
