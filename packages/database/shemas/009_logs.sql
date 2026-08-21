-- ================================================================
-- CORMERY - Schéma Logs (Journalisation)
-- Version: 1.0.0
-- Date: 2026-08-07
-- Description: Tables de journalisation pour l'application,
--              Fleet Command, workers, et API
-- ================================================================

-- ================================================================
-- TABLE: logs.application_logs
-- ================================================================
-- Description: Logs généraux de l'application CORMERY
--              (tous les services)
-- ================================================================

CREATE TABLE logs.application_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES identity.users(id) ON DELETE SET NULL,
    session_id UUID REFERENCES security.sessions(id) ON DELETE SET NULL,
    
    -- Identification du log
    log_id VARCHAR(100) NOT NULL,
    log_level VARCHAR(20) NOT NULL,  -- 'debug', 'info', 'warn', 'error', 'fatal'
    log_source VARCHAR(100) NOT NULL,  -- Service ou module source
    log_source_type VARCHAR(50) NOT NULL,  -- 'service', 'worker', 'api', 'agent', 'fleet', 'scheduler'
    
    -- Message
    message TEXT NOT NULL,
    formatted_message TEXT,
    
    -- Contexte
    context JSONB DEFAULT '{}'::jsonb,
    structured_data JSONB DEFAULT '{}'::jsonb,
    
    -- Erreur
    error_code VARCHAR(50),
    error_stack TEXT,
    error_details JSONB DEFAULT '{}'::jsonb,
    
    -- Performance
    duration_ms INTEGER,
    memory_usage_bytes BIGINT,
    cpu_usage_percent DECIMAL(5,2),
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_app_logs_level CHECK (log_level IN ('debug', 'info', 'warn', 'error', 'fatal')),
    CONSTRAINT ck_app_logs_source CHECK (log_source_type IN ('service', 'worker', 'api', 'agent', 'fleet', 'scheduler', 'legion', 'mercure', 'venus', 'optimus'))
);

COMMENT ON TABLE logs.application_logs IS 'Logs généraux de l''application CORMERY';
COMMENT ON COLUMN logs.application_logs.log_level IS 'Niveau de log (debug/info/warn/error/fatal)';
COMMENT ON COLUMN logs.application_logs.log_source IS 'Service ou module source';
COMMENT ON COLUMN logs.application_logs.log_source_type IS 'Type de source (service/worker/api/agent/fleet/scheduler)';
COMMENT ON COLUMN logs.application_logs.message IS 'Message du log';
COMMENT ON COLUMN logs.application_logs.context IS 'Contexte d''exécution (JSONB)';
COMMENT ON COLUMN logs.application_logs.structured_data IS 'Données structurées associées';

-- Index
CREATE INDEX idx_app_logs_tenant ON logs.application_logs(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX idx_app_logs_user ON logs.application_logs(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_app_logs_level ON logs.application_logs(log_level, logged_at DESC);
CREATE INDEX idx_app_logs_source ON logs.application_logs(log_source, logged_at DESC);
CREATE INDEX idx_app_logs_source_type ON logs.application_logs(log_source_type, logged_at DESC);
CREATE INDEX idx_app_logs_logged_at ON logs.application_logs(logged_at DESC);
CREATE INDEX idx_app_logs_error ON logs.application_logs(logged_at DESC) WHERE log_level IN ('error', 'fatal');

-- Partitionnement des logs (mensuel)
CREATE TABLE logs.application_logs_2026_08 PARTITION OF logs.application_logs
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

-- ================================================================
-- TABLE: logs.fleet_logs
-- ================================================================
-- Description: Logs spécifiques à Fleet Command
--              (commandes, heartbeat, orchestration)
-- ================================================================

CREATE TABLE logs.fleet_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES identity.users(id) ON DELETE SET NULL,
    
    -- Identification du log
    log_level VARCHAR(20) NOT NULL,
    component VARCHAR(50) NOT NULL,  -- 'scheduler', 'orchestrator', 'monitor', 'heartbeat'
    
    -- Commande ou événement
    command_type VARCHAR(50),  -- 'start', 'stop', 'scale', 'deploy', 'health_check'
    command_id VARCHAR(100),
    target_agent_id VARCHAR(100),
    target_legion_node_id UUID,
    
    -- Contexte
    message TEXT NOT NULL,
    details JSONB DEFAULT '{}'::jsonb,
    state_before JSONB,
    state_after JSONB,
    
    -- Résultat
    success BOOLEAN DEFAULT TRUE,
    error_code VARCHAR(50),
    error_message TEXT,
    execution_time_ms INTEGER,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_fleet_logs_level CHECK (log_level IN ('debug', 'info', 'warn', 'error', 'fatal')),
    CONSTRAINT ck_fleet_logs_component CHECK (component IN ('scheduler', 'orchestrator', 'monitor', 'heartbeat', 'command', 'agent_manager', 'legion_manager')),
    CONSTRAINT ck_fleet_logs_command CHECK (command_type IS NULL OR command_type IN ('start', 'stop', 'scale', 'deploy', 'health_check', 'restart', 'update', 'collect_metrics'))
);

COMMENT ON TABLE logs.fleet_logs IS 'Logs spécifiques à Fleet Command (orchestration)';
COMMENT ON COLUMN logs.fleet_logs.component IS 'Composant Fleet Command (scheduler/orchestrator/monitor/heartbeat)';
COMMENT ON COLUMN logs.fleet_logs.command_type IS 'Type de commande émise (start/stop/scale/deploy/health_check)';
COMMENT ON COLUMN logs.fleet_logs.target_agent_id IS 'Agent MERCURE cible de la commande';
COMMENT ON COLUMN logs.fleet_logs.target_legion_node_id IS 'Nœud LEGION cible de la commande';
COMMENT ON COLUMN logs.fleet_logs.state_before IS 'État avant la commande';
COMMENT ON COLUMN logs.fleet_logs.state_after IS 'État après la commande';

-- Index
CREATE INDEX idx_fleet_logs_tenant ON logs.fleet_logs(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX idx_fleet_logs_component ON logs.fleet_logs(component, logged_at DESC);
CREATE INDEX idx_fleet_logs_command ON logs.fleet_logs(command_type, logged_at DESC) WHERE command_type IS NOT NULL;
CREATE INDEX idx_fleet_logs_target_agent ON logs.fleet_logs(target_agent_id, logged_at DESC) WHERE target_agent_id IS NOT NULL;
CREATE INDEX idx_fleet_logs_success ON logs.fleet_logs(success) WHERE success = FALSE;
CREATE INDEX idx_fleet_logs_logged_at ON logs.fleet_logs(logged_at DESC);

-- ================================================================
-- TABLE: logs.worker_logs
-- ================================================================
-- Description: Logs des workers MERCURE et LEGION
--              (exécution des tâches)
-- ================================================================

CREATE TABLE logs.worker_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    worker_id VARCHAR(100) NOT NULL,
    worker_type VARCHAR(50) NOT NULL,  -- 'mercure', 'legion'
    task_id UUID REFERENCES event_sourcing.legion_tasks(signal_event_id) ON DELETE SET NULL,
    
    -- Identification du log
    log_level VARCHAR(20) NOT NULL,
    phase VARCHAR(50) NOT NULL,  -- 'start', 'execution', 'completion', 'error'
    
    -- Tâche
    task_type VARCHAR(50),
    task_details JSONB DEFAULT '{}'::jsonb,
    input_data_hash VARCHAR(64),
    output_data_hash VARCHAR(64),
    
    -- Métriques
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_ms INTEGER,
    cpu_usage_percent DECIMAL(5,2),
    memory_usage_mb INTEGER,
    network_usage_mb INTEGER,
    
    -- Résultat
    success BOOLEAN DEFAULT TRUE,
    error_code VARCHAR(50),
    error_message TEXT,
    error_stack TEXT,
    retry_count INTEGER DEFAULT 0,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_worker_logs_level CHECK (log_level IN ('debug', 'info', 'warn', 'error', 'fatal')),
    CONSTRAINT ck_worker_logs_type CHECK (worker_type IN ('mercure', 'legion', 'venus', 'optimus')),
    CONSTRAINT ck_worker_logs_phase CHECK (phase IN ('start', 'execution', 'completion', 'error', 'retry'))
);

COMMENT ON TABLE logs.worker_logs IS 'Logs des workers MERCURE et LEGION';
COMMENT ON COLUMN logs.worker_logs.worker_id IS 'ID du worker (agent MERCURE ou nœud LEGION)';
COMMENT ON COLUMN logs.worker_logs.worker_type IS 'Type de worker (mercure/legion/venus/optimus)';
COMMENT ON COLUMN logs.worker_logs.phase IS 'Phase d''exécution (start/execution/completion/error/retry)';
COMMENT ON COLUMN logs.worker_logs.task_type IS 'Type de tâche exécutée';
COMMENT ON COLUMN logs.worker_logs.input_data_hash IS 'Hash des données d''entrée';
COMMENT ON COLUMN logs.worker_logs.output_data_hash IS 'Hash des données de sortie';
COMMENT ON COLUMN logs.worker_logs.retry_count IS 'Nombre de tentatives (si échec)';

-- Index
CREATE INDEX idx_worker_logs_worker ON logs.worker_logs(worker_id, logged_at DESC);
CREATE INDEX idx_worker_logs_type ON logs.worker_logs(worker_type, logged_at DESC);
CREATE INDEX idx_worker_logs_phase ON logs.worker_logs(phase, logged_at DESC);
CREATE INDEX idx_worker_logs_task ON logs.worker_logs(task_id) WHERE task_id IS NOT NULL;
CREATE INDEX idx_worker_logs_success ON logs.worker_logs(success) WHERE success = FALSE;
CREATE INDEX idx_worker_logs_duration ON logs.worker_logs(duration_ms DESC) WHERE duration_ms IS NOT NULL;
CREATE INDEX idx_worker_logs_logged_at ON logs.worker_logs(logged_at DESC);

-- ================================================================
-- TABLE: logs.api_requests
-- ================================================================
-- Description: Journal des requêtes API (GraphQL + REST)
-- ================================================================

CREATE TABLE logs.api_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES identity.users(id) ON DELETE SET NULL,
    session_id UUID REFERENCES security.sessions(id) ON DELETE SET NULL,
    api_key_id UUID REFERENCES identity.api_keys(id) ON DELETE SET NULL,
    
    -- Requête
    request_id VARCHAR(100) NOT NULL UNIQUE,
    request_method VARCHAR(10) NOT NULL,
    request_path TEXT NOT NULL,
    request_query TEXT,
    request_headers JSONB DEFAULT '{}'::jsonb,
    request_body_size INTEGER,
    request_body_hash VARCHAR(64),
    
    -- GraphQL
    is_graphql BOOLEAN DEFAULT FALSE,
    graphql_operation VARCHAR(50),  -- 'query', 'mutation', 'subscription'
    graphql_operation_name VARCHAR(255),
    graphql_variables JSONB DEFAULT '{}'::jsonb,
    
    -- Réponse
    response_status INTEGER NOT NULL,
    response_headers JSONB DEFAULT '{}'::jsonb,
    response_body_size INTEGER,
    response_body_hash VARCHAR(64),
    error_type VARCHAR(50),
    error_message TEXT,
    
    -- Performance
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_ms INTEGER,
    db_query_count INTEGER DEFAULT 0,
    db_query_time_ms INTEGER DEFAULT 0,
    external_api_calls INTEGER DEFAULT 0,
    external_api_time_ms INTEGER DEFAULT 0,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    ip_address INET,
    user_agent TEXT,
    
    -- Audit
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_api_requests_method CHECK (request_method IN ('GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS')),
    CONSTRAINT ck_api_requests_graphql_op CHECK (graphql_operation IS NULL OR graphql_operation IN ('query', 'mutation', 'subscription'))
);

