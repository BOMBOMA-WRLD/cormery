-- ================================================================
-- CORMERY - Schéma Market (Marché et Données Économiques)
-- Version: 1.0.0
-- Date: 2026-08-07
-- Description: Tables représentant l'environnement économique
--              utilisé par VENUS (contexte lent)
-- ================================================================

-- ================================================================
-- TABLE: market.countries
-- ================================================================
-- Description: Pays du monde entier (référentiel géographique de base)
-- ================================================================

CREATE TABLE market.countries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    iso_code_2 VARCHAR(2) NOT NULL UNIQUE,
    iso_code_3 VARCHAR(3) NOT NULL UNIQUE,
    numeric_code VARCHAR(3),
    name VARCHAR(255) NOT NULL,
    official_name VARCHAR(255),
    native_name VARCHAR(255),
    
    -- Caractéristiques
    continent VARCHAR(50),
    region VARCHAR(100),
    sub_region VARCHAR(100),
    capital VARCHAR(255),
    population BIGINT,
    area_km2 NUMERIC(15,2),
    
    -- Devise
    currency_code VARCHAR(3),
    currency_name VARCHAR(100),
    currency_symbol VARCHAR(10),
    
    -- Données socio-économiques
    gdp_usd NUMERIC(20,2),
    gdp_per_capita_usd NUMERIC(20,2),
    purchasing_power_index DECIMAL(10,4),
    human_development_index DECIMAL(5,4),
    gini_index DECIMAL(5,4),
    
    -- Données géopolitiques
    is_eu_member BOOLEAN DEFAULT FALSE,
    is_shengen_member BOOLEAN DEFAULT FALSE,
    is_nato_member BOOLEAN DEFAULT FALSE,
    is_un_member BOOLEAN DEFAULT TRUE,
    
    -- Restrictions
    sanctions_active BOOLEAN DEFAULT FALSE,
    embargo_active BOOLEAN DEFAULT FALSE,
    trade_restrictions JSONB DEFAULT '{}'::jsonb,
    
    -- Fuseau horaire
    timezone VARCHAR(50),
    utc_offset VARCHAR(6),
    dst_observed BOOLEAN DEFAULT FALSE,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_countries_iso_code_2 CHECK (iso_code_2 ~* '^[A-Z]{2}$'),
    CONSTRAINT ck_countries_iso_code_3 CHECK (iso_code_3 ~* '^[A-Z]{3}$')
);

COMMENT ON TABLE market.countries IS 'Référentiel des pays du monde entier (alimenté par VENUS)';
COMMENT ON COLUMN market.countries.iso_code_2 IS 'Code ISO 3166-1 alpha-2 (ex: "FR")';
COMMENT ON COLUMN market.countries.iso_code_3 IS 'Code ISO 3166-1 alpha-3 (ex: "FRA")';
COMMENT ON COLUMN market.countries.numeric_code IS 'Code ISO 3166-1 numérique (ex: "250")';
COMMENT ON COLUMN market.countries.purchasing_power_index IS 'Indice de pouvoir d''achat relatif (1.0 = référence)';
COMMENT ON COLUMN market.countries.sanctions_active IS 'Indique si le pays est sous sanctions internationales';
COMMENT ON COLUMN market.countries.embargo_active IS 'Indique si un embargo commercial est actif';

-- Index
CREATE INDEX idx_countries_iso_2 ON market.countries(iso_code_2);
CREATE INDEX idx_countries_iso_3 ON market.countries(iso_code_3);
CREATE INDEX idx_countries_continent ON market.countries(continent);
CREATE INDEX idx_countries_currency ON market.countries(currency_code);
CREATE INDEX idx_countries_sanctions ON market.countries(sanctions_active) WHERE sanctions_active = TRUE;
CREATE INDEX idx_countries_name ON market.countries(name);

-- ================================================================
-- TABLE: market.regions
-- ================================================================
-- Description: Régions géographiques (regroupement de pays)
-- ================================================================

