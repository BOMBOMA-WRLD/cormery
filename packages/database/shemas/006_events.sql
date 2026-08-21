-- ================================================================
-- CORMERY - Schéma Event Sourcing (Événements et Traçabilité)
-- Version: 1.0.0
-- Date: 2026-08-07
-- Description: Modèle Event Sourcing complet pour la traçabilité
--              des décisions financières et opérationnelles
-- ================================================================

-- ================================================================
-- TABLE: event_sourcing.signal_events
-- ================================================================
-- Description: Événements de signal (base de tous les événements)
--              Contient les métadonnées communes à tous les événements
-- ================================================================

CREATE TABLE event_sourcing.signal_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    event_id VARCHAR(64) NOT NULL UNIQUE,  -- ULID ou UUID v7 pour tri temporel
    parent_event_id VARCHAR(64),  -- Chaînage d'événements
    
    -- Classification
    event_type VARCHAR(100) NOT NULL,  -- 'price_update', 'stock_update', 'arbitrage_computed', etc.
    event_category VARCHAR(50) NOT NULL,  -- 'signal', 'mercure', 'venus', 'legion', 'optimus'
    event_version INTEGER NOT NULL DEFAULT 1,
    
    -- Agrégats
    aggregate_type VARCHAR(50) NOT NULL,  -- 'sku', 'zone', 'product', 'arbitrage'
    aggregate_id VARCHAR(255) NOT NULL,
    aggregate_version INTEGER NOT NULL DEFAULT 0,
    
    -- Contenu
    payload JSONB NOT NULL,  -- Données spécifiques de l'événement
    metadata JSONB DEFAULT '{}'::jsonb,  -- Métadonnées de contexte
    
    -- Source
    source_system VARCHAR(50) NOT NULL,  -- 'mercure', 'venus', 'optimus', 'legion', 'oracle', 'reconciliator'
    source_service VARCHAR(100),
    source_instance VARCHAR(100),
    source_event_id VARCHAR(100),  -- ID source pour traçabilité
    
    -- Idempotence
    idempotency_key VARCHAR(255) NOT NULL UNIQUE,  -- Clé d'idempotence
    
    -- Traçabilité
    correlation_id VARCHAR(100),  -- ID de corrélation pour les chaînes d'événements
    causation_id VARCHAR(100),  -- ID de causalité
    
    -- Chronologie
    occurred_at TIMESTAMPTZ NOT NULL,  -- Date de l'événement source
    received_at TIMESTAMPTZ DEFAULT NOW(),  -- Date de réception
    processed_at TIMESTAMPTZ,
    
    -- Statut
    processing_status VARCHAR(50) DEFAULT 'pending',  -- 'pending', 'processing', 'done', 'error'
    processing_error TEXT,
    retry_count INTEGER DEFAULT 0,
    
    -- Index de recherche
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('english', COALESCE(payload->>'product_name', '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(payload->>'sku', '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(metadata->>'source', '')), 'C')
    ) STORED,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_signal_events_category CHECK (event_category IN ('signal', 'mercure', 'venus', 'legion', 'optimus', 'oracle', 'reconciliator')),
    CONSTRAINT ck_signal_events_status CHECK (processing_status IN ('pending', 'processing', 'done', 'error', 'skipped'))
);

COMMENT ON TABLE event_sourcing.signal_events IS 'Événements de signal (base de tous les événements CORMERY)';
COMMENT ON COLUMN event_sourcing.signal_events.event_id IS 'Identifiant unique de l''événement (ULID ou UUID v7)';
COMMENT ON COLUMN event_sourcing.signal_events.parent_event_id IS 'Événement parent (chaînage)';
COMMENT ON COLUMN event_sourcing.signal_events.event_type IS 'Type d''événement (price_update, arbitrage_computed, etc.)';
COMMENT ON COLUMN event_sourcing.signal_events.event_category IS 'Catégorie d''événement (mercure/venus/legion/optimus)';
COMMENT ON COLUMN event_sourcing.signal_events.aggregate_type IS 'Type d''agrégat (sku, zone, product, arbitrage)';
COMMENT ON COLUMN event_sourcing.signal_events.aggregate_id IS 'ID de l''agrégat';
COMMENT ON COLUMN event_sourcing.signal_events.payload IS 'Données spécifiques de l''événement (JSONB)';
COMMENT ON COLUMN event_sourcing.signal_events.idempotency_key IS 'Clé d''idempotence unique';
COMMENT ON COLUMN event_sourcing.signal_events.correlation_id IS 'ID de corrélation pour les chaînes d''événements';
COMMENT ON COLUMN event_sourcing.signal_events.causation_id IS 'ID de causalité';
COMMENT ON COLUMN event_sourcing.signal_events.occurred_at IS 'Date de l''événement source (dans le système source)';
COMMENT ON COLUMN event_sourcing.signal_events.processed_at IS 'Date de traitement';
COMMENT ON COLUMN event_sourcing.signal_events.processing_status IS 'Statut de traitement (pending/processing/done/error)';

