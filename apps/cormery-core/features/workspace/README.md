# Workspace — CORMERY CORE

## Rôle
Le Workspace organise la navigation de CORE, la sélection locale de l’espace, les filtres contextuels et la zone principale de visualisation. CORE ne recalcule pas les opportunités d’ILIADE et n’exécute pas d’opérations financières. Les statuts d’exécution relèvent de FUTURE.

## Intégration
Le dépôt utilise React 19, TypeScript et Vite 8 dans `apps/cormery-core`. La fonctionnalité respecte le chemin demandé `apps/cormery-core/features/workspace/` et est intégrée depuis `src/App.tsx`. Aucune dépendance n’a été ajoutée.

## Zones
- **TopLeft: Nav & Spaces** : identité CORMERY CORE, recherche globale signalant l’absence de service, sélecteur d’espace et préparation d’un brouillon local.
- **LeftSidebar** : navigation groupée, état actif accessible, barre repliable et tiroir mobile.
- **Context Panel** : filtres déclaratifs propres à la vue, filtres actifs et réinitialisation.
- **Main Workspace** : globe illustratif prioritaire, sans données cartographiques connectées.

## Architecture
Les responsabilités sont séparées entre `components/`, `config/`, `constants/`, `types/`, `hooks/`, `stores/`, `services/`, `utils/`, `validation/` et `__tests__/`.

## Données et limites
Navigation et filtres sont en mémoire. L’espace actif est local. Les espaces d’organisation, partagés et récents restent indisponibles faute de contrats vérifiés. La création d’espace ne produit qu’un brouillon local. Les filtres ne déclenchent aucune requête métier. Aucun score, bénéfice, produit, route, alerte ou statut d’exécution fictif n’est présenté comme réel.

## Vérification
Scripts disponibles dans `apps/cormery-core/package.json` : `pnpm --filter cormery-core build` et `pnpm --filter cormery-core lint`. Le connecteur GitHub ne fournit pas d’environnement d’exécution local ici ; aucun résultat de build, lint ou test n’est revendiqué.
