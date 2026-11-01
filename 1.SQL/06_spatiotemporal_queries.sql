-- ============================================================================
-- CS G516: Advanced Database Systems
-- 06_spatiotemporal_queries.sql: Combined Spatiotemporal Fleet Routing
-- ============================================================================


-- Q6.1: Metric Distance from Available Drivers to Active Outlets using Latest GPS Observation
WITH latest_telemetry AS (
    SELECT DISTINCT ON (driver_id) driver_id, location, recorded_at
    FROM location_trace
    ORDER BY driver_id, recorded_at DESC
)
SELECT o.order_id, d.name AS driver_name, r.name AS canteen_name,
       ROUND(ST_Distance(lt.location::geography, r.location::geography)::numeric, 1) AS distance_meters,
       lt.recorded_at AS ping_time
FROM "order" o
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
CROSS JOIN driver d
JOIN latest_telemetry lt ON d.driver_id = lt.driver_id
WHERE o.status = 'READY' AND d.status = 'AVAILABLE'
ORDER BY distance_meters ASC;

-- Q6.2: True Ground Distance KNN Dispatch Prioritization (<-> index assist)
WITH latest_telemetry AS (
    SELECT DISTINCT ON (driver_id) driver_id, location
    FROM location_trace
    ORDER BY driver_id, recorded_at DESC
)
SELECT d.driver_id, d.name AS driver_name, d.status,
       d.max_bag_capacity - COALESCE(SUM(oi.quantity), 0) AS remaining_slots,
       lt.location <-> r.location AS spatial_bounding_distance
FROM driver d
JOIN latest_telemetry lt ON d.driver_id = lt.driver_id
CROSS JOIN restaurant r
LEFT JOIN "order" o ON d.driver_id = o.driver_id AND o.status = 'IN_TRANSIT'
LEFT JOIN order_item oi ON o.order_id = oi.order_id
WHERE r.restaurant_id = 1 AND d.status = 'AVAILABLE'
GROUP BY d.driver_id, d.name, d.status, d.max_bag_capacity, lt.location, r.location
HAVING (d.max_bag_capacity - COALESCE(SUM(oi.quantity), 0)) > 0
ORDER BY spatial_bounding_distance ASC;

-- Q6.3: Multi-Leg Delivery Route Distance Calculation
SELECT o.order_id, d.name AS driver_name, r.name AS canteen_name, dl.name AS destination,
       ROUND(ST_Distance(lt.location::geography, r.location::geography)::numeric, 1) AS driver_to_canteen_m,
       ROUND(ST_Distance(r.location::geography, dl.point::geography)::numeric, 1) AS canteen_to_dropoff_m,
       ROUND((ST_Distance(lt.location::geography, r.location::geography) + ST_Distance(r.location::geography, dl.point::geography))::numeric, 1) AS total_route_m
FROM "order" o
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
JOIN delivery_location dl ON o.destination_id = dl.location_id
JOIN driver d ON o.driver_id = d.driver_id
JOIN (
    SELECT DISTINCT ON (driver_id) driver_id, location
    FROM location_trace
    ORDER BY driver_id, recorded_at DESC
) lt ON d.driver_id = lt.driver_id
WHERE o.status = 'IN_TRANSIT';

-- Q6.4: Spatiotemporal Continuous Trajectory Geometry Reconstruction
SELECT d.driver_id, d.name AS driver_name,
       COUNT(lt.trace_id) AS total_telemetry_pings,
       ST_MakeLine(lt.location ORDER BY lt.recorded_at ASC) AS continuous_trajectory_geom,
       ROUND(ST_Length(ST_MakeLine(lt.location ORDER BY lt.recorded_at ASC)::geography)::numeric, 1) AS total_distance_covered_meters
FROM driver d
JOIN location_trace lt ON d.driver_id = lt.driver_id
GROUP BY d.driver_id, d.name;
