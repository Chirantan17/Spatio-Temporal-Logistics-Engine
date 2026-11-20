-- ============================================================================
-- 08_analytical_queries.sql
-- Spatiotemporal Analytical Query Workload & Window Functions
-- ============================================================================


-- ----------------------------------------------------------------------------
-- A8.1: Actual Spatial Trajectory Reconstruction
-- Reconstructs real LineStrings chronologically from point observations
-- ----------------------------------------------------------------------------
SELECT
    d.driver_id,
    d.name AS driver_name,
    DATE(lt.recorded_at) AS shift_date,
    COUNT(lt.trace_id) AS total_gps_pings,
    ST_MakeLine(lt.location ORDER BY lt.recorded_at ASC) AS trajectory_geom,
    ROUND((ST_Length(ST_MakeLine(lt.location ORDER BY lt.recorded_at ASC)::geography) / 1000.0)::numeric, 2) AS distance_traversed_km
FROM driver d
JOIN location_trace lt ON d.driver_id = lt.driver_id
GROUP BY d.driver_id, d.name, DATE(lt.recorded_at)
ORDER BY d.driver_id, shift_date DESC;


-- ----------------------------------------------------------------------------
-- A8.2: Turnaround Latency by Canteen
-- Evaluates all 5 campus canteens across completed and active order lifecycles
-- ----------------------------------------------------------------------------
SELECT
    r.restaurant_id,
    r.name AS canteen_name,
    COUNT(o.order_id) AS orders_completed,
    COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (o.ready_at - o.created_at)) / 60) FILTER (WHERE o.ready_at IS NOT NULL)::numeric, 1), 0) AS avg_kitchen_prep_mins,
    COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (o.fulfilled_at - o.dispatched_at)) / 60) FILTER (WHERE o.fulfilled_at IS NOT NULL AND o.dispatched_at IS NOT NULL)::numeric, 1), 0) AS avg_transit_mins,
    COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (o.fulfilled_at - o.created_at)) / 60) FILTER (WHERE o.fulfilled_at IS NOT NULL)::numeric, 1), 0) AS total_turnaround_mins
FROM restaurant r
LEFT JOIN "order" o ON r.restaurant_id = o.restaurant_id
GROUP BY r.restaurant_id, r.name
ORDER BY orders_completed DESC, r.restaurant_id;


-- ----------------------------------------------------------------------------
-- A8.3: Dynamic Financial Ledger (Decoupled Platform Payout Model)
-- ----------------------------------------------------------------------------
SELECT
    o.order_id,
    r.name AS canteen_name,
    COALESCE(d.name, 'Unassigned') AS driver_name,
    o.delivery_fee AS customer_paid_fee,
    o.surge_bonus AS kitchen_funded_escalation_bonus,
    (o.delivery_fee + o.surge_bonus) AS total_driver_earnings
FROM "order" o
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
LEFT JOIN driver d ON o.driver_id = d.driver_id
ORDER BY o.created_at DESC;


-- ----------------------------------------------------------------------------
-- A8.4: Moving Average Turnaround per Driver (Window Specification)
-- ----------------------------------------------------------------------------
SELECT
    o.order_id,
    o.driver_id,
    d.name AS driver_name,
    COALESCE(o.fulfilled_at, CURRENT_TIMESTAMP) AS reference_time,
    ROUND((EXTRACT(EPOCH FROM (COALESCE(o.fulfilled_at, CURRENT_TIMESTAMP) - o.dispatched_at)) / 60)::numeric, 2) AS trip_duration_mins,
    ROUND(AVG(EXTRACT(EPOCH FROM (COALESCE(o.fulfilled_at, CURRENT_TIMESTAMP) - o.dispatched_at)) / 60) OVER (
        PARTITION BY o.driver_id
        ORDER BY COALESCE(o.fulfilled_at, CURRENT_TIMESTAMP)
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    )::numeric, 2) AS rolling_avg_3trips_mins
FROM "order" o
JOIN driver d ON o.driver_id = d.driver_id
WHERE o.dispatched_at IS NOT NULL
ORDER BY o.driver_id, reference_time;


