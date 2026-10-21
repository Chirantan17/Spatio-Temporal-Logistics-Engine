-- Q5.1: Retrieve orders placed within the last 2 hours
SELECT o.order_id, c.name AS customer_name, o.status, o.created_at
FROM "order" o
JOIN customer c ON o.customer_id = c.customer_id
WHERE o.created_at >= CURRENT_TIMESTAMP - INTERVAL '2 hours';

-- Q5.2: Average Delivery Time per Canteen
SELECT r.name AS restaurant_name,
       COUNT(o.order_id) AS completed_orders,
       ROUND(AVG(EXTRACT(EPOCH FROM (o.fulfilled_at - o.created_at)) / 60.0)::numeric, 2) AS avg_fulfillment_minutes
FROM "order" o
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'DELIVERED' AND o.fulfilled_at IS NOT NULL
GROUP BY r.restaurant_id, r.name;

-- Q5.3: Driver Telemetry Heartbeat - Telemetry pings in the last 15 minutes
SELECT driver_id, COUNT(*) AS total_pings, MAX(recorded_at) AS latest_ping_time
FROM location_trace
WHERE recorded_at >= CURRENT_TIMESTAMP - INTERVAL '15 minutes'
GROUP BY driver_id
ORDER BY driver_id;

-- Q5.4: Ghost Driver Detector (Telemetry Inactive > 45 Seconds on Active Delivery)
SELECT d.driver_id, d.name AS driver_name, o.order_id,
       EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(lt.recorded_at))) AS seconds_since_last_ping
FROM driver d
JOIN "order" o ON d.driver_id = o.driver_id
JOIN location_trace lt ON d.driver_id = lt.driver_id
WHERE o.status = 'IN_TRANSIT'
GROUP BY d.driver_id, d.name, o.order_id
HAVING EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(lt.recorded_at))) > 45;