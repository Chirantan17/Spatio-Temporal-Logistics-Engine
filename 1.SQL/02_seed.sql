TRUNCATE TABLE security_breach_log, location_trace, order_item, "order", menu_item, customer, delivery_location, driver, restaurant, campus_zone RESTART IDENTITY CASCADE;

-- 1. CAMPUS ZONES (Security Hierarchy Enabled)
INSERT INTO campus_zone (zone_name, zone_type, boundary) VALUES
('Academic Corridor', 'PERMITTED_CORRIDOR', ST_GeomFromText('POLYGON((78.540 17.520, 78.545 17.520, 78.545 17.525, 78.540 17.525, 78.540 17.520))', 4326)),
('Sports Complex Exterior', 'PERMITTED_CORRIDOR', ST_GeomFromText('POLYGON((78.535 17.520, 78.540 17.520, 78.540 17.525, 78.535 17.525, 78.535 17.520))', 4326)),
('Faculty Enclave Park', 'PERMITTED_CORRIDOR', ST_GeomFromText('POLYGON((78.540 17.525, 78.545 17.525, 78.545 17.530, 78.540 17.530, 78.540 17.525))', 4326)),
('Hostel Pathway Sector', 'PERMITTED_CORRIDOR', ST_GeomFromText('POLYGON((78.545 17.520, 78.550 17.520, 78.550 17.530, 78.545 17.530, 78.545 17.520))', 4326)),
('Director Estate Garden & Residence', 'RESTRICTED_INTERIOR', ST_GeomFromText('POLYGON((78.538 17.528, 78.539 17.528, 78.539 17.529, 78.538 17.529, 78.538 17.528))', 4326)),
('Faculty Flat C Building', 'RESTRICTED_INTERIOR', ST_GeomFromText('POLYGON((78.541 17.526, 78.542 17.526, 78.542 17.527, 78.541 17.527, 78.541 17.526))', 4326)),
('Hostel 1 Interior Block', 'RESTRICTED_INTERIOR', ST_GeomFromText('POLYGON((78.546 17.521, 78.547 17.521, 78.547 17.522, 78.546 17.522, 78.546 17.521))', 4326));

-- 2. DINING HUBS (5 Outlets matching frontend architecture)
INSERT INTO restaurant (name, facility_type, phone, student_rating, location) VALUES
('Main Canteen (Academic Canteen)', 'Canteen', '040-11112222', 4.6, ST_SetSRID(ST_MakePoint(78.5415, 17.5215), 4326)),
('SAC Canteen',                     'Canteen', '040-11112223', 4.4, ST_SetSRID(ST_MakePoint(78.5375, 17.5220), 4326)),
('Yummpys',                         'Canteen', '040-11112224', 4.8, ST_SetSRID(ST_MakePoint(78.5435, 17.5235), 4326)),
('Central Library Cafe',            'Canteen', '040-11112225', 4.2, ST_SetSRID(ST_MakePoint(78.5425, 17.5210), 4326)),
('Hostel Circle Late-Night Hub',    'Canteen', '040-11112226', 4.7, ST_SetSRID(ST_MakePoint(78.5455, 17.5250), 4326));

-- 3. DRIVERS (Full 10-Driver Fleet: 2 dedicated per dining facility)
INSERT INTO driver (driver_id, name, phone, staging_restaurant_id, status, max_bag_capacity) VALUES
(1,  'Driver Ramesh', '9876543201', 1, 'AVAILABLE', 5),
(2,  'Driver Suresh', '9876543202', 1, 'AVAILABLE', 5),
(3,  'Driver Anita',  '9876543203', 2, 'AVAILABLE', 5),
(4,  'Driver Vikram', '9876543204', 2, 'AVAILABLE', 5),
(5,  'Driver Pooja',  '9876543205', 3, 'AVAILABLE', 5),
(6,  'Driver Karan',  '9876543206', 3, 'AVAILABLE', 5),
(7,  'Driver Deepak', '9876543207', 4, 'AVAILABLE', 5),
(8,  'Driver Sneha',  '9876543208', 4, 'AVAILABLE', 5),
(9,  'Driver Farhan', '9876543209', 5, 'AVAILABLE', 5),
(10, 'Driver Imran',  '9876543210', 5, 'OFFLINE',   5);

