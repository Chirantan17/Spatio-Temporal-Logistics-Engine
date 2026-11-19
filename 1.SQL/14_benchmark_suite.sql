-- ============================================================================
-- CS G516: REPRODUCIBLE INDEXING & QUERY OPTIMIZATION BENCHMARK SUITE
-- Safely simulates 50,000 sequential GPS pings inside a ROLLBACK transaction
-- to measure real disk footprints (pg_relation_size) and KNN latency.
-- ============================================================================

BEGIN;

-- 1. Ensure target indexes exist
CREATE INDEX IF NOT EXISTS idx_location_trace_gist ON location_trace USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_location_trace_brin_time ON location_trace USING BRIN (recorded_at) WITH (pages_per_range = 128);
CREATE INDEX IF NOT EXISTS idx_order_active_hotpath ON "order" (restaurant_id, created_at) WHERE status IN ('PENDING', 'PREPARING', 'READY');

-- 2. Generate 50,000 chronological GPS observations across BPHC campus bounds
INSERT INTO location_trace (driver_id, location, speed_kmh, recorded_at)
SELECT 
    (g % 10) + 1,
    ST_SetSRID(ST_MakePoint(78.5370 + (random() * 0.013), 17.5200 + (random() * 0.006)), 4326),
    ROUND((random() * 25)::numeric, 2),
    CURRENT_TIMESTAMP - ((50000 - g) * INTERVAL '5 seconds')
FROM generate_series(1, 50000) AS g;

-- Create temporary standard B-Tree on timestamp for direct size comparison
CREATE INDEX idx_temp_btree_time ON location_trace USING BTREE (recorded_at);
ANALYZE location_trace;

-- 3. Compare Index Disk Footprint (B-Tree vs BRIN vs GiST vs Partial)
SELECT 
    'Standard B-Tree (recorded_at)' AS index_strategy,
    pg_size_pretty(pg_relation_size('idx_temp_btree_time')) AS disk_footprint,
    ROUND(pg_relation_size('idx_temp_btree_time') / 1024.0, 1) AS size_kb
UNION ALL
SELECT 
    'BRIN Index (recorded_at, pages_per_range=128)',
    pg_size_pretty(pg_relation_size('idx_location_trace_brin_time')),
    ROUND(pg_relation_size('idx_location_trace_brin_time') / 1024.0, 1)
UNION ALL
SELECT 
    'GiST Spatial R-Tree (location)',
    pg_size_pretty(pg_relation_size('idx_location_trace_gist')),
    ROUND(pg_relation_size('idx_location_trace_gist') / 1024.0, 1)
UNION ALL
SELECT 
    'Partial Hot-Path Index (Active Orders Only)',
    pg_size_pretty(pg_relation_size('idx_order_active_hotpath')),
    ROUND(pg_relation_size('idx_order_active_hotpath') / 1024.0, 1);

-- 4. Benchmark Spatial KNN (<->) Execution: GiST Index Scan vs Forced Seq Scan
DO $$
DECLARE
    t0 TIMESTAMPTZ; t1 TIMESTAMPTZ;
    v_gist_ms NUMERIC; v_seq_ms NUMERIC;
    v_pt geometry := ST_SetSRID(ST_MakePoint(78.5415, 17.5215), 4326);
BEGIN
    t0 := clock_timestamp();
    FOR i IN 1..20 LOOP
        PERFORM driver_id FROM location_trace ORDER BY location <-> v_pt LIMIT 1;
    END LOOP;
    t1 := clock_timestamp();
    v_gist_ms := ROUND((EXTRACT(EPOCH FROM (t1 - t0)) * 1000.0 / 20.0)::numeric, 3);

    PERFORM set_config('enable_indexscan', 'off', true);
    PERFORM set_config('enable_bitmapscan', 'off', true);
    t0 := clock_timestamp();
    FOR i IN 1..20 LOOP
        PERFORM driver_id FROM location_trace ORDER BY location <-> v_pt LIMIT 1;
    END LOOP;
    t1 := clock_timestamp();
    v_seq_ms := ROUND((EXTRACT(EPOCH FROM (t1 - t0)) * 1000.0 / 20.0)::numeric, 3);

    RAISE NOTICE 'GiST Index KNN Avg: % ms | Forced Seq Scan Avg: % ms | Speedup: %x',
        v_gist_ms, v_seq_ms, ROUND(v_seq_ms / GREATEST(v_gist_ms, 0.001), 1);
END $$;

-- Cleanly rollback synthetic test rows so seed data stays untouched
ROLLBACK;
