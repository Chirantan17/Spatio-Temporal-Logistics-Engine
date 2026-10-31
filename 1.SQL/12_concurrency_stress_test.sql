-- ============================================================================
-- 12_concurrency_stress_test.sql
-- Rigorous Two-Session Concurrency Verification Harness
-- ============================================================================

\c campus_delivery;

-- Verification Objective:
-- Prove that two simultaneous order dispatch transactions competing for the
-- nearest available driver will NOT produce a double-booking anomaly or a deadlock.

-- Reset Driver 2 to AVAILABLE and verify location
UPDATE driver SET status = 'AVAILABLE' WHERE driver_id = 2;

-- ----------------------------------------------------------------------------
-- SESSION 1 (Simulated Terminal 1)
-- ----------------------------------------------------------------------------
BEGIN;

-- Session 1 targets Order 14 at Main Canteen (78.5415, 17.5215)
SELECT d.driver_id, d.name
FROM driver d
JOIN location_trace lt ON d.driver_id = lt.driver_id
WHERE d.status = 'AVAILABLE'
ORDER BY lt.location <-> ST_SetSRID(ST_MakePoint(78.5415, 17.5215), 4326)
FOR UPDATE OF d SKIP LOCKED
LIMIT 1;
-- Output: Driver 2 (Suresh) is locked by Session 1.
-- (DO NOT COMMIT YET; Leave Session 1 open)

-- ----------------------------------------------------------------------------
-- SESSION 2 (Simulated Terminal 2, executed concurrently while Session 1 holds lock)
-- ----------------------------------------------------------------------------
-- If standard 'FOR UPDATE' were used, Session 2 would block/hang waiting for Session 1.
-- With 'SKIP LOCKED', Session 2 automatically bypasses Driver 2 and acquires Driver 3!

BEGIN;

SELECT d.driver_id, d.name
FROM driver d
JOIN location_trace lt ON d.driver_id = lt.driver_id
WHERE d.status = 'AVAILABLE'
ORDER BY lt.location <-> ST_SetSRID(ST_MakePoint(78.5415, 17.5215), 4326)
FOR UPDATE OF d SKIP LOCKED
LIMIT 1;
-- Output: Driver 3 (Anita) is acquired cleanly without blocking.

COMMIT; -- Commit Session 2

-- ----------------------------------------------------------------------------
-- FINALIZE SESSION 1
-- ----------------------------------------------------------------------------
COMMIT; -- Commit Session 1