CREATE TABLE market.regions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,  -- 'continent', 'economic_zone', 'political', 'cultural'
    
    -- Hiérarchie
    parent_id UUID REFERENCES market.regions(id) ON DELETE SET NULL,
    
    -- Pays membres (via table de liaison)
    -- (relation N-N avec countries)
    
    -- Caractéristiques
    population BIGINT,
    area_km2 NUMERIC(15,2),
    gdp_usd NUMERIC(20,2),
    
    -- Accord commercial
    has_free_trade_agreement BOOLEAN DEFAULT FALSE,
    has_customs_union BOOLEAN DEFAULT FALSE,
    trade_agreement_name VARCHAR(255),
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_regions_type CHECK (type IN ('continent', 'economic_zone', 'political', 'cultural', 'trade_zone'))
);

COMMENT ON TABLE market.regions IS 'Régions géographiques regroupant plusieurs pays (ex: UE, ALENA)';
COMMENT ON COLUMN market.regions.code IS 'Code unique de la région (ex: "EU", "NAFTA", "APAC")';
COMMENT ON COLUMN market.regions.type IS 'Type de région (continent/economic_zone/political/cultural/trade_zone)';
COMMENT ON COLUMN market.regions.has_free_trade_agreement IS 'Indique si la région a un accord de libre-échange';

-- Index
CREATE INDEX idx_regions_code ON market.regions(code);
CREATE INDEX idx_regions_type ON market.regions(type);
CREATE INDEX idx_regions_parent ON market.regions(parent_id);

-- ================================================================
-- TABLE: market.region_countries
-- ================================================================
-- Description: Association entre régions et pays (N-N)
-- ================================================================

CREATE TABLE market.region_countries (
    region_id UUID NOT NULL REFERENCES market.regions(id) ON DELETE CASCADE,
    country_id UUID NOT NULL REFERENCES market.countries(id) ON DELETE CASCADE,
    
    -- Métadonnées
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    is_current BOOLEAN DEFAULT TRUE,
    notes TEXT,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (region_id, country_id)
);

COMMENT ON TABLE market.region_countries IS 'Association entre régions et pays membres';
COMMENT ON COLUMN market.region_countries.joined_at IS 'Date d''adhésion à la région';
COMMENT ON COLUMN market.region_countries.left_at IS 'Date de départ de la région (null = toujours membre)';

-- Index
CREATE INDEX idx_region_countries_region ON market.region_countries(region_id);
CREATE INDEX idx_region_countries_country ON market.region_countries(country_id);
CREATE INDEX idx_region_countries_current ON market.region_countries(region_id, country_id) WHERE is_current = TRUE;

-- ================================================================
-- TABLE: market.zones
-- ================================================================
-- Description: Zones économiques/géographiques (granularité fine)
--              Utilisées pour les calculs d'arbitrage OPTIMUS
-- ================================================================

CREATE TABLE market.zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,  -- 'country', 'region', 'economic_zone', 'custom_union', 'port', 'free_trade_zone'
    
    -- Hiérarchie
    country_id UUID REFERENCES market.countries(id) ON DELETE SET NULL,
    region_id UUID REFERENCES market.regions(id) ON DELETE SET NULL,
    parent_zone_id UUID REFERENCES market.zones(id) ON DELETE SET NULL,
    
    -- Niveau hiérarchique (pour calculs)
    hierarchy_level INTEGER DEFAULT 1,
    
    -- Caractéristiques économiques
    currency_code VARCHAR(3) NOT NULL,
    default_vat_rate DECIMAL(5,2),
    default_import_tax_rate DECIMAL(5,2),
    purchasing_power_index DECIMAL(10,4) DEFAULT 1.0,
    
    -- Caractéristiques géopolitiques
    sanctions_active BOOLEAN DEFAULT FALSE,
    embargo_active BOOLEAN DEFAULT FALSE,
    trade_restrictions JSONB DEFAULT '{}'::jsonb,
    geopolitical_risk_index DECIMAL(5,4) DEFAULT 0,
    
    -- Caractéristiques logistiques
    is_island BOOLEAN DEFAULT FALSE,
    is_landlocked BOOLEAN DEFAULT FALSE,
    average_import_delay_days INTEGER DEFAULT 7,
    average_export_delay_days INTEGER DEFAULT 7,
    
    -- Données de transport
    major_ports JSONB DEFAULT '[]'::jsonb,
    major_airports JSONB DEFAULT '[]'::jsonb,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    context_version INTEGER DEFAULT 1,  -- Version du contexte VENUS
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_zones_type CHECK (type IN (
        'country', 'region', 'economic_zone', 'custom_union', 
        'port', 'free_trade_zone', 'city', 'postal_area'
    ))
);

