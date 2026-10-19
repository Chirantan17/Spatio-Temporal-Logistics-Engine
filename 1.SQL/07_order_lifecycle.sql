-- ============================================================================
-- 07_order_lifecycle.sql - End-to-End Transaction & Spatiotemporal Execution
-- ============================================================================
-- Purpose: This script walks the faculty through a complete order lifecycle 
-- using pure raw SQL. It visually outputs the exact table state after EVERY 
-- single action to prove the database logic is actively functioning in real-time.
--
-- Note for IC: We utilize `currval(pg_get_serial_sequence())` so this script 
-- is 100% dynamic and targets the newly created order automatically.
-- ============================================================================

-- ============================================================================
-- STEP 1: ORDER CREATION (ACID Transaction)
-- Customer 3 (Amit Verma) orders 2x Veg Thali and 1x Cold Coffee from Canteen 1.
-- Delivery location: Hostel Gate (Destination 3).
-- ============================================================================
BEGIN;

-- Insert Transaction Header (status: 'PENDING', driver: NULL)
INSERT INTO "order" (customer_id, restaurant_id, driver_id, destination_id, status, delivery_fee, created_at, fulfilled_at)
VALUES (3, 1, NULL, 3, 'PENDING', 0.00, CURRENT_TIMESTAMP, NULL);

-- Insert Line Items with Historical Price Snapshots
INSERT INTO order_item (order_id, item_id, restaurant_id, quantity, price_at_order)
VALUES 
(currval(pg_get_serial_sequence('"order"', 'order_id'))::INT, 1, 1, 2, 120.00), -- 2x Veg Thali
(currval(pg_get_serial_sequence('"order"', 'order_id'))::INT, 2, 1, 1, 70.00);  -- 1x Cold Coffee

COMMIT;

-- 🟢 PROOF 1: Display the newly inserted relational data and dynamic View total (Expected: 310.00)
SELECT order_id, customer_id, restaurant_id, status, created_at 
FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT;

SELECT order_id, item_id, quantity, price_at_order 
FROM order_item WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT;

SELECT order_id, total_amount AS dynamic_invoice_total 
FROM order_total WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT;


-- ============================================================================
-- STEP 2: CANTEEN ACCEPTANCE
-- The Canteen acknowledges the order and begins cooking.
-- ============================================================================
UPDATE "order" 
SET status = 'PREPARING' 
WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT 
  AND status = 'PENDING';

-- 🟢 PROOF 2: Show the order status has successfully changed to PREPARING
SELECT order_id, status AS current_order_status 
FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT;


-- ============================================================================
-- STEP 3: SPATIAL DRIVER DISPATCH
-- The system automatically finds the closest 'AVAILABLE' driver to Canteen 1 via GiST KNN.
-- ============================================================================
WITH nearest_driver AS (
    SELECT d.driver_id 
    FROM driver d 
    JOIN location_trace lt ON d.driver_id = lt.driver_id
    JOIN restaurant r ON r.restaurant_id = 1 
    WHERE d.status = 'AVAILABLE'
    ORDER BY lt.location <-> r.location 
    LIMIT 1
)
UPDATE "order" 
SET driver_id = (SELECT driver_id FROM nearest_driver), status = 'IN_TRANSIT' 
WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT;

-- Instantly update that assigned driver's workforce status to prevent double-booking
UPDATE driver 
SET status = 'BUSY' 
WHERE driver_id = (SELECT driver_id FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT);

-- 🟢 PROOF 3: Show the order is now IN_TRANSIT with a driver, and the driver is BUSY
SELECT order_id, driver_id AS assigned_driver, status AS current_order_status 
FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT;

SELECT driver_id, name, status AS workforce_status 
FROM driver WHERE driver_id = (SELECT driver_id FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT);


-- ============================================================================
-- STEP 4: TELEMETRY & AUTOMATED PICKUP (GEOFENCING)
-- The assigned driver physically reaches Canteen 1, sending a GPS ping.
-- ============================================================================
INSERT INTO location_trace (driver_id, location, recorded_at)
VALUES (
    (SELECT driver_id FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT),
    ST_SetSRID(ST_MakePoint(78.5415, 17.5215), 4326), 
    CURRENT_TIMESTAMP
);

-- 🟢 PROOF 4: Show the live telemetry ping, then prove they are within the 30m pickup geofence
SELECT trace_id, driver_id, location, recorded_at 
FROM location_trace ORDER BY trace_id DESC LIMIT 1;

SELECT ST_DWithin(lt.location::geography, r.location::geography, 30.0) AS pickup_geofence_valid
FROM location_trace lt, restaurant r 
WHERE lt.driver_id = (SELECT driver_id FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT)
  AND r.restaurant_id = 1
ORDER BY lt.recorded_at DESC LIMIT 1;


-- ============================================================================
-- STEP 5: DELIVERY COMPLETION & WORKFORCE RELEASE
-- The driver successfully drops off the food at the destination.
-- ============================================================================
-- Free the driver back into the dispatch pool
UPDATE driver 
SET status = 'AVAILABLE' 
WHERE driver_id = (SELECT driver_id FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT);

-- Close the order and lock in the fulfillment timestamp
UPDATE "order" 
SET status = 'DELIVERED', fulfilled_at = CURRENT_TIMESTAMP 
WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT;

-- 🟢 PROOF 5: Show the order is finalized with a timestamp, and the driver is ready for a new task
SELECT order_id, driver_id, status AS final_order_status, fulfilled_at 
FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT;

SELECT driver_id, name, status AS workforce_status 
FROM driver WHERE driver_id = (SELECT driver_id FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT);


-- ============================================================================
-- FINAL SYSTEM AUDIT
-- Expected Output: 0 Rows. 
-- Proves that no logical anomalies (like a missing driver or stranded order) 
-- occurred during this complex lifecycle sequence.
-- ============================================================================
SELECT * FROM integrity_audit;