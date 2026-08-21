-- ================================================================
-- CORMERY - Schéma Products (Produits et Catalogues)
-- Version: 1.0.0
-- Date: 2026-08-07
-- Description: Tables permettant au Réconciliateur de construire
--              un SKU universel à partir des sources MERCURE
-- ================================================================

-- ================================================================
-- TABLE: products.brands
-- ================================================================
-- Description: Marques des produits (référentiel)
-- ================================================================

CREATE TABLE products.brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    
    -- Informations
    description TEXT,
    logo_url VARCHAR(500),
    website VARCHAR(255),
    
    -- Classification
    parent_brand_id UUID REFERENCES products.brands(id) ON DELETE SET NULL,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT uk_brands_name UNIQUE (name)
);

COMMENT ON TABLE products.brands IS 'Marques des produits (référentiel)';
COMMENT ON COLUMN products.brands.slug IS 'Identifiant unique URL-friendly de la marque';
COMMENT ON COLUMN products.brands.parent_brand_id IS 'Marque parente (ex: LVMH → Louis Vuitton)';

-- Index
CREATE INDEX idx_brands_slug ON products.brands(slug);
CREATE INDEX idx_brands_parent ON products.brands(parent_brand_id);
CREATE INDEX idx_brands_name ON products.brands(name);

-- ================================================================
-- TABLE: products.categories
-- ================================================================
-- Description: Catégories de produits (taxonomie)
-- ================================================================

CREATE TABLE products.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    
    -- Hiérarchie
    parent_category_id UUID REFERENCES products.categories(id) ON DELETE SET NULL,
    lft INTEGER NOT NULL,           -- Nested Set Left
    rgt INTEGER NOT NULL,           -- Nested Set Right
    depth INTEGER NOT NULL DEFAULT 0,
    
    -- Classification
    external_code VARCHAR(50),       -- Code externe (ex: GPC, UNSPSC)
    external_system VARCHAR(50),     -- Système de classification source
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT ck_categories_lft_rgt CHECK (lft < rgt)
);

COMMENT ON TABLE products.categories IS 'Catégories de produits (taxonomie)';
COMMENT ON COLUMN products.categories.lft IS 'Nested Set - valeur gauche pour l''arbre hiérarchique';
COMMENT ON COLUMN products.categories.rgt IS 'Nested Set - valeur droite pour l''arbre hiérarchique';
COMMENT ON COLUMN products.categories.depth IS 'Profondeur dans l''arbre (0 = racine)';
COMMENT ON COLUMN products.categories.external_code IS 'Code externe (ex: GPC, UNSPSC)';

-- Index
CREATE INDEX idx_categories_slug ON products.categories(slug);
CREATE INDEX idx_categories_parent ON products.categories(parent_category_id);
CREATE INDEX idx_categories_nested ON products.categories(lft, rgt);
CREATE INDEX idx_categories_depth ON products.categories(depth);
CREATE INDEX idx_categories_external ON products.categories(external_code, external_system);

-- ================================================================
-- TABLE: products.products
-- ================================================================
-- Description: Produits de base (version canonique)
-- ================================================================

CREATE TABLE products.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    canonical_sku_id UUID,  -- FK vers SKUCanonical (définie plus tard)
    
    -- Informations produit
    name VARCHAR(500) NOT NULL,
    description TEXT,
    short_description TEXT,
    
    -- Classification
    brand_id UUID REFERENCES products.brands(id) ON DELETE SET NULL,
    category_id UUID REFERENCES products.categories(id) ON DELETE SET NULL,
    
    -- Identifiants externes
    gtin VARCHAR(14),       -- Global Trade Item Number
    ean VARCHAR(13),        -- European Article Number
    upc VARCHAR(12),        -- Universal Product Code
    mpn VARCHAR(100),       -- Manufacturer Part Number
    isbn VARCHAR(13),       -- International Standard Book Number
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT uk_products_tenant_gtin UNIQUE (tenant_id, gtin) WHERE gtin IS NOT NULL,
    CONSTRAINT uk_products_tenant_ean UNIQUE (tenant_id, ean) WHERE ean IS NOT NULL,
    CONSTRAINT uk_products_tenant_upc UNIQUE (tenant_id, upc) WHERE upc IS NOT NULL,
    CONSTRAINT uk_products_tenant_mpn_brand UNIQUE (tenant_id, mpn, brand_id) WHERE mpn IS NOT NULL
);