COMMENT ON TABLE market.zones IS 'Zones économiques/géographiques pour les calculs d''arbitrage (OPTIMUS)';
COMMENT ON COLUMN market.zones.code IS 'Code unique de la zone (ex: "FR-IDF", "US-CA", "CN-SH")';
COMMENT ON COLUMN market.zones.type IS 'Type de zone (country/region/economic_zone/custom_union/port/free_trade_zone/city/postal_area)';
COMMENT ON COLUMN market.zones.purchasing_power_index IS 'Indice de pouvoir d''achat local (1.0 = référence)';
COMMENT ON COLUMN market.zones.geopolitical_risk_index IS 'Indice de risque géopolitique (0=aucun, 1=très élevé)';
COMMENT ON COLUMN market.zones.context_version IS 'Version du contexte VENUS utilisée pour cette zone';

-- Index
CREATE INDEX idx_zones_code ON market.zones(code);
CREATE INDEX idx_zones_country ON market.zones(country_id);
CREATE INDEX idx_zones_region ON market.zones(region_id);
CREATE INDEX idx_zones_type ON market.zones(type);
CREATE INDEX idx_zones_currency ON market.zones(currency_code);
CREATE INDEX idx_zones_parent ON market.zones(parent_zone_id);
CREATE INDEX idx_zones_sanctions ON market.zones(sanctions_active, embargo_active) WHERE sanctions_active = TRUE OR embargo_active = TRUE;
CREATE INDEX idx_zones_active ON market.zones(is_active) WHERE is_active = TRUE;

-- ================================================================
-- TABLE: market.currencies
-- ================================================================
-- Description: Devises du monde entier
-- ================================================================

CREATE TABLE market.currencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    code VARCHAR(3) NOT NULL UNIQUE,
    numeric_code VARCHAR(3),
    name VARCHAR(255) NOT NULL,
    symbol VARCHAR(10),
    
    -- Caractéristiques
    decimals INTEGER DEFAULT 2,
    is_fiat BOOLEAN DEFAULT TRUE,
    is_crypto BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_currencies_code CHECK (code ~* '^[A-Z]{3}$'),
    CONSTRAINT ck_currencies_decimals CHECK (decimals BETWEEN 0 AND 8)
);

COMMENT ON TABLE market.currencies IS 'Devises du monde entier';
COMMENT ON COLUMN market.currencies.code IS 'Code ISO 4217 (ex: "USD", "EUR")';
COMMENT ON COLUMN market.currencies.numeric_code IS 'Code ISO 4217 numérique (ex: "840")';
COMMENT ON COLUMN market.currencies.is_fiat IS 'Si vrai, devise fiduciaire (pas crypto)';
COMMENT ON COLUMN market.currencies.is_crypto IS 'Si vrai, crypto-monnaie';

-- Index
CREATE INDEX idx_currencies_code ON market.currencies(code);
CREATE INDEX idx_currencies_active ON market.currencies(is_active) WHERE is_active = TRUE;

-- ================================================================
-- TABLE: market.exchange_rates
-- ================================================================
-- Description: Taux de change historiques et en temps réel
--              (TimescaleDB hypertable)
-- ================================================================

CREATE TABLE market.exchange_rates (
    -- Partitionnement TimescaleDB
    rate_time TIMESTAMPTZ NOT NULL,
    
    -- Identification
    base_currency VARCHAR(3) NOT NULL,
    target_currency VARCHAR(3) NOT NULL,
    
    -- Valeur
    rate DECIMAL(20,8) NOT NULL,
    inverse_rate DECIMAL(20,8) NOT NULL,  -- 1/rate
    spread DECIMAL(20,8),
    
    -- Source et qualité
    source VARCHAR(100) NOT NULL,  -- 'venus_api', 'fixer', 'ecb', 'manual'
    confidence_score DECIMAL(5,4) DEFAULT 0.95,
    is_verified BOOLEAN DEFAULT FALSE,
    verified_by UUID,
    verified_at TIMESTAMPTZ,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (rate_time, base_currency, target_currency)
);

