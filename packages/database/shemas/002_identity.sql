-- ================================================================
-- CORMERY - Schéma Identity (Identité et Authentification)
-- Version: 1.0.0
-- Date: 2026-08-07
-- Description: Tables d'identité, authentification et autorisation
-- ================================================================

-- ================================================================
-- TABLE: tenant.plans
-- ================================================================
-- Description: Plans d'abonnement disponibles pour les tenants
--              (gère les paliers SaaS)
-- ================================================================

CREATE TABLE tenant.plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiant public (slug)
    slug VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Caractéristiques du plan
    product_limit INTEGER NOT NULL DEFAULT 1000,        -- -1 = illimité
    refresh_rate_min_seconds INTEGER NOT NULL DEFAULT 3600, -- 1 heure
    arbitration_priority INTEGER NOT NULL DEFAULT 3,     -- 1 = plus haute, 5 = plus basse
    legion_contributor_reduction INTEGER DEFAULT 0,      -- Réduction % pour contributeurs LEGION
    
    -- Features incluses
    features JSONB NOT NULL DEFAULT jsonb_build_object(
        'venus_enriched', false,
        'oracle_predictions', false,
        'legion_compute', false,
        'api_access', true,
        'web_dashboard', true,
        'historical_data_days', 30
    ),
    
    -- Tarification (en cents)
    price_monthly_cents INTEGER,
    price_yearly_cents INTEGER,
    
    -- Métadonnées
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    display_order INTEGER DEFAULT 0,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_plans_product_limit CHECK (product_limit >= -1),
    CONSTRAINT ck_plans_refresh_rate CHECK (refresh_rate_min_seconds >= 60),
    CONSTRAINT ck_plans_priority CHECK (arbitration_priority BETWEEN 1 AND 5),
    CONSTRAINT ck_plans_reduction CHECK (legion_contributor_reduction BETWEEN 0 AND 100)
);

COMMENT ON TABLE tenant.plans IS 'Plans d''abonnement disponibles pour les tenants CORMERY';
COMMENT ON COLUMN tenant.plans.id IS 'Identifiant unique du plan';
COMMENT ON COLUMN tenant.plans.slug IS 'Identifiant public unique du plan (ex: "starter", "pro", "enterprise")';
COMMENT ON COLUMN tenant.plans.product_limit IS 'Nombre maximum de produits suivis (-1 = illimité)';
COMMENT ON COLUMN tenant.plans.refresh_rate_min_seconds IS 'Intervalle minimum de rafraîchissement en secondes';
COMMENT ON COLUMN tenant.plans.arbitrage_priority IS 'Priorité de calcul (1=haute, 5=basse)';
COMMENT ON COLUMN tenant.plans.legion_contributor_reduction IS 'Réduction en % pour les contributeurs LEGION';
COMMENT ON COLUMN tenant.plans.features IS 'Features incluses dans le plan (JSONB)';
COMMENT ON COLUMN tenant.plans.price_monthly_cents IS 'Prix mensuel en cents (null = non disponible)';
COMMENT ON COLUMN tenant.plans.price_yearly_cents IS 'Prix annuel en cents (null = non disponible)';

