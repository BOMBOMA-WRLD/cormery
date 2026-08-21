-- ================================================================
-- CORMERY - Schéma Tracking (Suivi et Observations)
-- Version: 1.0.0
-- Date: 2026-08-07
-- Description: Tables de suivi temps réel alimentées par MERCURE
--              Optimisées pour TimescaleDB (hypertables)
-- ================================================================

-- ================================================================
-- TABLE: tracking.tracked_products
-- ================================================================
-- Description: Produits suivis activement par les utilisateurs
--              (mode hybride OPTIMUS - pré-calcul)
-- ================================================================

CREATE TABLE tracking.tracked_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    sku_canonical_id UUID NOT NULL REFERENCES products.sku_canonical(id) ON DELETE CASCADE,
    user_id UUID REFERENCES identity.users(id) ON DELETE SET NULL,
    
    -- Origine du suivi
    tracking_source VARCHAR(50) NOT NULL,  -- 'user_request', 'auto_promoted', 'oracle_detected', 'watchlist'
    popularity_score INTEGER DEFAULT 1,    -- Décroît dans le temps, incrémenté à chaque consultation
    
    -- Paramètres de rafraîchissement adaptatifs
    refresh_interval_s INTEGER NOT NULL DEFAULT 3600,  -- 1 heure par défaut
    min_refresh_interval_s INTEGER DEFAULT 60,         -- 1 minute max
    max_refresh_interval_s INTEGER DEFAULT 86400,      -- 24h max
    price_volatility_index DECIMAL(5,4) DEFAULT 0,     -- 0-1, calculé automatiquement
    last_refresh_at TIMESTAMPTZ DEFAULT NOW(),
    refresh_count INTEGER DEFAULT 0,
    
    -- Quota et limites
    quota_used INTEGER DEFAULT 0,
    quota_limit INTEGER DEFAULT 1000,
    
    -- Statut
    is_active BOOLEAN DEFAULT TRUE,
    is_auto_tracked BOOLEAN DEFAULT FALSE,  -- Suivi automatique (Oracle)
    pause_reason VARCHAR(100),
    paused_at TIMESTAMPTZ,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    tracked_since TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT uk_tracked_tenant_sku UNIQUE (tenant_id, sku_canonical_id),
    CONSTRAINT ck_tracked_refresh_interval CHECK (
        refresh_interval_s >= min_refresh_interval_s 
        AND refresh_interval_s <= max_refresh_interval_s
    ),
    CONSTRAINT ck_tracked_volatility CHECK (price_volatility_index BETWEEN 0 AND 1),
    CONSTRAINT ck_tracked_source CHECK (tracking_source IN ('user_request', 'auto_promoted', 'oracle_detected', 'watchlist', 'legion'))
);

COMMENT ON TABLE tracking.tracked_products IS 'Produits suivis activement (mode hybride OPTIMUS)';
COMMENT ON COLUMN tracking.tracked_products.tracking_source IS 'Source du suivi (user_request/auto_promoted/oracle_detected/watchlist/legion)';
COMMENT ON COLUMN tracking.tracked_products.popularity_score IS 'Score de popularité (décroît dans le temps)';
COMMENT ON COLUMN tracking.tracked_products.refresh_interval_s IS 'Intervalle de rafraîchissement en secondes';
COMMENT ON COLUMN tracking.tracked_products.price_volatility_index IS 'Indice de volatilité des prix (0-1)';
COMMENT ON COLUMN tracking.tracked_products.is_auto_tracked IS 'Si vrai, suivi automatique par Oracle';