COMMENT ON TABLE market.exchange_rates IS 'Taux de change historiques (TimescaleDB hypertable)';
COMMENT ON COLUMN market.exchange_rates.rate_time IS 'Horodatage du taux de change';
COMMENT ON COLUMN market.exchange_rates.base_currency IS 'Devise de base (ex: "USD")';
COMMENT ON COLUMN market.exchange_rates.target_currency IS 'Devise cible (ex: "EUR")';
COMMENT ON COLUMN market.exchange_rates.rate IS 'Taux de change (1 base_currency = X target_currency)';
COMMENT ON COLUMN market.exchange_rates.inverse_rate IS 'Taux inverse (1 target_currency = X base_currency)';
COMMENT ON COLUMN market.exchange_rates.source IS 'Source du taux de change (VENUS/API tiers)';

-- Conversion en hypertable TimescaleDB
SELECT create_hypertable('market.exchange_rates', 'rate_time',
    chunk_time_interval => INTERVAL '1 day'
);

-- Index
CREATE INDEX idx_exchange_rates_currencies ON market.exchange_rates(base_currency, target_currency, rate_time DESC);
CREATE INDEX idx_exchange_rates_rate_time ON market.exchange_rates(rate_time DESC);
CREATE INDEX idx_exchange_rates_source ON market.exchange_rates(source);

-- Compression TimescaleDB
ALTER TABLE market.exchange_rates SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'base_currency, target_currency',
    timescaledb.compress_orderby = 'rate_time DESC'
);

SELECT add_compression_policy('market.exchange_rates', INTERVAL '7 days');

-- Rétention
SELECT add_retention_policy('market.exchange_rates', INTERVAL '5 years');

-- ================================================================
-- TABLE: market.marketplaces
-- ================================================================
-- Description: Plateformes d'e-commerce (acteurs MERCURE)
-- ================================================================

CREATE TABLE market.marketplaces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    domain VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Catégorie
    type VARCHAR(50) NOT NULL,  -- 'generalist', 'niche', 'marketplace', 'dropshipping'
    
    -- Pays disponibles
    countries JSONB DEFAULT '[]'::jsonb,  -- Liste des codes ISO
    
    -- Caractéristiques
    is_active BOOLEAN DEFAULT TRUE,
    scraping_allowed BOOLEAN DEFAULT TRUE,
    robots_txt_handling VARCHAR(50) DEFAULT 'respect',  -- 'respect', 'ignore', 'custom'
    
    -- Configuration de scraping (MERCURE)
    scrape_config JSONB DEFAULT '{}'::jsonb,
    rate_limit_config JSONB DEFAULT '{}'::jsonb,
    anti_bot_config JSONB DEFAULT '{}'::jsonb,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_marketplaces_type CHECK (type IN ('generalist', 'niche', 'marketplace', 'dropshipping', 'social_commerce'))
);

COMMENT ON TABLE market.marketplaces IS 'Plateformes d''e-commerce (acteurs MERCURE)';
COMMENT ON COLUMN market.marketplaces.type IS 'Type de plateforme (generalist/niche/marketplace/dropshipping/social_commerce)';
COMMENT ON COLUMN market.marketplaces.scraping_allowed IS 'Indique si le scraping est autorisé par les CGU';
COMMENT ON COLUMN market.marketplaces.robots_txt_handling IS 'Comportement face au robots.txt (respect/ignore/custom)';
COMMENT ON COLUMN market.marketplaces.scrape_config IS 'Configuration de scraping spécifique à la plateforme';
COMMENT ON COLUMN market.marketplaces.rate_limit_config IS 'Configuration des limites de taux pour MERCURE';
COMMENT ON COLUMN market.marketplaces.anti_bot_config IS 'Configuration anti-bot pour MERCURE';

-- Index
CREATE INDEX idx_marketplaces_slug ON market.marketplaces(slug);
CREATE INDEX idx_marketplaces_domain ON market.marketplaces(domain);
CREATE INDEX idx_marketplaces_type ON market.marketplaces(type);
CREATE INDEX idx_marketplaces_active ON market.marketplaces(is_active) WHERE is_active = TRUE;

-- ================================================================
-- TABLE: market.sellers
-- ================================================================
-- Description: Vendeurs sur les plateformes (acteurs MERCURE)
-- ================================================================