-- Index
CREATE INDEX idx_signal_events_event_id ON event_sourcing.signal_events(event_id);
CREATE INDEX idx_signal_events_tenant_time ON event_sourcing.signal_events(tenant_id, occurred_at DESC);
CREATE INDEX idx_signal_events_category ON event_sourcing.signal_events(event_category, occurred_at DESC);
CREATE INDEX idx_signal_events_type ON event_sourcing.signal_events(event_type, occurred_at DESC);
CREATE INDEX idx_signal_events_aggregate ON event_sourcing.signal_events(aggregate_type, aggregate_id, occurred_at DESC);
CREATE INDEX idx_signal_events_idempotency ON event_sourcing.signal_events(idempotency_key);
CREATE INDEX idx_signal_events_correlation ON event_sourcing.signal_events(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_signal_events_status ON event_sourcing.signal_events(processing_status) WHERE processing_status = 'pending';
CREATE INDEX idx_signal_events_search ON event_sourcing.signal_events USING GIN(search_vector);
CREATE INDEX idx_signal_events_parent ON event_sourcing.signal_events(parent_event_id) WHERE parent_event_id IS NOT NULL;

-- ================================================================
-- TABLE: event_sourcing.mercure_events
-- ================================================================
-- Description: Événements spécifiques à MERCURE (ingestion haute fréquence)
--              Prix, stock, ad velocity, etc.
-- ================================================================

CREATE TABLE event_sourcing.mercure_events (
    -- Héritage (référence à signal_events)
    signal_event_id UUID PRIMARY KEY REFERENCES event_sourcing.signal_events(id) ON DELETE CASCADE,
    
    -- Type spécifique MERCURE
    mercure_event_type VARCHAR(50) NOT NULL,  -- 'price_scraped', 'stock_scraped', 'ad_velocity', 'product_discovered'
    
    -- Source
    agent_id VARCHAR(100) NOT NULL,  -- ID de l'agent MERCURE
    agent_version VARCHAR(20),
    scraper_type VARCHAR(50),  -- 'html_parser', 'api', 'headless_browser'
    
    -- Cible
    target_url TEXT NOT NULL,
    target_domain VARCHAR(255) NOT NULL,
    target_platform VARCHAR(100),
    
    -- Résultat du scraping
    raw_data_hash VARCHAR(64),  -- Hash des données brutes
    raw_data_size_bytes INTEGER,
    extraction_confidence DECIMAL(5,4) DEFAULT 1.0,
    
    -- Performance
    scrape_duration_ms INTEGER,
    proxy_used VARCHAR(255),
    retry_attempts INTEGER DEFAULT 0,
    success BOOLEAN DEFAULT TRUE,
    error_code VARCHAR(50),
    error_message TEXT,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_mercure_events_type CHECK (mercure_event_type IN (
        'price_scraped', 'stock_scraped', 'ad_velocity', 
        'product_discovered', 'product_updated', 'product_removed'
    )),
    CONSTRAINT ck_mercure_events_confidence CHECK (extraction_confidence BETWEEN 0 AND 1)
);

COMMENT ON TABLE event_sourcing.mercure_events IS 'Événements spécifiques à MERCURE (ingestion haute fréquence)';
COMMENT ON COLUMN event_sourcing.mercure_events.mercure_event_type IS 'Type d''événement MERCURE';
COMMENT ON COLUMN event_sourcing.mercure_events.agent_id IS 'ID de l''agent MERCURE source';
COMMENT ON COLUMN event_sourcing.mercure_events.target_url IS 'URL cible du scraping';
COMMENT ON COLUMN event_sourcing.mercure_events.raw_data_hash IS 'Hash des données brutes (déduplication)';
COMMENT ON COLUMN event_sourcing.mercure_events.success IS 'Le scraping a-t-il réussi ?';

-- Index
CREATE INDEX idx_mercure_events_type ON event_sourcing.mercure_events(mercure_event_type);
CREATE INDEX idx_mercure_events_agent ON event_sourcing.mercure_events(agent_id);
CREATE INDEX idx_mercure_events_domain ON event_sourcing.mercure_events(target_domain);
CREATE INDEX idx_mercure_events_success ON event_sourcing.mercure_events(success) WHERE success = FALSE;
CREATE INDEX idx_mercure_events_duration ON event_sourcing.mercure_events(scrape_duration_ms);

-- ================================================================
-- TABLE: event_sourcing.venus_events
-- ================================================================
-- Description: Événements spécifiques à VENUS (contexte lent)
--              FX, douanes, sanctions, données socio-économiques
-- ================================================================

CREATE TABLE event_sourcing.venus_events (
    -- Héritage
    signal_event_id UUID PRIMARY KEY REFERENCES event_sourcing.signal_events(id) ON DELETE CASCADE,
    
    -- Type spécifique VENUS
    venus_event_type VARCHAR(50) NOT NULL,  -- 'fx_updated', 'custom_duty_updated', 'sanction_updated', 'macro_data_updated'
    
    -- Source de données
    data_source VARCHAR(100) NOT NULL,  -- 'fixer', 'ecb', 'world_bank', 'imf', 'un_comtrade'
    data_version VARCHAR(50),
    data_url TEXT,
    
    -- Période
    data_period_start DATE,
    data_period_end DATE,
    data_frequency VARCHAR(20),  -- 'daily', 'weekly', 'monthly', 'quarterly', 'yearly'
    
    -- Métriques
    data_points_count INTEGER,
    validation_status VARCHAR(50) DEFAULT 'pending',  -- 'pending', 'validated', 'rejected'
    validation_notes TEXT,
    
    -- Qualité
    data_quality_score DECIMAL(5,4) DEFAULT 0.95,
    source_confidence DECIMAL(5,4) DEFAULT 0.90,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_venus_events_type CHECK (venus_event_type IN (
        'fx_updated', 'custom_duty_updated', 'sanction_updated', 
        'macro_data_updated', 'trade_agreement_updated', 'zone_updated'
    )),
    CONSTRAINT ck_venus_events_quality CHECK (data_quality_score BETWEEN 0 AND 1)
);

COMMENT ON TABLE event_sourcing.venus_events IS 'Événements spécifiques à VENUS (contexte lent)';
COMMENT ON COLUMN event_sourcing.venus_events.venus_event_type IS 'Type d''événement VENUS';
COMMENT ON COLUMN event_sourcing.venus_events.data_source IS 'Source des données (fixer/ecb/world_bank/imf/un_comtrade)';
COMMENT ON COLUMN event_sourcing.venus_events.validation_status IS 'Statut de validation (pending/validated/rejected)';
COMMENT ON COLUMN event_sourcing.venus_events.data_quality_score IS 'Score de qualité des données (0-1)';

-- Index
CREATE INDEX idx_venus_events_type ON event_sourcing.venus_events(venus_event_type);
CREATE INDEX idx_venus_events_source ON event_sourcing.venus_events(data_source);
CREATE INDEX idx_venus_events_validation ON event_sourcing.venus_events(validation_status);
CREATE INDEX idx_venus_events_period ON event_sourcing.venus_events(data_period_start, data_period_end);

-- ================================================================
-- TABLE: event_sourcing.legion_tasks
-- ================================================================
-- Description: Tâches distribuées aux nœuds LEGION
--              (calcul pur délégué)
-- ================================================================

CREATE TABLE event_sourcing.legion_tasks (
    -- Héritage
    signal_event_id UUID PRIMARY KEY REFERENCES event_sourcing.signal_events(id) ON DELETE CASCADE,
    
    -- Identification
    task_id VARCHAR(64) NOT NULL UNIQUE,
    task_type VARCHAR(50) NOT NULL,  -- 'embedding_compute', 'scoring', 'model_inference'
    task_version INTEGER DEFAULT 1,
    
    -- Tâche
    task_definition JSONB NOT NULL,  -- Définition complète de la tâche
    task_parameters JSONB,  -- Paramètres d'exécution
    priority INTEGER DEFAULT 1,  -- 1 = plus haute, 5 = plus basse
    
    -- Distribution
    assigned_to UUID,  -- Nœud LEGION assigné
    assigned_at TIMESTAMPTZ,
    accepted_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    
    -- Résultat
    result_received_at TIMESTAMPTZ,
    result_validation_status VARCHAR(50) DEFAULT 'pending',  -- 'pending', 'validated', 'rejected'
    result_hash VARCHAR(64),  -- Hash du résultat pour vérification
    result_size_bytes INTEGER,
    
    -- Redondance (Byzantine Fault Tolerance)
    validation_rounds INTEGER DEFAULT 1,
    consensus_nodes INTEGER DEFAULT 3,  -- Nombre de nœuds requis pour consensus
    consensus_reached BOOLEAN DEFAULT FALSE,
    
    -- Performance
    execution_time_ms INTEGER,
    node_reputation_required DECIMAL(5,4) DEFAULT 0.7,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_legion_tasks_type CHECK (task_type IN (
        'embedding_compute', 'scoring', 'model_inference', 
        'similarity_search', 'data_aggregation', 'vector_indexing'
    )),
    CONSTRAINT ck_legion_tasks_priority CHECK (priority BETWEEN 1 AND 5),
    CONSTRAINT ck_legion_tasks_consensus CHECK (consensus_nodes >= 1)
);

COMMENT ON TABLE event_sourcing.legion_tasks IS 'Tâches distribuées aux nœuds LEGION (calcul pur)';
COMMENT ON COLUMN event_sourcing.legion_tasks.task_id IS 'Identifiant unique de la tâche LEGION';
COMMENT ON COLUMN event_sourcing.legion_tasks.task_type IS 'Type de tâche (embedding_compute/scoring/model_inference/similarity_search)';
COMMENT ON COLUMN event_sourcing.legion_tasks.task_definition IS 'Définition complète de la tâche (JSONB)';
COMMENT ON COLUMN event_sourcing.legion_tasks.assigned_to IS 'Nœud LEGION assigné';
COMMENT ON COLUMN event_sourcing.legion_tasks.consensus_nodes IS 'Nombre de nœuds requis pour le consensus';
COMMENT ON COLUMN event_sourcing.legion_tasks.node_reputation_required IS 'Réputation minimale requise pour le nœud';

-- Index
CREATE INDEX idx_legion_tasks_task_id ON event_sourcing.legion_tasks(task_id);
CREATE INDEX idx_legion_tasks_type ON event_sourcing.legion_tasks(task_type);
CREATE INDEX idx_legion_tasks_status ON event_sourcing.legion_tasks(result_validation_status);
CREATE INDEX idx_legion_tasks_assigned ON event_sourcing.legion_tasks(assigned_to) WHERE assigned_to IS NOT NULL;
CREATE INDEX idx_legion_tasks_priority ON event_sourcing.legion_tasks(priority);
CREATE INDEX idx_legion_tasks_created ON event_sourcing.legion_tasks(created_at);

-- ================================================================
-- TABLE: event_sourcing.legion_results
-- ================================================================
-- Description: Résultats des tâches LEGION (validés par consensus)
-- ================================================================

CREATE TABLE event_sourcing.legion_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    task_id UUID NOT NULL REFERENCES event_sourcing.legion_tasks(signal_event_id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Résultat
    result_type VARCHAR(50) NOT NULL,  -- 'embedding', 'score', 'prediction', 'search_result'
    result_value JSONB NOT NULL,
    result_hash VARCHAR(64) NOT NULL,  -- Hash pour vérification d'intégrité
    
    -- Nœud source
    node_id UUID NOT NULL,
    node_version VARCHAR(20),
    node_reputation DECIMAL(5,4) DEFAULT 0.5,
    
    -- Métadonnées
    execution_time_ms INTEGER,
    node_metrics JSONB DEFAULT '{}'::jsonb,  -- CPU, mémoire, etc.
    
    -- Validation
    validation_count INTEGER DEFAULT 1,
    validation_consensus DECIMAL(5,4) DEFAULT 1.0,
    is_consensus_validated BOOLEAN DEFAULT FALSE,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    validated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_legion_results_type CHECK (result_type IN (
        'embedding', 'score', 'prediction', 'search_result',
        'similarity_matrix', 'inference_result'
    )),
    CONSTRAINT ck_legion_results_consensus CHECK (validation_consensus BETWEEN 0 AND 1)
);

COMMENT ON TABLE event_sourcing.legion_results IS 'Résultats des tâches LEGION (validés par consensus)';
COMMENT ON COLUMN event_sourcing.legion_results.result_type IS 'Type de résultat (embedding/score/prediction/search_result)';
COMMENT ON COLUMN event_sourcing.legion_results.result_hash IS 'Hash pour vérification d''intégrité';
COMMENT ON COLUMN event_sourcing.legion_results.node_id IS 'ID du nœud LEGION source';
COMMENT ON COLUMN event_sourcing.legion_results.validation_consensus IS 'Score de consensus (0-1)';

-- Index
CREATE INDEX idx_legion_results_task ON event_sourcing.legion_results(task_id);
CREATE INDEX idx_legion_results_tenant ON event_sourcing.legion_results(tenant_id);
CREATE INDEX idx_legion_results_node ON event_sourcing.legion_results(node_id);
CREATE INDEX idx_legion_results_type ON event_sourcing.legion_results(result_type);
CREATE INDEX idx_legion_results_validated ON event_sourcing.legion_results(is_consensus_validated) WHERE is_consensus_validated = TRUE;
CREATE INDEX idx_legion_results_submitted ON event_sourcing.legion_results(submitted_at DESC);

-- ================================================================
-- TABLE: event_sourcing.optimus_results
-- ================================================================
-- Description: Résultats des calculs d'arbitrage OPTIMUS
--              (Event Sourcing pour les décisions financières)
-- ================================================================

CREATE TABLE event_sourcing.optimus_results (
    -- Héritage
    signal_event_id UUID PRIMARY KEY REFERENCES event_sourcing.signal_events(id) ON DELETE CASCADE,
    
    -- Identification
    result_id VARCHAR(64) NOT NULL UNIQUE,
    calculation_version INTEGER NOT NULL DEFAULT 1,
    
    -- Références métier
    sku_id UUID NOT NULL REFERENCES products.sku_canonical(id) ON DELETE CASCADE,
    zone_buy_id UUID NOT NULL REFERENCES market.zones(id),
    zone_sell_id UUID NOT NULL REFERENCES market.zones(id),
    
    -- Résultats financiers
    buy_price_usd DECIMAL(15,4) NOT NULL,
    sell_price_usd DECIMAL(15,4) NOT NULL,
    gross_margin_usd DECIMAL(15,4) NOT NULL,
    
    -- Coûts détaillés
    shipping_cost_usd DECIMAL(15,4) DEFAULT 0,
    customs_duties_usd DECIMAL(15,4) DEFAULT 0,
    taxes_usd DECIMAL(15,4) DEFAULT 0,
    fx_conversion_cost_usd DECIMAL(15,4) DEFAULT 0,
    platform_fees_usd DECIMAL(15,4) DEFAULT 0,
    handling_cost_usd DECIMAL(15,4) DEFAULT 0,
    
    -- Résultat net
    net_margin_usd DECIMAL(15,4) NOT NULL,
    net_margin_percent DECIMAL(8,4) NOT NULL,
    
    -- Faisabilité
    feasibility_score DECIMAL(5,4) DEFAULT 0,  -- 0-1
    feasibility_flags JSONB DEFAULT '{}'::jsonb,  -- Blocages/drapeaux
    risk_score DECIMAL(5,4) DEFAULT 0,  -- 0-1
    confidence_score DECIMAL(5,4) DEFAULT 0.5,  -- 0-1
    
    -- Versionnement du contexte
    context_version INTEGER NOT NULL,
    fx_rate_version INTEGER,
    custom_duty_version INTEGER,
    zone_version INTEGER,
    
    -- Mode de calcul
    computation_mode VARCHAR(50) NOT NULL,  -- 'precomputed', 'ondemand', 'legion', 'oracle'
    computation_latency_ms INTEGER,
    computation_source VARCHAR(50),  -- 'scheduler', 'user', 'webhook', 'oracle'
    
    -- Références aux observations sources
    price_obs_buy_id VARCHAR(64),  -- ID de l'observation prix source
    price_obs_sell_id VARCHAR(64),
    price_obs_buy_at TIMESTAMPTZ,
    price_obs_sell_at TIMESTAMPTZ,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_optimus_results_margin CHECK (net_margin_percent >= -1000 AND net_margin_percent <= 1000),
    CONSTRAINT ck_optimus_results_feasibility CHECK (feasibility_score BETWEEN 0 AND 1),
    CONSTRAINT ck_optimus_results_risk CHECK (risk_score BETWEEN 0 AND 1),
    CONSTRAINT ck_optimus_results_confidence CHECK (confidence_score BETWEEN 0 AND 1),
    CONSTRAINT ck_optimus_results_mode CHECK (computation_mode IN ('precomputed', 'ondemand', 'legion', 'oracle', 'backfill')),
    CONSTRAINT ck_optimus_results_zones CHECK (zone_buy_id != zone_sell_id)
);

COMMENT ON TABLE event_sourcing.optimus_results IS 'Résultats des calculs d''arbitrage OPTIMUS (Event Sourcing)';
COMMENT ON COLUMN event_sourcing.optimus_results.result_id IS 'Identifiant unique du résultat';
COMMENT ON COLUMN event_sourcing.optimus_results.calculation_version IS 'Version de l''algorithme de calcul';
COMMENT ON COLUMN event_sourcing.optimus_results.buy_price_usd IS 'Prix d''achat en USD';
COMMENT ON COLUMN event_sourcing.optimus_results.sell_price_usd IS 'Prix de vente en USD';
COMMENT ON COLUMN event_sourcing.optimus_results.net_margin_usd IS 'Marge nette en USD';
COMMENT ON COLUMN event_sourcing.optimus_results.net_margin_percent IS 'Marge nette en pourcentage';
COMMENT ON COLUMN event_sourcing.optimus_results.feasibility_score IS 'Score de faisabilité (0-1)';
COMMENT ON COLUMN event_sourcing.optimus_results.feasibility_flags IS 'Drapeaux de faisabilité (JSONB)';
COMMENT ON COLUMN event_sourcing.optimus_results.computation_mode IS 'Mode de calcul (precomputed/ondemand/legion/oracle)';
COMMENT ON COLUMN event_sourcing.optimus_results.price_obs_buy_id IS 'ID de l''observation prix source (achat)';

-- Index
CREATE INDEX idx_optimus_results_result_id ON event_sourcing.optimus_results(result_id);
CREATE INDEX idx_optimus_results_sku ON event_sourcing.optimus_results(sku_id, calculated_at DESC);
CREATE INDEX idx_optimus_results_zones ON event_sourcing.optimus_results(zone_buy_id, zone_sell_id);
CREATE INDEX idx_optimus_results_margin ON event_sourcing.optimus_results(net_margin_usd DESC) 
    WHERE feasibility_score > 0.5;
CREATE INDEX idx_optimus_results_feasibility ON event_sourcing.optimus_results(feasibility_score) 
    WHERE feasibility_score > 0.5;
CREATE INDEX idx_optimus_results_mode ON event_sourcing.optimus_results(computation_mode);
CREATE INDEX idx_optimus_results_calculated ON event_sourcing.optimus_results(calculated_at DESC);

-- ================================================================
-- FONCTIONS UTILITAIRES POUR L'EVENT SOURCING
-- ================================================================

-- Fonction pour rejouer les événements d'un aggregate
CREATE OR REPLACE FUNCTION event_sourcing.replay_aggregate(
    p_aggregate_type VARCHAR(50),
    p_aggregate_id VARCHAR(255),
    p_tenant_id UUID,
    p_target_version INTEGER DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    result JSONB := '{}'::jsonb;
    rec RECORD;
    current_version INTEGER := 0;
BEGIN
    FOR rec IN
        SELECT * FROM event_sourcing.signal_events
        WHERE aggregate_type = p_aggregate_type
            AND aggregate_id = p_aggregate_id
            AND tenant_id = p_tenant_id
            AND (p_target_version IS NULL OR aggregate_version <= p_target_version)
            AND processing_status = 'done'
        ORDER BY aggregate_version ASC
    LOOP
        result := event_sourcing.apply_event(result, rec);
        current_version := rec.aggregate_version;
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION event_sourcing.replay_aggregate IS 'Rejoue tous les événements d''un aggregate pour obtenir son état';

-- Fonction pour appliquer un événement à l'état courant
CREATE OR REPLACE FUNCTION event_sourcing.apply_event(
    current_state JSONB,
    event_row event_sourcing.signal_events
)
RETURNS JSONB AS $$
BEGIN
    -- Application selon le type d'événement
    CASE event_row.event_type
        -- Événements de prix
        WHEN 'price_updated' THEN
            RETURN current_state || jsonb_build_object(
                'last_price', event_row.payload->>'price_usd',
                'last_price_at', event_row.occurred_at,
                'last_zone', event_row.payload->>'zone_id',
                'version', event_row.aggregate_version,
                'state_updated_at', NOW()
            );
        
        -- Événements de stock
        WHEN 'stock_updated' THEN
            RETURN current_state || jsonb_build_object(
                'stock_quantity', (event_row.payload->>'stock_quantity')::INTEGER,
                'stock_status', event_row.payload->>'stock_status',
                'stock_updated_at', event_row.occurred_at,
                'version', event_row.aggregate_version
            );
        
        -- Événements d'arbitrage
        WHEN 'arbitrage_computed' THEN
            RETURN current_state || jsonb_build_object(
                'last_arbitrage', event_row.payload,
                'last_arbitrage_at', event_row.occurred_at,
                'version', event_row.aggregate_version
            );
        
        -- Événements SKU
        WHEN 'sku_created' THEN
            RETURN current_state || jsonb_build_object(
                'sku_id', event_row.aggregate_id,
                'product_name', event_row.payload->>'product_name',
                'brand', event_row.payload->>'brand',
                'category', event_row.payload->>'category',
                'created_at', event_row.occurred_at,
                'version', event_row.aggregate_version
            );
        
        -- Événements SKU mis à jour
        WHEN 'sku_updated' THEN
            RETURN current_state || jsonb_build_object(
                'product_name', COALESCE(event_row.payload->>'product_name', current_state->>'product_name'),
                'brand', COALESCE(event_row.payload->>'brand', current_state->>'brand'),
                'category', COALESCE(event_row.payload->>'category', current_state->>'category'),
                'updated_at', event_row.occurred_at,
                'version', event_row.aggregate_version
            );
        
        -- Événements de zone
        WHEN 'zone_updated' THEN
            RETURN current_state || jsonb_build_object(
                'zone_code', event_row.payload->>'code',
                'zone_name', event_row.payload->>'name',
                'zone_type', event_row.payload->>'type',
                'zone_updated_at', event_row.occurred_at,
                'version', event_row.aggregate_version
            );
        
        -- Événements de taux de change
        WHEN 'fx_updated' THEN
            RETURN current_state || jsonb_build_object(
                'fx_rates', event_row.payload,
                'fx_updated_at', event_row.occurred_at,
                'version', event_row.aggregate_version
            );
        
        -- Sinon, retourner l'état inchangé
        ELSE
            RETURN current_state;
    END CASE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION event_sourcing.apply_event IS 'Applique un événement à l''état courant';

-- Fonction pour vérifier l'idempotence
CREATE OR REPLACE FUNCTION event_sourcing.check_idempotency(
    p_idempotency_key VARCHAR(255)
)
RETURNS BOOLEAN AS $$
DECLARE
    existing UUID;
BEGIN
    SELECT id INTO existing
    FROM event_sourcing.signal_events
    WHERE idempotency_key = p_idempotency_key
    LIMIT 1;
    
    RETURN existing IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION event_sourcing.check_idempotency IS 'Vérifie si un événement avec cette clé d''idempotence existe déjà';

-- Fonction pour créer un snapshot d'aggregate
CREATE OR REPLACE FUNCTION event_sourcing.create_snapshot(
    p_aggregate_type VARCHAR(50),
    p_aggregate_id VARCHAR(255),
    p_tenant_id UUID
)
RETURNS UUID AS $$
DECLARE
    snapshot_data JSONB;
    current_version INTEGER;
    snapshot_id UUID;
BEGIN
    -- Récupérer la version actuelle
    SELECT MAX(aggregate_version) INTO current_version
    FROM event_sourcing.signal_events
    WHERE aggregate_type = p_aggregate_type
        AND aggregate_id = p_aggregate_id
        AND tenant_id = p_tenant_id
        AND processing_status = 'done';
    
    IF current_version IS NULL THEN
        RAISE EXCEPTION 'Aucun événement trouvé pour l''aggregate %:%', p_aggregate_type, p_aggregate_id;
    END IF;
    
    -- Rejouer tous les événements
    snapshot_data := event_sourcing.replay_aggregate(
        p_aggregate_type,
        p_aggregate_id,
        p_tenant_id,
        current_version
    );
    
    -- Insérer le snapshot
    INSERT INTO event_sourcing.aggregate_snapshots (
        aggregate_type,
        aggregate_id,
        tenant_id,
        version,
        snapshot,
        created_at
    ) VALUES (
        p_aggregate_type,
        p_aggregate_id,
        p_tenant_id,
        current_version,
        snapshot_data,
        NOW()
    ) RETURNING id INTO snapshot_id;
    
    RETURN snapshot_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION event_sourcing.create_snapshot IS 'Crée un snapshot d''un aggregate pour accélérer les rebuilds';

-- Fonction pour obtenir l'état d'un aggregate via snapshot + événements récents
CREATE OR REPLACE FUNCTION event_sourcing.get_aggregate_state(
    p_aggregate_type VARCHAR(50),
    p_aggregate_id VARCHAR(255),
    p_tenant_id UUID
)
RETURNS JSONB AS $$
DECLARE
    snapshot_rec RECORD;
    state JSONB := '{}'::jsonb;
    current_version INTEGER := 0;
BEGIN
    -- Récupérer le snapshot le plus récent
    SELECT * INTO snapshot_rec
    FROM event_sourcing.aggregate_snapshots
    WHERE aggregate_type = p_aggregate_type
        AND aggregate_id = p_aggregate_id
        AND tenant_id = p_tenant_id
    ORDER BY version DESC
    LIMIT 1;
    
    IF snapshot_rec IS NOT NULL THEN
        state := snapshot_rec.snapshot;
        current_version := snapshot_rec.version;
    ELSE
        -- Pas de snapshot, rejouer depuis le début
        RETURN event_sourcing.replay_aggregate(
            p_aggregate_type,
            p_aggregate_id,
            p_tenant_id
        );
    END IF;
    
    -- Appliquer les événements plus récents que le snapshot
    FOR rec IN
        SELECT * FROM event_sourcing.signal_events
        WHERE aggregate_type = p_aggregate_type
            AND aggregate_id = p_aggregate_id
            AND tenant_id = p_tenant_id
            AND aggregate_version > current_version
            AND processing_status = 'done'
        ORDER BY aggregate_version ASC
    LOOP
        state := event_sourcing.apply_event(state, rec);
    END LOOP;
    
    RETURN state;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION event_sourcing.get_aggregate_state IS 'Récupère l''état courant d''un aggregate (snapshot + événements récents)';

-- ================================================================
-- TABLE: event_sourcing.aggregate_snapshots
-- ================================================================
-- Description: Snapshots des aggregates pour accélérer les rebuilds
-- ================================================================

CREATE TABLE event_sourcing.aggregate_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE