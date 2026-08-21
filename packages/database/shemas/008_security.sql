-- ================================================================
-- CORMERY - Schéma Security (Sécurité et Audit)
-- Version: 1.0.0
-- Date: 2026-08-07
-- Description: Tables de sécurité, authentification,
--              audit et conformité (RGPD)
-- ================================================================

-- ================================================================
-- TABLE: security.sessions
-- ================================================================
-- Description: Sessions utilisateur actives et historiques
-- ================================================================

CREATE TABLE security.sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Identifiants de session
    session_token_hash VARCHAR(255) NOT NULL UNIQUE,
    refresh_token_hash VARCHAR(255) UNIQUE,
    
    -- Métadonnées de connexion
    ip_address INET NOT NULL,
    user_agent TEXT NOT NULL,
    device_id VARCHAR(255),
    location_city VARCHAR(100),
    location_country VARCHAR(2),
    location_latitude DECIMAL(10,8),
    location_longitude DECIMAL(11,8),
    
    -- Authentification
    auth_method VARCHAR(50) DEFAULT 'password',  -- 'password', 'google', 'github', 'sso', '2fa'
    auth_provider VARCHAR(100),
    auth_provider_id VARCHAR(255),
    
    -- 2FA
    two_factor_verified BOOLEAN DEFAULT FALSE,
    two_factor_method VARCHAR(50),  -- 'totp', 'sms', 'email', 'backup_code'
    two_factor_verified_at TIMESTAMPTZ,
    
    -- Statut
    is_active BOOLEAN DEFAULT TRUE,
    is_revoked BOOLEAN DEFAULT FALSE,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT,
    revoked_by UUID REFERENCES identity.users(id) ON DELETE SET NULL,
    
    -- Durée de vie
    expires_at TIMESTAMPTZ NOT NULL,
    refresh_expires_at TIMESTAMPTZ,
    last_activity_at TIMESTAMPTZ DEFAULT NOW(),
    last_activity_ip INET,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_sessions_expiry CHECK (expires_at > created_at),
    CONSTRAINT ck_sessions_refresh_expiry CHECK (refresh_expires_at IS NULL OR refresh_expires_at > created_at),
    CONSTRAINT ck_sessions_auth_method CHECK (auth_method IN ('password', 'google', 'github', 'sso', '2fa', 'api_key', 'biometric'))
);

COMMENT ON TABLE security.sessions IS 'Sessions utilisateur actives et historiques';
COMMENT ON COLUMN security.sessions.session_token_hash IS 'Hash du token de session (JWT ou opaque)';
COMMENT ON COLUMN security.sessions.refresh_token_hash IS 'Hash du refresh token';
COMMENT ON COLUMN security.sessions.auth_method IS 'Méthode d''authentification utilisée';
COMMENT ON COLUMN security.sessions.two_factor_verified IS 'Indique si la 2FA a été validée';
COMMENT ON COLUMN security.sessions.is_revoked IS 'Session révoquée (manuellement ou par sécurité)';
COMMENT ON COLUMN security.sessions.revoked_reason IS 'Raison de la révocation (expired/security/logout)';

-- Index
CREATE INDEX idx_sessions_user ON security.sessions(user_id);
CREATE INDEX idx_sessions_tenant ON security.sessions(tenant_id);
CREATE INDEX idx_sessions_token ON security.sessions(session_token_hash);
CREATE INDEX idx_sessions_refresh ON security.sessions(refresh_token_hash) WHERE refresh_token_hash IS NOT NULL;
CREATE INDEX idx_sessions_active ON security.sessions(user_id, is_active) WHERE is_active = TRUE AND is_revoked = FALSE;
CREATE INDEX idx_sessions_expires ON security.sessions(expires_at) WHERE is_active = TRUE AND is_revoked = FALSE;
CREATE INDEX idx_sessions_ip ON security.sessions(ip_address);
CREATE INDEX idx_sessions_device ON security.sessions(device_id) WHERE device_id IS NOT NULL;
CREATE INDEX idx_sessions_created ON security.sessions(created_at DESC);