-- ----------------------------------------------------------------------------
-- A8.5: Hourly Canteen Demand Density
-- Ranks all 5 canteens per active order hour using DENSE_RANK()
-- ----------------------------------------------------------------------------
WITH active_hours AS (
    SELECT DISTINCT EXTRACT(HOUR FROM created_at)::int AS hour_of_day
    FROM "order"
)
SELECT
    r.name AS canteen_name,
    ah.hour_of_day,
    COUNT(o.order_id) AS order_volume,
    DENSE_RANK() OVER (
        PARTITION BY ah.hour_of_day
        ORDER BY COUNT(o.order_id) DESC
    ) AS demand_rank_in_hour
FROM active_hours ah
CROSS JOIN restaurant r
LEFT JOIN "order" o
    ON o.restaurant_id = r.restaurant_id
   AND EXTRACT(HOUR FROM o.created_at)::int = ah.hour_of_day
GROUP BY r.name, ah.hour_of_day
ORDER BY ah.hour_of_day, demand_rank_in_hour, r.name;


-- ----------------------------------------------------------------------------
-- A8.6: Zonewise Aggregation of Orders (Spatial Containment)
-- Computes total order volume across all geofenced campus zones
-- ----------------------------------------------------------------------------
SELECT
    z.zone_name,
    COUNT(o.order_id) AS total_zone_orders
FROM campus_zone z
LEFT JOIN delivery_location dl ON ST_Covers(z.boundary, dl.point)
LEFT JOIN "order" o ON dl.location_id = o.destination_id
GROUP BY z.zone_name
ORDER BY total_zone_orders DESC, z.zone_name;


-- ----------------------------------------------------------------------------
-- A8.7: Order Batching / Logistics Optimization
-- Evaluates canteen-to-zone corridors and flags multi-order batch opportunities
-- ----------------------------------------------------------------------------
SELECT
    r.name AS pickup_restaurant,
    z.zone_name AS dropoff_zone,
    COUNT(o.order_id) AS batch_size,
    ARRAY_AGG(o.order_id) AS clubbed_order_ids,
    MIN(o.created_at) AS oldest_pending_order_time,
    CASE
        WHEN COUNT(o.order_id) > 1 THEN 'BATCH_ELIGIBLE'
        ELSE 'SINGLE_DISPATCH'
    END AS dispatch_strategy
FROM "order" o
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
JOIN delivery_location dl ON o.destination_id = dl.location_id
JOIN campus_zone z ON ST_Covers(z.boundary, dl.point)
WHERE o.status IN ('PENDING', 'PREPARING', 'READY', 'IN_TRANSIT', 'DELIVERED')
GROUP BY r.name, z.zone_name
ORDER BY batch_size DESC, oldest_pending_order_time ASC;


-- ----------------------------------------------------------------------------
-- A8.8: Historical Demand Forecasting by Zone
-- Ranks all campus zones partitioned by active month using RANK()
-- ----------------------------------------------------------------------------
WITH active_months AS (
    SELECT DISTINCT EXTRACT(MONTH FROM created_at)::int AS order_month
    FROM "order"
)
SELECT
    z.zone_name,
    am.order_month,
    COUNT(o.order_id) AS historical_order_volume,
    RANK() OVER (
        PARTITION BY am.order_month
        ORDER BY COUNT(o.order_id) DESC
    ) AS monthly_demand_rank
FROM active_months am
CROSS JOIN campus_zone z
LEFT JOIN delivery_location dl ON ST_Covers(z.boundary, dl.point)
LEFT JOIN "order" o
    ON o.destination_id = dl.location_id
   AND EXTRACT(MONTH FROM o.created_at)::int = am.order_month
   AND o.status <> 'CANCELLED'
GROUP BY z.zone_name, am.order_month
ORDER BY am.order_month DESC, monthly_demand_rank ASC, z.zone_name;