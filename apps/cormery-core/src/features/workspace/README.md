# Workspace — CORMERY CORE

## Rôle

Le Workspace organise la navigation de CORE, le choix de l’espace actif, les filtres contextuels et la zone principale de visualisation géographique. Il ne recalcule pas les opportunités d’ILIADE et n’exécute aucune opération financière.

## Structure réellement ajoutée

- `index.ts` : export public du shell Workspace.
- `workspace-shell.tsx` : navigation supérieure et latérale, choix d’espace, filtres contextuels, états de vues, dialogue de préparation d’espace et visualisation illustrative du globe.
- `workspace.css` : thème sombre carbone, surfaces translucides discrètes, états de navigation et règles responsive.

La fonctionnalité est placée dans `apps/cormery-core/src/features/workspace/`, et non dans `apps/cormery-core/features/workspace/`, car l’application Vite/TypeScript compile les sources sous `src`. Le dossier demandé initialement n’existait pas.

## Navigation et état

La vue active, l’espace sélectionné, la réduction de la barre latérale, les filtres, la recherche et les dialogues sont gérés avec l’état React du shell. Les destinations non développées affichent un état de préparation au lieu d’une page vide. La navigation mobile s’ouvre en tiroir ; la barre latérale peut être réduite sur grand écran.

## Espaces

Global Workspace et Personal Space sont des sélections d’interface locales. Les espaces d’organisation, partagés et récents restent indisponibles, faute de contrats d’autorisation et de persistance vérifiés. « Préparer un espace » valide un nom et prépare un brouillon temporaire dans le dialogue ; cela ne crée pas un espace distant.

## Panneau contextuel

Les filtres affichés dépendent de la vue active et peuvent être réinitialisés. Ils restent locaux et ne filtrent pas encore de données métier. La recherche globale est distincte de la recherche de produits et indique que son service distant n’est pas connecté.

## Contrats et limites

- L’audit initial n’a pas identifié de contrat frontend Workspace ni d’API de données à brancher.
- Le globe est une illustration SVG de l’interface, pas une carte interactive alimentée par des données géographiques.
- Aucun score, bénéfice, produit, route, alerte ou statut d’exécution fictif n’est présenté comme réel.
- Les analyses/opportunités doivent venir d’ILIADE ; les statuts d’exécution doivent être confirmés par FUTURE.
- L’application actuelle est React 19 + TypeScript + Vite 8, pas Next.js. Aucune dépendance UI ou d’icônes n’a été ajoutée.
- Les vues enregistrées, alertes, recherche distante et création persistante d’espaces restent en attente de services.

## Vérification

Scripts identifiés dans `apps/cormery-core/package.json` : `pnpm --filter cormery-core build`, `pnpm --filter cormery-core lint`. Le connecteur GitHub permet de modifier le dépôt mais ne fournit pas ici un environnement local d’exécution ; aucun résultat de build, lint ou test n’est donc revendiqué.
