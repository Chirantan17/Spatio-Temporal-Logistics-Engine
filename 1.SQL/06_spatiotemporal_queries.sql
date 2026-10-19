-- ============================================================================
-- 4. SPATIO-TEMPORAL QUERIES (Combined Spatial & Temporal Constraints)
-- ============================================================================

-- Q6.1: Automated Pickup Geofence Check - Detect drivers within 30m of canteen-1
WITH latest_telemetry AS (
    SELECT DISTINCT ON (driver_id) driver_id, location, recorded_at
    FROM location_trace
    ORDER BY driver_id, recorded_at DESC
)
SELECT DISTINCT o.order_id, d.name AS driver_name, r.name AS canteen_name,
       ROUND(ST_Distance(lt.location::geography, r.location::geography)::numeric, 2) AS distance_meters,
       lt.recorded_at AS ping_time
FROM "order" o
JOIN driver d ON o.driver_id = d.driver_id
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
JOIN latest_telemetry lt ON lt.driver_id = d.driver_id
WHERE o.status = 'PREPARING'
  AND ST_DWithin(lt.location::geography, r.location::geography, 30);

-- Q6.2: Nearest Available Driver Dispatch via GiST Index KNN Operator (<->) 
WITH latest_telemetry AS (
    SELECT DISTINCT ON (driver_id) driver_id, location, recorded_at
    FROM location_trace
    ORDER BY driver_id, recorded_at DESC
)
SELECT d.driver_id, d.name AS driver_name, d.status,
       lt.location <-> r.location AS spatial_bounding_distance
FROM driver d
JOIN latest_telemetry lt ON d.driver_id = lt.driver_id
CROSS JOIN restaurant r
WHERE r.name = 'Canteen 1 (Main Hub)'
  AND d.status = 'AVAILABLE'
ORDER BY lt.location <-> r.location
LIMIT 1;

-- Q6.3: Two-Leg Delivery Route Distance (Driver -> Canteen Pickup -> Drop-Off) 
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
WHERE o.status = 'PREPARING';

-- Q6.4: Spatio-Temporal Zone Revenue Analysis (Rolling 24-Hour Window)
SELECT z.zone_name, 
       COUNT(DISTINCT o.order_id) AS total_delivered_orders,
       COALESCE(SUM(oi.quantity * oi.price_at_order), 0) AS revenue_inr
FROM campus_zone z
LEFT JOIN delivery_location dl ON ST_Covers(z.boundary, dl.point)
LEFT JOIN "order" o ON o.destination_id = dl.location_id 
                    AND o.status = 'DELIVERED' 
                    AND o.fulfilled_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
LEFT JOIN order_item oi ON o.order_id = oi.order_id
GROUP BY z.zone_id, z.zone_name
ORDER BY revenue_inr DESC;

-- ============================================================================
-- FLAGSHIP SPATIO-TEMPORAL AGGREGATION
-- ============================================================================

-- Q6.5: Continuous Trajectory Synthesis - Reconstruct full driver travel path (LINESTRING) from discrete pings
SELECT d.driver_id,
       d.name AS driver_name,
       COUNT(lt.trace_id) AS total_telemetry_pings,
       MIN(lt.recorded_at) AS trip_start_time,
       MAX(lt.recorded_at) AS trip_end_time,
       ST_MakeLine(lt.location ORDER BY lt.recorded_at) AS continuous_trajectory_geom,
       ROUND((ST_Length(ST_MakeLine(lt.location ORDER BY lt.recorded_at)::geography))::numeric, 2) AS total_distance_covered_meters
FROM driver d
JOIN location_trace lt ON d.driver_id = lt.driver_id
GROUP BY d.driver_id, d.name
HAVING COUNT(lt.trace_id) > 1
ORDER BY d.driver_id;

-- ============================================================================
-- 5. ADVANCED ANOMALY DETECTION & EXTREME ROUTING
-- ============================================================================

-- Q6.6: Logistical Anomaly Detection
-- Expected Output: 0 Rows. Proves our active delivery state is completely consistent with driver workforce state.
SELECT o.order_id, o.status AS order_status, d.name AS driver_name, d.status AS current_driver_status
FROM "order" o
JOIN driver d ON o.driver_id = d.driver_id
WHERE o.status IN ('PENDING', 'PREPARING', 'IN_TRANSIT') 
  AND d.status = 'OFFLINE';

-- Q6.7: Extreme Cross-Campus Routing Analysis
WITH latest_telemetry AS (
    SELECT DISTINCT ON (driver_id) driver_id, location, recorded_at
    FROM location_trace
    ORDER BY driver_id, recorded_at DESC
)
SELECT o.order_id, r.name AS source_canteen, dl.name AS destination_point,
       ROUND(ST_Distance(r.location::geography, dl.point::geography)::numeric, 2) AS straight_line_delivery_distance_meters,
       ROUND((ST_Distance(lt.location::geography, r.location::geography) + ST_Distance(r.location::geography, dl.point::geography))::numeric, 2) AS total_driver_route_meters
FROM "order" o
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
JOIN delivery_location dl ON o.destination_id = dl.location_id
JOIN driver d ON o.driver_id = d.driver_id
JOIN latest_telemetry lt ON lt.driver_id = d.driver_id
WHERE o.status = 'PREPARING'
ORDER BY total_driver_route_meters DESC;

-- ============================================================================
-- 6. DYNAMIC PRICING & SPATIAL MONETIZATION
-- ============================================================================

-- Q6.8: Spatial Surge Delivery Fee Calculator
SELECT o.order_id, r.name AS canteen, dl.name AS dropoff_point,
       ROUND(ST_Distance(r.location::geography, dl.point::geography)::numeric, 2) AS straight_line_distance_m,
       o.delivery_fee AS actual_fee_charged,
       (15.00 + ROUND((ST_Distance(r.location::geography, dl.point::geography) / 100.0 * 5.0)::numeric, 2)) AS computed_spatial_fee
FROM "order" o
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
JOIN delivery_location dl ON o.destination_id = dl.location_id
WHERE o.delivery_fee > 0;

-- Q6.9: Awkward-Timing Surge Pricing Audit
SELECT oi.order_id, mi.name AS item_name, mi.category, 
       mi.price AS current_catalog_price, 
       oi.price_at_order AS actual_price_paid,
       (oi.price_at_order - mi.price) AS surge_premium_collected,
       ROUND(((oi.price_at_order - mi.price) / mi.price * 100), 1) AS surge_percentage
FROM order_item oi
JOIN menu_item mi ON oi.item_id = mi.item_id
WHERE oi.price_at_order > mi.price
ORDER BY surge_premium_collected DESC;

-- ============================================================================
-- 7. DRIVER BEHAVIORAL INTELLIGENCE
-- ============================================================================

-- Q6.10: Predictive Driver Hotspots based on lowest-rated Messes
WITH worst_mess AS (
    SELECT r.name, r.student_rating, z.zone_id, z.zone_name
    FROM restaurant r
    JOIN campus_zone z ON ST_Covers(z.boundary, r.location)
    WHERE r.facility_type = 'Mess'
    ORDER BY r.student_rating ASC 
    LIMIT 1
)
SELECT wm.name AS underlying_issue_facility, 
       wm.student_rating, 
       wm.zone_name AS high_demand_zone, 
       dl.name AS recommended_driver_hotspot
FROM worst_mess wm
JOIN delivery_location dl ON dl.zone_id = wm.zone_id;