-- Index
CREATE INDEX idx_tracked_tenant_active ON tracking.tracked_products(tenant_id, is_active) WHERE is_active = TRUE;
CREATE INDEX idx_tracked_popularity ON tracking.tracked_products(popularity_score DESC) WHERE is_active = TRUE;
CREATE INDEX idx_tracked_refresh ON tracking.tracked_products(refresh_interval_s, last_refresh_at);
CREATE INDEX idx_tracked_sku ON tracking.tracked_products(sku_canonical_id);
CREATE INDEX idx_tracked_user ON tracking.tracked_products(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_tracked_volatility ON tracking.tracked_products(price_volatility_index DESC) WHERE is_active = TRUE;

-- ================================================================
-- TABLE: tracking.watchlists
-- ================================================================
-- Description: Listes de surveillance personnalisées des utilisateurs
-- ================================================================

CREATE TABLE tracking.watchlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    
    -- Identifiants
    name VARCHAR(255) NOT NULL,
    description TEXT,
    slug VARCHAR(100) NOT NULL,
    
    -- Configuration
    is_public BOOLEAN DEFAULT FALSE,
    is_default BOOLEAN DEFAULT FALSE,
    notification_enabled BOOLEAN DEFAULT TRUE,
    notification_triggers JSONB DEFAULT '{"price_drop": true, "stock_alert": true, "arbitrage_opportunity": true}'::jsonb,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT uk_watchlists_tenant_user_slug UNIQUE (tenant_id, user_id, slug)
);

COMMENT ON TABLE tracking.watchlists IS 'Listes de surveillance personnalisées des utilisateurs';
COMMENT ON COLUMN tracking.watchlists.slug IS 'Identifiant URL-friendly de la liste';
COMMENT ON COLUMN tracking.watchlists.is_default IS 'Liste par défaut de l''utilisateur';
COMMENT ON COLUMN tracking.watchlists.notification_triggers IS 'Conditions de notification (JSONB)';

-- Index
CREATE INDEX idx_watchlists_tenant ON tracking.watchlists(tenant_id);
CREATE INDEX idx_watchlists_user ON tracking.watchlists(user_id);
CREATE INDEX idx_watchlists_slug ON tracking.watchlists(slug);
CREATE INDEX idx_watchlists_default ON tracking.watchlists(tenant_id, user_id, is_default) WHERE is_default = TRUE;

-- ================================================================
-- TABLE: tracking.watchlist_items
-- ================================================================
-- Description: Produits dans les listes de surveillance
-- ================================================================

CREATE TABLE tracking.watchlist_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    watchlist_id UUID NOT NULL REFERENCES tracking.watchlists(id) ON DELETE CASCADE,
    sku_canonical_id UUID NOT NULL REFERENCES products.sku_canonical(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Métadonnées
    notes TEXT,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT uk_watchlist_items_watchlist_sku UNIQUE (watchlist_id, sku_canonical_id)
);

COMMENT ON TABLE tracking.watchlist_items IS 'Produits dans les listes de surveillance';

-- Index
CREATE INDEX idx_watchlist_items_watchlist ON tracking.watchlist_items(watchlist_id);
CREATE INDEX idx_watchlist_items_sku ON tracking.watchlist_items(sku_canonical_id);
CREATE INDEX idx_watchlist_items_tenant ON tracking.watchlist_items(tenant_id);

-- ================================================================
-- TABLE: tracking.price_observations (TimescaleDB Hypertable)
-- ================================================================
-- Description: Observations de prix en temps réel (MERCURE)
--              Hypertable TimescaleDB avec compression
-- ================================================================

