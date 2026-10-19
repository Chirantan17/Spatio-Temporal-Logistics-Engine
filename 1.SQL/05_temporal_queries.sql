-- ============================================================================
-- 3. PURE TEMPORAL QUERIES (Time-Series & Window Aggregations)
-- ============================================================================

-- Q5.1: Retrieve orders placed within the last 2 hours (Initial check)
SELECT o.order_id, c.name AS customer_name, o.status, o.created_at
FROM "order" o
JOIN customer c ON o.customer_id = c.customer_id
WHERE o.created_at >= CURRENT_TIMESTAMP - INTERVAL '2 hours';

-- Create a new real-time order with valid seed foreign keys and corresponding line item
BEGIN;
INSERT INTO "order" (customer_id, restaurant_id, driver_id, destination_id, status, delivery_fee, created_at, fulfilled_at)
VALUES (3, 1, NULL, 3, 'PENDING', 0.00, CURRENT_TIMESTAMP, NULL);

INSERT INTO order_item (order_id, item_id, restaurant_id, quantity, price_at_order)
VALUES (currval(pg_get_serial_sequence('"order"', 'order_id'))::INT, 1, 1, 1, 120.00);
COMMIT;

-- Q5.1-2: Retrieve orders placed within the last 2 hours (Demonstrates newly inserted order)
SELECT o.order_id, c.name AS customer_name, o.status, o.created_at
FROM "order" o
JOIN customer c ON o.customer_id = c.customer_id
WHERE o.created_at >= CURRENT_TIMESTAMP - INTERVAL '2 hours';

-- Q5.2: Fulfillment Duration - Compute average delivery time (in minutes) per canteen
SELECT r.name AS restaurant_name,
       COUNT(o.order_id) AS completed_orders,
       ROUND(AVG(EXTRACT(EPOCH FROM (o.fulfilled_at - o.created_at)) / 60.0)::numeric, 2) AS avg_fulfillment_minutes
FROM "order" o
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'DELIVERED' AND o.fulfilled_at IS NOT NULL
GROUP BY r.restaurant_id, r.name;

-- Insert real-time telemetry GPS pings for active drivers (Driver 1 & 2) to guarantee live results
INSERT INTO location_trace (driver_id, location, recorded_at)
VALUES 
    (1, ST_SetSRID(ST_MakePoint(78.5415, 17.5215), 4326), CURRENT_TIMESTAMP),
    (2, ST_SetSRID(ST_MakePoint(78.5435, 17.5235), 4326), CURRENT_TIMESTAMP);

-- Q5.3: Driver Telemetry Frequency - Count GPS telemetry pings per driver in the last hour
SELECT driver_id, COUNT(*) AS total_pings, MAX(recorded_at) AS latest_ping_time
FROM location_trace
WHERE recorded_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
GROUP BY driver_id
ORDER BY driver_id;

-- Q5.4: LIVE CUSTOMER DYNAMIC PRICING ENGINE
-- Dynamically calculates the exact price a customer would pay right now based on local campus time
SELECT mi.name AS item_name, 
       r.name AS canteen,
       mi.serve_start_time, 
       mi.serve_end_time,
       mi.price AS standard_catalog_price,
       CASE 
           WHEN (CURRENT_TIME AT TIME ZONE 'Asia/Kolkata')::time BETWEEN mi.serve_start_time AND mi.serve_end_time THEN mi.price
           ELSE mi.price * 1.5 
       END AS live_dynamic_price,
       CASE 
           WHEN (CURRENT_TIME AT TIME ZONE 'Asia/Kolkata')::time BETWEEN mi.serve_start_time AND mi.serve_end_time THEN 'Available at Standard Rate'
           ELSE 'Out of Standard Window (1.5x Surge Applied)' 
       END AS pricing_status
FROM menu_item mi
JOIN restaurant r ON mi.restaurant_id = r.restaurant_id
ORDER BY pricing_status DESC, mi.name ASC;