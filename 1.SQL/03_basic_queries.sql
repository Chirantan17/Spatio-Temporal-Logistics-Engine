-- ============================================================================
-- CS G516: Advanced Database Systems
-- 03_basic_queries.sql: Baseline Relational Inquiries
-- ============================================================================

\c campus_delivery;

-- Q3.1: Active Facilities and Aggregate Counts
SELECT facility_type, COUNT(*) AS total_facilities
FROM restaurant
GROUP BY facility_type;

-- Q3.2: High-Rated Food Hubs (Rating >= 4.2)
SELECT restaurant_id, name, facility_type, student_rating, phone
FROM restaurant
WHERE student_rating >= 4.20
ORDER BY student_rating DESC;

-- Q3.3: Complete Menu Catalog with Outlet Join
SELECT m.item_id, m.name AS item_name, m.category, m.price, m.stove_units, m.prep_time_minutes, r.name AS canteen_name
FROM menu_item m
JOIN restaurant r ON m.restaurant_id = r.restaurant_id
ORDER BY r.name, m.price ASC;

-- Q3.4: Orders by Customer Role
SELECT o.order_id, c.name AS customer_name, c.campus_role, r.name AS canteen_name, o.status, o.created_at
FROM "order" o
JOIN customer c ON o.customer_id = c.customer_id
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
ORDER BY o.created_at DESC;

-- Q3.5: Financial Ledger Overview
SELECT order_id, delivery_fee, surge_bonus, (delivery_fee + surge_bonus) AS total_delivery_comp, status
FROM "order";

-- Q3.6: Fleet Status and Uniform Bag Capacity Accounting
SELECT d.driver_id, d.name, d.status, d.max_bag_capacity,
       COALESCE(SUM(oi.quantity), 0) AS current_items_in_bag,
       (d.max_bag_capacity - COALESCE(SUM(oi.quantity), 0)) AS remaining_slots
FROM driver d
LEFT JOIN "order" o ON d.driver_id = o.driver_id AND o.status = 'IN_TRANSIT'
LEFT JOIN order_item oi ON o.order_id = oi.order_id
GROUP BY d.driver_id, d.name, d.status, d.max_bag_capacity
ORDER BY d.driver_id;

-- Q3.7: Staged Drivers Stationed per Dining Hub
SELECT r.name AS dining_hub, COUNT(d.driver_id) AS staged_driver_count
FROM restaurant r
LEFT JOIN driver d ON r.restaurant_id = d.staged_hub_id
GROUP BY r.name
ORDER BY staged_driver_count DESC;