CREATE TABLE tracking.price_observations (
    -- Partitionnement TimescaleDB
    observed_at TIMESTAMPTZ NOT NULL,
    
    -- Références
    tenant_id UUID NOT NULL,
    sku_id UUID NOT NULL,  -- Référence à products.sku_canonical
    zone_id UUID NOT NULL REFERENCES market.zones(id),
    actor_id UUID,  -- Référence à market.sellers
    marketplace_id UUID,  -- Référence à market.marketplaces
    
    -- Valeur
    price_raw DECIMAL(15,4) NOT NULL,
    currency_code VARCHAR(3) NOT NULL,
    price_usd_equivalent DECIMAL(15,4) NOT NULL,  -- Normalisé USD
    
    -- Contexte
    source_event_id VARCHAR(64) NOT NULL,  -- Référence à l'event MERCURE
    source_url TEXT,
    source_product_url TEXT,
    
    -- Statut
    is_active_offer BOOLEAN DEFAULT TRUE,
    is_available BOOLEAN DEFAULT TRUE,
    availability_status VARCHAR(50) DEFAULT 'in_stock',  -- 'in_stock', 'low_stock', 'out_of_stock', 'preorder'
    stock_quantity INTEGER,  -- Quantité disponible si connu
    stock_quantity_available INTEGER,
    
    -- Métriques de qualité
    confidence_score DECIMAL(5,4) DEFAULT 1.0,  -- Confiance dans le prix extrait
    is_verified BOOLEAN DEFAULT FALSE,  -- Vérifié par LEGION
    verification_attempts INTEGER DEFAULT 0,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_price_observations_price CHECK (price_raw > 0),
    CONSTRAINT ck_price_observations_confidence CHECK (confidence_score BETWEEN 0 AND 1),
    CONSTRAINT ck_price_observations_status CHECK (availability_status IN ('in_stock', 'low_stock', 'out_of_stock', 'preorder', 'unknown'))
);

COMMENT ON TABLE tracking.price_observations IS 'Observations de prix en temps réel (MERCURE - TimescaleDB hypertable)';
COMMENT ON COLUMN tracking.price_observations.observed_at IS 'Horodatage de l''observation (partition)';
COMMENT ON COLUMN tracking.price_observations.price_raw IS 'Prix brut dans la devise locale';
COMMENT ON COLUMN tracking.price_observations.price_usd_equivalent IS 'Prix normalisé en USD pour comparaison';
COMMENT ON COLUMN tracking.price_observations.source_event_id IS 'Référence à l''événement MERCURE source';
COMMENT ON COLUMN tracking.price_observations.is_active_offer IS 'L''offre est-elle encore disponible ?';
COMMENT ON COLUMN tracking.price_observations.confidence_score IS 'Score de confiance (0-1)';

-- Conversion en hypertable TimescaleDB
SELECT create_hypertable(
    'tracking.price_observations',
    'observed_at',
    chunk_time_interval => INTERVAL '1 day',
    partitioning_column => 'tenant_id',
    number_partitions => 64
);

-- Index
CREATE INDEX idx_price_observations_sku_zone ON tracking.price_observations(sku_id, zone_id, observed_at DESC);
CREATE INDEX idx_price_observations_tenant_sku ON tracking.price_observations(tenant_id, sku_id, observed_at DESC);
CREATE INDEX idx_price_observations_tenant_zone ON tracking.price_observations(tenant_id, zone_id, observed_at DESC);
CREATE INDEX idx_price_observations_actor ON tracking.price_observations(actor_id, observed_at DESC);
CREATE INDEX idx_price_observations_marketplace ON tracking.price_observations(marketplace_id, observed_at DESC);
CREATE INDEX idx_price_observations_status ON tracking.price_observations(availability_status, observed_at DESC);
CREATE INDEX idx_price_observations_source ON tracking.price_observations(source_event_id);

-- Configuration de la compression
ALTER TABLE tracking.price_observations SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'tenant_id, sku_id, zone_id',
    timescaledb.compress_orderby = 'observed_at DESC'
);

SELECT add_compression_policy('tracking.price_observations', INTERVAL '7 days');

-- Politique de rétention
SELECT add_retention_policy('tracking.price_observations', INTERVAL '90 days');

-- ================================================================
-- TABLE: tracking.stock_observations (TimescaleDB Hypertable)
-- ================================================================
-- Description: Observations de stock en temps réel (MERCURE)
-- ================================================================