-- 4. AUTHORIZED GATES
INSERT INTO delivery_location (zone_id, name, point) VALUES
(1, 'Auditorium Outer Drop',           ST_SetSRID(ST_MakePoint(78.5410, 17.5210), 4326)),
(1, 'Library Exterior Drop',           ST_SetSRID(ST_MakePoint(78.5430, 17.5230), 4326)),
(2, 'Cricket Stadium Outer Gate',      ST_SetSRID(ST_MakePoint(78.5380, 17.5210), 4326)),
(2, 'Tennis Court Gate',               ST_SetSRID(ST_MakePoint(78.5360, 17.5240), 4326)),
(3, 'Flat C Security Desk',            ST_SetSRID(ST_MakePoint(78.5410, 17.5258), 4326)),
(4, 'Hostel 1 Entrance Gate',          ST_SetSRID(ST_MakePoint(78.5460, 17.5208), 4326)),
(1, 'Director Security Gate',          ST_SetSRID(ST_MakePoint(78.5400, 17.5240), 4326));

-- 5. CUSTOMERS
INSERT INTO customer (name, phone, email, user_role, gender, designation_block) VALUES
('Rahul Sharma',   '9123456701', 'rahul.s@campus.edu', 'STUDENT', 'MALE', 'Hostel 1'),
('Priya Patel',    '9123456702', 'priya.p@campus.edu', 'STUDENT', 'FEMALE', 'Hostel 3'),
('Prof. K. Rao',   '9123456709', 'k.rao@campus.edu',   'FACULTY', 'N/A',  'Flat C'),
('Dr. M. Swamy',   '9123456710', 'm.swamy@campus.edu', 'DIRECTOR','N/A',  'Director Estate'),
('Amit Verma',     '9123456703', 'amit.v@campus.edu',  'STAFF',   'N/A',  'Staff Quarters');

-- 6. MENU ITEMS
INSERT INTO menu_item (restaurant_id, name, category, price, prep_time_minutes, stove_units) VALUES
(1, 'Veg Thali',            'General', 120.00, 10, 2),
(1, 'Chicken Biryani',      'General', 180.00, 15, 2),
(2, 'High-Protein Smoothie','Healthy', 110.00,  5, 0),
(2, 'Grilled Chicken Salad','Healthy', 140.00, 10, 1),
(3, 'Chicken Tikka Roll',   'Snack',    90.00,  8, 1),
(3, 'Veg Cheese Burger',    'Snack',    80.00,  8, 2),
(4, 'Cold Coffee',          'Cafe',     70.00,  5, 0),
(5, 'Midnight Maggi Bowl',  'Snack',    50.00,  5, 1);

-- 7. ORDERS (One in transit, one delivered)
INSERT INTO "order" (customer_id, restaurant_id, driver_id, destination_id, status, delivery_fee, created_at, fulfilled_at) VALUES
(1, 1, 1, 6, 'IN_TRANSIT', 15.00, CURRENT_TIMESTAMP - INTERVAL '20 minutes', NULL),
(2, 3, 5, 2, 'DELIVERED',  15.00, CURRENT_TIMESTAMP - INTERVAL '60 minutes', CURRENT_TIMESTAMP - INTERVAL '35 minutes');

-- 8. ORDER ITEMS (Order 1 contains 2 items: 2/5 of bag capacity)
INSERT INTO order_item (order_id, item_id, restaurant_id, quantity, price_at_order) VALUES
(1, 1, 1, 2, 120.00),
(2, 5, 3, 1, 90.00);

-- 9. LOCATION TRACES
INSERT INTO location_trace (driver_id, location, recorded_at) VALUES 
(1, ST_SetSRID(ST_MakePoint(78.5416, 17.5214), 4326), CURRENT_TIMESTAMP),
(2, ST_SetSRID(ST_MakePoint(78.5414, 17.5216), 4326), CURRENT_TIMESTAMP),
(5, ST_SetSRID(ST_MakePoint(78.5434, 17.5234), 4326), CURRENT_TIMESTAMP);