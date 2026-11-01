-- ============================================================================
-- CS G516: Advanced Database Systems
-- 12_concurrency_stress_test.sql: Two-Session Concurrency Verification Harness
-- ============================================================================

-- Reset Driver pool status to clean baseline
UPDATE driver SET status = 'AVAILABLE' WHERE driver_id IN (1, 2, 3);

-- ----------------------------------------------------------------------------
-- TRANSACTION 1: Simulating Order Dispatch Worker 1
-- ----------------------------------------------------------------------------
BEGIN;

-- Worker 1 requests nearest driver at Main Canteen (78.5415, 17.5215)
-- Locks candidate tuple using row-level locking (SKIP LOCKED)
SELECT 
    d.driver_id, 
    d.name, 
    'Worker 1 (First Acquired)' AS lock_holder
FROM driver d
JOIN location_trace lt ON d.driver_id = lt.driver_id
WHERE d.status = 'AVAILABLE'
ORDER BY lt.location <-> ST_SetSRID(ST_MakePoint(78.5415, 17.5215), 4326)
FOR UPDATE OF d SKIP LOCKED
LIMIT 1;

COMMIT;

-- ----------------------------------------------------------------------------
-- TRANSACTION 2: Simulating Order Dispatch Worker 2 (Non-blocking Next Best)
-- ----------------------------------------------------------------------------
BEGIN;

-- Worker 2 runs concurrently for the same hub.
-- SKIP LOCKED prevents blocking/deadlocks and cleanly allocates the next available candidate.
SELECT 
    d.driver_id, 
    d.name, 
    'Worker 2 (Next Candidate via SKIP LOCKED)' AS lock_holder
FROM driver d
JOIN location_trace lt ON d.driver_id = lt.driver_id
WHERE d.status = 'AVAILABLE'
ORDER BY lt.location <-> ST_SetSRID(ST_MakePoint(78.5415, 17.5215), 4326)
FOR UPDATE OF d SKIP LOCKED
LIMIT 1;

COMMIT;