CREATE TABLE tracking.stock_observations (
    -- Partitionnement TimescaleDB
    observed_at TIMESTAMPTZ NOT NULL,
    
    -- Références
    tenant_id UUID NOT NULL,
    sku_id UUID NOT NULL,
    zone_id UUID NOT NULL REFERENCES market.zones(id),
    actor_id UUID,  -- Référence à market.sellers
    marketplace_id UUID,  -- Référence à market.marketplaces
    
    -- Stock
    stock_quantity INTEGER NOT NULL,
    stock_status VARCHAR(50) NOT NULL,  -- 'in_stock', 'low_stock', 'out_of_stock', 'preorder', 'backorder'
    restock_date_estimate TIMESTAMPTZ,
    restock_quantity_expected INTEGER,
    
    -- Tendances
    stock_movement_rate INTEGER,  -- Unités par jour (positif = sorties, négatif = entrées)
    days_to_out_of_stock INTEGER,  -- Projection si le mouvement continue
    weekly_trend DECIMAL(5,4),  -- Tendance hebdomadaire (-1 à 1)
    
    -- Sources
    source_event_id VARCHAR(64) NOT NULL,
    source_url TEXT,
    
    -- Métriques de qualité
    confidence_score DECIMAL(5,4) DEFAULT 1.0,
    is_verified BOOLEAN DEFAULT FALSE,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_stock_observations_quantity CHECK (stock_quantity >= 0),
    CONSTRAINT ck_stock_observations_status CHECK (stock_status IN ('in_stock', 'low_stock', 'out_of_stock', 'preorder', 'backorder', 'unknown')),
    CONSTRAINT ck_stock_observations_confidence CHECK (confidence_score BETWEEN 0 AND 1)
);

COMMENT ON TABLE tracking.stock_observations IS 'Observations de stock en temps réel (MERCURE - TimescaleDB hypertable)';
COMMENT ON COLUMN tracking.stock_observations.stock_quantity IS 'Quantité en stock';
COMMENT ON COLUMN tracking.stock_observations.stock_status IS 'Statut du stock (in_stock/low_stock/out_of_stock/preorder/backorder/unknown)';
COMMENT ON COLUMN tracking.stock_observations.stock_movement_rate IS 'Taux de mouvement (unités/jour)';
COMMENT ON COLUMN tracking.stock_observations.days_to_out_of_stock IS 'Jours estimés avant rupture de stock';

-- Conversion en hypertable
SELECT create_hypertable(
    'tracking.stock_observations',
    'observed_at',
    chunk_time_interval => INTERVAL '1 day',
    partitioning_column => 'tenant_id',
    number_partitions => 64
);

-- Index
CREATE INDEX idx_stock_observations_sku ON tracking.stock_observations(sku_id, observed_at DESC);
CREATE INDEX idx_stock_observations_zone ON tracking.stock_observations(zone_id, observed_at DESC);
CREATE INDEX idx_stock_observations_tenant ON tracking.stock_observations(tenant_id, observed_at DESC);
CREATE INDEX idx_stock_observations_status ON tracking.stock_observations(stock_status, observed_at DESC) 
    WHERE stock_status IN ('out_of_stock', 'low_stock');
CREATE INDEX idx_stock_observations_source ON tracking.stock_observations(source_event_id);

-- Compression
ALTER TABLE tracking.stock_observations SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'tenant_id, sku_id, zone_id',
    timescaledb.compress_orderby = 'observed_at DESC'
);

SELECT add_compression_policy('tracking.stock_observations', INTERVAL '7 days');
SELECT add_retention_policy('tracking.stock_observations', INTERVAL '90 days');

-- ================================================================
-- TABLE: tracking.availability_observations (TimescaleDB Hypertable)
-- ================================================================
-- Description: Observations de disponibilité (état des offres)
-- ================================================================