COMMENT ON TABLE products.products IS 'Produits de base (version canonique)';
COMMENT ON COLUMN products.products.canonical_sku_id IS 'Référence au SKU canonique (défini dans SKUCanonical)';
COMMENT ON COLUMN products.products.gtin IS 'Global Trade Item Number (GTIN-14, GTIN-13, GTIN-12)';
COMMENT ON COLUMN products.products.ean IS 'European Article Number (EAN-13)';
COMMENT ON COLUMN products.products.upc IS 'Universal Product Code (UPC-12)';
COMMENT ON COLUMN products.products.mpn IS 'Manufacturer Part Number';

-- Index
CREATE INDEX idx_products_tenant ON products.products(tenant_id);
CREATE INDEX idx_products_brand ON products.products(brand_id);
CREATE INDEX idx_products_category ON products.products(category_id);
CREATE INDEX idx_products_canonical_sku ON products.products(canonical_sku_id);
CREATE INDEX idx_products_gtin ON products.products(gtin) WHERE gtin IS NOT NULL;
CREATE INDEX idx_products_ean ON products.products(ean) WHERE ean IS NOT NULL;
CREATE INDEX idx_products_upc ON products.products(upc) WHERE upc IS NOT NULL;

-- ================================================================
-- TABLE: products.product_variants
-- ================================================================
-- Description: Variations d'un produit (taille, couleur, etc.)
-- ================================================================

CREATE TABLE products.product_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    product_id UUID NOT NULL REFERENCES products.products(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Identifiants
    sku VARCHAR(100) NOT NULL,  -- SKU du variant
    name VARCHAR(255),
    
    -- Attributs de variation
    attributes JSONB NOT NULL DEFAULT '{}'::jsonb,  -- { 'size': 'L', 'color': 'Red', 'material': 'Cotton' }
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT uk_variants_tenant_product_sku UNIQUE (tenant_id, product_id, sku),
    CONSTRAINT ck_variants_attributes CHECK (jsonb_typeof(attributes) = 'object')
);

COMMENT ON TABLE products.product_variants IS 'Variations d''un produit (taille, couleur, etc.)';
COMMENT ON COLUMN products.product_variants.sku IS 'SKU unique du variant';
COMMENT ON COLUMN products.product_variants.attributes IS 'Attributs de variation (JSONB)';

-- Index
CREATE INDEX idx_variants_product ON products.product_variants(product_id);
CREATE INDEX idx_variants_tenant ON products.product_variants(tenant_id);
CREATE INDEX idx_variants_sku ON products.product_variants(sku);
CREATE INDEX idx_variants_attributes ON products.product_variants USING GIN(attributes);

-- ================================================================
-- TABLE: products.product_images
-- ================================================================
-- Description: Images des produits (pour le matching visuel)
-- ================================================================

CREATE TABLE products.product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    product_id UUID REFERENCES products.products(id) ON DELETE CASCADE,
    variant_id UUID REFERENCES products.product_variants(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Identifiants
    url VARCHAR(500) NOT NULL,
    image_hash VARCHAR(64),  -- SHA-256 hash pour déduplication
    
    -- Métadonnées
    is_primary BOOLEAN DEFAULT FALSE,
    display_order INTEGER DEFAULT 0,
    alt_text VARCHAR(500),
    
    -- Vecteur d'embedding (référence Qdrant)
    embedding_id VARCHAR(100),  -- ID dans Qdrant
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    width INTEGER,
    height INTEGER,
    file_size_bytes BIGINT,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT ck_images_product_or_variant CHECK (
        (product_id IS NOT NULL AND variant_id IS NULL) OR
        (product_id IS NULL AND variant_id IS NOT NULL)
    )
);