CREATE TABLE market.sellers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    marketplace_id UUID NOT NULL REFERENCES market.marketplaces(id) ON DELETE CASCADE,
    external_seller_id VARCHAR(255) NOT NULL,
    store_name VARCHAR(255),
    store_url VARCHAR(500),
    
    -- Contact
    email VARCHAR(255),
    phone VARCHAR(50),
    address TEXT,
    country_code VARCHAR(2),
    
    -- Métriques
    seller_rating DECIMAL(3,2),
    seller_rating_count INTEGER DEFAULT 0,
    total_sales INTEGER DEFAULT 0,
    total_products INTEGER DEFAULT 0,
    
    -- Statut
    is_verified BOOLEAN DEFAULT FALSE,
    is_trusted BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Données spécifiques à la plateforme
    platform_metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    last_observed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT uk_seller_marketplace UNIQUE (marketplace_id, external_seller_id)
);

COMMENT ON TABLE market.sellers IS 'Vendeurs sur les plateformes d''e-commerce';
COMMENT ON COLUMN market.sellers.marketplace_id IS 'Plateforme d''appartenance';
COMMENT ON COLUMN market.sellers.external_seller_id IS 'Identifiant du vendeur sur la plateforme';
COMMENT ON COLUMN market.sellers.seller_rating IS 'Note du vendeur (0-5)';
COMMENT ON COLUMN market.sellers.is_trusted IS 'Vendeur de confiance (vérifié manuellement)';

-- Index
CREATE INDEX idx_sellers_marketplace ON market.sellers(marketplace_id);
CREATE INDEX idx_sellers_external_id ON market.sellers(external_seller_id);
CREATE INDEX idx_sellers_country ON market.sellers(country_code);
CREATE INDEX idx_sellers_trusted ON market.sellers(is_trusted, is_verified) WHERE is_trusted = TRUE AND is_verified = TRUE;
CREATE INDEX idx_sellers_active ON market.sellers(is_active) WHERE is_active = TRUE;

-- ================================================================
-- TABLE: market.warehouses
-- ================================================================
-- Description: Entrepôts/centres de distribution (logistique)
-- ================================================================

CREATE TABLE market.warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    type VARCHAR(50) NOT NULL,  -- 'fulfillment', 'distribution', 'franchise', 'third_party'
    
    -- Localisation
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country_id UUID REFERENCES market.countries(id),
    zone_id UUID REFERENCES market.zones(id),
    
    -- Coordonnées GPS
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    
    -- Caractéristiques
    storage_capacity_m2 NUMERIC(10,2),
    storage_capacity_units INTEGER,
    current_utilization_percent DECIMAL(5,2) DEFAULT 0,
    
    -- Opérations
    operates_24h BOOLEAN DEFAULT FALSE,
    average_picking_time_minutes INTEGER DEFAULT 30,
    average_packing_time_minutes INTEGER DEFAULT 20,
    average_shipping_delay_days INTEGER DEFAULT 1,
    
    -- Zones desservies
    serviced_zones JSONB DEFAULT '[]'::jsonb,
    
    -- Transporteurs associés
    transporters JSONB DEFAULT '[]'::jsonb,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_warehouses_type CHECK (type IN ('fulfillment', 'distribution', 'franchise', 'third_party', 'cross_dock'))
);

COMMENT ON TABLE market.warehouses IS 'Entrepôts et centres de distribution logistique';
COMMENT ON COLUMN market.warehouses.type IS 'Type d''entrepôt (fulfillment/distribution/franchise/third_party/cross_dock)';
COMMENT ON COLUMN market.warehouses.serviced_zones IS 'Zones géographiques desservies par l''entrepôt';

-- Index
CREATE INDEX idx_warehouses_code ON market.warehouses(code);
CREATE INDEX idx_warehouses_country ON market.warehouses(country_id);
CREATE INDEX idx_warehouses_zone ON market.warehouses(zone_id);
CREATE INDEX idx_warehouses_active ON market.warehouses(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_warehouses_coordinates ON market.warehouses(latitude, longitude) 
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- ================================================================
-- TABLE: market.transporters
-- ================================================================
-- Description: Transporteurs/logisticiens (fret et livraison)
-- ================================================================

CREATE TABLE market.transporters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    type VARCHAR(50) NOT NULL,  -- 'shipping', 'courier', 'freight', 'last_mile'
    
    -- Contact
    website VARCHAR(255),
    support_phone VARCHAR(50),
    support_email VARCHAR(255),
    tracking_url_template VARCHAR(500),
    
    -- Services
    services_offered JSONB DEFAULT '[]'::jsonb,  -- ['express', 'standard', 'economy', 'freight']
    insurance_options JSONB DEFAULT '[]'::jsonb,
    
    -- Zones de service
    service_zones JSONB DEFAULT '[]'::jsonb,
    
    -- Tarification
    pricing_model VARCHAR(50) DEFAULT 'weight_based',  -- 'weight_based', 'distance_based', 'flat_rate'
    base_rate_usd_per_kg DECIMAL(10,4),
    fuel_surcharge_percent DECIMAL(5,2) DEFAULT 0,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_transporters_type CHECK (type IN ('shipping', 'courier', 'freight', 'last_mile', 'air_freight', 'sea_freight')),
    CONSTRAINT ck_transporters_pricing CHECK (pricing_model IN ('weight_based', 'distance_based', 'flat_rate', 'volume_based'))
);