CREATE TABLE tracking.availability_observations (
    -- Partitionnement TimescaleDB
    observed_at TIMESTAMPTZ NOT NULL,
    
    -- Références
    tenant_id UUID NOT NULL,
    sku_id UUID NOT NULL,
    zone_id UUID NOT NULL REFERENCES market.zones(id),
    actor_id UUID,
    marketplace_id UUID,
    
    -- Disponibilité
    is_available BOOLEAN NOT NULL,
    availability_status VARCHAR(50),  -- 'in_stock', 'limited_stock', 'out_of_stock', 'preorder', 'discontinued'
    available_quantity INTEGER,
    delivery_time_days INTEGER,
    delivery_cost_usd DECIMAL(10,4),
    shipping_options JSONB,  -- Liste des options de livraison
    
    -- Contexte
    source_event_id VARCHAR(64) NOT NULL,
    source_url TEXT,
    
    -- Métriques de qualité
    confidence_score DECIMAL(5,4) DEFAULT 1.0,
    is_verified BOOLEAN DEFAULT FALSE,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_availability_observations_quantity CHECK (available_quantity >= 0),
    CONSTRAINT ck_availability_observations_status CHECK (availability_status IN ('in_stock', 'limited_stock', 'out_of_stock', 'preorder', 'discontinued', 'unknown'))
);

COMMENT ON TABLE tracking.availability_observations IS 'Observations de disponibilité (MERCURE - TimescaleDB hypertable)';
COMMENT ON COLUMN tracking.availability_observations.is_available IS 'Le produit est-il disponible ?';
COMMENT ON COLUMN tracking.availability_observations.availability_status IS 'Statut de disponibilité détaillé';
COMMENT ON COLUMN tracking.availability_observations.delivery_time_days IS 'Délai de livraison estimé en jours';
COMMENT ON COLUMN tracking.availability_observations.delivery_cost_usd IS 'Coût de livraison en USD';

-- Conversion en hypertable
SELECT create_hypertable(
    'tracking.availability_observations',
    'observed_at',
    chunk_time_interval => INTERVAL '1 day',
    partitioning_column => 'tenant_id',
    number_partitions => 64
);

-- Index
CREATE INDEX idx_availability_observations_sku ON tracking.availability_observations(sku_id, observed_at DESC);
CREATE INDEX idx_availability_observations_zone ON tracking.availability_observations(zone_id, observed_at DESC);
CREATE INDEX idx_availability_observations_tenant ON tracking.availability_observations(tenant_id, observed_at DESC);
CREATE INDEX idx_availability_observations_status ON tracking.availability_observations(availability_status, observed_at DESC) 
    WHERE is_available = FALSE;
CREATE INDEX idx_availability_observations_source ON tracking.availability_observations(source_event_id);

-- Compression
ALTER TABLE tracking.availability_observations SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'tenant_id, sku_id, zone_id',
    timescaledb.compress_orderby = 'observed_at DESC'
);

SELECT add_compression_policy('tracking.availability_observations', INTERVAL '7 days');
SELECT add_retention_policy('tracking.availability_observations', INTERVAL '90 days');

-- ================================================================
-- TABLE: tracking.price_history (Aggregated View)
-- ================================================================
-- Description: Vue matérialisée des historiques de prix agrégés
--              (optimisée pour les dashboards)
-- ================================================================

CREATE MATERIALIZED VIEW tracking.price_history
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', observed_at) AS bucket,
    tenant_id,
    sku_id,
    zone_id,
    AVG(price_usd_equivalent) AS avg_price_usd,
    MIN(price_usd_equivalent) AS min_price_usd,
    MAX(price_usd_equivalent) AS max_price_usd,
    FIRST(price_usd_equivalent, observed_at) AS opening_price_usd,
    LAST(price_usd_equivalent, observed_at) AS closing_price_usd,
    COUNT(*) AS observation_count,
    STDDEV(price_usd_equivalent) AS price_volatility,
    AVG(confidence_score) AS avg_confidence
FROM tracking.price_observations
GROUP BY bucket, tenant_id, sku_id, zone_id
WITH NO DATA;

COMMENT ON MATERIALIZED VIEW tracking.price_history IS 'Historique de prix agrégé par heure (dashboard)';

-- Index sur la vue matérialisée
CREATE INDEX idx_price_history_bucket ON tracking.price_history(bucket DESC);
CREATE INDEX idx_price_history_tenant_sku ON tracking.price_history(tenant_id, sku_id);
CREATE INDEX idx_price_history_zone ON tracking.price_history(zone_id);