COMMENT ON TABLE products.product_images IS 'Images des produits (pour le matching visuel)';
COMMENT ON COLUMN products.product_images.image_hash IS 'SHA-256 hash pour la déduplication';
COMMENT ON COLUMN products.product_images.embedding_id IS 'Identifiant du vecteur d''embedding dans Qdrant';
COMMENT ON COLUMN products.product_images.is_primary IS 'Image principale du produit';

-- Index
CREATE INDEX idx_images_product ON products.product_images(product_id) WHERE product_id IS NOT NULL;
CREATE INDEX idx_images_variant ON products.product_images(variant_id) WHERE variant_id IS NOT NULL;
CREATE INDEX idx_images_tenant ON products.product_images(tenant_id);
CREATE INDEX idx_images_hash ON products.product_images(image_hash);
CREATE INDEX idx_images_embedding ON products.product_images(embedding_id) WHERE embedding_id IS NOT NULL;

-- ================================================================
-- TABLE: products.product_attributes
-- ================================================================
-- Description: Attributs structurés des produits
-- ================================================================

CREATE TABLE products.product_attributes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    product_id UUID REFERENCES products.products(id) ON DELETE CASCADE,
    variant_id UUID REFERENCES products.product_variants(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Attribut
    attribute_name VARCHAR(100) NOT NULL,
    attribute_value TEXT NOT NULL,
    attribute_type VARCHAR(50) DEFAULT 'string',  -- 'string', 'number', 'boolean', 'date', 'json'
    
    -- Métadonnées
    unit VARCHAR(20),         -- Unité de mesure (ex: 'kg', 'cm')
    is_searchable BOOLEAN DEFAULT TRUE,
    is_filterable BOOLEAN DEFAULT TRUE,
    display_order INTEGER DEFAULT 0,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT ck_attributes_product_or_variant CHECK (
        (product_id IS NOT NULL AND variant_id IS NULL) OR
        (product_id IS NULL AND variant_id IS NOT NULL)
    ),
    CONSTRAINT ck_attributes_type CHECK (attribute_type IN ('string', 'number', 'boolean', 'date', 'json', 'url'))
);

COMMENT ON TABLE products.product_attributes IS 'Attributs structurés des produits';
COMMENT ON COLUMN products.product_attributes.attribute_name IS 'Nom de l''attribut (ex: "weight", "color", "material")';
COMMENT ON COLUMN products.product_attributes.attribute_value IS 'Valeur de l''attribut';
COMMENT ON COLUMN products.product_attributes.attribute_type IS 'Type de l''attribut (string/number/boolean/date/json/url)';
COMMENT ON COLUMN products.product_attributes.unit IS 'Unité de mesure (ex: kg, cm, L)';

-- Index
CREATE INDEX idx_attributes_product ON products.product_attributes(product_id) WHERE product_id IS NOT NULL;
CREATE INDEX idx_attributes_variant ON products.product_attributes(variant_id) WHERE variant_id IS NOT NULL;
CREATE INDEX idx_attributes_tenant ON products.product_attributes(tenant_id);
CREATE INDEX idx_attributes_name ON products.product_attributes(attribute_name);
CREATE INDEX idx_attributes_type ON products.product_attributes(attribute_type);
CREATE INDEX idx_attributes_searchable ON products.product_attributes(attribute_name, attribute_value) 
    WHERE is_searchable = TRUE;

-- ================================================================
-- TABLE: products.sku_canonical
-- ================================================================
-- Description: SKU universel - résultat du Réconciliateur
--              (alimenté par matching multimodal)
-- ================================================================