-- ================================================================
-- TABLE: security.devices
-- ================================================================
-- Description: Appareils enregistrés des utilisateurs
-- ================================================================

CREATE TABLE security.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Identifiants
    device_id VARCHAR(255) NOT NULL UNIQUE,
    device_name VARCHAR(255),
    device_type VARCHAR(50),  -- 'desktop', 'mobile', 'tablet', 'server'
    device_os VARCHAR(100),
    device_os_version VARCHAR(50),
    device_browser VARCHAR(100),
    device_browser_version VARCHAR(50),
    
    -- Empreinte
    fingerprint_hash VARCHAR(255),  -- Hash de l'empreinte matérielle
    screen_resolution VARCHAR(50),
    timezone VARCHAR(100),
    language VARCHAR(10),
    
    -- Sécurité
    is_trusted BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    last_used_at TIMESTAMPTZ,
    first_seen_at TIMESTAMPTZ,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT uk_devices_user_device UNIQUE (user_id, device_id)
);

COMMENT ON TABLE security.devices IS 'Appareils enregistrés des utilisateurs pour l''authentification';
COMMENT ON COLUMN security.devices.device_type IS 'Type d''appareil (desktop/mobile/tablet/server)';
COMMENT ON COLUMN security.devices.fingerprint_hash IS 'Hash de l''empreinte matérielle pour identification';
COMMENT ON COLUMN security.devices.is_trusted IS 'Appareil de confiance (réduit les vérifications)';

-- Index
CREATE INDEX idx_devices_user ON security.devices(user_id);
CREATE INDEX idx_devices_tenant ON security.devices(tenant_id);
CREATE INDEX idx_devices_device_id ON security.devices(device_id);
CREATE INDEX idx_devices_trusted ON security.devices(user_id, is_trusted) WHERE is_trusted = TRUE;
CREATE INDEX idx_devices_active ON security.devices(user_id, is_active) WHERE is_active = TRUE;
CREATE INDEX idx_devices_fingerprint ON security.devices(fingerprint_hash) WHERE fingerprint_hash IS NOT NULL;

-- ================================================================
-- TABLE: security.tokens
-- ================================================================
-- Description: Tokens d'authentification (JWT, API, etc.)
-- ================================================================

CREATE TABLE security.tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    session_id UUID REFERENCES security.sessions(id) ON DELETE SET NULL,
    
    -- Token
    token_type VARCHAR(50) NOT NULL,  -- 'access', 'refresh', 'api', 'reset', 'verify', 'invite'
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    token_jti VARCHAR(255),  -- JWT ID (pour JWT)
    
    -- Métadonnées
    scopes JSONB DEFAULT '[]'::jsonb,  -- Scopes d'accès
    permissions JSONB DEFAULT '[]'::jsonb,  -- Permissions spécifiques
    
    -- Statut
    is_revoked BOOLEAN DEFAULT FALSE,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT,
    
    -- Durée de vie
    issued_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    use_count INTEGER DEFAULT 0,
    max_uses INTEGER,
    
    -- Contexte
    ip_address INET,
    user_agent TEXT,
    device_id VARCHAR(255),
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_tokens_type CHECK (token_type IN ('access', 'refresh', 'api', 'reset', 'verify', 'invite', 'magic_link', 'sso')),
    CONSTRAINT ck_tokens_expiry CHECK (expires_at > issued_at),
    CONSTRAINT ck_tokens_max_uses CHECK (max_uses IS NULL OR max_uses > 0)
);

