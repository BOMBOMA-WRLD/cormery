# Manifeste — Lot A : Frontend + API Gateway (32 fichiers)
**IA responsable** : ChatGPT — brief complet dans `A-frontend-api-gateway.md`

---

## API Gateway (11 fichiers)

### 137. `api-gateway/graphql/schema.graphql`
**Prompt** : "Écris le schéma GraphQL exposant les vues composées
(fiche produit = SKU + offres + Score Delta + zones), en te basant sur
les entités de `shared/types/entities.py`. Respecte le nommage
client-facing de l'ADR 0005 dans les descriptions de champs exposées à la
documentation GraphQL (jamais 'OPTIMUS' ou 'Oracle')."

### 138. `api-gateway/graphql/resolvers/product.ts`
**Prompt** : "Écris les resolvers GraphQL pour les requêtes produit,
agrégeant les données depuis l'API interne du Lot C (schéma) et du Lot B
(OPTIMUS, Réconciliateur) sans aucune logique métier locale."

### 139. `api-gateway/graphql/resolvers/zone.ts`
**Prompt** : "Écris les resolvers GraphQL pour les requêtes de zones
géographiques et leurs indicateurs enrichis par VENUS."

### 140. `api-gateway/graphql/resolvers/arbitrage.ts`
**Prompt** : "Écris les resolvers GraphQL exposant les résultats
d'arbitrage (Score Delta), en respectant la distinction produit
suivi/recherche libre définie en ADR 0004 (le Gateway ne décide jamais
lui-même du mode, il relaie l'appel à OPTIMUS)."

### 141. `api-gateway/rest/routes/agents.ts`
**Prompt** : "Écris les routes REST de commande pour piloter les agents
depuis la Console Cormery (vue client de Fleet Command), avec scoping
tenant strict."

### 142. `api-gateway/rest/routes/tracked-products.ts`
**Prompt** : "Écris les routes REST pour ajouter/retirer un produit suivi
(`TrackedProduct`), avec vérification du quota du plan du tenant avant
ajout."

### 143. `api-gateway/middleware/tenant-scope.ts`
**Prompt** : "Écris le middleware extrayant et validant le `tenant_id`
du token d'authentification sur toutes les routes, en coordination avec
`security/tenant_scope.py` du Lot B (même logique, contexte TypeScript)."

### 144. `api-gateway/middleware/rate-limit.ts`
**Prompt** : "Écris le middleware de rate limiting par tenant et IP côté
Gateway, cohérent avec la politique définie par le Lot B (Sécurité)."

### 145. `api-gateway/config.ts`
**Prompt** : "Écris la configuration du Gateway (endpoints internes des
services Lot B/C, secrets lus depuis variables d'environnement)."

### 146. `api-gateway/README.md`
**Prompt** : "Documente le schéma GraphQL et les routes REST exposées,
avec exemples de requêtes."

### 147. `api-gateway/tests/resolvers.test.ts`
**Prompt** : "Écris des tests des resolvers GraphQL avec mocks des
services backend, vérifiant qu'aucune donnée d'un autre tenant ne fuite
jamais dans une réponse."

## Frontend (21 fichiers)

### 148. `frontend/app/layout.tsx`
**Prompt** : "Écris le layout racine Next.js 15 (App Router),
implémentant la structure de navigation et le thème adaptatif clair/
sombre — voir brief Lot A, direction artistique Apple 2026, principe 5."

### 149. `frontend/app/page.tsx`
**Prompt** : "Écris le dashboard principal listant les produits suivis
du tenant connecté, avec Score Delta en point focal visuel de chaque
carte produit — voir brief Lot A, contrainte métier spécifique."

### 150. `frontend/app/products/[id]/page.tsx`
**Prompt** : "Écris la fiche produit détaillée : Score Delta, carte des
zones (MapLibre GL), timeline de marge projetée (Recharts)."

### 151. `frontend/app/search/page.tsx`
**Prompt** : "Écris l'écran de recherche libre avec indicateur explicite
de fraîcheur du calcul (voir ADR 0004 — l'utilisateur doit comprendre
qu'il consulte un résultat à la demande, potentiellement en cache court)."

### 152. `frontend/app/console/page.tsx`
**Prompt** : "Écris la Console Cormery : vue restreinte au tenant des
agents/tâches liées à ses produits suivis, jamais de vue sur les données
d'un autre tenant."

### 153. `frontend/app/onboarding/reseau/page.tsx`
**Prompt** : "Écris le flow d'onboarding du Réseau Cormery (LEGION),
avec pédagogie explicite et rassurante sur ce qui est délégué (calcul
pur uniquement, jamais de scraping) — voir brief Lot A section écrans à
livrer, point 5."

### 154. `frontend/app/settings/plan/page.tsx`
**Prompt** : "Écris l'écran de gestion de plan/quota : consommation
actuelle vs limite du palier souscrit, avec incitation claire à
contribuer au Réseau Cormery pour un avantage de palier."

### 155. `frontend/components/ScoreDeltaCard.tsx`
**Prompt** : "Écris le composant visuel du Score Delta (nom client
d'OPTIMUS), traitement typographique et spatial dédié façon métrique
clé Apple (ex: niveau de batterie) — voir brief Lot A."

### 156. `frontend/components/ZoneMap.tsx`
**Prompt** : "Écris le composant de carte interactive (MapLibre GL)
affichant les écarts de prix par zone pour un produit, avec code couleur
fonctionnel (vert = opportunité, rouge = infaisabilité)."

### 157. `frontend/components/MarginTimeline.tsx`
**Prompt** : "Écris le composant de timeline de marge projetée
(Recharts), distinguant visuellement marge actuelle et marge prédite."

### 158. `frontend/components/ProductSearchBar.tsx`
**Prompt** : "Écris la barre de recherche produit avec auto-complétion,
déclenchant la voie 'recherche libre' de l'API."

### 159. `frontend/components/ConsoleAgentList.tsx`
**Prompt** : "Écris la liste des agents/tâches actifs affichée dans la
Console Cormery, avec statut temps réel (WebSocket)."

### 160. `frontend/components/QuotaUsageBar.tsx`
**Prompt** : "Écris la barre de progression visuelle de consommation de
quota vs limite du plan."

### 161. `frontend/components/OnboardingConsentFlow.tsx`
**Prompt** : "Écris le composant de consentement explicite pour rejoindre
le Réseau Cormery, avec explication claire et non trompeuse du périmètre
exact délégué (voir ADR 0003)."

### 162. `frontend/lib/api-client.ts`
**Prompt** : "Écris le client API (GraphQL + REST) utilisé par tous les
composants, avec gestion centralisée de l'authentification."

### 163. `frontend/lib/naming-translation.ts`
**Prompt** : "Écris la table de traduction centralisée nom-interne →
nom-client (OPTIMUS → Score Delta, Oracle → Éclaireur, LEGION → Réseau
Cormery, etc. — voir ADR 0005). Aucun composant ne doit hardcoder un nom
interne, tout doit passer par cette table."

### 164. `frontend/lib/websocket-client.ts`
**Prompt** : "Écris le client WebSocket pour les mises à jour temps réel
(Fleet Command, mises à jour de prix), avec reconnexion automatique."

### 165. `frontend/styles/theme.ts`
**Prompt** : "Écris les tokens de design (couleurs, typographie,
espacements, ombres) implémentant les 7 principes Apple 2026 du brief
Lot A, en mode clair et sombre."

### 166. `frontend/styles/tokens.css`
**Prompt** : "Écris les variables CSS custom properties correspondant à
`theme.ts`, pour l'usage dans les composants non-React si nécessaire."

### 167. `frontend/README.md`
**Prompt** : "Documente comment lancer le frontend en local, connecté
au docker-compose de dev, et comment ajouter un nouvel écran respectant
la direction artistique définie."

### 168. `frontend/tests/ScoreDeltaCard.test.tsx`
**Prompt** : "Écris des tests du composant `ScoreDeltaCard` vérifiant
qu'aucun nom interne (OPTIMUS) n'apparaît jamais dans le DOM rendu ou
l'arbre d'accessibilité — test de non-régression pour l'ADR 0005."
