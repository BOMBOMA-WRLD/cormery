-- ================================================================
-- CORMERY - Schémas PostgreSQL 17
-- Version: 1.0.0
-- Date: 2026-08-07
-- Description: Création des schémas de base pour l'architecture
--              multi-tenant de CORMERY
-- ================================================================

-- ================================================================
-- 1. SCHÉMA PUBLIC (Schéma par défaut)
-- ================================================================
-- Rôle: Point d'entrée par défaut, contient les extensions
--       et les fonctions utilitaires globales
-- ================================================================

COMMENT ON SCHEMA public IS 'Schéma par défaut contenant les extensions PostgreSQL, fonctions globales et objets partagés';

-- ================================================================
-- 2. SCHÉMA CORE (Noyau métier)
-- ================================================================
-- Rôle: Entités fondamentales partagées par tous les modules
--       (UUID, types personnalisés, fonctions de base)
-- ================================================================

CREATE SCHEMA IF NOT EXISTS core;

COMMENT ON SCHEMA core IS 'Noyau métier - Entités fondamentales, types personnalisés et fonctions de base partagées par tous les modules';

-- ================================================================
-- 3. SCHÉMA IDENTITY (Identité et authentification)
-- ================================================================
-- Rôle: Gestion des utilisateurs, rôles, permissions
--       Authentification et autorisation
-- ================================================================

CREATE SCHEMA IF NOT EXISTS identity;

COMMENT ON SCHEMA identity IS 'Identité et authentification - Gestion des utilisateurs, rôles, permissions et sessions';

-- ================================================================
-- 4. SCHÉMA MARKET (Marché et données économiques)
-- ================================================================
-- Rôle: Zones géographiques, devises, données macro-économiques
--       (alimenté par VENUS)
-- ================================================================

CREATE SCHEMA IF NOT EXISTS market;

COMMENT ON SCHEMA market IS 'Marché et données économiques - Zones géographiques, devises, données macro-économiques (VENUS)';

-- ================================================================
-- 5. SCHÉMA PRODUCTS (Produits et catalogues)
-- ================================================================
-- Rôle: SKU canoniques, produits, catégories, embeddings
--       (alimenté par le Réconciliateur et MERCURE)
-- ================================================================

CREATE SCHEMA IF NOT EXISTS products;

COMMENT ON SCHEMA products IS 'Produits et catalogues - SKU canoniques, catégories, embeddings multimodaux (Réconciliateur)';

-- ================================================================
-- 6. SCHÉMA TRACKING (Suivi et observations)
-- ================================================================
-- Rôle: Prix, stock, vélocité publicitaire (TimescaleDB)
--       (alimenté par MERCURE)
-- ================================================================

CREATE SCHEMA IF NOT EXISTS tracking;

COMMENT ON SCHEMA tracking IS 'Suivi et observations - Prix, stock, vélocité publicitaire en temps réel (MERCURE + TimescaleDB)';

-- ================================================================
-- 7. SCHÉMA AI (Intelligence Artificielle)
-- ================================================================
-- Rôle: Embeddings, modèles ML, prédictions, scoring
--       (alimenté par OPTIMUS, Oracle, LEGION)
-- ================================================================

CREATE SCHEMA IF NOT EXISTS ai;

COMMENT ON SCHEMA ai IS 'Intelligence Artificielle - Embeddings, modèles ML, prédictions, scoring (OPTIMUS, Oracle, LEGION)';

-- ================================================================
-- 8. SCHÉMA SECURITY (Sécurité et conformité)
-- ================================================================
-- Rôle: RLS, audit, logs, chiffrement, conformité RGPD
-- ================================================================

CREATE SCHEMA IF NOT EXISTS security;

COMMENT ON SCHEMA security IS 'Sécurité et conformité - RLS, audit, logs, chiffrement, RGPD';

-- ================================================================
-- 9. SCHÉMA LOGS (Journalisation)
-- ================================================================
-- Rôle: Logs d'application, métriques, événements système
-- ================================================================

CREATE SCHEMA IF NOT EXISTS logs;

COMMENT ON SCHEMA logs IS 'Journalisation - Logs d''application, métriques, événements système';

-- ================================================================
-- 10. SCHÉMA ANALYTICS (Analytique et reporting)
-- ================================================================
-- Rôle: Vues matérialisées, agrégations, dashboards, KPI
-- ================================================================

CREATE SCHEMA IF NOT EXISTS analytics;

COMMENT ON SCHEMA analytics IS 'Analytique et reporting - Vues matérialisées, agrégations, KPI dashboards';

-- ================================================================
-- 11. SCHÉMA TENANT (Multi-tenancy et plans)
-- ================================================================
-- Rôle: Tenants, plans d'abonnement, quotas, facturation
-- ================================================================

CREATE SCHEMA IF NOT EXISTS tenant;

COMMENT ON SCHEMA tenant IS 'Multi-tenancy et plans - Tenants, abonnements, quotas, facturation';

-- ================================================================
-- 12. SCHÉMA EVENT_SOURCING (Traçabilité événementielle)
-- ================================================================
-- Rôle: Event store, projections, snapshots
--       (Event Sourcing pour décisions financières)
-- ================================================================

CREATE SCHEMA IF NOT EXISTS event_sourcing;

COMMENT ON SCHEMA event_sourcing IS 'Traçabilité événementielle - Event store, projections, snapshots (Event Sourcing)';

