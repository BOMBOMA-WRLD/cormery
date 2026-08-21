-- ================================================================
-- CORMERY - Schéma AI (Intelligence Artificielle)
-- Version: 1.0.0
-- Date: 2026-08-07
-- Description: Tables pour les modèles, embeddings et prédictions
--              utilisées par OPTIMUS, Oracle, et LEGION
-- ================================================================

-- ================================================================
-- TABLE: ai.model_registry
-- ================================================================
-- Description: Registre des modèles ML utilisés dans CORMERY
--              Versioning, métadonnées, et suivi des performances
-- ================================================================

CREATE TABLE ai.model_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Identifiants
    model_id VARCHAR(100) NOT NULL UNIQUE,
    model_name VARCHAR(255) NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    model_type VARCHAR(50) NOT NULL,  -- 'embedding', 'classification', 'regression', 'forecasting', 'similarity'
    
    -- Framework
    framework VARCHAR(50) NOT NULL,  -- 'pytorch', 'tensorflow', 'sklearn', 'transformers'
    framework_version VARCHAR(50),
    model_format VARCHAR(50),  -- 'onnx', 'safetensors', 'h5', 'pickle'
    
    -- Stockage
    model_path VARCHAR(500) NOT NULL,  -- Chemin S3 ou local
    model_size_bytes BIGINT,
    model_hash VARCHAR(64),  -- SHA-256 du modèle
    
    -- Métadonnées
    description TEXT,
    task_description TEXT,
    input_schema JSONB,  -- Schéma des entrées
    output_schema JSONB,  -- Schéma des sorties
    hyperparameters JSONB DEFAULT '{}'::jsonb,
    
    -- Performance
    accuracy DECIMAL(5,4),
    precision DECIMAL(5,4),
    recall DECIMAL(5,4),
    f1_score DECIMAL(5,4),
    latency_ms INTEGER,
    batch_size INTEGER DEFAULT 1,
    
    -- Statut
    status VARCHAR(50) DEFAULT 'development',  -- 'development', 'staging', 'production', 'archived', 'deprecated'
    is_active BOOLEAN DEFAULT TRUE,
    deployed_at TIMESTAMPTZ,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_model_registry_type CHECK (model_type IN ('embedding', 'classification', 'regression', 'forecasting', 'similarity', 'clustering', 'recommendation')),
    CONSTRAINT ck_model_registry_framework CHECK (framework IN ('pytorch', 'tensorflow', 'sklearn', 'transformers', 'onnx', 'xgboost', 'lightgbm')),
    CONSTRAINT ck_model_registry_status CHECK (status IN ('development', 'staging', 'production', 'archived', 'deprecated'))
);

COMMENT ON TABLE ai.model_registry IS 'Registre des modèles ML utilisés dans CORMERY';
COMMENT ON COLUMN ai.model_registry.model_id IS 'Identifiant unique du modèle (ex: "bert-embedding-v2")';
COMMENT ON COLUMN ai.model_registry.model_type IS 'Type de modèle (embedding/classification/regression/forecasting/similarity)';
COMMENT ON COLUMN ai.model_registry.framework IS 'Framework utilisé (pytorch/tensorflow/sklearn/transformers)';
COMMENT ON COLUMN ai.model_registry.model_path IS 'Chemin de stockage du modèle (S3 ou local)';
COMMENT ON COLUMN ai.model_registry.status IS 'Statut du modèle (development/staging/production/archived/deprecated)';

-- Index
CREATE INDEX idx_model_registry_id ON ai.model_registry(model_id);
CREATE INDEX idx_model_registry_type ON ai.model_registry(model_type);
CREATE INDEX idx_model_registry_status ON ai.model_registry(status) WHERE status = 'production';
CREATE INDEX idx_model_registry_framework ON ai.model_registry(framework);
CREATE INDEX idx_model_registry_created ON ai.model_registry(created_at DESC);

-- ================================================================
-- TABLE: ai.embeddings
-- ================================================================
-- Description: Base des embeddings (texte et image)
--              Références vers Qdrant pour les vecteurs
-- ================================================================