CREATE TABLE products.sku_canonical (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    sku_hash VARCHAR(64) NOT NULL,  -- SHA-256 du SKU unifié
    
    -- Informations produit
    name VARCHAR(500) NOT NULL,
    description TEXT,
    brand_id UUID REFERENCES products.brands(id) ON DELETE SET NULL,
    category_id UUID REFERENCES products.categories(id) ON DELETE SET NULL,
    
    -- Identifiants externes (agrégés)
    gtin VARCHAR(14),
    ean VARCHAR(13),
    upc VARCHAR(12),
    mpn VARCHAR(100),
    isbn VARCHAR(13),
    
    -- Attributs consolidés
    attributes JSONB DEFAULT '{}'::jsonb,
    
    -- Résultat du réconciliateur
    confidence_score DECIMAL(5,4) NOT NULL DEFAULT 0,  -- 0-1
    matching_status VARCHAR(50) NOT NULL DEFAULT 'pending',  -- 'pending', 'auto', 'human_review', 'human_validated'
    matched_by UUID,  -- Utilisateur ou agent qui a validé
    matched_at TIMESTAMPTZ,
    
    -- Sources d'alimentation (traçabilité MERCURE)
    source_event_ids JSONB DEFAULT '[]'::jsonb,
    source_products JSONB DEFAULT '[]'::jsonb,  -- Liste des product_ids fusionnés
    
    -- Vecteurs d'embedding (références Qdrant)
    text_embedding_id VARCHAR(100),    -- Embedding du texte
    image_embedding_ids JSONB DEFAULT '[]'::jsonb,  -- IDs des embeddings d'images
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    is_primary BOOLEAN DEFAULT TRUE,  -- SKU canonique principal
    
    -- Audit
    version INTEGER DEFAULT 1,  -- Version du SKU (incrémentée à chaque mise à jour)
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT uk_canonical_tenant_sku_hash UNIQUE (tenant_id, sku_hash),
    CONSTRAINT ck_canonical_confidence CHECK (confidence_score BETWEEN 0 AND 1),
    CONSTRAINT ck_canonical_status CHECK (matching_status IN ('pending', 'auto', 'human_review', 'human_validated', 'rejected'))
);

COMMENT ON TABLE products.sku_canonical IS 'SKU universel - résultat du Réconciliateur';
COMMENT ON COLUMN products.sku_canonical.sku_hash IS 'Hash SHA-256 unique du SKU unifié (tenant + identifiants)';
COMMENT ON COLUMN products.sku_canonical.confidence_score IS 'Score de confiance du réconciliateur (0-1)';
COMMENT ON COLUMN products.sku_canonical.matching_status IS 'Statut du matching (pending/auto/human_review/human_validated/rejected)';
COMMENT ON COLUMN products.sku_canonical.source_event_ids IS 'IDs des événements MERCURE ayant alimenté ce SKU';
COMMENT ON COLUMN products.sku_canonical.source_products IS 'IDs des products.products fusionnés dans ce SKU';
COMMENT ON COLUMN products.sku_canonical.text_embedding_id IS 'Identifiant du vecteur d''embedding texte dans Qdrant';
COMMENT ON COLUMN products.sku_canonical.image_embedding_ids IS 'IDs des vecteurs d''embedding d''images dans Qdrant';

-- Index
CREATE INDEX idx_canonical_tenant ON products.sku_canonical(tenant_id);
CREATE INDEX idx_canonical_hash ON products.sku_canonical(sku_hash);
CREATE INDEX idx_canonical_brand ON products.sku_canonical(brand_id);
CREATE INDEX idx_canonical_category ON products.sku_canonical(category_id);
CREATE INDEX idx_canonical_gtin ON products.sku_canonical(gtin) WHERE gtin IS NOT NULL;
CREATE INDEX idx_canonical_ean ON products.sku_canonical(ean) WHERE ean IS NOT NULL;
CREATE INDEX idx_canonical_upc ON products.sku_canonical(upc) WHERE upc IS NOT NULL;
CREATE INDEX idx_canonical_confidence ON products.sku_canonical(confidence_score DESC);
CREATE INDEX idx_canonical_status ON products.sku_canonical(matching_status) WHERE matching_status != 'rejected';
CREATE INDEX idx_canonical_text_embedding ON products.sku_canonical(text_embedding_id) WHERE text_embedding_id IS NOT NULL;