-- Actualisation automatique (chaque heure)
CREATE OR REPLACE FUNCTION tracking.refresh_price_history()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY tracking.price_history;
    PERFORM pg_notify('price_history_refreshed', 'refresh_completed');
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- FUNCTIONS UTILITAIRES POUR LE TRACKING
-- ================================================================

-- Fonction de mise à jour de la volatilité des prix
CREATE OR REPLACE FUNCTION tracking.update_price_volatility(
    p_sku_id UUID,
    p_tenant_id UUID,
    p_days INTEGER DEFAULT 30
)
RETURNS DECIMAL(5,4) AS $$
DECLARE
    volatility DECIMAL(5,4);
    avg_price DECIMAL(15,4);
BEGIN
    SELECT 
        STDDEV(price_usd_equivalent) / AVG(price_usd_equivalent)
    INTO volatility
    FROM tracking.price_observations
    WHERE sku_id = p_sku_id
        AND tenant_id = p_tenant_id
        AND observed_at >= NOW() - (p_days || ' days')::INTERVAL
        AND price_usd_equivalent > 0;
    
    -- Limiter à 1 (100% de volatilité)
    volatility := LEAST(COALESCE(volatility, 0), 1);
    
    RETURN volatility;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tracking.update_price_volatility IS 'Calcule l''indice de volatilité des prix sur N jours';

