# ADR 0004 — Mode de calcul hybride pour OPTIMUS

**Statut** : Accepté
**Date** : 2026-08-06

## Contexte
Le calcul d'arbitrage (marge nette + faisabilité géopolitique) peut être
déclenché de deux façons : pré-calculé en continu pour les produits suivis,
ou à la demande pour la recherche libre. Il fallait choisir un mode unique
ou un mode hybride, en évitant le piège classique de la divergence de
résultat entre les deux voies.

## Décision
**Mode hybride**, avec un principe non négociable : **un seul moteur de
calcul (`ArbitrageEngine` dans OPTIMUS), deux déclencheurs.** Jamais deux
implémentations séparées de la logique de scoring.

### Voie 1 — Produits "suivis" (pré-calcul continu)
- Déclenchée par consommation d'événements Kafka (`PriceObservation`) sur un
  SKU marqué `TrackedProduct.is_active = true`.
- Résultat persisté dans `arbitrage_results` (table) + publié en event.
- `refresh_interval_s` **adaptatif** par produit selon sa volatilité
  observée (pas un intervalle fixe global).

### Voie 2 — Recherche libre (à la demande)
- Calcul synchrone à la requête utilisateur.
- Cache court (Redis, TTL 2–5 min) pour absorber les rafales sur un même
  produit.

### Règle de cohérence anti-divergence
- Un produit suivi est **toujours** servi depuis `arbitrage_results` —
  jamais recalculé à la volée en parallèle.
- **Promotion automatique** : un produit en recherche libre dépassant un
  seuil de popularité (N recherches / 24h) bascule automatiquement en
  `TrackedProduct` (tracking_source = 'auto_promoted').

## Conséquences
- Nécessite l'entité `TrackedProduct` avec `popularity_score` et
  `refresh_interval_s` adaptatif dans le schéma canonique.
- Nécessite un scheduler capable de faire varier la fréquence de calcul par
  produit (pas un cron uniforme).
