-- ============================================================================
-- STEP 1: ORDER CREATION (ACID Transaction)
-- Customer 1 (Rahul Sharma) orders 2x Veg Thali and 1x Chicken Biryani (Total 3 items)
-- ============================================================================
BEGIN;

INSERT INTO "order" (customer_id, restaurant_id, driver_id, destination_id, status, delivery_fee, created_at)
VALUES (1, 1, NULL, 6, 'PENDING', 15.00, CURRENT_TIMESTAMP);

INSERT INTO order_item (order_id, item_id, restaurant_id, quantity, price_at_order)
VALUES 
(currval(pg_get_serial_sequence('"order"', 'order_id'))::INT, 1, 1, 2, 120.00), -- 2 items
(currval(pg_get_serial_sequence('"order"', 'order_id'))::INT, 2, 1, 1, 180.00); -- 1 item

COMMIT;

-- Verify 3 items placed (Requires 3 bag units)
SELECT order_id, total_amount FROM order_total 
WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT;

-- ============================================================================
-- STEP 2: KITCHEN ACCEPTS ONTO STOVES
-- ============================================================================
UPDATE "order" 
SET status = 'PREPARING' 
WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT;

-- ============================================================================
-- STEP 3: SPATIAL DISPATCH & BAG CAPACITY VERIFICATION
-- Finds closest online driver to Main Canteen with >= 3 open bag slots
-- ============================================================================
WITH qualified_driver AS (
    SELECT d.driver_id 
    FROM driver d 
    JOIN driver_bag_capacity_view bcv ON d.driver_id = bcv.driver_id
    JOIN location_trace lt ON d.driver_id = lt.driver_id
    JOIN restaurant r ON r.restaurant_id = 1 
    WHERE d.status != 'OFFLINE' 
      AND bcv.remaining_slots >= 3
    ORDER BY lt.location <-> r.location 
    LIMIT 1
)
UPDATE "order" 
SET driver_id = (SELECT driver_id FROM qualified_driver), status = 'IN_TRANSIT' 
WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT;

-- Check updated bag state
SELECT * FROM driver_bag_capacity_view 
WHERE driver_id = (SELECT driver_id FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT);

-- ============================================================================
-- STEP 4: TELEMETRY & 30M GEOFENCE CHECK
-- ============================================================================
INSERT INTO location_trace (driver_id, location, recorded_at)
VALUES (
    (SELECT driver_id FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT),
    ST_SetSRID(ST_MakePoint(78.5415, 17.5215), 4326), 
    CURRENT_TIMESTAMP
);

SELECT ST_DWithin(lt.location::geography, r.location::geography, 30.0) AS within_pickup_geofence
FROM location_trace lt, restaurant r 
WHERE lt.driver_id = (SELECT driver_id FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT)
  AND r.restaurant_id = 1
ORDER BY lt.recorded_at DESC LIMIT 1;

-- ============================================================================
-- STEP 5: DELIVERY COMPLETION & BAG CAPACITY RELEASE
-- ============================================================================
UPDATE "order" 
SET status = 'DELIVERED', fulfilled_at = CURRENT_TIMESTAMP 
WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT;

-- Proves driver's bag slots are freed back up for subsequent batches
SELECT * FROM driver_bag_capacity_view 
WHERE driver_id = (SELECT driver_id FROM "order" WHERE order_id = currval(pg_get_serial_sequence('"order"', 'order_id'))::INT);

-- ============================================================================
-- FINAL SYSTEM AUDIT
-- Expected Output: 0 Rows (No orphan line items, no offline drivers holding orders, no bag breaches)
-- ============================================================================
SELECT * FROM integrity_audit;