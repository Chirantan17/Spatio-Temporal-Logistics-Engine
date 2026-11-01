-- ============================================================================
-- CS G516: Advanced Database Systems
-- 05_temporal_queries.sql: Temporal Windows and Telemetry Recency
-- ============================================================================

\c campus_delivery;

-- Q5.1: Active Shift Orders
SELECT o.order_id, c.name AS customer_name, o.status, o.created_at
FROM "order" o
JOIN customer c ON o.customer_id = c.customer_id
WHERE o.created_at >= CURRENT_DATE;

-- Q5.2: Average Delivery Turnaround Latency by Canteen
SELECT r.name AS restaurant_name,
       COUNT(o.order_id) AS completed_orders,
       ROUND(AVG(EXTRACT(EPOCH FROM (o.fulfilled_at - o.created_at)) / 60)::numeric, 1) AS avg_fulfillment_minutes
FROM "order" o
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'DELIVERED'
GROUP BY r.name;

-- Q5.3: Driver Telemetry Heartbeat Recency
SELECT driver_id, COUNT(trace_id) AS total_pings, MAX(recorded_at) AS latest_ping_time
FROM location_trace
GROUP BY driver_id;

-- Q5.4: Detection of Ghost Drivers (Heartbeat Gap > 45 Seconds)
SELECT d.driver_id, d.name AS driver_name, o.order_id,
       ROUND(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(lt.recorded_at)))::numeric, 0) AS seconds_since_last_ping
FROM driver d
JOIN location_trace lt ON d.driver_id = lt.driver_id
LEFT JOIN "order" o ON d.driver_id = o.driver_id AND o.status = 'IN_TRANSIT'
WHERE d.status = 'AVAILABLE' OR o.status = 'IN_TRANSIT'
GROUP BY d.driver_id, d.name, o.order_id
HAVING EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(lt.recorded_at))) > 45;