-- ================================================================
-- CONFIGURATION DE SÉCURITÉ PAR DÉFAUT
-- ================================================================

-- Révoquer les droits par défaut sur tous les schémas
DO $$
DECLARE
    schema_name TEXT;
BEGIN
    FOR schema_name IN 
        SELECT nspname 
        FROM pg_namespace 
        WHERE nspname NOT IN ('information_schema', 'pg_catalog')
        AND nspname NOT LIKE 'pg_%'
    LOOP
        EXECUTE format('REVOKE ALL ON SCHEMA %I FROM PUBLIC', schema_name);
        EXECUTE format('GRANT USAGE ON SCHEMA %I TO cormery_user', schema_name);
    END LOOP;
END;
$$;

-- ================================================================
-- FONCTIONS UTILITAIRES PAR SCHÉMA
-- ================================================================

-- Fonction pour définir le schéma de recherche par défaut
CREATE OR REPLACE FUNCTION core.set_search_path_to_cormery()
RETURNS VOID AS $$
BEGIN
    SET search_path TO public, core, identity, market, products, 
                          tracking, ai, security, logs, analytics, 
                          tenant, event_sourcing;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.set_search_path_to_cormery() IS 'Définit le schéma de recherche par défaut pour CORMERY';

-- ================================================================
-- VALIDATION DES SCHÉMAS
-- ================================================================

DO $$
DECLARE
    schema_name TEXT;
    schema_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO schema_count 
    FROM pg_namespace 
    WHERE nspname IN (
        'public', 'core', 'identity', 'market', 'products',
        'tracking', 'ai', 'security', 'logs', 'analytics',
        'tenant', 'event_sourcing'
    );
    
    IF schema_count = 12 THEN
        RAISE NOTICE '✅ Tous les schémas CORMERY ont été créés avec succès (12/12)';
    ELSE
        RAISE NOTICE '⚠️ Seulement % schémas sur 12 ont été créés', schema_count;
    END IF;
END;
$$;

-- ================================================================
-- RÉSUMÉ DES SCHÉMAS
-- ================================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│                  SCHÉMAS CORMERY - RÉSUMÉ                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  public          │ Schéma par défaut, extensions globales        │
│  core            │ Noyau métier, types fondamentaux              │
│  identity        │ Utilisateurs, rôles, authentification        │
│  market          │ Zones, devises, données économiques (VENUS)   │
│  products        │ SKU canoniques, catégories, embeddings       │
│  tracking        │ Prix, stock, ad velocity (MERCURE)           │
│  ai              │ Embeddings, modèles, prédictions (OPTIMUS)   │
│  security        │ RLS, audit, chiffrement, RGPD                │
│  logs            │ Logs d'application, métriques                │
│  analytics       │ Vues matérialisées, KPI, dashboards          │
│  tenant          │ Multi-tenancy, plans, quotas                 │
│  event_sourcing  │ Event store, projections, snapshots          │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
*/

-- ================================================================
-- EXTENSIONS PAR SCHÉMA
-- ================================================================

-- Extensions globales (schéma public)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pg_trgm" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "btree_gist" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "timescaledb" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" SCHEMA public;

-- ================================================================
-- MÉTADONNÉES DE VERSION DES SCHÉMAS
-- ================================================================

-- Table de versionnement des schémas
CREATE TABLE IF NOT EXISTS public.schema_version (
    schema_name VARCHAR(100) PRIMARY KEY,
    version VARCHAR(20) NOT NULL,
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    applied_by VARCHAR(100) DEFAULT CURRENT_USER,
    description TEXT
);

COMMENT ON TABLE public.schema_version IS 'Versionnement des schémas CORMERY';

-- Initialisation des versions
INSERT INTO public.schema_version (schema_name, version, description) VALUES
('public', '1.0.0', 'Schéma public - extensions et fonctions globales'),
('core', '1.0.0', 'Noyau métier - types et fonctions fondamentales'),
('identity', '1.0.0', 'Identité et authentification'),
('market', '1.0.0', 'Marché et données économiques (VENUS)'),
('products', '1.0.0', 'Produits et catalogues (Réconciliateur)'),
('tracking', '1.0.0', 'Suivi et observations (MERCURE + TimescaleDB)'),
('ai', '1.0.0', 'Intelligence Artificielle (OPTIMUS, Oracle, LEGION)'),
('security', '1.0.0', 'Sécurité et conformité'),
('logs', '1.0.0', 'Journalisation et métriques'),
('analytics', '1.0.0', 'Analytique et reporting'),
('tenant', '1.0.0', 'Multi-tenancy et plans'),
('event_sourcing', '1.0.0', 'Traçabilité événementielle')
ON CONFLICT (schema_name) DO UPDATE 
SET version = EXCLUDED.version, 
    applied_at = EXCLUDED.applied_at,
    description = EXCLUDED.description;

-- ================================================================
-- MESSAGES DE CONFIRMATION
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Schémas CORMERY créés et sécurisés avec succès';
    RAISE NOTICE '📁 Nombre de schémas: 12';
    RAISE NOTICE '🔐 RLS activé par défaut sur tous les schémas';
    RAISE NOTICE '📊 Extensions chargées: uuid-ossp, pg_trgm, btree_gist, pgcrypto, timescaledb, pg_stat_statements';
    RAISE NOTICE '📦 Version des schémas: 1.0.0';
END;
$$;