-- ================================================================
-- TABLE: products.sku_aliases
-- ================================================================
-- Description: Alias et correspondances entre SKUs (MERCURE → Canonical)
-- ================================================================

CREATE TABLE products.sku_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    canonical_sku_id UUID NOT NULL REFERENCES products.sku_canonical(id) ON DELETE CASCADE,
    
    -- Alias (SKU externe)
    alias_sku VARCHAR(255) NOT NULL,
    source_system VARCHAR(50) NOT NULL,  -- 'mercure', 'manual', 'legion', 'external_api'
    source_marketplace_id UUID REFERENCES market.marketplaces(id) ON DELETE SET NULL,
    
    -- Métadonnées
    confidence_score DECIMAL(5,4) DEFAULT 1.0,
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT uk_aliases_tenant_source UNIQUE (tenant_id, alias_sku, source_system)
);

COMMENT ON TABLE products.sku_aliases IS 'Alias et correspondances entre SKUs (MERCURE → Canonical)';
COMMENT ON COLUMN products.sku_aliases.alias_sku IS 'SKU externe (alias) provenant d''une source';
COMMENT ON COLUMN products.sku_aliases.source_system IS 'Système source (mercure/manual/legion/external_api)';
COMMENT ON COLUMN products.sku_aliases.confidence_score IS 'Score de confiance de la correspondance (0-1)';
COMMENT ON COLUMN products.sku_aliases.is_active IS 'Si vrai, l''alias est toujours actif';

-- Index
CREATE INDEX idx_aliases_canonical ON products.sku_aliases(canonical_sku_id);
CREATE INDEX idx_aliases_tenant ON products.sku_aliases(tenant_id);
CREATE INDEX idx_aliases_alias ON products.sku_aliases(alias_sku);
CREATE INDEX idx_aliases_source ON products.sku_aliases(source_system);
CREATE INDEX idx_aliases_marketplace ON products.sku_aliases(source_marketplace_id) WHERE source_marketplace_id IS NOT NULL;
CREATE INDEX idx_aliases_active ON products.sku_aliases(is_active, canonical_sku_id) WHERE is_active = TRUE;

-- ================================================================
-- FONCTIONS UTILITAIRES POUR LES PRODUITS
-- ================================================================

-- Fonction pour générer le hash SKU canonique
CREATE OR REPLACE FUNCTION products.generate_sku_hash(
    p_tenant_id UUID,
    p_gtin VARCHAR(14),
    p_ean VARCHAR(13),
    p_upc VARCHAR(12),
    p_mpn VARCHAR(100),
    p_name VARCHAR(500)
)
RETURNS VARCHAR(64) AS $$
DECLARE
    v_hash_string TEXT;
    v_hash VARCHAR(64);
BEGIN
    -- Construire une chaîne unique à partir des identifiants disponibles
    v_hash_string := COALESCE(p_gtin, '') || '|' ||
                     COALESCE(p_ean, '') || '|' ||
                     COALESCE(p_upc, '') || '|' ||
                     COALESCE(p_mpn, '') || '|' ||
                     COALESCE(p_name, '');
    
    -- Hacher avec SHA-256
    v_hash := ENCODE(DIGEST(v_hash_string, 'sha256'), 'hex');
    
    RETURN v_hash;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION products.generate_sku_hash IS 'Génère un hash SHA-256 pour le SKU canonique';