CREATE TABLE ai.embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    model_id UUID NOT NULL REFERENCES ai.model_registry(id),
    
    -- Identifiant dans Qdrant
    vector_id VARCHAR(100) NOT NULL UNIQUE,
    collection_name VARCHAR(100) NOT NULL,
    
    -- Métadonnées
    embedding_type VARCHAR(50) NOT NULL,  -- 'text', 'image', 'multimodal'
    dimension INTEGER NOT NULL,
    
    -- Source
    source_type VARCHAR(50) NOT NULL,  -- 'product', 'image', 'sku', 'category'
    source_id UUID NOT NULL,
    source_hash VARCHAR(64),  -- Hash pour déduplication
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Qualité
    confidence_score DECIMAL(5,4) DEFAULT 0.95,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    deleted_at TIMESTAMPTZ,
    
    -- Contraintes
    CONSTRAINT ck_embeddings_type CHECK (embedding_type IN ('text', 'image', 'multimodal', 'audio', 'video')),
    CONSTRAINT ck_embeddings_source CHECK (source_type IN ('product', 'image', 'sku', 'category', 'brand', 'description')),
    CONSTRAINT ck_embeddings_confidence CHECK (confidence_score BETWEEN 0 AND 1)
);

COMMENT ON TABLE ai.embeddings IS 'Base des embeddings (texte et image) - Références vers Qdrant';
COMMENT ON COLUMN ai.embeddings.vector_id IS 'Identifiant du vecteur dans Qdrant';
COMMENT ON COLUMN ai.embeddings.collection_name IS 'Nom de la collection Qdrant';
COMMENT ON COLUMN ai.embeddings.embedding_type IS 'Type d''embedding (text/image/multimodal)';
COMMENT ON COLUMN ai.embeddings.dimension IS 'Dimension du vecteur d''embedding';
COMMENT ON COLUMN ai.embeddings.source_type IS 'Type de source (product/image/sku/category)';
COMMENT ON COLUMN ai.embeddings.source_hash IS 'Hash pour déduplication';

-- Index
CREATE INDEX idx_embeddings_tenant ON ai.embeddings(tenant_id);
CREATE INDEX idx_embeddings_model ON ai.embeddings(model_id);
CREATE INDEX idx_embeddings_vector ON ai.embeddings(vector_id);
CREATE INDEX idx_embeddings_type ON ai.embeddings(embedding_type);
CREATE INDEX idx_embeddings_source ON ai.embeddings(source_type, source_id);
CREATE INDEX idx_embeddings_hash ON ai.embeddings(source_hash) WHERE source_hash IS NOT NULL;
CREATE INDEX idx_embeddings_active ON ai.embeddings(is_active) WHERE is_active = TRUE;

-- ================================================================
-- TABLE: ai.text_embeddings
-- ================================================================
-- Description: Embeddings de texte (spécialisé)
--              Contient les métadonnées textuelles
-- ================================================================