COMMENT ON TABLE security.tokens IS 'Tokens d''authentification (JWT, API, etc.)';
COMMENT ON COLUMN security.tokens.token_type IS 'Type de token (access/refresh/api/reset/verify/invite/magic_link/sso)';
COMMENT ON COLUMN security.tokens.token_hash IS 'Hash du token';
COMMENT ON COLUMN security.tokens.token_jti IS 'JWT ID (pour JWT tokens)';
COMMENT ON COLUMN security.tokens.scopes IS 'Scopes d''accès du token';
COMMENT ON COLUMN security.tokens.permissions IS 'Permissions spécifiques du token';
COMMENT ON COLUMN security.tokens.max_uses IS 'Nombre maximum d''utilisations (token à usage unique)';

-- Index
CREATE INDEX idx_tokens_user ON security.tokens(user_id);
CREATE INDEX idx_tokens_tenant ON security.tokens(tenant_id);
CREATE INDEX idx_tokens_session ON security.tokens(session_id) WHERE session_id IS NOT NULL;
CREATE INDEX idx_tokens_hash ON security.tokens(token_hash);
CREATE INDEX idx_tokens_type ON security.tokens(token_type);
CREATE INDEX idx_tokens_active ON security.tokens(user_id, token_type) 
    WHERE is_revoked = FALSE AND expires_at > NOW();
CREATE INDEX idx_tokens_expires ON security.tokens(expires_at) WHERE is_revoked = FALSE;
CREATE INDEX idx_tokens_jti ON security.tokens(token_jti) WHERE token_jti IS NOT NULL;

-- ================================================================
-- TABLE: security.login_history
-- ================================================================
-- Description: Historique complet des tentatives de connexion
-- ================================================================

CREATE TABLE security.login_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    user_id UUID REFERENCES identity.users(id) ON DELETE CASCADE,
    tenant_id UUID REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    session_id UUID REFERENCES security.sessions(id) ON DELETE SET NULL,
    
    -- Connexion
    username VARCHAR(255),
    email VARCHAR(255),
    ip_address INET NOT NULL,
    user_agent TEXT NOT NULL,
    
    -- Localisation
    location_city VARCHAR(100),
    location_country VARCHAR(2),
    location_region VARCHAR(100),
    location_latitude DECIMAL(10,8),
    location_longitude DECIMAL(11,8),
    timezone VARCHAR(100),
    
    -- Résultat
    login_result VARCHAR(50) NOT NULL,  -- 'success', 'failed', 'blocked', 'requires_2fa', '2fa_success', '2fa_failed'
    failure_reason VARCHAR(255),
    failure_code VARCHAR(50),  -- 'invalid_password', 'user_not_found', 'account_locked', 'rate_limited'
    
    -- Authentification
    auth_method VARCHAR(50),
    auth_provider VARCHAR(100),
    auth_provider_id VARCHAR(255),
    
    -- 2FA
    two_factor_required BOOLEAN DEFAULT FALSE,
    two_factor_method VARCHAR(50),  -- 'totp', 'sms', 'email', 'backup_code'
    two_factor_success BOOLEAN,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    attempted_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_login_history_result CHECK (login_result IN ('success', 'failed', 'blocked', 'requires_2fa', '2fa_success', '2fa_failed', 'timeout', 'error')),
    CONSTRAINT ck_login_history_2fa_method CHECK (two_factor_method IS NULL OR two_factor_method IN ('totp', 'sms', 'email', 'backup_code', 'push'))
);

COMMENT ON TABLE security.login_history IS 'Historique complet des tentatives de connexion';
COMMENT ON COLUMN security.login_history.login_result IS 'Résultat de la tentative de connexion';
COMMENT ON COLUMN security.login_history.failure_reason IS 'Raison de l''échec (si applicable)';
COMMENT ON COLUMN security.login_history.failure_code IS 'Code d''erreur standardisé';
COMMENT ON COLUMN security.login_history.two_factor_required IS 'Indique si la 2FA était requise';
COMMENT ON COLUMN security.login_history.two_factor_success IS 'Succès de la vérification 2FA';

