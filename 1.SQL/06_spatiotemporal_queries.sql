-- Q6.1: Automated Pickup Geofence Check (Driver within 30m of Main Canteen)
WITH latest_telemetry AS (
    SELECT DISTINCT ON (driver_id) driver_id, location, recorded_at
    FROM location_trace
    ORDER BY driver_id, recorded_at DESC
)
SELECT o.order_id, d.name AS driver_name, r.name AS canteen_name,
       ROUND(ST_Distance(lt.location::geography, r.location::geography)::numeric, 2) AS distance_meters,
       lt.recorded_at AS ping_time
FROM "order" o
JOIN driver d ON o.driver_id = d.driver_id
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
JOIN latest_telemetry lt ON lt.driver_id = d.driver_id
WHERE o.status = 'IN_TRANSIT'
  AND ST_DWithin(lt.location::geography, r.location::geography, 30);

-- Q6.2: Nearest Available Driver Dispatch via GiST KNN (<->) with Bag Capacity Check
WITH latest_telemetry AS (
    SELECT DISTINCT ON (driver_id) driver_id, location, recorded_at
    FROM location_trace
    ORDER BY driver_id, recorded_at DESC
)
SELECT d.driver_id, d.name AS driver_name, d.status,
       bcv.current_items_in_bag, bcv.remaining_slots,
       lt.location <-> r.location AS spatial_bounding_distance
FROM driver d
JOIN latest_telemetry lt ON d.driver_id = lt.driver_id
JOIN driver_bag_capacity_view bcv ON d.driver_id = bcv.driver_id
CROSS JOIN restaurant r
WHERE r.name = 'Main Canteen (Academic Canteen)'
  AND d.status != 'OFFLINE'
  AND bcv.remaining_slots >= 2 -- Checks if driver has enough capacity for an incoming 2-item order
ORDER BY lt.location <-> r.location
LIMIT 1;

-- Q6.3: Two-Leg Delivery Route Distance (Driver -> Canteen -> Drop-off)
WITH latest_telemetry AS (
    SELECT DISTINCT ON (driver_id) driver_id, location, recorded_at
    FROM location_trace
    ORDER BY driver_id, recorded_at DESC
)
SELECT o.order_id, d.name AS driver_name, r.name AS canteen_name, dl.name AS destination,
       ROUND(ST_Distance(lt.location::geography, r.location::geography)::numeric, 2) AS driver_to_canteen_m,
       ROUND(ST_Distance(r.location::geography, dl.point::geography)::numeric, 2) AS canteen_to_dropoff_m,
       ROUND((ST_Distance(lt.location::geography, r.location::geography) + ST_Distance(r.location::geography, dl.point::geography))::numeric, 2) AS total_route_m
FROM "order" o
JOIN driver d ON o.driver_id = d.driver_id
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
JOIN delivery_location dl ON o.destination_id = dl.location_id
JOIN latest_telemetry lt ON lt.driver_id = d.driver_id
WHERE o.status = 'IN_TRANSIT';

-- Q6.4: Continuous Trajectory Synthesis from discrete GPS pings
SELECT d.driver_id, d.name AS driver_name,
       COUNT(lt.trace_id) AS total_telemetry_pings,
       ST_MakeLine(lt.location ORDER BY lt.recorded_at) AS continuous_trajectory_geom,
       ROUND((ST_Length(ST_MakeLine(lt.location ORDER BY lt.recorded_at)::geography))::numeric, 2) AS total_distance_covered_meters
FROM driver d
JOIN location_trace lt ON d.driver_id = lt.driver_id
GROUP BY d.driver_id, d.name
HAVING COUNT(lt.trace_id) > 1
ORDER BY d.driver_id;