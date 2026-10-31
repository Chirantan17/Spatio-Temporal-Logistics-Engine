-- ============================================================================
-- 08_analytical_queries.sql
-- Spatiotemporal Analytical Query Workload & Window Functions
-- ============================================================================

\c campus_delivery;

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
GROUP BY d.driver_id, d.name, DATE(lt.recorded_at);

-- ----------------------------------------------------------------------------
-- A8.2: Turnaround Latency by Canteen
-- ----------------------------------------------------------------------------
SELECT 
    r.restaurant_id,
    r.name AS canteen_name,
    COUNT(o.order_id) AS orders_completed,
    ROUND(AVG(EXTRACT(EPOCH FROM (o.ready_at - o.created_at)) / 60)::numeric, 1) AS avg_kitchen_prep_mins,
    ROUND(AVG(EXTRACT(EPOCH FROM (o.fulfilled_at - o.dispatched_at)) / 60)::numeric, 1) AS avg_transit_mins,
    ROUND(AVG(EXTRACT(EPOCH FROM (o.fulfilled_at - o.created_at)) / 60)::numeric, 1) AS total_turnaround_mins
FROM restaurant r
JOIN "order" o ON r.restaurant_id = o.restaurant_id
WHERE o.status = 'DELIVERED'
GROUP BY r.restaurant_id, r.name;

-- ----------------------------------------------------------------------------
-- A8.3: Dynamic Financial Ledger (Decoupled Platform Payout Model)
-- ----------------------------------------------------------------------------
SELECT 
    o.order_id,
    r.name AS canteen_name,
    d.name AS driver_name,
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
    o.fulfilled_at,
    ROUND((EXTRACT(EPOCH FROM (o.fulfilled_at - o.dispatched_at)) / 60)::numeric, 2) AS trip_duration_mins,
    ROUND(AVG(EXTRACT(EPOCH FROM (o.fulfilled_at - o.dispatched_at)) / 60) OVER (
        PARTITION BY o.driver_id 
        ORDER BY o.fulfilled_at
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    )::numeric, 2) AS rolling_avg_3trips_mins
FROM "order" o
JOIN driver d ON o.driver_id = d.driver_id
WHERE o.status = 'DELIVERED' AND o.dispatched_at IS NOT NULL;

-- ----------------------------------------------------------------------------
-- A8.5: Hourly Canteen Demand Density
-- ----------------------------------------------------------------------------
SELECT 
    r.name AS canteen_name,
    EXTRACT(HOUR FROM o.created_at) AS hour_of_day,
    COUNT(o.order_id) AS order_volume,
    DENSE_RANK() OVER (
        PARTITION BY EXTRACT(HOUR FROM o.created_at) 
        ORDER BY COUNT(o.order_id) DESC
    ) AS demand_rank_in_hour
FROM restaurant r
JOIN "order" o ON r.restaurant_id = o.restaurant_id
GROUP BY r.name, EXTRACT(HOUR FROM o.created_at)
ORDER BY hour_of_day, demand_rank_in_hour;