# Manifeste — Lot B : Agents IA + Sécurité + OPTIMUS + Réconciliateur (64 fichiers)
**IA responsable** : DeepSeek — brief complet dans `B-agents-security-optimus.md`

---

## MERCURE (13 fichiers)

### 73. `services/mercure/agent_base.py`
**Prompt** : "Écris une classe abstraite `MercureAgent` définissant le
cycle de vie d'un agent d'extraction : fetch, parse, publish, heartbeat.
Doit être conçue pour scaler horizontalement (Kubernetes Jobs)."

### 74. `services/mercure/scraper_interface.py`
**Prompt** : "Écris l'interface `ScraperInterface` que chaque scraper
spécifique à une plateforme doit implémenter, avec une méthode
`extract_price_signal` retournant un `RawSignalEvent` conforme au
contrat de `shared/types/events.py`."

### 75. `services/mercure/proxy_manager.py`
**Prompt** : "Écris le gestionnaire de rotation de proxys/IP, avec
politique de throttling adaptatif par domaine cible — voir brief Lot B
section 1, angle légal à respecter strictement (pas de contournement
agressif d'anti-bot)."

### 76. `services/mercure/idempotency.py`
**Prompt** : "Écris la logique d'idempotence obligatoire : calcul de la
clé (`source_id + timestamp_scrape + hash_payload`) et vérification
avant publication sur Kafka, pour garantir qu'un agent qui redémarre ne
duplique jamais un signal."

### 77. `services/mercure/rate_limiter.py`
**Prompt** : "Écris un rate limiter par domaine cible, distinct du rate
limiter API (qui est côté sécurité), spécifique à la politesse du
scraping."

### 78. `services/mercure/scheduler.py`
**Prompt** : "Écris l'ordonnanceur distribuant les tâches d'extraction
entre agents disponibles, en coordination avec Fleet Command."

### 79. `services/mercure/kafka_producer.py`
**Prompt** : "Écris le producteur Kafka publiant sur
`cormery.mercure.raw-signal.ingested`, avec vérification d'idempotence
avant émission."

### 80. `services/mercure/raw_signal_event.py`
**Prompt** : "Écris la logique de construction du `RawSignalEvent` à
partir du résultat brut d'un scraper, avec validation Pydantic stricte."

### 81. `services/mercure/robots_compliance.py`
**Prompt** : "Écris un module vérifiant le respect raisonnable des
`robots.txt` des domaines ciblés, journalisant les cas de non-conformité
pour revue humaine."

### 82. `services/mercure/config.py`
**Prompt** : "Écris la configuration (Pydantic Settings) des agents
MERCURE : liste de domaines cibles, quotas de requêtes, credentials
proxy."

### 83. `services/mercure/README.md`
**Prompt** : "Documente comment lancer un agent MERCURE isolément en
local pour test, et comment ajouter un nouveau scraper de plateforme."

### 84. `services/mercure/tests/test_idempotency.py`
**Prompt** : "Écris des tests garantissant qu'un même payload scrapé
deux fois ne génère jamais deux publications Kafka distinctes."

### 85. `services/mercure/tests/test_agent_base.py`
**Prompt** : "Écris des tests du cycle de vie complet d'un agent
(fetch → parse → publish → heartbeat), avec mocks des dépendances
externes."

## LEGION (10 fichiers)

### 86. `services/legion/protocol.py`
**Prompt** : "Écris le protocole de communication entre Fleet Command et
les nœuds LEGION (assignation de tâche, soumission de résultat),
strictement limité aux tâches de calcul pur — voir ADR 0003."

### 87. `services/legion/worker_client.py`
**Prompt** : "Écris le client léger installable par l'utilisateur.
Runtime fixe et versionné, signé, ne recevant jamais de code exécutable
dynamique — uniquement des paramètres de tâche (voir ADR 0003
conséquences, exigence 1)."

### 88. `services/legion/task_dispatcher.py`
**Prompt** : "Écris le dispatcher assignant une tâche à N≥3 nœuds
indépendants (redondance obligatoire, voir ADR 0003 exigence 2)."

### 89. `services/legion/consensus.py`
**Prompt** : "Écris la logique de validation par consensus/majorité des
résultats retournés par les nœuds redondants, avant intégration en aval
(OPTIMUS, Réconciliateur)."

### 90. `services/legion/reputation.py`
**Prompt** : "Écris le système de réputation par nœud : un nœud
divergent du consensus de façon répétée est mis en quarantaine
automatiquement (voir ADR 0003 exigence 3)."

### 91. `services/legion/sandbox_runtime.py`
**Prompt** : "Écris/spécifie le sandboxing de l'exécution locale (WASM
ou conteneur restreint type gVisor) — exigence de sécurité critique, voir
ADR 0003 exigence 4."

### 92. `services/legion/task_types.py`
**Prompt** : "Écris l'énumération stricte des types de tâches
délégables (embeddings, scoring OPTIMUS non sensible, entraînement
Oracle) — toute tâche hors de cette liste doit être rejetée par
construction."