CREATE TABLE ai.text_embeddings (
    -- Héritage
    embedding_id UUID PRIMARY KEY REFERENCES ai.embeddings(id) ON DELETE CASCADE,
    
    -- Texte source
    text_source TEXT NOT NULL,
    text_hash VARCHAR(64) NOT NULL,
    text_length INTEGER,
    language VARCHAR(10),
    
    -- Prétraitement
    preprocessed_text TEXT,
    token_count INTEGER,
    
    -- Métriques
    similarity_score DECIMAL(5,4),  -- Score de similarité avec d'autres textes
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE ai.text_embeddings IS 'Embeddings de texte (spécialisé)';
COMMENT ON COLUMN ai.text_embeddings.text_source IS 'Texte source original';
COMMENT ON COLUMN ai.text_embeddings.text_hash IS 'Hash du texte pour déduplication';
COMMENT ON COLUMN ai.text_embeddings.language IS 'Code de langue (ex: "fr", "en")';
COMMENT ON COLUMN ai.text_embeddings.token_count IS 'Nombre de tokens après tokenization';

-- Index
CREATE INDEX idx_text_embeddings_hash ON ai.text_embeddings(text_hash);
CREATE INDEX idx_text_embeddings_language ON ai.text_embeddings(language);
CREATE INDEX idx_text_embeddings_similarity ON ai.text_embeddings(similarity_score DESC);

-- ================================================================
-- TABLE: ai.image_embeddings
-- ================================================================
-- Description: Embeddings d'image (spécialisé)
--              Contient les métadonnées d'image
-- ================================================================

CREATE TABLE ai.image_embeddings (
    -- Héritage
    embedding_id UUID PRIMARY KEY REFERENCES ai.embeddings(id) ON DELETE CASCADE,
    
    -- Source image
    image_url VARCHAR(500) NOT NULL,
    image_hash VARCHAR(64) NOT NULL,
    image_width INTEGER,
    image_height INTEGER,
    image_size_bytes BIGINT,
    
    -- Traitement
    preprocessed_image TEXT,  -- Path ou référence
    quality_score DECIMAL(5,4),
    blur_score DECIMAL(5,4),
    
    -- Détection
    object_detected JSONB DEFAULT '{}'::jsonb,
    ocr_text TEXT,  -- Texte détecté dans l'image
    dominant_colors JSONB DEFAULT '[]'::jsonb,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE ai.image_embeddings IS 'Embeddings d''image (spécialisé)';
COMMENT ON COLUMN ai.image_embeddings.image_url IS 'URL de l''image source';
COMMENT ON COLUMN ai.image_embeddings.image_hash IS 'Hash de l''image pour déduplication';
COMMENT ON COLUMN ai.image_embeddings.quality_score IS 'Score de qualité de l''image (0-1)';
COMMENT ON COLUMN ai.image_embeddings.ocr_text IS 'Texte extrait de l''image par OCR';
COMMENT ON COLUMN ai.image_embeddings.dominant_colors IS 'Couleurs dominantes (JSONB)';

-- Index
CREATE INDEX idx_image_embeddings_hash ON ai.image_embeddings(image_hash);
CREATE INDEX idx_image_embeddings_quality ON ai.image_embeddings(quality_score DESC);
CREATE INDEX idx_image_embeddings_size ON ai.image_embeddings(image_size_bytes);

-- ================================================================
-- TABLE: ai.predictions
-- ================================================================
-- Description: Prédictions générées par les modèles ML
--              (Oracle, OPTIMUS, etc.)
-- ================================================================

CREATE TABLE ai.predictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    model_id UUID NOT NULL REFERENCES ai.model_registry(id),
    sku_id UUID REFERENCES products.sku_canonical(id) ON DELETE SET NULL,
    
    -- Type de prédiction
    prediction_type VARCHAR(50) NOT NULL,  -- 'price_trend', 'arbitrage_opportunity', 'stock_forecast', 'winning_product'
    
    -- Prédiction
    prediction_value JSONB NOT NULL,  -- Résultat de la prédiction
    confidence_score DECIMAL(5,4) NOT NULL,
    
    -- Contexte
    input_context JSONB DEFAULT '{}'::jsonb,  -- Contexte utilisé pour la prédiction
    features_used JSONB DEFAULT '{}'::jsonb,  -- Features importantes
    
    -- Période
    prediction_timeframe_start TIMESTAMPTZ,
    prediction_timeframe_end TIMESTAMPTZ,
    
    -- Statut
    status VARCHAR(50) DEFAULT 'active',  -- 'active', 'expired', 'superseded'
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    predicted_at TIMESTAMPTZ DEFAULT NOW(),
    validated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Contraintes
    CONSTRAINT ck_predictions_type CHECK (prediction_type IN ('price_trend', 'arbitrage_opportunity', 'stock_forecast', 'winning_product', 'zone_opportunity', 'seasonality')),
    CONSTRAINT ck_predictions_confidence CHECK (confidence_score BETWEEN 0 AND 1)
);

COMMENT ON TABLE ai.predictions IS 'Prédictions générées par les modèles ML (Oracle, OPTIMUS)';
COMMENT ON COLUMN ai.predictions.prediction_type IS 'Type de prédiction (price_trend/arbitrage_opportunity/stock_forecast/winning_product)';
COMMENT ON COLUMN ai.predictions.prediction_value IS 'Résultat de la prédiction (JSONB)';
COMMENT ON COLUMN ai.predictions.input_context IS 'Contexte utilisé pour la prédiction';
COMMENT ON COLUMN ai.predictions.prediction_timeframe_start IS 'Début de la période de validité de la prédiction';
COMMENT ON COLUMN ai.predictions.prediction_timeframe_end IS 'Fin de la période de validité de la prédiction';

-- Index
CREATE INDEX idx_predictions_tenant ON ai.predictions(tenant_id);
CREATE INDEX idx_predictions_model ON ai.predictions(model_id);
CREATE INDEX idx_predictions_sku ON ai.predictions(sku_id) WHERE sku_id IS NOT NULL;
CREATE INDEX idx_predictions_type ON ai.predictions(prediction_type);
CREATE INDEX idx_predictions_confidence ON ai.predictions(confidence_score DESC);
CREATE INDEX idx_predictions_status ON ai.predictions(status) WHERE status = 'active';
CREATE INDEX idx_predictions_timeframe ON ai.predictions(prediction_timeframe_start, prediction_timeframe_end);
CREATE INDEX idx_predictions_predicted_at ON ai.predictions(predicted_at DESC);

-- ================================================================
-- TABLE: ai.prediction_history
-- ================================================================
-- Description: Historique des prédictions pour suivi de performance
--              Comparaison prédiction vs réalité
-- ================================================================

CREATE TABLE ai.prediction_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    prediction_id UUID NOT NULL REFERENCES ai.predictions(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Prédiction originale
    predicted_value JSONB NOT NULL,
    predicted_at TIMESTAMPTZ NOT NULL,
    prediction_confidence DECIMAL(5,4) NOT NULL,
    
    -- Réalité (lorsqu'elle est connue)
    actual_value JSONB,
    actual_at TIMESTAMPTZ,
    error_metric VARCHAR(50),  -- 'mae', 'mse', 'mape', 'accuracy'
    error_value DECIMAL(10,4),
    
    -- Analyse
    accuracy_score DECIMAL(5,4),
    is_accurate BOOLEAN,
    deviation_percent DECIMAL(8,4),
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE ai.prediction_history IS 'Historique des prédictions pour suivi de performance';
COMMENT ON COLUMN ai.prediction_history.predicted_value IS 'Valeur prédite originale';
COMMENT ON COLUMN ai.prediction_history.actual_value IS 'Valeur réelle (lorsqu''elle est connue)';
COMMENT ON COLUMN ai.prediction_history.error_metric IS 'Métrique d''erreur (mae/mse/mape/accuracy)';
COMMENT ON COLUMN ai.prediction_history.accuracy_score IS 'Score de précision (0-1)';

-- Index
CREATE INDEX idx_prediction_history_prediction ON ai.prediction_history(prediction_id);
CREATE INDEX idx_prediction_history_tenant ON ai.prediction_history(tenant_id);
CREATE INDEX idx_prediction_history_accuracy ON ai.prediction_history(accuracy_score DESC);
CREATE INDEX idx_prediction_history_created ON ai.prediction_history(created_at DESC);

-- ================================================================
-- TABLE: ai.similarity_scores
-- ================================================================
-- Description: Scores de similarité entre produits pour le Réconciliateur
-- ================================================================

CREATE TABLE ai.similarity_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    source_sku_id UUID NOT NULL REFERENCES products.sku_canonical(id) ON DELETE CASCADE,
    target_sku_id UUID NOT NULL REFERENCES products.sku_canonical(id) ON DELETE CASCADE,
    
    -- Scores
    text_similarity DECIMAL(5,4),
    image_similarity DECIMAL(5,4),
    metadata_similarity DECIMAL(5,4),
    combined_similarity DECIMAL(5,4) NOT NULL,
    
    -- Métriques
    confidence_score DECIMAL(5,4) DEFAULT 0.95,
    match_quality VARCHAR(50),  -- 'exact', 'high', 'medium', 'low'
    
    -- Contexte
    comparison_context JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT ck_similarity_scores_sku CHECK (source_sku_id != target_sku_id),
    CONSTRAINT ck_similarity_scores_text CHECK (text_similarity BETWEEN 0 AND 1),
    CONSTRAINT ck_similarity_scores_image CHECK (image_similarity BETWEEN 0 AND 1),
    CONSTRAINT ck_similarity_scores_combined CHECK (combined_similarity BETWEEN 0 AND 1),
    CONSTRAINT ck_similarity_scores_match CHECK (match_quality IN ('exact', 'high', 'medium', 'low', 'none'))
);

COMMENT ON TABLE ai.similarity_scores IS 'Scores de similarité entre produits pour le Réconciliateur';
COMMENT ON COLUMN ai.similarity_scores.text_similarity IS 'Score de similarité textuelle (0-1)';
COMMENT ON COLUMN ai.similarity_scores.image_similarity IS 'Score de similarité visuelle (0-1)';
COMMENT ON COLUMN ai.similarity_scores.metadata_similarity IS 'Score de similarité des métadonnées (0-1)';
COMMENT ON COLUMN ai.similarity_scores.combined_similarity IS 'Score combiné global (0-1)';
COMMENT ON COLUMN ai.similarity_scores.match_quality IS 'Qualité du match (exact/high/medium/low/none)';

-- Index
CREATE INDEX idx_similarity_source ON ai.similarity_scores(source_sku_id);
CREATE INDEX idx_similarity_target ON ai.similarity_scores(target_sku_id);
CREATE INDEX idx_similarity_tenant ON ai.similarity_scores(tenant_id);
CREATE INDEX idx_similarity_score ON ai.similarity_scores(combined_similarity DESC);
CREATE INDEX idx_similarity_quality ON ai.similarity_scores(match_quality) WHERE match_quality IN ('exact', 'high');

-- ================================================================
-- TABLE: ai.recommendations
-- ================================================================
-- Description: Recommandations générées par Oracle pour les utilisateurs
-- ================================================================

CREATE TABLE ai.recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES identity.users(id) ON DELETE CASCADE,
    
    -- Type
    recommendation_type VARCHAR(50) NOT NULL,  -- 'arbitrage_opportunity', 'price_alert', 'stock_alert', 'winning_product'
    
    -- Contenu
    content JSONB NOT NULL,
    priority INTEGER DEFAULT 1,  -- 1 = haute, 5 = basse
    
    -- Statut
    status VARCHAR(50) DEFAULT 'pending',  -- 'pending', 'read', 'dismissed', 'acted_on'
    read_at TIMESTAMPTZ,
    acted_at TIMESTAMPTZ,
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE ai.recommendations IS 'Recommandations générées par Oracle pour les utilisateurs';
COMMENT ON COLUMN ai.recommendations.recommendation_type IS 'Type de recommandation (arbitrage_opportunity/price_alert/stock_alert/winning_product)';
COMMENT ON COLUMN ai.recommendations.content IS 'Contenu de la recommandation (JSONB)';
COMMENT ON COLUMN ai.recommendations.priority IS 'Priorité (1=haute, 5=basse)';
COMMENT ON COLUMN ai.recommendations.status IS 'Statut (pending/read/dismissed/acted_on)';

-- Index
CREATE INDEX idx_recommendations_tenant ON ai.recommendations(tenant_id);
CREATE INDEX idx_recommendations_user ON ai.recommendations(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_recommendations_type ON ai.recommendations(recommendation_type);
CREATE INDEX idx_recommendations_status ON ai.recommendations(status) WHERE status = 'pending';
CREATE INDEX idx_recommendations_priority ON ai.recommendations(priority);
CREATE INDEX idx_recommendations_expires ON ai.recommendations(expires_at) WHERE expires_at IS NOT NULL;

-- ================================================================
-- TABLE: ai.model_metrics
-- ================================================================
-- Description: Métriques de performance des modèles en production
-- ================================================================

CREATE TABLE ai.model_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Références
    model_id UUID NOT NULL REFERENCES ai.model_registry(id) ON DELETE CASCADE,
    tenant_id UUID REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    
    -- Métriques
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(10,4) NOT NULL,
    metric_type VARCHAR(50),  -- 'accuracy', 'latency', 'throughput', 'memory_usage'
    
    -- Contexte
    batch_id VARCHAR(100),
    dataset_name VARCHAR(100),
    dataset_size INTEGER,
    test_split VARCHAR(20),  -- 'train', 'validation', 'test'
    
    -- Métadonnées
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit
    recorded_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE ai.model_metrics IS 'Métriques de performance des modèles en production';
COMMENT ON COLUMN ai.model_metrics.metric_name IS 'Nom de la métrique (accuracy/latency/throughput/memory_usage)';
COMMENT ON COLUMN ai.model_metrics.metric_value IS 'Valeur de la métrique';
COMMENT ON COLUMN ai.model_metrics.test_split IS 'Split utilisé (train/validation/test)';

-- Index
CREATE INDEX idx_model_metrics_model ON ai.model_metrics(model_id);
CREATE INDEX idx_model_metrics_tenant ON ai.model_metrics(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX idx_model_metrics_name ON ai.model_metrics(metric_name);
CREATE INDEX idx_model_metrics_recorded ON ai.model_metrics(recorded_at DESC);

-- ================================================================
-- FONCTIONS UTILITAIRES POUR LE SCHÉMA AI
-- ================================================================

-- Fonction pour trouver les produits similaires
CREATE OR REPLACE FUNCTION ai.find_similar_products(
    p_sku_id UUID,
    p_tenant_id UUID,
    p_min_similarity DECIMAL(5,4) DEFAULT 0.7,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    similar_sku_id UUID,
    combined_similarity DECIMAL(5,4),
    text_similarity DECIMAL(5,4),
    image_similarity DECIMAL(5,4)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ss.target_sku_id,
        ss.combined_similarity,
        ss.text_similarity,
        ss.image_similarity
    FROM ai.similarity_scores ss
    WHERE ss.source_sku_id = p_sku_id
        AND ss.tenant_id = p_tenant_id
        AND ss.combined_similarity >= p_min_similarity
        AND ss.match_quality IN ('exact', 'high')
    ORDER BY ss.combined_similarity DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION ai.find_similar_products IS 'Trouve les produits similaires à un SKU donné';

-- Fonction pour obtenir la dernière prédiction d'un SKU
CREATE OR REPLACE FUNCTION ai.get_latest_prediction(
    p_sku_id UUID,
    p_prediction_type VARCHAR(50),
    p_tenant_id UUID
)
RETURNS JSONB AS $$
DECLARE
    prediction_value JSONB;
BEGIN
    SELECT p.prediction_value INTO prediction_value
    FROM ai.predictions p
    WHERE p.sku_id = p_sku_id
        AND p.prediction_type = p_prediction_type
        AND p.tenant_id = p_tenant_id
        AND p.status = 'active'
        AND p.prediction_timeframe_end >= NOW()
    ORDER BY p.predicted_at DESC
    LIMIT 1;
    
    RETURN prediction_value;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION ai.get_latest_prediction IS 'Récupère la dernière prédiction active pour un SKU';

-- Fonction pour enregistrer les métriques de similarité
CREATE OR REPLACE FUNCTION ai.record_similarity(
    p_source_sku_id UUID,
    p_target_sku_id UUID,
    p_tenant_id UUID,
    p_combined_similarity DECIMAL(5,4),
    p_text_similarity DECIMAL(5,4) DEFAULT NULL,
    p_image_similarity DECIMAL(5,4) DEFAULT NULL,
    p_metadata_similarity DECIMAL(5,4) DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_match_quality VARCHAR(50);
    v_id UUID;
BEGIN
    -- Déterminer la qualité du match
    CASE
        WHEN p_combined_similarity >= 0.95 THEN v_match_quality := 'exact';
        WHEN p_combined_similarity >= 0.85 THEN v_match_quality := 'high';
        WHEN p_combined_similarity >= 0.70 THEN v_match_quality := 'medium';
        WHEN p_combined_similarity >= 0.50 THEN v_match_quality := 'low';
        ELSE v_match_quality := 'none';
    END CASE;
    
    -- Insérer ou mettre à jour
    INSERT INTO ai.similarity_scores (
        tenant_id,
        source_sku_id,
        target_sku_id,
        text_similarity,
        image_similarity,
        metadata_similarity,
        combined_similarity,
        match_quality,
        calculated_at
    ) VALUES (
        p_tenant_id,
        p_source_sku_id,
        p_target_sku_id,
        p_text_similarity,
        p_image_similarity,
        p_metadata_similarity,
        p_combined_similarity,
        v_match_quality,
        NOW()
    )
    ON CONFLICT (tenant_id, source_sku_id, target_sku_id) 
    DO UPDATE SET
        text_similarity = EXCLUDED.text_similarity,
        image_similarity = EXCLUDED.image_similarity,
        metadata_similarity = EXCLUDED.metadata_similarity,
        combined_similarity = EXCLUDED.combined_similarity,
        match_quality = EXCLUDED.match_quality,
        calculated_at = EXCLUDED.calculated_at
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION ai.record_similarity IS 'Enregistre ou met à jour les scores de similarité entre deux SKUs';

-- Trigger pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION ai.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer le trigger
CREATE TRIGGER tr_model_registry_update BEFORE UPDATE ON ai.model_registry
    FOR EACH ROW EXECUTE FUNCTION ai.update_updated_at_column();

CREATE TRIGGER tr_embeddings_update BEFORE UPDATE ON ai.embeddings
    FOR EACH ROW EXECUTE FUNCTION ai.update_updated_at_column();

CREATE TRIGGER tr_predictions_update BEFORE UPDATE ON ai.predictions
    FOR EACH ROW EXECUTE FUNCTION ai.update_updated_at_column();

CREATE TRIGGER tr_prediction_history_update BEFORE UPDATE ON ai.prediction_history
    FOR EACH ROW EXECUTE FUNCTION ai.update_updated_at_column();

CREATE TRIGGER tr_similarity_update BEFORE UPDATE ON ai.similarity_scores
    FOR EACH ROW EXECUTE FUNCTION ai.update_updated_at_column();

CREATE TRIGGER tr_recommendations_update BEFORE UPDATE ON ai.recommendations
    FOR EACH ROW EXECUTE FUNCTION ai.update_updated_at_column();

-- ================================================================
-- VUES UTILITAIRES POUR LE SCHÉMA AI
-- ================================================================

-- Vue des modèles en production
CREATE OR REPLACE VIEW ai.v_production_models AS
SELECT 
    mr.model_id,
    mr.model_name,
    mr.model_version,
    mr.model_type,
    mr.framework,
    mr.accuracy,
    mr.latency_ms,
    mr.deployed_at,
    mr.status,
    COALESCE(
        (SELECT AVG(mm.metric_value) 
         FROM ai.model_metrics mm 
         WHERE mm.model_id = mr.id 
           AND mm.metric_name = 'accuracy'
           AND mm.recorded_at >= NOW() - INTERVAL '7 days'
        ), mr.accuracy
    ) AS last_week_accuracy
FROM ai.model_registry mr
WHERE mr.status = 'production'
    AND mr.is_active = TRUE;

COMMENT ON VIEW ai.v_production_models IS 'Modèles actuellement en production';

-- Vue des prédictions récentes avec SKU
CREATE OR REPLACE VIEW ai.v_recent_predictions AS
SELECT 
    p.id,
    p.tenant_id,
    p.sku_id,
    sc.name AS product_name,
    p.prediction_type,
    p.prediction_value,
    p.confidence_score,
    p.predicted_at,
    p.prediction_timeframe_start,
    p.prediction_timeframe_end,
    p.status
FROM ai.predictions p
JOIN products.sku_canonical sc ON p.sku_id = sc.id
WHERE p.status = 'active'
    AND p.predicted_at >= NOW() - INTERVAL '24 hours'
ORDER BY p.confidence_score DESC;

COMMENT ON VIEW ai.v_recent_predictions IS 'Prédictions actives des dernières 24 heures';

-- ================================================================
-- RÉSUMÉ DU SCHÉMA AI
-- ================================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│                    SCHÉMA AI - RÉSUMÉ                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  model_registry      │ Registre des modèles ML                   │
│  embeddings          │ Base des embeddings (Qdrant)              │
│  text_embeddings     │ Embeddings de texte (spécialisé)         │
│  image_embeddings    │ Embeddings d''image (spécialisé)         │
│  predictions         │ Prédictions (Oracle, OPTIMUS)            │
│  prediction_history  │ Historique pour suivi performance        │
│  similarity_scores   │ Scores de similarité (Réconciliateur)    │
│  recommendations     │ Recommandations pour utilisateurs        │
│  model_metrics       │ Métriques de performance                 │
│                                                                   │
│  Intégrations :                                                  │
│  • Qdrant (vecteurs)    → embeddings.vector_id                  │
│  • OPTIMUS              → predictions (arbitrage_opportunity)   │
│  • Oracle               → predictions (winning_product)        │
│  • Réconciliateur       → similarity_scores                     │
│  • LEGION               → model_registry (inference)            │
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
    WHERE table_schema = 'ai'
    AND table_type = 'BASE TABLE';
    
    IF table_count = 9 THEN
        RAISE NOTICE '✅ Toutes les tables du schéma AI ont été créées (9/9)';
        RAISE NOTICE '📊 Modèles: %', (SELECT COUNT(*) FROM ai.model_registry);
        RAISE NOTICE '📊 Embeddings: %', (SELECT COUNT(*) FROM ai.embeddings);
        RAISE NOTICE '📊 Prédictions: %', (SELECT COUNT(*) FROM ai.predictions);
    ELSE
        RAISE NOTICE '⚠️ % tables sur 9 créées dans le schéma AI', table_count;
    END IF;
END;
$$;