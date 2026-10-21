-- Q4.1: Find all canteens inside 'Academic Corridor'
SELECT r.restaurant_id, r.name AS canteen_name, z.zone_name
FROM restaurant r
JOIN campus_zone z ON ST_Covers(z.boundary, r.location)
WHERE z.zone_name = 'Academic Corridor';

-- Q4.2: Distance Calculation (Meters) between Main Canteen and Hostel 1 Entrance Gate
SELECT r.name AS canteen_name, dl.name AS dropoff_point,
       ROUND(ST_Distance(r.location::geography, dl.point::geography)::numeric, 2) AS distance_meters
FROM restaurant r
CROSS JOIN delivery_location dl
WHERE r.name = 'Main Canteen (Academic Canteen)' AND dl.name = 'Hostel 1 Entrance Gate';

-- Q4.3: Categorize authorized delivery drop gates by permitted perimeter geofence
SELECT z.zone_name, dl.name AS dropoff_location_name
FROM campus_zone z
JOIN delivery_location dl ON ST_Covers(z.boundary, dl.point)
ORDER BY z.zone_name;

-- Q4.4: Proximity Check of Gate nodes to Restricted Residential Interiors
SELECT dl.name AS gate_node, rz.zone_name AS restricted_zone,
       ROUND(ST_Distance(dl.point::geography, rz.boundary::geography)::numeric, 2) AS buffer_clearance_meters
FROM delivery_location dl
CROSS JOIN campus_zone rz
WHERE rz.zone_type = 'RESTRICTED_INTERIOR'
ORDER BY buffer_clearance_meters ASC;