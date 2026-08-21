# ADR 0005 — Séparation nommage interne / nommage client-facing

**Statut** : Accepté
**Date** : 2026-08-06

## Contexte
Les noms internes (ADR 0001 : MERCURE, VENUS, OPTIMUS, LEGION, Fleet
Command, Oracle) sont pensés pour l'architecture et l'équipe technique. Le
logiciel étant destiné à des clients, il fallait déterminer si ces noms
sont adaptés à une exposition publique (UI, marketing, contrats).

## Décision
**Deux couches de nommage strictement étanches, sans recoupement.**

### Couche interne (engineering only)
Utilisée dans : code source, documentation technique, ADR, logs, canaux
internes (Slack, tickets).
→ MERCURE, VENUS, OPTIMUS, LEGION, Fleet Command, Oracle, Réconciliateur

### Couche client-facing (produit)
Utilisée dans : UI/dashboard, communication marketing, CGU, documentation
client, support.

| Interne | Client-facing |
|---|---|
| MERCURE | *(invisible)* — copy générique éventuelle : "Radar Prix" |
| VENUS | *(invisible)* — copy générique éventuelle : "Boussole Marché" |
| OPTIMUS | **Score Delta** |
| Oracle | **Éclaireur** |
| LEGION | **Réseau Cormery** / **CormeryBoost** |
| Fleet Command (vue client) | **Console Cormery** (Fleet Command reste le nom interne de l'outil ops complet) |
| Réconciliateur | **Fusion Produit** |

## ⚠️ Alerte propriété intellectuelle — raison additionnelle de la décision
Deux noms internes entrent en collision avec des marques déposées actives
et juridiquement agressives dans le secteur tech :
- **OPTIMUS** : collision avec *Optimus Prime* (Hasbro) et *Tesla Optimus*
  (robot humanoïde Tesla, marque très défendue).
- **Oracle** : collision directe avec Oracle Corporation, entreprise
  historiquement très litigieuse en propriété intellectuelle.

**Règle stricte** : ces deux noms ne doivent JAMAIS apparaître dans un dépôt
de marque, une CGU, une page marketing publique, ou toute communication
externe. Usage interne uniquement (code, documentation technique).

## Conséquences
- Le frontend (`frontend/`) doit implémenter une couche de traduction
  nom-interne → nom-client (constante centralisée, jamais de hardcoding du
  nom interne dans les composants UI).
- Toute nouvelle feature exposée publiquement doit recevoir un nom
  client-facing validé avant mise en production, indépendamment de son nom
  de code interne.
- Un contrôle de conformité marque (recherche d'antériorité) est recommandé
  avant tout dépôt officiel des noms client-facing retenus, en particulier
  "Score Delta" et "Réseau Cormery" / "CormeryBoost" — non réalisé dans ce
  document, à faire avec un conseil juridique le moment venu.
