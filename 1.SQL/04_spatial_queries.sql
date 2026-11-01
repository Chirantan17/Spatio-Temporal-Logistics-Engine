-- ============================================================================
-- CS G516: Advanced Database Systems
-- 04_spatial_queries.sql: Spatial PostGIS Geofence & Proximity Analysis
-- ============================================================================

\c campus_delivery;

-- Q4.1: Spatial Join - Identify Canteens Located Within Campus Zones
SELECT r.restaurant_id, r.name AS canteen_name, cz.zone_name
FROM restaurant r
JOIN campus_zone cz ON ST_Within(r.location, cz.boundary);

-- Q4.2: Metric Ground Distance from Canteens to Drop-Off Nodes
SELECT r.name AS canteen_name, dl.name AS dropoff_point,
       ROUND(ST_Distance(r.location::geography, dl.point::geography)::numeric, 1) AS distance_meters
FROM restaurant r
CROSS JOIN delivery_location dl
ORDER BY r.name, distance_meters ASC;

-- Q4.3: Drop-Off Gate Containment Audit
SELECT cz.zone_name, dl.name AS dropoff_location_name
FROM delivery_location dl
JOIN campus_zone cz ON ST_Contains(cz.boundary, dl.point);

-- Q4.4: Proximity Clearance to Restricted Interior Polygons (Buffer Inspection)
SELECT dl.name AS gate_node, cz.zone_name AS restricted_zone,
       ROUND(ST_Distance(dl.point::geography, cz.boundary::geography)::numeric, 1) AS buffer_clearance_meters
FROM delivery_location dl
CROSS JOIN campus_zone cz
WHERE cz.zone_type = 'RESTRICTED_INTERIOR'
ORDER BY buffer_clearance_meters ASC;