### 93. `services/legion/README.md`
**Prompt** : "Documente le protocole d'installation du client LEGION et
explique clairement, pour un futur utilisateur, ce qui est délégué et ce
qui ne l'est jamais (pas de scraping — voir ADR 0003)."

### 94. `services/legion/tests/test_consensus.py`
**Prompt** : "Écris des tests vérifiant qu'un résultat minoritaire
divergent est bien rejeté et qu'un nœud malveillant simulé est détecté."

### 95. `services/legion/tests/test_reputation.py`
**Prompt** : "Écris des tests vérifiant la mise en quarantaine
automatique d'un nœud après un nombre défini de divergences."

## Oracle (6 fichiers)

### 96. `services/oracle/trend_detector.py`
**Prompt** : "Écris le détecteur de tendances croisant ad velocity et
variations de stock fournisseurs, consommant les données MERCURE."

### 97. `services/oracle/forecasting_model.py`
**Prompt** : "Écris un modèle de prévision court terme (ARIMA ou
exponential smoothing pour commencer, pas de deep learning en V1 faute
d'historique — voir brief Lot B section 3.3) sur les séries temporelles
de prix."

### 98. `services/oracle/arbitrage_window_detector.py`
**Prompt** : "Écris la détection de fenêtres d'arbitrage naissantes
(écart de prix inter-zones qui se creuse), distincte de la détection de
produit gagnant isolé."

### 99. `services/oracle/signal_aggregator.py`
**Prompt** : "Écris l'agrégateur combinant plusieurs signaux (prix,
stock, ad velocity) en un score de tendance unique exploitable par le
frontend (Éclaireur)."

### 100. `services/oracle/README.md`
**Prompt** : "Documente les entrées/sorties du module Oracle et comment
l'entraîner/réentraîner sur de nouvelles données."

### 101. `services/oracle/tests/test_trend_detector.py`
**Prompt** : "Écris des tests du détecteur de tendance sur des séries
synthétiques aux caractéristiques connues (tendance haussière, plateau,
volatilité)."

## Réconciliateur (9 fichiers)

### 102. `services/reconciliator/text_embedder.py`
**Prompt** : "Écris le pipeline de génération d'embeddings texte
(modèle hébergé HuggingFace), pour la description produit."

### 103. `services/reconciliator/image_embedder.py`
**Prompt** : "Écris le pipeline de génération d'embeddings image (modèle
hébergé HuggingFace), pour les photos produit."

### 104. `services/reconciliator/matcher.py`
**Prompt** : "Écris la logique de matching combinant embeddings
texte+image via recherche hybride Qdrant, produisant des candidats de
fusion SKU."

### 105. `services/reconciliator/confidence_scorer.py`
**Prompt** : "Écris le calcul de score de confiance sur chaque match —
obligatoire avant toute fusion, voir brief Lot B section 0bis."

### 106. `services/reconciliator/human_review_queue.py`
**Prompt** : "Écris la file de révision humaine pour les matches
ambigus (confidence sous un seuil défini), jamais de fusion automatique
à 100% sur ces cas."

### 107. `services/reconciliator/qdrant_client.py`
**Prompt** : "Écris le client d'interrogation Qdrant (recherche hybride
dense vector + filtres payload), configuré selon le schéma provisionné
par le Lot C."

### 108. `services/reconciliator/README.md`
**Prompt** : "Documente le pipeline complet de bout en bout (image/texte
brut → SKU canonique fusionné ou mis en attente de révision)."

### 109. `services/reconciliator/tests/test_matcher.py`
**Prompt** : "Écris des tests du matcher sur des paires de produits
connues comme identiques et connues comme différentes (faux positifs à
éviter explicitement)."

### 110. `services/reconciliator/tests/test_confidence_scorer.py`
**Prompt** : "Écris des tests vérifiant que le score de confiance
dégrade correctement en cas de données incomplètes (image manquante,
description courte)."

## OPTIMUS (11 fichiers)

### 111. `services/optimus/arbitrage_engine.py`
**Prompt** : "Écris la classe `ArbitrageEngine` avec la méthode unique
`compute(sku_id, zone_a, zone_b, timestamp) → ArbitrageScore`, conforme
à la spécification du brief Lot B section 0. Ce point d'entrée unique est
appelé par les deux voies (pré-calcul et à la demande) — jamais de
logique dupliquée."

