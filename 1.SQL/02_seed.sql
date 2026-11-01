-- ============================================================================
-- CS G516: Advanced Database Systems - Studio Capstone
-- 02_seed.sql: Ground Truth Dataset for BITS Hyderabad Campus
-- ============================================================================

-- Clear existing data in correct dependency order
TRUNCATE security_breach_log, location_trace, order_item, "order", delivery_location, campus_zone, menu_item, driver, restaurant, customer RESTART IDENTITY CASCADE;

-- 1. Customers
INSERT INTO customer (customer_id, name, phone, email, campus_role, gender) VALUES
(1, 'Rahul Sharma', '9123456701', 'f2026001@hyderabad.bits-pilani.ac.in', 'STUDENT', 'MALE'),
(2, 'Priya Patel', '9123456702', 'f2026002@hyderabad.bits-pilani.ac.in', 'STUDENT', 'FEMALE'),
(3, 'Amit Verma', '9123456703', 'amit.verma@hyderabad.bits-pilani.ac.in', 'STAFF', 'MALE'),
(4, 'Prof. K. Rao', '9123456704', 'krao@hyderabad.bits-pilani.ac.in', 'FACULTY', 'MALE'),
(5, 'Dr. M. Swamy', '9123456705', 'director@hyderabad.bits-pilani.ac.in', 'DIRECTOR', 'MALE');

-- 2. Restaurants (Staging Hubs)
INSERT INTO restaurant (restaurant_id, name, facility_type, target_demographic, student_rating, phone, location) VALUES
(1, 'Main Canteen (Academic Canteen)', 'Mess & Fast Food', 'All', 4.20, '04066303501', ST_SetSRID(ST_MakePoint(78.5415, 17.5215), 4326)),
(2, 'SAC Canteen', 'Sports Complex Cafe', 'Fitness', 4.50, '04066303502', ST_SetSRID(ST_MakePoint(78.5375, 17.5220), 4326)),
(3, 'Yummpys', 'Fast Food Strip', 'Students', 4.10, '04066303503', ST_SetSRID(ST_MakePoint(78.5435, 17.5235), 4326)),
(4, 'Central Library Cafe', 'Cafe & Brews', 'Academics', 4.30, '04066303504', ST_SetSRID(ST_MakePoint(78.5425, 17.5210), 4326)),
(5, 'Hostel Circle Late-Night Hub', '24/7 Night Hub', 'Hostelers', 4.60, '04066303505', ST_SetSRID(ST_MakePoint(78.5455, 17.5250), 4326));

-- 3. Menu Items
INSERT INTO menu_item (item_id, restaurant_id, name, category, price, prep_time_minutes, stove_units) VALUES
(1, 1, 'Veg Thali', 'General', 120.00, 10, 2),
(2, 1, 'Chicken Biryani', 'General', 180.00, 15, 2),
(3, 3, 'Chicken Tikka Roll', 'Rolls', 90.00, 8, 1),
(4, 2, 'High-Protein Smoothie', 'Healthy', 110.00, 5, 0);

-- 4. Drivers (Staged Hub Mapping)
INSERT INTO driver (driver_id, name, phone, status, staged_hub_id, max_bag_capacity) VALUES
(1, 'Driver Ramesh', '9876543211', 'AVAILABLE', 1, 5),
(2, 'Driver Suresh', '9876543212', 'AVAILABLE', 1, 5),
(3, 'Driver Anita', '9876543213', 'AVAILABLE', 2, 5),
(4, 'Driver Vikram', '9876543214', 'AVAILABLE', 2, 5),
(5, 'Driver Pooja', '9876543215', 'AVAILABLE', 3, 5),
(6, 'Driver Karan', '9876543216', 'AVAILABLE', 3, 5),
(7, 'Driver Deepak', '9876543217', 'AVAILABLE', 4, 5),
(8, 'Driver Sneha', '9876543218', 'AVAILABLE', 4, 5),
(9, 'Driver Farhan', '9876543219', 'AVAILABLE', 5, 5),
(10, 'Driver Imran', '9876543220', 'OFFLINE', 5, 5);

-- 5. Campus Zones
INSERT INTO campus_zone (zone_id, zone_name, zone_type, boundary) VALUES
(1, 'Academic Corridor', 'AUTHORIZED_CORRIDOR', ST_SetSRID(ST_MakePolygon(ST_GeomFromText('LINESTRING(78.5390 17.5200, 78.5450 17.5200, 78.5450 17.5250, 78.5390 17.5250, 78.5390 17.5200)')), 4326)),
(2, 'Hostel Zone A', 'AUTHORIZED_CORRIDOR', ST_SetSRID(ST_MakePolygon(ST_GeomFromText('LINESTRING(78.5450 17.5200, 78.5500 17.5200, 78.5500 17.5260, 78.5450 17.5260, 78.5450 17.5200)')), 4326)),
(5, 'Hostel 1 Interior Block', 'RESTRICTED_INTERIOR', ST_SetSRID(ST_MakePolygon(ST_GeomFromText('LINESTRING(78.5460 17.5210, 78.5470 17.5210, 78.5470 17.5220, 78.5460 17.5220, 78.5460 17.5210)')), 4326));

-- 6. Delivery Locations
INSERT INTO delivery_location (location_id, zone_id, name, point) VALUES
(1, 1, 'Library Exterior Drop', ST_SetSRID(ST_MakePoint(78.5425, 17.5210), 4326)),
(2, 1, 'Auditorium Outer Drop', ST_SetSRID(ST_MakePoint(78.5410, 17.5210), 4326)),
(3, 2, 'Hostel 1 Entrance Gate', ST_SetSRID(ST_MakePoint(78.5460, 17.5210), 4326));

-- 7. Initial Telemetry Pings
INSERT INTO location_trace (driver_id, location, recorded_at) VALUES
(1, ST_SetSRID(ST_MakePoint(78.5416, 17.5214), 4326), CURRENT_TIMESTAMP - INTERVAL '1 minute'),
(2, ST_SetSRID(ST_MakePoint(78.5414, 17.5216), 4326), CURRENT_TIMESTAMP - INTERVAL '1 minute'),
(3, ST_SetSRID(ST_MakePoint(78.5374, 17.5219), 4326), CURRENT_TIMESTAMP - INTERVAL '1 minute');

-- 8. Seed Sample Orders (Includes full timestamp suite for analytical queries)
INSERT INTO "order" (order_id, customer_id, restaurant_id, driver_id, destination_id, status, delivery_fee, surge_bonus, created_at, ready_at, dispatched_at, fulfilled_at) VALUES
('ORD-10', 1, 1, 2, 3, 'DELIVERED', 15.00, 0.00, CURRENT_TIMESTAMP - INTERVAL '30 minutes', CURRENT_TIMESTAMP - INTERVAL '20 minutes', CURRENT_TIMESTAMP - INTERVAL '18 minutes', CURRENT_TIMESTAMP - INTERVAL '5 minutes'),
('ORD-11', 2, 3, NULL, 1, 'CANCELLED', 15.00, 0.00, CURRENT_TIMESTAMP - INTERVAL '40 minutes', NULL, NULL, NULL);

INSERT INTO order_item (order_id, item_id, restaurant_id, quantity, price_at_order) VALUES
('ORD-10', 1, 1, 1, 120.00),
('ORD-11', 3, 3, 1, 90.00);
