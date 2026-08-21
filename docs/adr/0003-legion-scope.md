# ADR 0003 — Périmètre du réseau de calcul distribué LEGION

**Statut** : Accepté
**Date** : 2026-08-06

## Contexte
LEGION délègue du calcul aux machines d'utilisateurs volontaires. Deux
natures de tâches étaient envisageables : calcul pur (embeddings, scoring)
ou scraping distribué (utiliser les nœuds comme points de collecte MERCURE
avec IP diverses).

## Décision
**LEGION v1 est strictement limité au calcul pur, sans aucune interaction
réseau avec des tiers.**

Tâches autorisées sur LEGION :
- Génération d'embeddings texte/image pour le Réconciliateur Universal SKU
- Scoring OPTIMUS sur données déjà collectées (non sensibles, non liées à un
  tenant spécifique)
- Entraînement/inférence de modèles de prédiction de tendance (Oracle)

Tâches explicitement exclues de LEGION :
- **Scraping** (reste 100% porté par MERCURE, sous infra et proxys
  contrôlés par l'éditeur)
- Tout calcul exposant des données propriétaires d'un tenant payant
- Exécution de code arbitraire non versionné/non signé

## Raison du rejet du scraping distribué
Faire porter à un utilisateur bénévole un risque juridique (violation
potentielle des CGU d'une plateforme tierce scrapée depuis SON IP, en son
nom) est jugé disproportionné par rapport au bénéfice (diversité
géographique de collecte). Ce risque n'est pas acceptable sans cadre
juridique explicite et consentement éclairé — non traité en V1.

## Conséquences — exigences de sécurité obligatoires
1. **Aucun code dynamique arbitraire** envoyé aux nœuds : le client LEGION
   embarque un runtime fixe, versionné, signé. Il ne reçoit que des
   paramètres de tâche, jamais du code exécutable à la volée.
2. **Redondance + consensus obligatoires** sur toute tâche critique :
   exécution sur N≥3 nœuds indépendants, résultat validé par majorité avant
   intégration en aval (OPTIMUS, Réconciliateur).
3. **Système de réputation par nœud** : un nœud divergent du consensus de
   façon répétée est mis en quarantaine automatiquement.
4. **Sandboxing strict** de l'environnement d'exécution local (WASM ou
   conteneur restreint type gVisor) — à trancher lors du module LEGION.

## Ouverture future (non actée, à ne pas implémenter maintenant)
Un mécanisme opt-in distinct de "vérification locale de prix" par des
utilisateurs volontaires (consentement explicite, cadre légal séparé)
pourrait être envisagé en V2. Hors périmètre actuel.
