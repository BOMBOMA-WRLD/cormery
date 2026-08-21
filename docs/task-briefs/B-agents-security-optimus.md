# Lot B — Agents IA + Sécurité + OPTIMUS + Réconciliateur
**IA responsable** : DeepSeek (support : HuggingFace pour hosting/modèles
d'embeddings)
**Dépend de** : `00-master-coordination.md` (contrats obligatoires),
schéma DB du Lot C (à consommer, jamais à redéfinir)

## Périmètre

1. **MERCURE** — essaim d'agents d'extraction (scraping)
2. **LEGION** — protocole de calcul distribué communautaire
3. **Oracle** — détection de tendances / winning products
4. **Réconciliateur** — pipeline complet : modèles d'embeddings
   texte/image + logique de matching/fusion (stockage assuré par le
   schéma du Lot C, la logique applicative est ici)
5. **OPTIMUS (ArbitrageEngine)** — moteur de scoring d'arbitrage complet
6. **Sécurité transverse** de l'ensemble du système

## 0. OPTIMUS — ArbitrageEngine (spécification fonctionnelle)

```
compute(sku_id, zone_a, zone_b, timestamp) → ArbitrageScore

ArbitrageScore {
  net_margin: Decimal        # Prix_vente - (Prix_achat + Fret + Taxes)
  feasibility_score: float   # 0 si sanction/embargo bloquant, sinon 0-1
  confidence: float          # qualité des données sources (fraîcheur, complétude)
  context_version_id: UUID
  computed_at: datetime
}
```

**Point d'architecture non négociable — event sourcing** : une marge nette
dépend de FX live + fret + vélocité. Chaque calcul doit être un
enregistrement immuable (jamais de colonne mutable "marge actuelle"),
référençant la version du référentiel VENUS utilisée
(`context_version_id`) et le `source_event_id` MERCURE ayant déclenché le
calcul. Nécessaire pour l'auditabilité en contexte financier.

**Mode hybride (voir ADR 0004)** : un seul point d'entrée
(`ArbitrageEngine.compute`), invoqué par deux voies — pré-calcul continu
(scheduler, produits "suivis") et à la demande (recherche libre, cache
Redis TTL 2-5 min). **Jamais deux implémentations séparées** de la
logique de scoring : la voie "à la demande" appelle exactement le même
code que la voie "pré-calcul".

Un produit suivi est toujours servi depuis le résultat pré-calculé
(table `arbitrage_results` définie par le Lot C) — jamais recalculé en
parallèle. Promotion automatique d'un produit en recherche libre vers
"suivi" au-delà d'un seuil de popularité.

## 0bis. Réconciliateur — logique de matching (complément)

- **Score de confiance obligatoire** sur chaque match, avec zone
  human-in-the-loop pour les cas ambigus — jamais de fusion automatique
  à 100% de confiance sur des volumes élevés (risque de faux positifs
  coûteux : deux produits différents fusionnés = arbitrage faux).
- Interroge l'index vectoriel (Qdrant, provisionné par le Lot C) et écrit
  les entités `SKUCanonical` résolues dans le schéma défini par le Lot C.

## 3.1 — MERCURE : essaim d'agents d'extraction

- Architecture d'agents distribués, scalables horizontalement (Kubernetes
  Jobs ou équivalent)
- **Idempotence obligatoire** : chaque événement porte une clé
  (`source_id + timestamp_scrape + hash_payload`) vérifiée avant
  publication sur le bus — un agent qui crash/redémarre ne doit jamais
  dupliquer un signal
- Rotation de proxys/IP gérée par l'infra propriétaire (jamais par les
  machines utilisateurs — voir ADR 0003)
- Throttling adaptatif par domaine cible, résilience face aux blocages
  (pas de contournement agressif de protections anti-bot — angle légal à
  respecter strictement)
- Publication sur `cormery.mercure.raw-signal.ingested` (contrat Kafka,
  voir document maître)

## 3.2 — LEGION : réseau de calcul distribué

**Rappel non négociable (ADR 0003)** : calcul pur uniquement, jamais de
scraping délégué à un nœud utilisateur.

- Client léger installable, **runtime fixe et versionné, signé** — ne
  reçoit jamais de code exécutable dynamique, uniquement des paramètres
  de tâche
- Sandboxing strict de l'exécution locale : WASM ou conteneur restreint
  (gVisor) — à spécifier précisément dans la livraison
- **Redondance et consensus obligatoires** sur toute tâche critique :
  exécution sur N≥3 nœuds indépendants, validation par majorité avant
  intégration en aval
- Système de réputation par nœud (mise en quarantaine automatique des
  nœuds divergents)
- Tâches déléguées : génération d'embeddings, scoring OPTIMUS sur données
  non sensibles, entraînement/inférence de modèles de tendance

## 3.3 — Oracle : détection de tendances

- Croisement de signaux : ad velocity, variations de stock fournisseurs
- Modèle de prévision à court terme sur les séries temporelles de
  MERCURE — démarrer simple (ARIMA / exponential smoothing / Prophet)
  avant d'envisager du deep learning, faute d'historique suffisant en
  phase initiale
- Doit aussi détecter des **fenêtres d'arbitrage** naissantes (écart de
  prix inter-zones qui se creuse), pas seulement des "produits gagnants"
  isolés

## 3.4 — Réconciliateur : modèles d'embeddings

- Pipeline multimodal texte + image pour le matching produit
- **Score de confiance obligatoire** sur chaque match, avec zone
  human-in-the-loop pour les matches ambigus — jamais de fusion
  automatique à 100% de confiance sur des volumes élevés (risque de faux
  positifs coûteux : deux produits différents fusionnés = arbitrage faux)
- Modèles hébergés via HuggingFace, endpoints exposés au Lot 1 pour
  intégration

## 3.5 — Sécurité transverse (périmètre complet du système)

- **Authentification/autorisation** : scoping strict par `tenant_id`
  (voir document maître section 4), protection contre les attaques IDOR
- **Gestion des secrets** : aucune clé API en dur, vault centralisé
  (ex: HashiCorp Vault ou équivalent cloud), rotation des secrets
- **Sécurité LEGION** : voir 3.2, c'est la surface d'attaque la plus
  sensible du système (exécution déléguée à des machines non fiables)
- **Rate limiting** : par tenant et par IP, sur toutes les APIs publiques
- **Audit trail** : toute modification de donnée sensible (quotas, plans,
  résultats d'arbitrage) doit être traçable (qui, quand, quoi) — cohérent
  avec l'event sourcing du Lot 1
- **Conformité scraping** : validation que MERCURE respecte une politique
  claire de résilience (pas de contournement agressif de CAPTCHA, respect
  des `robots.txt` dans la mesure du raisonnable) — point à documenter
  explicitement, pas seulement implémenté

## Interfaces à fournir aux autres lots

- Spécification des besoins de stockage (tables/champs requis) transmise
  au Lot 1, jamais imposée directement dans son schéma
- Contrats d'événements Kafka produits/consommés, alignés sur le document
  maître
- Documentation des endpoints de modèles (embeddings, prévision) pour
  intégration Lot 1
