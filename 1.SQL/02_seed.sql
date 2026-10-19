TRUNCATE TABLE security_breach_log, location_trace, order_item, "order", menu_item, customer, delivery_location, restaurant, driver, campus_zone RESTART IDENTITY CASCADE;

-- 1. CAMPUS ZONES (Security Hierarchy Enabled)
INSERT INTO campus_zone (zone_name, zone_type, boundary) VALUES
('Academic Corridor', 'PERMITTED_CORRIDOR', ST_GeomFromText('POLYGON((78.540 17.520, 78.545 17.520, 78.545 17.525, 78.540 17.525, 78.540 17.520))', 4326)),
('Sports Complex Exterior', 'PERMITTED_CORRIDOR', ST_GeomFromText('POLYGON((78.535 17.520, 78.540 17.520, 78.540 17.525, 78.535 17.525, 78.535 17.520))', 4326)),
('Faculty Enclave Park', 'PERMITTED_CORRIDOR', ST_GeomFromText('POLYGON((78.540 17.525, 78.545 17.525, 78.545 17.530, 78.540 17.530, 78.540 17.525))', 4326)),
('Hostel Pathway Sector', 'PERMITTED_CORRIDOR', ST_GeomFromText('POLYGON((78.545 17.520, 78.550 17.520, 78.550 17.530, 78.545 17.530, 78.545 17.520))', 4326)),
-- RESTRICTED INTERIOR ZONES (Driver Entry triggers Security Breach)
('Director Estate Garden & Residence', 'RESTRICTED_INTERIOR', ST_GeomFromText('POLYGON((78.538 17.528, 78.539 17.528, 78.539 17.529, 78.538 17.529, 78.538 17.528))', 4326)),
('Faculty Flat C Building', 'RESTRICTED_INTERIOR', ST_GeomFromText('POLYGON((78.541 17.526, 78.542 17.526, 78.542 17.527, 78.541 17.527, 78.541 17.526))', 4326)),
('Hostel 1 Interior Block', 'RESTRICTED_INTERIOR', ST_GeomFromText('POLYGON((78.546 17.521, 78.547 17.521, 78.547 17.522, 78.546 17.522, 78.546 17.521))', 4326));

-- 2. DRIVERS
INSERT INTO driver (name, phone, status) VALUES
('Driver Ramesh', '9876543210', 'BUSY'), ('Driver Suresh', '9876543211', 'AVAILABLE'),
('Driver Anita',  '9876543212', 'AVAILABLE'), ('Driver Vikram', '9876543213', 'BUSY'),
('Driver Pooja',  '9876543214', 'AVAILABLE'), ('Driver Karan',  '9876543215', 'OFFLINE');

-- 3. DINING OUTLETS
INSERT INTO restaurant (name, facility_type, phone, location) VALUES
('Main Canteen (Academic Canteen)', 'Canteen', '040-11112222', ST_SetSRID(ST_MakePoint(78.5415, 17.5215), 4326)),
('SAC Canteen',                     'Canteen', '040-11112223', ST_SetSRID(ST_MakePoint(78.5375, 17.5220), 4326)),
('Yummpys',                         'Canteen', '040-11112224', ST_SetSRID(ST_MakePoint(78.5435, 17.5235), 4326)),
('Central Library Cafe',            'Canteen', '040-11112225', ST_SetSRID(ST_MakePoint(78.5425, 17.5210), 4326)),
('Hostel Circle Late-Night Hub',    'Canteen', '040-11112226', ST_SetSRID(ST_MakePoint(78.5455, 17.5250), 4326));

-- 4. AUTHORIZED DELIVERY GATES
INSERT INTO delivery_location (zone_id, name, point) VALUES
(1, 'Auditorium Outer Drop',           ST_SetSRID(ST_MakePoint(78.5410, 17.5210), 4326)),
(1, 'Library Exterior Drop',           ST_SetSRID(ST_MakePoint(78.5430, 17.5230), 4326)),
(2, 'Cricket Stadium Outer Gate',      ST_SetSRID(ST_MakePoint(78.5380, 17.5210), 4326)),
(2, 'Tennis Court Gate',               ST_SetSRID(ST_MakePoint(78.5360, 17.5240), 4326)),
(3, 'Flat C Security Desk',            ST_SetSRID(ST_MakePoint(78.5410, 17.5258), 4326)), -- Just outside Restricted Flat C
(4, 'Hostel 1 Entrance Gate',          ST_SetSRID(ST_MakePoint(78.5460, 17.5208), 4326)), -- Just outside Restricted Hostel 1
(1, 'Director Security Gate',          ST_SetSRID(ST_MakePoint(78.5400, 17.5240), 4326));

-- 5. CUSTOMERS (With Hierarchy)
INSERT INTO customer (name, phone, email, user_role, gender, designation_block) VALUES
('Rahul Sharma',   '9123456701', 'rahul.s@campus.edu', 'STUDENT', 'MALE', 'Hostel 1'),
('Priya Patel',    '9123456702', 'priya.p@campus.edu', 'STUDENT', 'FEMALE', 'Hostel 3'),
('Prof. K. Rao',   '9123456709', 'k.rao@campus.edu',   'FACULTY', 'N/A',  'Flat C'),
('Dr. M. Swamy',   '9123456710', 'm.swamy@campus.edu', 'DIRECTOR','N/A',  'Director Estate'),
('Amit Verma',     '9123456703', 'amit.v@campus.edu',  'STAFF',   'N/A',  'Staff Quarters');

-- 6. MENU ITEMS (Available 24/7)
INSERT INTO menu_item (restaurant_id, name, category, price, prep_time_minutes) VALUES
(1, 'Veg Thali',           'General', 120.00, 10),
(1, 'Chicken Biryani',     'General', 180.00, 15),
(2, 'High-Protein Smoothie','Healthy', 110.00, 5),
(2, 'Grilled Chicken Salad','Healthy', 140.00, 10),
(3, 'Chicken Tikka Roll',  'Snack',    90.00, 8),
(3, 'Veg Cheese Burger',   'Snack',    80.00, 8),
(4, 'Cold Coffee',         'Cafe',     70.00, 5),
(5, 'Midnight Maggi Bowl', 'Snack',    50.00, 5);

-- 7. ORDERS
INSERT INTO "order" (customer_id, restaurant_id, driver_id, destination_id, status, delivery_fee, created_at, fulfilled_at) VALUES
(1, 1, 1, 6, 'IN_TRANSIT', 0.00, CURRENT_TIMESTAMP - INTERVAL '20 minutes', NULL),
(2, 3, 2, 7, 'DELIVERED',  0.00, CURRENT_TIMESTAMP - INTERVAL '110 minutes', CURRENT_TIMESTAMP - INTERVAL '85 minutes');

-- 8. ORDER ITEMS
INSERT INTO order_item (order_id, item_id, restaurant_id, quantity, price_at_order) VALUES
(1, 1, 1, 2, 120.00), (2, 5, 3, 1, 90.00);

-- 9. LOCATION TRACE 
-- (Inserting a rogue ping directly inside the Director's Garden to prove the Trigger works automatically)
INSERT INTO location_trace (driver_id, location, recorded_at) VALUES 
(1, ST_SetSRID(ST_MakePoint(78.5410, 17.5210), 4326), CURRENT_TIMESTAMP), -- Normal
(2, ST_SetSRID(ST_MakePoint(78.5385, 17.5285), 4326), CURRENT_TIMESTAMP); -- BREACH! Inside Director Estate