### 112. `services/optimus/margin_calculator.py`
**Prompt** : "Écris le calcul de marge nette : prix de vente moins
(prix d'achat + fret volumétrique + taxes/douanes + risque de change)."

### 113. `services/optimus/feasibility_scorer.py`
**Prompt** : "Écris le calcul du score de faisabilité géopolitique
(0 si sanction/embargo bloquant provenant de VENUS, sinon pondération
0-1)."

### 114. `services/optimus/confidence_calculator.py`
**Prompt** : "Écris le calcul du score de confiance du résultat
d'arbitrage, basé sur la fraîcheur et la complétude des données sources
(VENUS + MERCURE)."

### 115. `services/optimus/scheduler_precompute.py`
**Prompt** : "Écris le scheduler consommant les events
`PriceObservation` pour les `TrackedProduct` actifs, avec
`refresh_interval_s` adaptatif selon la volatilité observée — voir ADR
0004."

### 116. `services/optimus/on_demand_handler.py`
**Prompt** : "Écris le handler de calcul à la demande, avec cache Redis
TTL 2-5 min et logique de promotion automatique en `TrackedProduct` au
-delà d'un seuil de popularité — voir ADR 0004."

### 117. `services/optimus/cache_client.py`
**Prompt** : "Écris le client Redis dédié au cache court terme
d'OPTIMUS, distinct du cache de contexte VENUS."

### 118. `services/optimus/README.md`
**Prompt** : "Documente le mode hybride (ADR 0004) et comment tester
localement les deux voies de déclenchement."

### 119. `services/optimus/tests/test_arbitrage_engine.py`
**Prompt** : "Écris des tests de `ArbitrageEngine.compute` sur des cas
connus (marge positive claire, marge négative, embargo bloquant)."

### 120. `services/optimus/tests/test_margin_calculator.py`
**Prompt** : "Écris des tests unitaires du calcul de marge avec des
valeurs de fret/taxes/FX connues et un résultat attendu calculé à la
main."

### 121. `services/optimus/tests/test_hybrid_consistency.py`
**Prompt** : "Écris un test garantissant que la voie pré-calcul et la
voie à la demande produisent un résultat identique pour les mêmes
paramètres d'entrée — test de non-régression critique pour ADR 0004."

## Fleet Command (6 fichiers)

### 122. `services/fleet-command/agent_registry.py`
**Prompt** : "Écris le registre des agents MERCURE et nœuds LEGION
actifs, avec statut et dernière activité."

### 123. `services/fleet-command/command_dispatcher.py`
**Prompt** : "Écris le dispatcher de commandes asynchrones vers les
agents via Kafka (topic `agent-commands`), jamais de couplage HTTP
synchrone direct — voir point d'architecture initial signalé."

### 124. `services/fleet-command/heartbeat_monitor.py`
**Prompt** : "Écris le moniteur de heartbeat détectant les agents/nœuds
inactifs ou en échec, consommant `cormery.fleet.agent.heartbeat`."

### 125. `services/fleet-command/legion_orchestrator.py`
**Prompt** : "Écris l'orchestrateur spécifique à LEGION, gérant
l'assignation de tâches redondantes (voir `legion/task_dispatcher.py`) et
l'exposition de l'API publique authentifiée pour les nœuds externes."

### 126. `services/fleet-command/README.md`
**Prompt** : "Documente l'architecture C2 et comment un nouvel agent ou
nœud LEGION s'enregistre auprès de Fleet Command."

### 127. `services/fleet-command/tests/test_heartbeat_monitor.py`
**Prompt** : "Écris des tests simulant un agent qui cesse d'émettre des
heartbeats et vérifiant sa détection comme inactif après le délai
configuré."

## Sécurité transverse (9 fichiers)

### 128. `security/auth_middleware.py`
**Prompt** : "Écris le middleware d'authentification/autorisation
extrayant le `tenant_id` du token, appliqué à toutes les APIs — voir
document maître section 4."

### 129. `security/tenant_scope.py`
**Prompt** : "Écris l'utilitaire garantissant qu'aucune requête DB ne
peut s'exécuter sans scoping explicite par `tenant_id`, protection contre
les attaques IDOR."

### 130. `security/rate_limiter.py`
**Prompt** : "Écris le rate limiter applicatif par tenant et par IP,
distinct du throttling de scraping MERCURE."

### 131. `security/secrets_vault_client.py`
**Prompt** : "Écris le client d'intégration avec le vault centralisé
(HashiCorp Vault ou équivalent cloud) pour la lecture/rotation des
secrets — aucune clé en dur nulle part dans le code."

### 132. `security/audit_log.py`
**Prompt** : "Écris le module de traçabilité (qui, quand, quoi) pour
toute modification de donnée sensible (quotas, plans, résultats
d'arbitrage), cohérent avec l'event sourcing d'`arbitrage_results`."

### 133. `security/idor_guard.py`
**Prompt** : "Écris un décorateur/garde réutilisable empêchant l'accès à
une ressource dont le `tenant_id` ne correspond pas à celui du
token authentifié."

### 134. `security/README.md`
**Prompt** : "Documente la politique de sécurité globale du système :
gestion des secrets, scoping multi-tenant, conformité scraping (pas de
contournement agressif de CAPTCHA)."

### 135. `security/tests/test_tenant_scope.py`
**Prompt** : "Écris des tests garantissant qu'une requête sans
`tenant_id` valide est systématiquement rejetée."

### 136. `security/tests/test_idor_guard.py`
**Prompt** : "Écris des tests simulant une tentative d'accès à une
ressource d'un autre tenant, vérifiant le rejet explicite."
