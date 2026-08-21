# ADR 0002 — Modèle de distribution et de déploiement

**Statut** : Accepté
**Date** : 2026-08-06

## Contexte
Deux exigences business en tension devaient être arbitrées :
1. Un moteur de calcul performant "à rythme industriel" sur des millions de
   produits, nécessitant potentiellement une infra centralisée maîtrisée.
2. Une volonté de rendre CORMERY largement déployable, avec plusieurs offres
   tarifaires selon la puissance de calcul (modèle type Claude/API tiers).

## Décision
**Modèle SaaS managé à paliers (tiers), pas de self-hosting du core.**
CORMERY est hébergé et opéré par l'éditeur. Les utilisateurs ne déploient pas
d'instance CORMERY complète chez eux.

En complément, une partie de la charge de calcul (pas de données brutes, pas
de scraping) est déléguée à un réseau de calcul distribué communautaire —
**LEGION** — constitué des machines des utilisateurs volontaires, entièrement
piloté par Fleet Command (voir ADR 0003 pour le périmètre de LEGION).

## Conséquences
- **Multi-tenancy obligatoire dès le schéma de données** : `tenant_id` /
  `plan_id` doivent être présents sur toutes les entités pertinentes
  (produits suivis, résultats d'arbitrage, quotas).
- Nécessité d'un système de **plans/quotas** : nombre de produits suivis,
  fréquence de rafraîchissement OPTIMUS, profondeur d'analyse VENUS,
  priorité dans les files de calcul.
- Fleet Command devient le C2 unique pour DEUX flottes : les agents MERCURE
  (infra propriétaire) ET les nœuds LEGION (infra communautaire).
- Pas de packaging "self-hosted" à prévoir en V1 (Docker/Helm restent des
  outils internes de développement, pas un produit distribué aux clients).
