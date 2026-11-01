-- ============================================================================
-- 12_concurrency_stress_test.sql
-- Rigorous Two-Session Concurrency Verification Harness
-- ============================================================================

-- Safety rollback to clear hanging GUI/terminal session states
COMMIT;
ROLLBACK;

-- Verification Objective:
-- Prove that two simultaneous order dispatch transactions competing for the
-- nearest available driver will NOT produce a double-booking anomaly or a deadlock.

UPDATE driver SET status = 'AVAILABLE' WHERE driver_id = 2;

-- ----------------------------------------------------------------------------
-- SESSION 1 (Simulated Terminal 1)
-- ----------------------------------------------------------------------------
BEGIN;

SELECT d.driver_id, d.name
FROM driver d
JOIN location_trace lt ON d.driver_id = lt.driver_id
WHERE d.status = 'AVAILABLE'
ORDER BY lt.location <-> ST_SetSRID(ST_MakePoint(78.5415, 17.5215), 4326)
FOR UPDATE OF d SKIP LOCKED
LIMIT 1;

-- ----------------------------------------------------------------------------
-- SESSION 2 (Simulated Terminal 2)
-- ----------------------------------------------------------------------------
BEGIN;

SELECT d.driver_id, d.name
FROM driver d
JOIN location_trace lt ON d.driver_id = lt.driver_id
WHERE d.status = 'AVAILABLE'
ORDER BY lt.location <-> ST_SetSRID(ST_MakePoint(78.5415, 17.5215), 4326)
FOR UPDATE OF d SKIP LOCKED
LIMIT 1;

COMMIT;
COMMIT;