COMMENT ON TABLE market.transporters IS 'Transporteurs et logisticiens pour le fret';
COMMENT ON COLUMN market.transporters.type IS 'Type de transporteur (shipping/courier/freight/last_mile/air_freight/sea_freight)';
COMMENT ON COLUMN market.transporters.services_offered IS 'Services offerts (express/standard/economy/freight)';
COMMENT ON COLUMN market.transporters.pricing_model IS 'Modèle de tarification (weight_based/distance_based/flat_rate/volume_based)';

-- Index
CREATE INDEX idx_transporters_code ON market.transporters(code);
CREATE INDEX idx_transporters_type ON market.transporters(type);
CREATE INDEX idx_transporters_active ON market.transporters(is_active) WHERE is_active = TRUE;

-- ================================================================
-- TABLE: market.custom_duties
-- ================================================================
-- Description: Droits de douane par pays et catégorie de produit
-- ================================================================

CREATE TABLE market.custom_duties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identification
    country_id UUID NOT NULL REFERENCES market.countries(id) ON DELETE CASCADE,
    hs_code VARCHAR(20) NOT NULL,  -- Code du système harmonisé (6-10 chiffres)
    hs_description TEXT,
    
    -- Droits de douane
    import_duty_percent DECIMAL(8,4),
    import_duty_min_usd DECIMAL(10,2),
    import_duty_max_usd DECIMAL(10,2),
    
    -- Taxes
    vat_percent DECIMAL(8,4),
    excise_tax_percent DECIMAL(8,4),
    luxury_tax_percent DECIMAL(8,4),
    anti_dumping_duty_percent DECIMAL(8,4),
    
    -- Quotas
    quota_quantity INTEGER,
    quota_unit VARCHAR(20),  -- 'kg', 'unit', 'liter'
    quota_period VARCHAR(20),  -- 'year', 'quarter', 'month'
    
    -- Restrictions
    requires_import_license BOOLEAN DEFAULT FALSE,
    requires_certificates JSONB DEFAULT '[]'::jsonb,
    prohibited BOOLEAN DEFAULT FALSE,
    restricted BOOLEAN DEFAULT FALSE,
    
    -- Règles d'origine
    preferential_origin_required BOOLEAN DEFAULT FALSE,
    eligible_countries JSONB DEFAULT '[]'::jsonb,  -- Liste des codes ISO éligibles
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT uk_custom_duties_country_hs UNIQUE (country_id, hs_code)
);

COMMENT ON TABLE market.custom_duties IS 'Droits de douane par pays et catégorie de produit (HS Code)';
COMMENT ON COLUMN market.custom_duties.hs_code IS 'Code du système harmonisé (6-10 chiffres)';
COMMENT ON COLUMN market.custom_duties.import_duty_percent IS 'Pourcentage de droits d''importation';
COMMENT ON COLUMN market.custom_duties.vat_percent IS 'Taux de TVA applicable';
COMMENT ON COLUMN market.custom_duties.prohibited IS 'Si vrai, le produit est interdit à l''importation';
COMMENT ON COLUMN market.custom_duties.restricted IS 'Si vrai, le produit est soumis à des restrictions';
COMMENT ON COLUMN market.custom_duties.valid_from IS 'Date de début de validité du tarif';
COMMENT ON COLUMN market.custom_duties.valid_until IS 'Date de fin de validité du tarif';