-- Index sur le schéma tenant
CREATE INDEX idx_plans_slug ON tenant.plans(slug);
CREATE INDEX idx_plans_is_active ON tenant.plans(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_plans_is_default ON tenant.plans(is_default) WHERE is_default = TRUE;

-- ================================================================
-- TABLE: tenant.tenants
-- ================================================================
-- Description: Tenants (organisations) utilisant CORMERY
--              Multi-tenancy au niveau des lignes
-- ================================================================

CREATE TABLE tenant.tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(50) NOT NULL UNIQUE,
    legal_name VARCHAR(255),
    tax_id VARCHAR(100),
    vat_number VARCHAR(100),
    
    -- Informations de contact
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    website VARCHAR(255),
    
    -- Adresse
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country_code VARCHAR(2),
    
    -- Plan et abonnement
    plan_id UUID NOT NULL REFERENCES tenant.plans(id),
    plan_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    plan_expires_at TIMESTAMPTZ,
    
    -- Quotas (surrides du plan)
    product_quota INTEGER,
    refresh_rate_quota INTEGER,
    arbitration_priority INTEGER,
    
    -- Statistiques d'usage (dénormalisées)
    products_tracked_current INTEGER DEFAULT 0,
    total_arbitrage_calls INTEGER DEFAULT 0,
    total_legion_contributions INTEGER DEFAULT 0,
    total_price_observations BIGINT DEFAULT 0,
    
    -- Configuration spécifique tenant
    config JSONB DEFAULT '{}'::jsonb,
    
    -- Statut
    status VARCHAR(50) DEFAULT 'active' NOT NULL,  -- 'active', 'suspended', 'cancelled', 'expired'
    suspended_at TIMESTAMPTZ,
    suspension_reason TEXT,
    cancellation_requested_at TIMESTAMPTZ,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    version INTEGER DEFAULT 1,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_tenants_status CHECK (status IN ('active', 'suspended', 'cancelled', 'expired')),
    CONSTRAINT ck_tenants_product_quota CHECK (product_quota IS NULL OR product_quota >= -1),
    CONSTRAINT ck_tenants_refresh_quota CHECK (refresh_rate_quota IS NULL OR refresh_rate_quota >= 60),
    CONSTRAINT ck_tenants_priority CHECK (arbitration_priority IS NULL OR arbitration_priority BETWEEN 1 AND 5)
);

COMMENT ON TABLE tenant.tenants IS 'Tenants (organisations) utilisant le service CORMERY';
COMMENT ON COLUMN tenant.tenants.id IS 'Identifiant unique du tenant';
COMMENT ON COLUMN tenant.tenants.slug IS 'Identifiant public unique du tenant';
COMMENT ON COLUMN tenant.tenants.plan_id IS 'Plan d''abonnement actif';
COMMENT ON COLUMN tenant.tenants.plan_expires_at IS 'Date d''expiration du plan (null = illimité)';
COMMENT ON COLUMN tenant.tenants.status IS 'Statut du tenant (active/suspended/cancelled/expired)';
COMMENT ON COLUMN tenant.tenants.config IS 'Configuration spécifique au tenant (JSONB)';

-- Index
CREATE INDEX idx_tenants_slug ON tenant.tenants(slug);
CREATE INDEX idx_tenants_email ON tenant.tenants(email);
CREATE INDEX idx_tenants_plan_id ON tenant.tenants(plan_id);
CREATE INDEX idx_tenants_status ON tenant.tenants(status) WHERE status = 'active';
CREATE INDEX idx_tenants_plan_expires ON tenant.tenants(plan_expires_at) WHERE plan_expires_at IS NOT NULL;
CREATE INDEX idx_tenants_country ON tenant.tenants(country_code);
CREATE INDEX idx_tenants_created ON tenant.tenants(created_at DESC);

-- ================================================================
-- TABLE: identity.users
-- ================================================================
-- Description: Utilisateurs CORMERY (liés à un tenant)
--              Authentification et autorisation
-- ================================================================

