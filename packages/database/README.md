# CORMERY — Architecture & Spécifications de la Base de Données

Ce document constitue la référence d'architecture pour le moteur de données relationnel et temporel de **CORMERY**. 

CORMERY est un système décisionnel spatio-temporel opérant à échelle industrielle. Sa base de données combine **PostgreSQL 17** pour le domaine transactionnel, la multi-tenancy et la cohérence forte, avec **TimescaleDB** pour l'ingestion à très haute fréquence et l'analyse décisionnelle de séries temporelles (prix, vélocité publicitaire, contextes macroéconomiques et géopolitiques).

---

## Sommaire

1. [Vue d'Ensemble & Piliers Systèmes](#1-vue-densemble--piliers-systèmes)
2. [PostgreSQL 17 — Choix Moteur & Apports](#2-postgresql-17--choix-moteur--apports)
3. [TimescaleDB — Gestion des Séries Temporelles](#3-timescaledb--gestion-des-séries-temporelles)
4. [Architecture Multi-Tenant (RLS)](#4-architecture-multi-tenant-rls)
5. [Immutabilité & Event Sourcing (CQRS)](#5-immutabilité--event-sourcing-cqrs)
6. [Stratégie de Partitionnement Spatio-Temporel](#6-stratégie-de-partitionnement-spatio-temporel)
7. [Indexation Avancée & Performance](#7-indexation-avancée--performance)
8. [Réplication, Haute Disponibilité & CDC](#8-réplication-haute-disponibilité--cdc)
9. [Optimisation Système & Tuning Mémoire](#9-optimisation-système--tuning-mémoire)
10. [Conventions SQL & Typage Strict](#10-conventions-sql--typage-strict)
11. [Stratégie de Migration Zero-Downtime](#11-stratégie-de-migration-zero-downtime)

---

## 1. Vue d'Ensemble & Piliers Systèmes

La base de données CORMERY dessert quatre sous-systèmes métier interconnectés :
### A. Hypertables Déclarées
1. **`price_observations`** : Partitionnée sur `time` (intervalle : 1 jour).
2. **`zone_metrics`** : Partitionnée sur `time` (intervalle : 7 jours).
3. **`arbitrage_results`** : Partitionnée sur `time` (intervalle : 1 jour).

### B. Compression Columnar Automatique
Les données temporelles anciennes passent automatiquement d'un format de stockage en ligne (Row-based OLTP) à un format hybride columnar orienté analytique :

```sql
-- Activation de la compression columnar sur price_observations
ALTER TABLE price_observations SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'sku_canonical_id, zone_id',
    timescaledb.compress_orderby = 'time DESC'
);

-- Politique : Compresser les chunks de plus de 7 jours
SELECT add_compression_policy('price_observations', INTERVAL '7 days');
