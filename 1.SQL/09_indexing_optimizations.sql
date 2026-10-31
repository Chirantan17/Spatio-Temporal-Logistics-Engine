\c campus_delivery;

-- 1. SPATIAL ACCESS METHODS (GiST)
DROP INDEX IF EXISTS idx_location_trace_gist;
CREATE INDEX idx_location_trace_gist ON location_trace USING GIST (location);

DROP INDEX IF EXISTS idx_campus_zone_boundary_gist;
CREATE INDEX idx_campus_zone_boundary_gist ON campus_zone USING GIST (boundary);

-- 2. TEMPORAL STORAGE OPTIMIZATIONS (BRIN)
-- Rationale: location_trace records arrive sequentially. BRIN reduces 98% of index overhead vs B-Tree.
DROP INDEX IF EXISTS idx_location_trace_brin_time;
CREATE INDEX idx_location_trace_brin_time ON location_trace USING BRIN (recorded_at) WITH (pages_per_range = 128);

-- 3. PARTIAL INDEXES FOR ACTIVE HOT-PATHS
-- Excludes historical 'DELIVERED'/'CANCELLED' orders to keep RAM footprint sub-millisecond
DROP INDEX IF EXISTS idx_order_active_hotpath;
CREATE INDEX idx_order_active_hotpath ON "order" (restaurant_id, created_at) 
WHERE status IN ('PENDING', 'PREPARING', 'READY');

-- Isolates available fleet members for PostGIS KNN dispatch calculations (Fixes Audit 5.C.1)
DROP INDEX IF EXISTS idx_driver_available_pool;
CREATE INDEX idx_driver_available_pool ON driver (driver_id) WHERE status = 'AVAILABLE';

-- 4. PHYSICAL CLUSTERING
CLUSTER location_trace USING idx_location_trace_gist;
ANALYZE "order"; ANALYZE location_trace;
