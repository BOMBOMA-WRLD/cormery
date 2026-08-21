# ADR 0001 — Nomenclature officielle des sous-systèmes CORMERY

**Statut** : Accepté
**Date** : 2026-08-06

## Contexte
CORMERY se compose de plusieurs sous-systèmes distincts nécessitant des noms
clairs et cohérents pour la documentation, le code, et la communication
d'équipe.

## Décision
Convention de nommage mythologique (romain) pour les pipelines de données et
moteurs de calcul ; noms fonctionnels neutres pour les composants
d'infrastructure/pilotage.

| Nom          | Rôle                                                              | Type de composant        |
|--------------|--------------------------------------------------------------------|---------------------------|
| **MERCURE**  | Essaim d'agents d'extraction — ingestion haute fréquence (prix, stock, ad velocity) | Pipeline de données (rapide) |
| **VENUS**    | Ingestion de contexte lent (FX, douanes, sanctions, socio-éco)     | Pipeline de données (lent) |
| **OPTIMUS**  | Moteur de scoring d'arbitrage spatio-temporel                     | Moteur de calcul métier   |
| **LEGION**   | Réseau de calcul distribué communautaire (nœuds utilisateurs)     | Infrastructure de calcul secondaire |
| **Fleet Command** | Centre de commandement unique : pilote MERCURE ET LEGION      | Plan de contrôle (C2)     |

## Conséquences
- Tout nouveau sous-système de type "pipeline de données" ou "moteur de
  calcul métier" doit suivre la convention mythologique romaine, validée
  explicitement avec le porteur de projet avant implémentation.
- Les composants d'infra générique (API Gateway, Fleet Command) gardent des
  noms fonctionnels neutres — pas de sur-ingénierie du nommage.