CREATE TABLE identity.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    username VARCHAR(100) NOT NULL,
    
    -- Identifiants externes
    external_id VARCHAR(255),
    auth0_id VARCHAR(255),
    
    -- Informations personnelles
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    display_name VARCHAR(255),
    
    -- Authentification
    password_hash VARCHAR(255),
    password_salt VARCHAR(64),
    password_last_changed_at TIMESTAMPTZ,
    requires_password_change BOOLEAN DEFAULT FALSE,
    
    -- 2FA
    two_factor_enabled BOOLEAN DEFAULT FALSE,
    two_factor_secret VARCHAR(255),
    two_factor_recovery_codes JSONB,
    
    -- Statut
    is_active BOOLEAN DEFAULT TRUE,
    is_locked BOOLEAN DEFAULT FALSE,
    locked_at TIMESTAMPTZ,
    lock_reason TEXT,
    is_email_verified BOOLEAN DEFAULT FALSE,
    email_verified_at TIMESTAMPTZ,
    
    -- Session et sécurité
    last_login_at TIMESTAMPTZ,
    last_login_ip INET,
    login_count INTEGER DEFAULT 0,
    failed_login_attempts INTEGER DEFAULT 0,
    last_failed_login_at TIMESTAMPTZ,
    
    -- Métadonnées
    preferences JSONB DEFAULT '{}'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT uk_users_tenant_email UNIQUE (tenant_id, email),
    CONSTRAINT uk_users_tenant_username UNIQUE (tenant_id, username),
    CONSTRAINT ck_users_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT ck_users_username_length CHECK (LENGTH(username) >= 3)
);

COMMENT ON TABLE identity.users IS 'Utilisateurs du système CORMERY, liés à un tenant';
COMMENT ON COLUMN identity.users.id IS 'Identifiant unique de l''utilisateur';
COMMENT ON COLUMN identity.users.tenant_id IS 'Référence au tenant propriétaire';
COMMENT ON COLUMN identity.users.email IS 'Email de l''utilisateur (unique par tenant)';
COMMENT ON COLUMN identity.users.username IS 'Nom d''utilisateur (unique par tenant)';
COMMENT ON COLUMN identity.users.password_hash IS 'Hash du mot de passe (bcrypt/argon2)';
COMMENT ON COLUMN identity.users.two_factor_enabled IS 'Indique si l''authentification à deux facteurs est active';
COMMENT ON COLUMN identity.users.is_active IS 'Compte actif (false = désactivé)';
COMMENT ON COLUMN identity.users.is_locked IS 'Compte verrouillé pour raison de sécurité';
COMMENT ON COLUMN identity.users.last_login_at IS 'Date du dernier login réussi';
COMMENT ON COLUMN identity.users.failed_login_attempts IS 'Nombre d''échecs de login consécutifs';