-- Index
CREATE INDEX idx_login_history_user ON security.login_history(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_login_history_tenant ON security.login_history(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX idx_login_history_ip ON security.login_history(ip_address);
CREATE INDEX idx_login_history_result ON security.login_history(login_result);
CREATE INDEX idx_login_history_attempted ON security.login_history(attempted_at DESC);
CREATE INDEX idx_login_history_email ON security.login_history(email) WHERE email IS NOT NULL;
CREATE INDEX idx_login_history_failures ON security.login_history(user_id, attempted_at) 
    WHERE login_result = 'failed';
CREATE INDEX idx_login_history_country ON security.login_history(location_country) 
    WHERE location_country IS NOT NULL;

-- ================================================================
-- TABLE: security.audit_logs
-- ================================================================
-- Description: Journal d'audit complet (conformité RGPD, SOC2)
-- ================================================================

CREATE TABLE security.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES identity.users(id) ON DELETE SET NULL,
    session_id UUID REFERENCES security.sessions(id) ON DELETE SET NULL,
    
    -- Action
    action_type VARCHAR(100) NOT NULL,
    action_category VARCHAR(50) NOT NULL,  -- 'auth', 'user', 'product', 'arbitrage', 'system', 'security', 'data'
    resource_type VARCHAR(100) NOT NULL,
    resource_id UUID,
    resource_name VARCHAR(255),
    
    -- Détails
    details JSONB DEFAULT '{}'::jsonb,
    old_value JSONB,
    new_value JSONB,
    changes JSONB DEFAULT '{}'::jsonb,  -- Diff structurée des changements
    
    -- Contexte
    ip_address INET,
    user_agent TEXT,
    device_id VARCHAR(255),
    location_city VARCHAR(100),
    location_country VARCHAR(2),
    correlation_id VARCHAR(255),
    
    -- Résultat
    success BOOLEAN DEFAULT TRUE,
    error_code VARCHAR(50),
    error_message TEXT,
    http_method VARCHAR(10),
    http_status INTEGER,
    endpoint_path TEXT,
    response_time_ms INTEGER,
    payload_size_bytes INTEGER,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    event_time TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_audit_logs_category CHECK (action_category IN ('auth', 'user', 'product', 'arbitrage', 'system', 'security', 'data', 'admin', 'billing')),
    CONSTRAINT ck_audit_logs_http_status CHECK (http_status IS NULL OR (http_status >= 100 AND http_status <= 599))
);

COMMENT ON TABLE security.audit_logs IS 'Journal d''audit complet (conformité RGPD, SOC2)';
COMMENT ON COLUMN security.audit_logs.action_type IS 'Type d''action (login, create_product, etc.)';
COMMENT ON COLUMN security.audit_logs.action_category IS 'Catégorie d''action (auth/user/product/arbitrage/system/security/data/admin/billing)';
COMMENT ON COLUMN security.audit_logs.resource_type IS 'Type de ressource (tenant/user/product/arbitrage)';
COMMENT ON COLUMN security.audit_logs.old_value IS 'Ancienne valeur (avant modification)';
COMMENT ON COLUMN security.audit_logs.new_value IS 'Nouvelle valeur (après modification)';
COMMENT ON COLUMN security.audit_logs.changes IS 'Diff structurée des changements';
COMMENT ON COLUMN security.audit_logs.correlation_id IS 'ID de corrélation pour les appels distribués';
COMMENT ON COLUMN security.audit_logs.response_time_ms IS 'Temps de réponse en millisecondes';

-- Index
CREATE INDEX idx_audit_logs_tenant ON security.audit_logs(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX idx_audit_logs_user ON security.audit_logs(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_audit_logs_resource ON security.audit_logs(resource_type, resource_id) 
    WHERE resource_id IS NOT NULL;
CREATE INDEX idx_audit_logs_category ON security.audit_logs(action_category, event_time DESC);
CREATE INDEX idx_audit_logs_action ON security.audit_logs(action_type, event_time DESC);
CREATE INDEX idx_audit_logs_correlation ON security.audit_logs(correlation_id) 
    WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_audit_logs_ip ON security.audit_logs(ip_address);
CREATE INDEX idx_audit_logs_success ON security.audit_logs(success) WHERE success = FALSE;
CREATE INDEX idx_audit_logs_event_time ON security.audit_logs(event_time DESC);
CREATE INDEX idx_audit_logs_http_path ON security.audit_logs(endpoint_path) 
    WHERE endpoint_path IS NOT NULL;

-- Partitionnement des logs d'audit (mensuel)
CREATE TABLE security.audit_logs_2026_08 PARTITION OF security.audit_logs
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

-- Fonction de création automatique des partitions
CREATE OR REPLACE FUNCTION security.create_audit_partitions()
RETURNS VOID AS $$
DECLARE
    month_date DATE;
    partition_name TEXT;
BEGIN
    FOR month_date IN 
        SELECT generate_series(
            DATE_TRUNC('month', NOW()),
            DATE_TRUNC('month', NOW() + INTERVAL '3 months'),
            INTERVAL '1 month'
        )
    LOOP
        partition_name := 'audit_logs_' || TO_CHAR(month_date, 'YYYY_MM');
        
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I PARTITION OF security.audit_logs
            FOR VALUES FROM (%L) TO (%L)
        ', partition_name, month_date, month_date + INTERVAL '1 month');
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- TABLE: security.password_reset_tokens
-- ================================================================
-- Description: Tokens de réinitialisation de mot de passe
-- ================================================================

CREATE TABLE security.password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Token
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    
    -- Contexte
    ip_address INET,
    user_agent TEXT,
    
    -- Statut
    is_used BOOLEAN DEFAULT FALSE,
    used_at TIMESTAMPTZ,
    
    -- Durée de vie
    expires_at TIMESTAMPTZ NOT NULL,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_password_reset_expiry CHECK (expires_at > created_at)
);

COMMENT ON TABLE security.password_reset_tokens IS 'Tokens de réinitialisation de mot de passe';
COMMENT ON COLUMN security.password_reset_tokens.token_hash IS 'Hash du token de réinitialisation';
COMMENT ON COLUMN security.password_reset_tokens.is_used IS 'Indique si le token a été utilisé';
COMMENT ON COLUMN security.password_reset_tokens.expires_at IS 'Date d''expiration du token';

-- Index
CREATE INDEX idx_password_reset_user ON security.password_reset_tokens(user_id);
CREATE INDEX idx_password_reset_tenant ON security.password_reset_tokens(tenant_id);
CREATE INDEX idx_password_reset_token ON security.password_reset_tokens(token_hash);
CREATE INDEX idx_password_reset_unused ON security.password_reset_tokens(user_id) 
    WHERE is_used = FALSE AND expires_at > NOW();

-- ================================================================
-- TABLE: security.api_rate_limits
-- ================================================================
-- Description: Limites de taux d'API par tenant/utilisateur/clé
-- ================================================================

CREATE TABLE security.api_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES identity.users(id) ON DELETE CASCADE,
    api_key_id UUID REFERENCES identity.api_keys(id) ON DELETE CASCADE,
    
    -- Identifiants
    identifier VARCHAR(255) NOT NULL,  -- Clé composée pour la recherche
    endpoint VARCHAR(255),
    method VARCHAR(10),
    
    -- Limites
    limit_per_minute INTEGER DEFAULT 60,
    limit_per_hour INTEGER DEFAULT 1000,
    limit_per_day INTEGER DEFAULT 10000,
    
    -- Utilisation actuelle
    current_usage_minute INTEGER DEFAULT 0,
    current_usage_hour INTEGER DEFAULT 0,
    current_usage_day INTEGER DEFAULT 0,
    
    -- Réinitialisation
    reset_at_minute TIMESTAMPTZ,
    reset_at_hour TIMESTAMPTZ,
    reset_at_day TIMESTAMPTZ,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_rate_limits CHECK (
        limit_per_minute >= 0 AND 
        limit_per_hour >= limit_per_minute AND 
        limit_per_day >= limit_per_hour
    )
);

COMMENT ON TABLE security.api_rate_limits IS 'Limites de taux d''API par tenant/utilisateur/clé';
COMMENT ON COLUMN security.api_rate_limits.limit_per_minute IS 'Limite de requêtes par minute';
COMMENT ON COLUMN security.api_rate_limits.limit_per_hour IS 'Limite de requêtes par heure';
COMMENT ON COLUMN security.api_rate_limits.limit_per_day IS 'Limite de requêtes par jour';

-- Index
CREATE INDEX idx_rate_limits_identifier ON security.api_rate_limits(identifier);
CREATE INDEX idx_rate_limits_tenant ON security.api_rate_limits(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX idx_rate_limits_user ON security.api_rate_limits(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_rate_limits_api_key ON security.api_rate_limits(api_key_id) WHERE api_key_id IS NOT NULL;

-- ================================================================
-- TABLE: security.encryption_keys
-- ================================================================
-- Description: Clés de chiffrement pour les données sensibles
-- ================================================================

CREATE TABLE security.encryption_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    key_id VARCHAR(100) NOT NULL UNIQUE,
    key_type VARCHAR(50) NOT NULL,  -- 'master', 'data', 'field', 'token'
    key_version INTEGER DEFAULT 1,
    
    -- Clé (encryptée)
    encrypted_key TEXT NOT NULL,
    key_wrapping_algorithm VARCHAR(50) DEFAULT 'aes-256-gcm',
    key_encryption_algorithm VARCHAR(50) DEFAULT 'aes-256-gcm',
    
    -- Métadonnées
    key_usage VARCHAR(255),  -- Description de l'utilisation
    key_rotation_scheduled BOOLEAN DEFAULT FALSE,
    previous_key_id UUID REFERENCES security.encryption_keys(id) ON DELETE SET NULL,
    
    -- Statut
    is_active BOOLEAN DEFAULT TRUE,
    is_compromised BOOLEAN DEFAULT FALSE,
    compromised_at TIMESTAMPTZ,
    
    -- Durée de vie
    valid_from TIMESTAMPTZ DEFAULT NOW(),
    valid_until TIMESTAMPTZ,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_encryption_keys_type CHECK (key_type IN ('master', 'data', 'field', 'token', 'signing')),
    CONSTRAINT ck_encryption_keys_valid CHECK (valid_until IS NULL OR valid_until > valid_from)
);

COMMENT ON TABLE security.encryption_keys IS 'Clés de chiffrement pour les données sensibles';
COMMENT ON COLUMN security.encryption_keys.key_type IS 'Type de clé (master/data/field/token/signing)';
COMMENT ON COLUMN security.encryption_keys.encrypted_key IS 'Clé encryptée (stockage sécurisé)';
COMMENT ON COLUMN security.encryption_keys.key_rotation_scheduled IS 'Rotation planifiée de la clé';
COMMENT ON COLUMN security.encryption_keys.is_compromised IS 'Clé compromise (ne plus utiliser)';

-- Index
CREATE INDEX idx_encryption_keys_id ON security.encryption_keys(key_id);
CREATE INDEX idx_encryption_keys_type ON security.encryption_keys(key_type);
CREATE INDEX idx_encryption_keys_active ON security.encryption_keys(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_encryption_keys_valid ON security.encryption_keys(valid_until) WHERE valid_until IS NOT NULL;

-- ================================================================
-- TABLE: security.data_masking_rules
-- ================================================================
-- Description: Règles de masquage des données (RGPD)
-- ================================================================

CREATE TABLE security.data_masking_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identification
    rule_name VARCHAR(255) NOT NULL UNIQUE,
    table_name VARCHAR(255) NOT NULL,
    column_name VARCHAR(255) NOT NULL,
    
    -- Masquage
    masking_type VARCHAR(50) NOT NULL,  -- 'redact', 'partial', 'hash', 'encrypt', 'nullify'
    masking_pattern VARCHAR(255),  -- Pattern de masquage (ex: '***', 'XXXX-****')
    masking_function VARCHAR(255),  -- Fonction de masquage personnalisée
    
    -- Conditions
    applies_to_roles JSONB DEFAULT '[]'::jsonb,
    applies_to_tenant_types JSONB DEFAULT '[]'::jsonb,
    applies_to_data_types JSONB DEFAULT '[]'::jsonb,  -- 'pii', 'financial', 'health'
    
    -- Statut
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_masking_type CHECK (masking_type IN ('redact', 'partial', 'hash', 'encrypt', 'nullify', 'pseudonymize', 'mask'))
);

COMMENT ON TABLE security.data_masking_rules IS 'Règles de masquage des données (RGPD)';
COMMENT ON COLUMN security.data_masking_rules.masking_type IS 'Type de masquage (redact/partial/hash/encrypt/nullify/pseudonymize/mask)';
COMMENT ON COLUMN security.data_masking_rules.applies_to_roles IS 'Rôles auxquels le masquage s''applique';
COMMENT ON COLUMN security.data_masking_rules.applies_to_data_types IS 'Types de données sensibles (pii/financial/health)';

-- Index
CREATE INDEX idx_masking_rules_table ON security.data_masking_rules(table_name, column_name);
CREATE INDEX idx_masking_rules_active ON security.data_masking_rules(is_active) WHERE is_active = TRUE;

-- ================================================================
-- FONCTIONS UTILITAIRES POUR LA SÉCURITÉ
-- ================================================================

-- Fonction pour journaliser les événements d'audit
CREATE OR REPLACE FUNCTION security.log_audit_event(
    p_tenant_id UUID,
    p_user_id UUID,
    p_action_type VARCHAR(100),
    p_action_category VARCHAR(50),
    p_resource_type VARCHAR(100),
    p_resource_id UUID DEFAULT NULL,
    p_details JSONB DEFAULT '{}'::jsonb,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_success BOOLEAN DEFAULT TRUE
)
RETURNS UUID AS $$
DECLARE
    v_event_id UUID;
BEGIN
    INSERT INTO security.audit_logs (
        tenant_id,
        user_id,
        action_type,
        action_category,
        resource_type,
        resource_id,
        details,
        ip_address,
        user_agent,
        success,
        event_time
    ) VALUES (
        p_tenant_id,
        p_user_id,
        p_action_type,
        p_action_category,
        p_resource_type,
        p_resource_id,
        p_details,
        p_ip_address,
        p_user_agent,
        p_success,
        NOW()
    ) RETURNING id INTO v_event_id;
    
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION security.log_audit_event IS 'Journalise un événement d''audit';

-- Fonction pour vérifier les limites de taux
CREATE OR REPLACE FUNCTION security.check_rate_limit(
    p_identifier VARCHAR(255),
    p_limit_per_minute INTEGER DEFAULT 60
)
RETURNS BOOLEAN AS $$
DECLARE
    current_usage INTEGER;
BEGIN
    -- Récupérer ou créer le compteur
    INSERT INTO security.api_rate_limits (identifier, limit_per_minute, reset_at_minute)
    VALUES (p_identifier, p_limit_per_minute, NOW())
    ON CONFLICT (identifier) DO UPDATE
    SET 
        current_usage_minute = CASE 
            WHEN api_rate_limits.reset_at_minute < NOW() - INTERVAL '1 minute' THEN 0
            ELSE api_rate_limits.current_usage_minute + 1
        END,
        reset_at_minute = CASE 
            WHEN api_rate_limits.reset_at_minute < NOW() - INTERVAL '1 minute' THEN NOW()
            ELSE api_rate_limits.reset_at_minute
        END,
        updated_at = NOW()
    WHERE api_rate_limits.identifier = p_identifier
    RETURNING current_usage_minute INTO current_usage;
    
    RETURN current_usage <= p_limit_per_minute;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION security.check_rate_limit IS 'Vérifie si une requête respecte les limites de taux';

-- Fonction pour révoquer toutes les sessions d'un utilisateur
CREATE OR REPLACE FUNCTION security.revoke_user_sessions(
    p_user_id UUID,
    p_reason TEXT DEFAULT 'security',
    p_except_session_id UUID DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    revoked_count INTEGER;
BEGIN
    UPDATE security.sessions
    SET 
        is_revoked = TRUE,
        revoked_at = NOW(),
        revoked_reason = p_reason
    WHERE user_id = p_user_id
        AND is_active = TRUE
        AND is_revoked = FALSE
        AND (p_except_session_id IS NULL OR id != p_except_session_id)
    RETURNING COUNT(*) INTO revoked_count;
    
    RETURN revoked_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION security.revoke_user_sessions IS 'Révoque toutes les sessions d''un utilisateur (sauf une éventuelle)';

-- Fonction pour détecter les tentatives de connexion suspectes
CREATE OR REPLACE FUNCTION security.detect_suspicious_login(
    p_user_id UUID,
    p_ip_address INET,
    p_user_agent TEXT,
    p_max_failures INTEGER DEFAULT 5,
    p_time_window_minutes INTEGER DEFAULT 15
)
RETURNS BOOLEAN AS $$
DECLARE
    recent_failures INTEGER;
    known_ip BOOLEAN;
BEGIN
    -- Compter les échecs récents
    SELECT COUNT(*) INTO recent_failures
    FROM security.login_history
    WHERE user_id = p_user_id
        AND login_result = 'failed'
        AND attempted_at > NOW() - (p_time_window_minutes || ' minutes')::INTERVAL;
    
    -- Vérifier si l'IP est connue pour cet utilisateur
    SELECT EXISTS (
        SELECT 1
        FROM security.login_history
        WHERE user_id = p_user_id
            AND ip_address = p_ip_address
            AND login_result = 'success'
            AND attempted_at > NOW() - INTERVAL '30 days'
    ) INTO known_ip;
    
    -- Une IP inconnue + plusieurs échecs = suspect
    IF NOT known_ip AND recent_failures >= p_max_failures THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION security.detect_suspicious_login IS 'Détecte les tentatives de connexion suspectes';

-- Trigger pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION security.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer le trigger
CREATE TRIGGER tr_sessions_update BEFORE UPDATE ON security.sessions
    FOR EACH ROW EXECUTE FUNCTION security.update_updated_at_column();

CREATE TRIGGER tr_devices_update BEFORE UPDATE ON security.devices
    FOR EACH ROW EXECUTE FUNCTION security.update_updated_at_column();

CREATE TRIGGER tr_tokens_update BEFORE UPDATE ON security.tokens
    FOR EACH ROW EXECUTE FUNCTION security.update_updated_at_column();

CREATE TRIGGER tr_encryption_keys_update BEFORE UPDATE ON security.encryption_keys
    FOR EACH ROW EXECUTE FUNCTION security.update_updated_at_column();

-- ================================================================
-- VUES UTILITAIRES POUR LA SÉCURITÉ
-- ================================================================

-- Vue des sessions actives
CREATE OR REPLACE VIEW security.v_active_sessions AS
SELECT 
    s.id,
    s.user_id,
    u.email AS user_email,
    u.username,
    s.tenant_id,
    t.name AS tenant_name,
    s.ip_address,
    s.user_agent,
    s.device_id,
    s.auth_method,
    s.two_factor_verified,
    s.last_activity_at,
    s.expires_at,
    EXTRACT(EPOCH FROM (s.expires_at - NOW())) / 3600 AS hours_remaining
FROM security.sessions s
JOIN identity.users u ON s.user_id = u.id
JOIN tenant.tenants t ON s.tenant_id = t.id
WHERE s.is_active = TRUE
    AND s.is_revoked = FALSE
    AND s.expires_at > NOW()
ORDER BY s.last_activity_at