-- Fonction pour obtenir les dernières observations de prix
CREATE OR REPLACE FUNCTION tracking.get_latest_price(
    p_sku_id UUID,
    p_tenant_id UUID,
    p_zone_id UUID DEFAULT NULL
)
RETURNS TABLE (
    price_usd DECIMAL(15,4),
    observed_at TIMESTAMPTZ,
    currency_code VARCHAR(3),
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        price_usd_equivalent,
        observed_at,
        currency_code,
        is_active_offer
    FROM tracking.price_observations
    WHERE sku_id = p_sku_id
        AND tenant_id = p_tenant_id
        AND (p_zone_id IS NULL OR zone_id = p_zone_id)
    ORDER BY observed_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tracking.get_latest_price IS 'Récupère la dernière observation de prix pour un SKU';

-- Fonction de suivi automatique (promotion vers tracked_products)
CREATE OR REPLACE FUNCTION tracking.auto_track_product(
    p_sku_id UUID,
    p_tenant_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_source VARCHAR(50) DEFAULT 'auto_promoted'
)
RETURNS UUID AS $$
DECLARE
    v_tracked_id UUID;
BEGIN
    -- Vérifier si déjà suivi
    SELECT id INTO v_tracked_id
    FROM tracking.tracked_products
    WHERE sku_canonical_id = p_sku_id
        AND tenant_id = p_tenant_id;
    
    IF v_tracked_id IS NOT NULL THEN
        -- Mettre à jour le score de popularité
        UPDATE tracking.tracked_products
        SET popularity_score = popularity_score + 1,
            updated_at = NOW()
        WHERE id = v_tracked_id;
        
        RETURN v_tracked_id;
    END IF;
    
    -- Créer un nouveau suivi
    INSERT INTO tracking.tracked_products (
        tenant_id,
        sku_canonical_id,
        user_id,
        tracking_source,
        popularity_score,
        tracked_since
    ) VALUES (
        p_tenant_id,
        p_sku_id,
        p_user_id,
        p_source,
        1,
        NOW()
    ) RETURNING id INTO v_tracked_id;
    
    RETURN v_tracked_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tracking.auto_track_product IS 'Ajoute automatiquement un produit au suivi (Oracle)';

-- Trigger pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION tracking.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer le trigger
CREATE TRIGGER tr_tracked_update BEFORE UPDATE ON tracking.tracked_products
    FOR EACH ROW EXECUTE FUNCTION tracking.update_updated_at_column();

CREATE TRIGGER tr_watchlists_update BEFORE UPDATE ON tracking.watchlists
    FOR EACH ROW EXECUTE FUNCTION tracking.update_updated_at_column();

CREATE TRIGGER tr_watchlist_items_update BEFORE UPDATE ON tracking.watchlist_items
    FOR EACH ROW EXECUTE FUNCTION tracking.update_updated_at_column();

-- ================================================================
-- VUES UTILITAIRES
-- ================================================================

-- Vue des produits suivis avec dernière observation
CREATE OR REPLACE VIEW tracking.v_tracked_with_latest_price AS
SELECT 
    tp.id AS tracked_id,
    tp.tenant_id,
    tp.sku_canonical_id,
    sc.name AS product_name,
    sc.sku_hash,
    tp.tracking_source,
    tp.popularity_score,
    tp.price_volatility_index,
    tp.tracked_since,
    tp.is_active,
    po.price_usd_equivalent AS latest_price_usd,
    po.observed_at AS latest_price_at,
    po.zone_id,
    z.code AS zone_code,
    z.name AS zone_name
FROM tracking.tracked_products tp
JOIN products.sku_canonical sc ON tp.sku_canonical_id = sc.id
LEFT JOIN LATERAL (
    SELECT price_usd_equivalent, observed_at, zone_id
    FROM tracking.price_observations
    WHERE sku_id = sc.id
        AND tenant_id = tp.tenant_id
    ORDER BY observed_at DESC
    LIMIT 1
) po ON TRUE
LEFT JOIN market.zones z ON po.zone_id = z.id
WHERE tp.is_active = TRUE;

COMMENT ON VIEW tracking.v_tracked_with_latest_price IS 'Produits suivis avec leur dernière observation de prix';

-- Vue des alertes de rupture de stock
CREATE OR REPLACE VIEW tracking.v_stock_alerts AS
SELECT 
    so.sku_id,
    sc.name AS product_name,
    so.zone_id,
    z.code AS zone_code,
    so.stock_quantity,
    so.stock_status,
    so.days_to_out_of_stock,
    so.observed_at,
    so.source_event_id,
    EXTRACT(EPOCH FROM (NOW() - so.observed_at)) / 3600 AS hours_since_observation
FROM tracking.stock_observations so
JOIN products.sku_canonical sc ON so.sku_id = sc.id
JOIN market.zones z ON so.zone_id = z.id
WHERE so.stock_status IN ('low_stock', 'out_of_stock')
    AND so.observed_at >= NOW() - INTERVAL '24 hours'
ORDER BY so.observed_at DESC;

COMMENT ON VIEW tracking.v_stock_alerts IS 'Alertes de rupture de stock (24h)';

-- ================================================================
-- RÉSUMÉ DU SCHÉMA TRACKING
-- ================================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│                  SCHÉMA TRACKING - RÉSUMÉ                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  tracked_products          │ Produits suivis (mode hybride)      │
│  watchlists                │ Listes de surveillance              │
│  watchlist_items           │ Produits dans les watchlists       │
│  price_observations        │ Prix temps réel (TimescaleDB)      │
│  stock_observations        │ Stock temps réel (TimescaleDB)     │
│  availability_observations │ Disponibilité (TimescaleDB)        │
│  price_history             │ Vue matérialisée (dashboard)       │
│                                                                   │
│  Hypertables :                                                     │
│  • price_observations      │ Partition par jour + tenant        │
│  • stock_observations      │ Compression après 7 jours          │
│  • availability_observations│ Rétention 90 jours               │
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
    WHERE table_schema = 'tracking'
    AND table_type = 'BASE TABLE';
    
    IF table_count = 6 THEN
        RAISE NOTICE '✅ Toutes les tables du schéma tracking ont été créées (6/6)';
        RAISE NOTICE '📊 Hypertables créées: price_observations, stock_observations, availability_observations';
        RAISE NOTICE '🗜️ Compression activée sur toutes les hypertables';
        RAISE NOTICE '⏰ Rétention configurée: 90 jours';
    ELSE
        RAISE NOTICE '⚠️ % tables sur 6 créées dans le schéma tracking', table_count;
    END IF;
END;
$$;