-- Index
CREATE INDEX idx_users_tenant_id ON identity.users(tenant_id);
CREATE INDEX idx_users_email ON identity.users(email);
CREATE INDEX idx_users_username ON identity.users(username);
CREATE INDEX idx_users_auth0_id ON identity.users(auth0_id) WHERE auth0_id IS NOT NULL;
CREATE INDEX idx_users_external_id ON identity.users(external_id) WHERE external_id IS NOT NULL;
CREATE INDEX idx_users_is_active ON identity.users(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_users_created_at ON identity.users(created_at DESC);
CREATE INDEX idx_users_last_login ON identity.users(last_login_at DESC) WHERE last_login_at IS NOT NULL;

-- ================================================================
-- TABLE: identity.roles
-- ================================================================
-- Description: Rôles prédéfinis (globaux ou spécifiques au tenant)
-- ================================================================

CREATE TABLE identity.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiant
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    
    -- Scope (global ou tenant-specific)
    is_global BOOLEAN DEFAULT FALSE,  -- true = rôle global, false = rôle tenant
    tenant_id UUID REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Niveau de hiérarchie (pour l'héritage)
    hierarchy_level INTEGER DEFAULT 1,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_roles_tenant_scope CHECK (
        (is_global = TRUE AND tenant_id IS NULL) OR
        (is_global = FALSE AND tenant_id IS NOT NULL)
    ),
    CONSTRAINT ck_roles_name_length CHECK (LENGTH(name) >= 2),
    CONSTRAINT ck_roles_slug_format CHECK (slug ~* '^[a-z0-9-]+$')
);

COMMENT ON TABLE identity.roles IS 'Rôles définis pour le contrôle d''accès';
COMMENT ON COLUMN identity.roles.is_global IS 'Si vrai, le rôle est disponible pour tous les tenants';
COMMENT ON COLUMN identity.roles.tenant_id IS 'Tenant propriétaire (si rôle spécifique)';
COMMENT ON COLUMN identity.roles.hierarchy_level IS 'Niveau hiérarchique du rôle (1 = plus bas, plus haut = plus de privilèges)';

-- Index
CREATE INDEX idx_roles_slug ON identity.roles(slug);
CREATE INDEX idx_roles_tenant_id ON identity.roles(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX idx_roles_global ON identity.roles(is_global) WHERE is_global = TRUE;
CREATE INDEX idx_roles_hierarchy ON identity.roles(hierarchy_level);

-- ================================================================
-- TABLE: identity.permissions
-- ================================================================
-- Description: Permissions granulaires (CRUD par ressource)
-- ================================================================

CREATE TABLE identity.permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiant
    resource VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,  -- create, read, update, delete, execute
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Resource scope
    scope VARCHAR(50) DEFAULT 'tenant',  -- 'global', 'tenant', 'user'
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT uk_permissions_resource_action UNIQUE (resource, action),
    CONSTRAINT ck_permissions_action CHECK (action IN ('create', 'read', 'update', 'delete', 'execute')),
    CONSTRAINT ck_permissions_scope CHECK (scope IN ('global', 'tenant', 'user'))
);

COMMENT ON TABLE identity.permissions IS 'Permissions granulaires définies par ressource et action';
COMMENT ON COLUMN identity.permissions.resource IS 'Ressource cible (ex: "product", "arbitrage", "user")';
COMMENT ON COLUMN identity.permissions.action IS 'Action autorisée (create/read/update/delete/execute)';
COMMENT ON COLUMN identity.permissions.scope IS 'Portée de la permission (global/tenant/user)';

-- Index
CREATE INDEX idx_permissions_resource ON identity.permissions(resource);
CREATE INDEX idx_permissions_action ON identity.permissions(action);
CREATE INDEX idx_permissions_scope ON identity.permissions(scope);

-- ================================================================
-- TABLE: identity.role_permissions
-- ================================================================
-- Description: Association entre rôles et permissions (N-N)
-- ================================================================

CREATE TABLE identity.role_permissions (
    role_id UUID NOT NULL REFERENCES identity.roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES identity.permissions(id) ON DELETE CASCADE,
    
    -- Métadonnées additionnelles
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    granted_by UUID REFERENCES identity.users(id),
    expires_at TIMESTAMPTZ,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (role_id, permission_id)
);

COMMENT ON TABLE identity.role_permissions IS 'Association entre rôles et permissions (relation N-N)';
COMMENT ON COLUMN identity.role_permissions.granted_at IS 'Date d''octroi de la permission';
COMMENT ON COLUMN identity.role_permissions.expires_at IS 'Date d''expiration de la permission (null = permanente)';

-- Index
CREATE INDEX idx_role_permissions_role ON identity.role_permissions(role_id);
CREATE INDEX idx_role_permissions_permission ON identity.role_permissions(permission_id);

-- ================================================================
-- TABLE: identity.user_roles
-- ================================================================
-- Description: Attribution des rôles aux utilisateurs (N-N)
-- ================================================================

CREATE TABLE identity.user_roles (
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES identity.roles(id) ON DELETE CASCADE,
    
    -- Métadonnées
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    assigned_by UUID REFERENCES identity.users(id),
    expires_at TIMESTAMPTZ,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (user_id, role_id)
);

COMMENT ON TABLE identity.user_roles IS 'Attribution des rôles aux utilisateurs';
COMMENT ON COLUMN identity.user_roles.assigned_at IS 'Date d''attribution du rôle';
COMMENT ON COLUMN identity.user_roles.expires_at IS 'Date d''expiration du rôle (null = permanent)';

-- Index
CREATE INDEX idx_user_roles_user ON identity.user_roles(user_id);
CREATE INDEX idx_user_roles_role ON identity.user_roles(role_id);
CREATE INDEX idx_user_roles_expires ON identity.user_roles(expires_at) WHERE expires_at IS NOT NULL;

-- ================================================================
-- TABLE: identity.api_keys
-- ================================================================
-- Description: Clés API pour l'accès programmatique
-- ================================================================

CREATE TABLE identity.api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    
    -- Identifiants
    name VARCHAR(255) NOT NULL,
    key_prefix VARCHAR(20) NOT NULL,
    key_hash VARCHAR(255) NOT NULL UNIQUE,
    key_salt VARCHAR(64) NOT NULL,
    
    -- Métadonnées de la clé
    last_used_at TIMESTAMPTZ,
    last_used_ip INET,
    last_used_user_agent TEXT,
    usage_count INTEGER DEFAULT 0,
    
    -- Statut
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMPTZ,
    last_rotated_at TIMESTAMPTZ,
    rotation_count INTEGER DEFAULT 0,
    
    -- Permissions spécifiques à la clé (surride des rôles)
    allowed_permissions JSONB DEFAULT '[]'::jsonb,
    rate_limit_per_minute INTEGER DEFAULT 60,
    rate_limit_per_day INTEGER DEFAULT 1000,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT ck_api_keys_key_prefix_length CHECK (LENGTH(key_prefix) >= 3),
    CONSTRAINT ck_api_keys_rate_limits CHECK (
        rate_limit_per_minute >= 1 AND 
        rate_limit_per_day >= rate_limit_per_minute
    )
);