COMMENT ON TABLE logs.api_requests IS 'Journal des requêtes API (GraphQL + REST)';
COMMENT ON COLUMN logs.api_requests.request_id IS 'ID unique de la requête (pour corrélation)';
COMMENT ON COLUMN logs.api_requests.is_graphql IS 'Si vrai, requête GraphQL';
COMMENT ON COLUMN logs.api_requests.graphql_operation_name IS 'Nom de l''opération GraphQL';
COMMENT ON COLUMN logs.api_requests.response_status IS 'Code de statut HTTP';
COMMENT ON COLUMN logs.api_requests.db_query_count IS 'Nombre de requêtes DB effectuées';
COMMENT ON COLUMN logs.api_requests.external_api_calls IS 'Nombre d''appels API externes';

-- Index
CREATE INDEX idx_api_requests_tenant ON logs.api_requests(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX idx_api_requests_user ON logs.api_requests(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_api_requests_request_id ON logs.api_requests(request_id);
CREATE INDEX idx_api_requests_path ON logs.api_requests(request_path);
CREATE INDEX idx_api_requests_method ON logs.api_requests(request_method);
CREATE INDEX idx_api_requests_status ON logs.api_requests(response_status);
CREATE INDEX idx_api_requests_graphql ON logs.api_requests(is_graphql, graphql_operation) WHERE is_graphql = TRUE;
CREATE INDEX idx_api_requests_duration ON logs.api_requests(duration_ms DESC) WHERE duration_ms IS NOT NULL;
CREATE INDEX idx_api_requests_started_at ON logs.api_requests(started_at DESC);
CREATE INDEX idx_api_requests_ip ON logs.api_requests(ip_address) WHERE ip_address IS NOT NULL;

-- ================================================================
-- TABLE: logs.api_errors
-- ================================================================
-- Description: Erreurs API détaillées (4xx, 5xx)
-- ================================================================

CREATE TABLE logs.api_errors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    request_id VARCHAR(100) NOT NULL REFERENCES logs.api_requests(request_id) ON DELETE CASCADE,
    tenant_id UUID REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES identity.users(id) ON DELETE SET NULL,
    
    -- Erreur
    error_code VARCHAR(50) NOT NULL,
    error_type VARCHAR(50) NOT NULL,  -- 'validation', 'authentication', 'authorization', 'not_found', 'internal', 'rate_limit', 'timeout'
    error_subtype VARCHAR(100),
    error_message TEXT NOT NULL,
    error_detail JSONB DEFAULT '{}'::jsonb,
    
    -- Stack trace (si disponible)
    stack_trace TEXT,
    stack_trace_hash VARCHAR(64),
    
    -- Contexte
    file_name VARCHAR(255),
    line_number INTEGER,
    function_name VARCHAR(255),
    
    -- Catégorie
    category VARCHAR(50) NOT NULL,  -- 'client', 'server', 'security', 'business'
    severity VARCHAR(20) NOT NULL,  -- 'low', 'medium', 'high', 'critical'
    
    -- Résolution
    is_resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    resolved_by UUID REFERENCES identity.users(id) ON DELETE SET NULL,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_api_errors_type CHECK (error_type IN ('validation', 'authentication', 'authorization', 'not_found', 'internal', 'rate_limit', 'timeout', 'bad_request', 'conflict', 'unprocessable')),
    CONSTRAINT ck_api_errors_category CHECK (category IN ('client', 'server', 'security', 'business')),
    CONSTRAINT ck_api_errors_severity CHECK (severity IN ('low', 'medium', 'high', 'critical'))
);

COMMENT ON TABLE logs.api_errors IS 'Erreurs API détaillées (4xx, 5xx)';
COMMENT ON COLUMN logs.api_errors.request_id IS 'Référence à la requête API associée';
COMMENT ON COLUMN logs.api_errors.error_type IS 'Type d''erreur (validation/authentication/authorization/not_found/internal/rate_limit/timeout)';
COMMENT ON COLUMN logs.api_errors.error_detail IS 'Détails supplémentaires de l''erreur';
COMMENT ON COLUMN logs.api_errors.category IS 'Catégorie d''erreur (client/server/security/business)';
COMMENT ON COLUMN logs.api_errors.severity IS 'Sévérité (low/medium/high/critical)';
COMMENT ON COLUMN logs.api_errors.is_resolved IS 'Indique si l''erreur a été résolue';

-- Index
CREATE INDEX idx_api_errors_request ON logs.api_errors(request_id);
CREATE INDEX idx_api_errors_tenant ON logs.api_errors(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX idx_api_errors_type ON logs.api_errors(error_type, logged_at DESC);
CREATE INDEX idx_api_errors_severity ON logs.api_errors(severity, logged_at DESC);
CREATE INDEX idx_api_errors_category ON logs.api_errors(category, logged_at DESC);
CREATE INDEX idx_api_errors_resolved ON logs.api_errors(is_resolved) WHERE is_resolved = FALSE;
CREATE INDEX idx_api_errors_logged_at ON logs.api_errors(logged_at DESC);

-- ================================================================
-- FONCTIONS UTILITAIRES POUR LES LOGS
-- ================================================================

-- Fonction pour créer un log d'application
CREATE OR REPLACE FUNCTION logs.log_application(
    p_level VARCHAR(20),
    p_source VARCHAR(100),
    p_source_type VARCHAR(50),
    p_message TEXT,
    p_tenant_id UUID DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_context JSONB DEFAULT '{}'::jsonb,
    p_error_code VARCHAR(50) DEFAULT NULL,
    p_stack TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO logs.application_logs (
        log_id,
        log_level,
        log_source,
        log_source_type,
        message,
        tenant_id,
        user_id,
        context,
        error_code,
        error_stack,
        logged_at
    ) VALUES (
        gen_random_uuid()::TEXT,
        p_level,
        p_source,
        p_source_type,
        p_message,
        p_tenant_id,
        p_user_id,
        p_context,
        p_error_code,
        p_stack,
        NOW()
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION logs.log_application IS 'Crée un log d''application standardisé';

-- Fonction pour créer un log API
CREATE OR REPLACE FUNCTION logs.log_api_request(
    p_request_method VARCHAR(10),
    p_request_path TEXT,
    p_response_status INTEGER,
    p_tenant_id UUID DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_session_id UUID DEFAULT NULL,
    p_api_key_id UUID DEFAULT NULL,
    p_is_graphql BOOLEAN DEFAULT FALSE,
    p_graphql_operation VARCHAR(50) DEFAULT NULL,
    p_graphql_operation_name VARCHAR(255) DEFAULT NULL,
    p_duration_ms INTEGER DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_request_id VARCHAR(100);
    v_log_id UUID;
BEGIN
    v_request_id := gen_random_uuid()::TEXT;
    
    INSERT INTO logs.api_requests (
        request_id,
        request_method,
        request_path,
        response_status,
        tenant_id,
        user_id,
        session_id,
        api_key_id,
        is_graphql,
        graphql_operation,
        graphql_operation_name,
        duration_ms,
        ip_address,
        user_agent,
        metadata,
        started_at,
        completed_at,
        logged_at
    ) VALUES (
        v_request_id,
        p_request_method,
        p_request_path,
        p_response_status,
        p_tenant_id,
        p_user_id,
        p_session_id,
        p_api_key_id,
        p_is_graphql,
        p_graphql_operation,
        p_graphql_operation_name,
        p_duration_ms,
        p_ip_address,
        p_user_agent,
        p_metadata,
        NOW() - (COALESCE(p_duration_ms, 0) || ' milliseconds')::INTERVAL,
        NOW(),
        NOW()
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION logs.log_api_request IS 'Crée un log de requête API';

-- Fonction pour créer un log d'erreur API
CREATE OR REPLACE FUNCTION logs.log_api_error(
    p_request_id VARCHAR(100),
    p_error_code VARCHAR(50),
    p_error_type VARCHAR(50),
    p_error_message TEXT,
    p_severity VARCHAR(20),
    p_category VARCHAR(50),
    p_tenant_id UUID DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_error_detail JSONB DEFAULT '{}'::jsonb,
    p_stack TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO logs.api_errors (
        request_id,
        error_code,
        error_type,
        error_message,
        severity,
        category,
        tenant_id,
        user_id,
        error_detail,
        stack_trace,
        logged_at
    ) VALUES (
        p_request_id,
        p_error_code,
        p_error_type,
        p_error_message,
        p_severity,
        p_category,
        p_tenant_id,
        p_user_id,
        p_error_detail,
        p_stack,
        NOW()
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION logs.log_api_error IS 'Crée un log d''erreur API détaillé';

-- Trigger pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION logs.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer le trigger
CREATE TRIGGER tr_api_errors_update BEFORE UPDATE ON logs.api_errors
    FOR EACH ROW EXECUTE FUNCTION logs.update_updated_at_column();

-- ================================================================
-- VUES UTILITAIRES POUR LES LOGS
-- ================================================================

-- Vue des erreurs récentes
CREATE OR REPLACE VIEW logs.v_recent_errors AS
SELECT 
    al.logged_at,
    al.log_level,
    al.log_source,
    al.message,
    al.error_code,
    al.tenant_id,
    al.user_id,
    u.email AS user_email,
    u.username AS user_name
FROM logs.application_logs al
LEFT JOIN identity.users u ON al.user_id = u.id
WHERE al.log_level IN ('error', 'fatal')
    AND al.logged_at >= NOW() - INTERVAL '24 hours'
ORDER BY al.logged_at DESC
LIMIT 100;

COMMENT ON VIEW logs.v_recent_errors IS 'Erreurs des dernières 24 heures';

-- Vue des statistiques API
CREATE OR REPLACE VIEW logs.v_api_stats AS
SELECT 
    DATE_TRUNC('hour', started_at) AS hour_bucket,
    request_path,
    request_method,
    response_status,
    COUNT(*) AS request_count,
    AVG(duration_ms) AS avg_duration_ms,
    MAX(duration_ms) AS max_duration_ms,
    MIN(duration_ms) AS min_duration_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) AS p95_duration_ms
FROM logs.api_requests
WHERE started_at >= NOW() - INTERVAL '24 hours'
GROUP BY hour_bucket, request_path, request_method, response_status
ORDER BY hour_bucket DESC, request_count DESC;

COMMENT ON VIEW logs.v_api_stats IS 'Statistiques horaires des requêtes API';

-- Vue des erreurs API par catégorie
CREATE OR REPLACE VIEW logs.v_error_summary AS
SELECT 
    DATE_TRUNC('hour', logged_at) AS hour_bucket,
    error_type,
    category,
    severity,
    COUNT(*) AS error_count,
    COUNT(DISTINCT user_id) AS affected_users,
    COUNT(DISTINCT request_id) AS affected_requests
FROM logs.api_errors
WHERE logged_at >= NOW() - INTERVAL '24 hours'
GROUP BY hour_bucket, error_type, category, severity
ORDER BY hour_bucket DESC, error_count DESC;

COMMENT ON VIEW logs.v_error_summary IS 'Résumé des erreurs API par catégorie et sévérité';

-- ================================================================
-- RÉSUMÉ DU SCHÉMA LOGS
-- ================================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│                    SCHÉMA LOGS - RÉSUMÉ                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  application_logs    │ Logs généraux de l'application          │
│  fleet_logs          │ Logs Fleet Command (orchestration)      │
│  worker_logs         │ Logs des workers (MERCURE/LEGION)       │
│  api_requests        │ Requêtes API (GraphQL + REST)           │
│  api_errors          │ Erreurs API détaillées (4xx/5xx)        │
│                                                                   │
│  Partitionnement :    │ Application_logs (mensuel)             │
│  Compression :        │ TimescaleDB (si activé)                │
│  Rétention :          │ 30 jours (configurable)                │
│                                                                   │
│  Vues utiles :                                                  │
│  • v_recent_errors   │ Erreurs des dernières 24h              │
│  • v_api_stats       │ Statistiques API horaires              │
│  • v_error_summary   │ Résumé des erreurs par catégorie       │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
*/

-- ================================================================
-- VERIFICATION
-- ================================================================

DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'logs'
    AND table_type = 'BASE TABLE';
    
    IF table_count = 5 THEN
        RAISE NOTICE '✅ Toutes les tables du schéma logs ont été créées (5/5)';
        RAISE NOTICE '📊 Logs application: %', (SELECT COUNT(*) FROM logs.application_logs);
        RAISE NOTICE '📊 Requêtes API: %', (SELECT COUNT(*) FROM logs.api_requests);
        RAISE NOTICE '📊 Erreurs API: %', (SELECT COUNT(*) FROM logs.api_errors);
    ELSE
        RAISE NOTICE '⚠️ % tables sur 5 créées dans le schéma logs', table_count;
    END IF;
END;
$$;