-- Fonction pour obtenir la catégorie complète (chemin)
CREATE OR REPLACE FUNCTION products.get_category_path(
    p_category_id UUID
)
RETURNS TEXT AS $$
DECLARE
    v_path TEXT;
BEGIN
    WITH RECURSIVE category_tree AS (
        SELECT id, name, parent_category_id, 1 AS level
        FROM products.categories
        WHERE id = p_category_id
        
        UNION ALL
        
        SELECT c.id, c.name, c.parent_category_id, ct.level + 1
        FROM products.categories c
        JOIN category_tree ct ON c.id = ct.parent_category_id
    )
    SELECT string_agg(name, ' › ' ORDER BY level DESC)
    INTO v_path
    FROM category_tree;
    
    RETURN v_path;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION products.get_category_path IS 'Retourne le chemin complet d''une catégorie (ex: "Électronique › Smartphones › iPhone")';

-- Trigger pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION products.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer le trigger aux tables
CREATE TRIGGER tr_brands_update BEFORE UPDATE ON products.brands
    FOR EACH ROW EXECUTE FUNCTION products.update_updated_at_column();

CREATE TRIGGER tr_categories_update BEFORE UPDATE ON products.categories
    FOR EACH ROW EXECUTE FUNCTION products.update_updated_at_column();

CREATE TRIGGER tr_products_update BEFORE UPDATE ON products.products
    FOR EACH ROW EXECUTE FUNCTION products.update_updated_at_column();

CREATE TRIGGER tr_variants_update BEFORE UPDATE ON products.product_variants
    FOR EACH ROW EXECUTE FUNCTION products.update_updated_at_column();

CREATE TRIGGER tr_images_update BEFORE UPDATE ON products.product_images
    FOR EACH ROW EXECUTE FUNCTION products.update_updated_at_column();

CREATE TRIGGER tr_attributes_update BEFORE UPDATE ON products.product_attributes
    FOR EACH ROW EXECUTE FUNCTION products.update_updated_at_column();

CREATE TRIGGER tr_canonical_update BEFORE UPDATE ON products.sku_canonical
    FOR EACH ROW EXECUTE FUNCTION products.update_updated_at_column();

CREATE TRIGGER tr_aliases_update BEFORE UPDATE ON products.sku_aliases
    FOR EACH ROW EXECUTE FUNCTION products.update_updated_at_column();

-- ================================================================
-- RÉSUMÉ DU SCHÉMA PRODUCTS
-- ================================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│                  SCHÉMA PRODUCTS - RÉSUMÉ                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  brands           │ Marques des produits                         │
│  categories       │ Taxonomie des catégories (nested set)       │
│  products         │ Produits de base (version canonique)        │
│  product_variants │ Variations (taille, couleur, etc.)          │
│  product_images   │ Images pour matching visuel                 │
│  product_attributes│ Attributs structurés                       │
│  sku_canonical    │ SKU universel (Résultat Réconciliateur)     │
│  sku_aliases      │ Correspondances MERCURE → Canonical         │
│                                                                   │
│  Relations clés :                                                │
│  products → brand_id (brands)                                   │
│  products → category_id (categories)                            │
│  products → canonical_sku_id (sku_canonical)                    │
│  product_variants → product_id (products)                       │
│  product_images → product_id OR variant_id                      │
│  product_attributes → product_id OR variant_id                  │
│  sku_canonical → brand_id, category_id                          │
│  sku_aliases → canonical_sku_id (sku_canonical)                 │
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
    WHERE table_schema = 'products'
    AND table_type = 'BASE TABLE';
    
    IF table_count = 8 THEN
        RAISE NOTICE '✅ Toutes les tables du schéma products ont été créées (8/8)';
    ELSE
        RAISE NOTICE '⚠️ % tables sur 8 créées dans le schéma products', table_count;
    END IF;
END;
$$;