COMMENT ON TABLE identity.api_keys IS 'Clés API pour l''accès programmatique aux APIs CORMERY';
COMMENT ON COLUMN identity.api_keys.tenant_id IS 'Tenant propriétaire de la clé API';
COMMENT ON COLUMN identity.api_keys.user_id IS 'Utilisateur associé à la clé API';
COMMENT ON COLUMN identity.api_keys.key_prefix IS 'Préfixe de la clé (pour identification)';
COMMENT ON COLUMN identity.api_keys.key_hash IS 'Hash sécurisé de la clé API';
COMMENT ON COLUMN identity.api_keys.expires_at IS 'Date d''expiration de la clé (null = permanente)';
COMMENT ON COLUMN identity.api_keys.allowed_permissions IS 'Permissions spécifiques de la clé (JSONB)';
COMMENT ON COLUMN identity.api_keys.rate_limit_per_minute IS 'Nombre maximal de requêtes par minute';
COMMENT ON COLUMN identity.api_keys.rate_limit_per_day IS 'Nombre maximal de requêtes par jour';

-- Index
CREATE INDEX idx_api_keys_tenant_id ON identity.api_keys(tenant_id);
CREATE INDEX idx_api_keys_user_id ON identity.api_keys(user_id);
CREATE INDEX idx_api_keys_key_hash ON identity.api_keys(key_hash);
CREATE INDEX idx_api_keys_key_prefix ON identity.api_keys(key_prefix);
CREATE INDEX idx_api_keys_is_active ON identity.api_keys(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_api_keys_expires_at ON identity.api_keys(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_api_keys_last_used ON identity.api_keys(last_used_at DESC) WHERE last_used_at IS NOT NULL;

-- ================================================================
-- TABLE: identity.user_sessions
-- ================================================================
-- Description: Sessions utilisateur (authentification)
-- ================================================================

CREATE TABLE identity.user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Identifiants de session
    session_token_hash VARCHAR(255) NOT NULL UNIQUE,
    refresh_token_hash VARCHAR(255),
    
    -- Métadonnées
    user_agent TEXT,
    ip_address INET,
    device_id VARCHAR(255),
    
    -- Statut
    is_active BOOLEAN DEFAULT TRUE,
    is_revoked BOOLEAN DEFAULT FALSE,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT,
    
    -- Durée de vie
    expires_at TIMESTAMPTZ NOT NULL,
    refresh_expires_at TIMESTAMPTZ,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_sessions_expiry CHECK (expires_at > created_at)
);

COMMENT ON TABLE identity.user_sessions IS 'Sessions actives des utilisateurs';
COMMENT ON COLUMN identity.user_sessions.session_token_hash IS 'Hash du token de session';
COMMENT ON COLUMN identity.user_sessions.refresh_token_hash IS 'Hash du refresh token';
COMMENT ON COLUMN identity.user_sessions.is_revoked IS 'Indique si la session a été révoquée';
COMMENT ON COLUMN identity.user_sessions.expires_at IS 'Date d''expiration de la session';

-- Index
CREATE INDEX idx_sessions_user_id ON identity.user_sessions(user_id);
CREATE INDEX idx_sessions_tenant_id ON identity.user_sessions(tenant_id);
CREATE INDEX idx_sessions_token_hash ON identity.user_sessions(session_token_hash);
CREATE INDEX idx_sessions_refresh_hash ON identity.user_sessions(refresh_token_hash);
CREATE INDEX idx_sessions_is_active ON identity.user_sessions(is_active, is_revoked) 
    WHERE is_active = TRUE AND is_revoked = FALSE;
CREATE INDEX idx_sessions_expires_at ON identity.user_sessions(expires_at) 
    WHERE is_active = TRUE AND is_revoked = FALSE;

-- ================================================================
-- TABLE: identity.password_reset_tokens
-- ================================================================
-- Description: Tokens de réinitialisation de mot de passe
-- ================================================================

CREATE TABLE identity.password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Token
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    
    -- Métadonnées
    ip_address INET,
    user_agent TEXT,
    
    -- Statut
    is_used BOOLEAN DEFAULT FALSE,
    used_at TIMESTAMPTZ,
    
    -- Durée de vie
    expires_at TIMESTAMPTZ NOT NULL,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_reset_expiry CHECK (expires_at > created_at)
);