-- Index
CREATE INDEX idx_custom_duties_country ON market.custom_duties(country_id);
CREATE INDEX idx_custom_duties_hs ON market.custom_duties(hs_code);
CREATE INDEX idx_custom_duties_active ON market.custom_duties(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_custom_duties_valid ON market.custom_duties(valid_from, valid_until) 
    WHERE valid_from IS NOT NULL AND valid_until IS NOT NULL;
CREATE INDEX idx_custom_duties_prohibited ON market.custom_duties(prohibited) WHERE prohibited = TRUE;

-- ================================================================
-- TABLE: market.shipping_rates
-- ================================================================
-- Description: Tarifs d'expédition par zone, transporteur et poids
-- ================================================================

CREATE TABLE market.shipping_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identification
    transporter_id UUID NOT NULL REFERENCES market.transporters(id) ON DELETE CASCADE,
    origin_zone_id UUID NOT NULL REFERENCES market.zones(id) ON DELETE CASCADE,
    destination_zone_id UUID NOT NULL REFERENCES market.zones(id) ON DELETE CASCADE,
    
    -- Tarification
    weight_min_kg DECIMAL(10,4) NOT NULL,
    weight_max_kg DECIMAL(10,4) NOT NULL,
    price_usd DECIMAL(10,4) NOT NULL,
    
    -- Options
    service_type VARCHAR(50) NOT NULL,  -- 'express', 'standard', 'economy'
    includes_insurance BOOLEAN DEFAULT FALSE,
    includes_tracking BOOLEAN DEFAULT TRUE,
    estimated_delivery_days_min INTEGER,
    estimated_delivery_days_max INTEGER,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_shipping_rates_weight CHECK (weight_min_kg >= 0 AND weight_max_kg > weight_min_kg),
    CONSTRAINT ck_shipping_rates_service CHECK (service_type IN ('express', 'standard', 'economy', 'freight'))
);

COMMENT ON TABLE market.shipping_rates IS 'Tarifs d''expédition par zone, transporteur et poids';
COMMENT ON COLUMN market.shipping_rates.weight_min_kg IS 'Poids minimum en kg pour ce tarif';
COMMENT ON COLUMN market.shipping_rates.weight_max_kg IS 'Poids maximum en kg pour ce tarif';
COMMENT ON COLUMN market.shipping_rates.price_usd IS 'Prix en USD pour ce tarif';
COMMENT ON COLUMN market.shipping_rates.service_type IS 'Type de service (express/standard/economy/freight)';
COMMENT ON COLUMN market.shipping_rates.estimated_delivery_days_min IS 'Délai de livraison minimum estimé en jours';

-- Index
CREATE INDEX idx_shipping_rates_origin ON market.shipping_rates(origin_zone_id);
CREATE INDEX idx_shipping_rates_destination ON market.shipping_rates(destination_zone_id);
CREATE INDEX idx_shipping_rates_transporter ON market.shipping_rates(transporter_id);
CREATE INDEX idx_shipping_rates_weight ON market.shipping_rates(weight_min_kg, weight_max_kg);
CREATE INDEX idx_shipping_rates_service ON market.shipping_rates(service_type);
CREATE INDEX idx_shipping_rates_active ON market.shipping_rates(is_active) WHERE is_active = TRUE;

-- ================================================================
-- TABLE: market.trade_agreements
-- ================================================================
-- Description: Accords commerciaux entre pays/régions
-- ================================================================

CREATE TABLE market.trade_agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    type VARCHAR(50) NOT NULL,  -- 'free_trade', 'customs_union', 'economic_partnership', 'preferential_trade'
    
    -- Parties
    participating_countries JSONB NOT NULL,  -- Liste des codes ISO
    participating_regions JSONB,
    
    -- Conditions
    tariff_reduction_percent DECIMAL(5,2),
    eliminates_tariffs BOOLEAN DEFAULT FALSE,
    eliminates_quotas BOOLEAN DEFAULT FALSE,
    
    -- Portée
    coverage_products JSONB DEFAULT '[]'::jsonb,  -- HS codes couverts
    excludes_products JSONB DEFAULT '[]'::jsonb,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    signed_at TIMESTAMPTZ,
    effective_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_trade_agreements_type CHECK (type IN ('free_trade', 'customs_union', 'economic_partnership', 'preferential_trade', 'mutual_recognition'))
);

COMMENT ON TABLE market.trade_agreements IS 'Accords commerciaux entre pays/régions';
COMMENT ON COLUMN market.trade_agreements.type IS 'Type d''accord (free_trade/customs_union/economic_partnership/preferential_trade/mutual_recognition)';
COMM