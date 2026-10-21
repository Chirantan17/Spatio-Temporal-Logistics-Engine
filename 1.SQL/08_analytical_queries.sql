-- ============================================================================
-- 08_analytical_queries.sql - Advanced Analytical Queries & Business Intelligence
-- ============================================================================

-- A8.1: Driver Bag Utilization & Stowage Efficiency
-- Computes the average, maximum, and percentage saturation of thermal bag capacity 
-- per active driver across in-progress deliveries.
WITH driver_stowage AS (
    SELECT d.driver_id,
           d.name AS driver_name,
           r.name AS staged_hub,
           d.status AS workforce_status,
           COALESCE(SUM(oi.quantity), 0) AS total_items_stowed,
           d.max_bag_capacity
    FROM driver d
    LEFT JOIN restaurant r ON d.staging_restaurant_id = r.restaurant_id
    LEFT JOIN "order" o ON d.driver_id = o.driver_id AND o.status IN ('PREPARING', 'IN_TRANSIT')
    LEFT JOIN order_item oi ON o.order_id = oi.order_id
    GROUP BY d.driver_id, d.name, r.name, d.status, d.max_bag_capacity
)
SELECT driver_id,
       driver_name,
       staged_hub,
       workforce_status,
       total_items_stowed,
       max_bag_capacity,
       ROUND((total_items_stowed::numeric / max_bag_capacity * 100), 1) AS bag_utilization_pct,
       CASE 
           WHEN total_items_stowed = 0 THEN 'Empty Bag'
           WHEN total_items_stowed < 5 THEN 'Space Available'
           WHEN total_items_stowed = 5 THEN 'Fully Saturated'
           ELSE 'Overfill Breach (>5)'
       END AS stowage_tier
FROM driver_stowage
ORDER BY bag_utilization_pct DESC, driver_id ASC;


-- A8.2: Role-Based Demand & Expenditure Distribution
-- Analyzes spend per customer persona (STUDENT vs FACULTY vs STAFF vs DIRECTOR)
-- to evaluate campus purchasing power and target drops.
SELECT c.user_role,
       COUNT(DISTINCT c.customer_id) AS distinct_customers,
       COUNT(DISTINCT o.order_id) AS total_orders_placed,
       ROUND(AVG(ot.total_amount), 2) AS avg_ticket_size,
       SUM(ot.total_amount) AS gross_merchandise_value,
       ROUND(
           SUM(ot.total_amount) / SUM(SUM(ot.total_amount)) OVER () * 100, 2
       ) AS pct_total_platform_revenue
FROM customer c
JOIN "order" o ON c.customer_id = o.customer_id
JOIN order_total ot ON o.order_id = ot.order_id
WHERE o.status != 'CANCELLED'
GROUP BY c.user_role
ORDER BY gross_merchandise_value DESC;


-- A8.3: Hub Fulfillment Velocity & Bottleneck Diagnostic
-- Measures order fulfillment duration metrics (Min, Max, Avg, Median/P50, P90)
-- grouped by dining outlet to spot kitchen delays.
SELECT r.restaurant_id,
       r.name AS dining_facility,
       COUNT(o.order_id) AS completed_orders,
       ROUND(MIN(EXTRACT(EPOCH FROM (o.fulfilled_at - o.created_at)) / 60.0)::numeric, 1) AS min_duration_mins,
       ROUND(AVG(EXTRACT(EPOCH FROM (o.fulfilled_at - o.created_at)) / 60.0)::numeric, 1) AS avg_duration_mins,
       ROUND(
           PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (o.fulfilled_at - o.created_at)) / 60.0)::numeric, 1
       ) AS p50_median_duration_mins,
       ROUND(
           PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (o.fulfilled_at - o.created_at)) / 60.0)::numeric, 1
       ) AS p90_tail_duration_mins
FROM restaurant r
JOIN "order" o ON r.restaurant_id = o.restaurant_id
WHERE o.status = 'DELIVERED' 
  AND o.fulfilled_at IS NOT NULL
GROUP BY r.restaurant_id, r.name
ORDER BY avg_duration_mins DESC;


-- A8.4: Spatio-Temporal Geofence Delivery Concentration (Gate Traffic Matrix)
-- Aggregates delivery drops by campus perimeter gate and joins spatial zones
-- to identify physical courier bottlenecks across the campus ring road.
SELECT cz.zone_name,
       dl.name AS dropoff_gate,
       COUNT(o.order_id) AS delivery_count,
       COALESCE(SUM(ot.total_amount), 0.00) AS total_delivered_volume,
       DENSE_RANK() OVER (ORDER BY COUNT(o.order_id) DESC) AS campus_drop_rank
FROM delivery_location dl
JOIN campus_zone cz ON dl.zone_id = cz.zone_id
LEFT JOIN "order" o ON o.destination_id = dl.location_id AND o.status = 'DELIVERED'
LEFT JOIN order_total ot ON o.order_id = ot.order_id
GROUP BY cz.zone_name, dl.location_id, dl.name
ORDER BY delivery_count DESC;


-- A8.5: Kitchen Line Unit vs. Item Quantity Correlation
-- Compares physical cooking slot requirements against customer basket sizes 
-- to analyze kitchen load per hour of the day.
SELECT EXTRACT(HOUR FROM o.created_at) AS order_hour_window,
       COUNT(DISTINCT o.order_id) AS order_volume,
       SUM(oi.quantity) AS total_physical_food_items,
       SUM(oi.quantity * mi.stove_units) AS cumulative_cooking_line_slots_used,
       ROUND(
           AVG(oi.quantity * mi.stove_units)::numeric, 2
       ) AS avg_line_slots_per_ticket
FROM "order" o
JOIN order_item oi ON o.order_id = oi.order_id
JOIN menu_item mi ON oi.item_id = mi.item_id
WHERE o.status != 'CANCELLED'
GROUP BY EXTRACT(HOUR FROM o.created_at)
ORDER BY order_hour_window ASC;


-- A8.6: Driver Fleet Compensation & Payout Ledger
-- Computes baseline delivery earnings along with estimated distance metrics per courier.
SELECT d.driver_id,
       d.name AS courier_name,
       r.name AS staged_hub,
       d.status AS current_shift_status,
       COUNT(o.order_id) AS completed_drops,
       SUM(COALESCE(o.delivery_fee, 0.00)) AS total_delivery_fees_collected,
       COALESCE(lt_stat.total_pings, 0) AS recorded_telemetry_pings
FROM driver d
LEFT JOIN restaurant r ON d.staging_restaurant_id = r.restaurant_id
LEFT JOIN "order" o ON d.driver_id = o.driver_id AND o.status = 'DELIVERED'
LEFT JOIN (
    SELECT driver_id, COUNT(*) AS total_pings
    FROM location_trace
    GROUP BY driver_id
) lt_stat ON d.driver_id = lt_stat.driver_id
GROUP BY d.driver_id, d.name, r.name, d.status, lt_stat.total_pings
ORDER BY completed_drops DESC, d.driver_id ASC;