COMMENT ON TABLE identity.password_reset_tokens IS 'Tokens de réinitialisation de mot de passe';
COMMENT ON COLUMN identity.password_reset_tokens.token_hash IS 'Hash du token de réinitialisation';
COMMENT ON COLUMN identity.password_reset_tokens.is_used IS 'Indique si le token a été utilisé';
COMMENT ON COLUMN identity.password_reset_tokens.expires_at IS 'Date d''expiration du token';

-- Index
CREATE INDEX idx_reset_user_id ON identity.password_reset_tokens(user_id);
CREATE INDEX idx_reset_token_hash ON identity.password_reset_tokens(token_hash);
CREATE INDEX idx_reset_tenant_id ON identity.password_reset_tokens(tenant_id);
CREATE INDEX idx_reset_unused ON identity.password_reset_tokens(user_id) 
    WHERE is_used = FALSE AND expires_at > NOW();

-- ================================================================
-- TABLE: identity.user_activity_log
-- ================================================================
-- Description: Logs d'activité des utilisateurs
-- ================================================================

CREATE TABLE identity.user_activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Activité
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100),
    resource_id UUID,
    details JSONB,
    
    -- Contexte
    ip_address INET,
    user_agent TEXT,
    session_id UUID REFERENCES identity.user_sessions(id),
    
    -- Résultat
    success BOOLEAN DEFAULT TRUE,
    error_code VARCHAR(50),
    error_message TEXT,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE identity.user_activity_log IS 'Logs d''activité des utilisateurs';
COMMENT ON COLUMN identity.user_activity_log.action IS 'Action effectuée (ex: "login", "create_product")';
COMMENT ON COLUMN identity.user_activity_log.resource_type IS 'Type de ressource concernée';
COMMENT ON COLUMN identity.user_activity_log.details IS 'Détails de l''action (JSONB)';
COMMENT ON COLUMN identity.user_activity_log.success IS 'Indique si l''action a réussi';

-- Index
CREATE INDEX idx_activity_user_id ON identity.user_activity_log(user_id);
CREATE INDEX idx_activity_tenant_id ON identity.user_activity_log(tenant_id);
CREATE INDEX idx_activity_created_at ON identity.user_activity_log(created_at DESC);
CREATE INDEX idx_activity_action ON identity.user_activity_log(action);
CREATE INDEX idx_activity_resource ON identity.user_activity_log(resource_type, resource_id);

-- ================================================================
-- FONCTIONS UTILITAIRES POUR L'IDENTITÉ
-- ================================================================

-- Fonction pour vérifier les permissions d'un utilisateur
CREATE OR REPLACE FUNCTION identity.has_permission(
    p_user_id UUID,
    p_resource VARCHAR(100),
    p_action VARCHAR(50)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_has_permission BOOLEAN := FALSE;
BEGIN
    -- Vérifier via les rôles et permissions
    SELECT EXISTS (
        SELECT 1
        FROM identity.user_roles ur
        JOIN identity.role_permissions rp ON ur.role_id = rp.role_id
        JOIN identity.permissions p ON rp.permission_id = p.id
        WHERE ur.user_id = p_user_id
            AND p.resource = p_resource
            AND p.action = p_action
            AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
            AND (rp.expires_at IS NULL OR rp.expires_at > NOW())
    ) INTO v_has_permission;
    
    RETURN v_has_permission;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION identity.has_permission IS 'Vérifie si un utilisateur a une permission spécifique';

-- Fonction pour créer un tenant avec son utilisateur admin
CREATE OR REPLACE FUNCTION identity.create_tenant_with_admin(
    p_tenant_name VARCHAR(255),
    p_tenant_slug VARCHAR(50),
    p_admin_email VARCHAR(255),
    p_admin_username VARCHAR(100),
    p_admin_password_hash VARCHAR(255),
    p_plan_slug VARCHAR(50) DEFAULT 'starter'
)
RETURNS JSONB AS $$
DECLARE
    v_tenant_id UUID;
    v_plan_id UUID;
    v_admin_id UUID;
    v_result JSONB;
BEGIN
    -- Récupérer le plan
    SELECT id INTO v_plan_id
    FROM tenant.plans
    WHERE slug = p_plan_slug;
    
    IF v_plan_id IS NULL THEN
        RAISE EXCEPTION 'Plan "%" not found', p_plan_slug;
    END IF;
    
    -- Créer le tenant
    INSERT INTO tenant.tenants (
        name,
        slug,
        email,
        plan_id,
        created_at,
        updated_at
    ) VALUES (
        p_tenant_name,
        p_tenant_slug,
        p_admin_email,
        v_plan_id,
        NOW(),
        NOW()
    ) RETURNING id INTO v_tenant_id;
    
    -- Créer l'utilisateur admin
    INSERT INTO identity.users (
        tenant_id,
        email,
        username,
        password_hash,
        is_active,
        is_email_verified,
        created_at,
        updated_at
    ) VALUES (
        v_tenant_id,
        p_admin_email,
        p_admin_username,
        p_admin_password_hash,
        TRUE,
        FALSE,
        NOW(),
        NOW()
    ) RETURNING id INTO v_admin_id;
    
    -- Assigner le rôle admin par défaut
    INSERT INTO identity.user_roles (user_id, role_id)
    SELECT v_admin_id, id
    FROM identity.roles
    WHERE slug = 'admin' AND tenant_id = v_tenant_id;
    
    -- Construire le résultat
    v_result := jsonb_build_object(
        'tenant_id', v_tenant_id,
        'admin_id', v_admin_id,
        'plan', p_plan_slug
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION identity.create_tenant_with_admin IS 'Crée un tenant et son utilisateur administrateur en une transaction';

-- ================================================================
-- TRIGGERS POUR L'IDENTITÉ
-- ================================================================

-- Trigger pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION identity.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer le trigger à toutes les tables d'identité
CREATE TRIGGER tr_users_update BEFORE UPDATE ON identity.users
    FOR EACH ROW EXECUTE FUNCTION identity.update_updated_at_column();

CREATE TRIGGER tr_roles_update BEFORE UPDATE ON identity.roles
    FOR EACH ROW EXECUTE FUNCTION identity.update_updated_at_column();

CREATE TRIGGER tr_tenants_update BEFORE UPDATE ON tenant.tenants
    FOR EACH ROW EXECUTE FUNCTION identity.update_updated_at_column();

CREATE TRIGGER tr_api_keys_update BEFORE UPDATE ON identity.api_keys
    FOR EACH ROW EXECUTE FUNCTION identity.update_updated_at_column();

-- ================================================================
-- DONNÉES INITIALES (Seed)
-- ================================================================

-- Plans par défaut
INSERT INTO tenant.plans (
    slug, 
    name, 
    description, 
    product_limit, 
    refresh_rate_min_seconds, 
    arbitration_priority,
    price_monthly_cents,
    price_yearly_cents,
    features,
    is_active,
    is_default,
    display_order
) VALUES
('starter', 'Starter', 'Plan de base pour les utilisateurs individuels', 
    100, 3600, 3, 
    2900, 29000,
    jsonb_build_object(
        'venus_enriched', false,
        'oracle_predictions', false,
        'legion_compute', false,
        'api_access', true,
        'web_dashboard', true,
        'historical_data_days', 30
    ),
    true, true, 1),

('pro', 'Professional', 'Plan professionnel pour les petites entreprises',
    1000, 600, 2,
    9900, 99000,
    jsonb_build_object(
        'venus_enriched', true,
        'oracle_predictions', true,
        'legion_compute', false,
        'api_access', true,
        'web_dashboard', true,
        'historical_data_days', 90
    ),
    true, false, 2),

('business', 'Business', 'Plan entreprise pour les équipes',
    10000, 300, 1,
    29900, 299000,
    jsonb_build_object(
        'venus_enriched', true,
        'oracle_predictions', true,
        'legion_compute', true,
        'api_access', true,
        'web_dashboard', true,
        'historical_data_days', 365
    ),
    true, false, 3);

-- Rôles par défaut (globaux)
INSERT INTO identity.roles (slug, name, description, is_global, hierarchy_level) VALUES
('admin', 'Administrator', 'Full system administration', true, 5),
('manager', 'Manager', 'Team management and oversight', true, 4),
('analyst', 'Analyst', 'Full read access and analysis', true, 3),
('member', 'Member', 'Standard user access', true, 2),
('viewer', 'Viewer', 'Read-only access', true, 1);

-- Permissions par défaut
INSERT INTO identity.permissions (resource, action, name, description, scope) VALUES
-- Tenant
('tenant', 'read', 'Tenant Read', 'Read tenant information', 'tenant'),
('tenant', 'update', 'Tenant Update', 'Update tenant information', 'tenant'),

-- Users
('user', 'create', 'User Create', 'Create users', 'tenant'),
('user', 'read', 'User Read', 'Read user information', 'tenant'),
('user', 'update', 'User Update', 'Update user information', 'tenant'),
('user', 'delete', 'User Delete', 'Delete users', 'tenant'),

-- Products
('product', 'create', 'Product Create', 'Create products', 'tenant'),
('product', 'read', 'Product Read', 'Read product information', 'tenant'),
('product', 'update', 'Product Update', 'Update product information', 'tenant'),
('product', 'delete', 'Product Delete', 'Delete products', 'tenant'),

-- Arbitrage
('arbitrage', 'read', 'Arbitrage Read', 'Read arbitrage calculations