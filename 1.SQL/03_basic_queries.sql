-- Q3.0: SYSTEM INTEGRITY AUDIT (View Q3.0)
SELECT * FROM integrity_audit;

-- Q3.1: Dining Infrastructure Summary (Count by facility type)
SELECT facility_type, COUNT(*) AS total_facilities
FROM restaurant
GROUP BY facility_type
ORDER BY facility_type;

-- Q3.2: Complete List of Active Campus Dining Hubs
SELECT restaurant_id, name, facility_type, student_rating, phone
FROM restaurant
ORDER BY restaurant_id;

-- Q3.3: Menu Catalog for Main Canteen (Focusing on slot capacity and pricing)
SELECT mi.item_id, mi.name AS item_name, mi.category, mi.price, mi.stove_units, mi.prep_time_minutes, r.name AS canteen_name
FROM menu_item mi
JOIN restaurant r ON mi.restaurant_id = r.restaurant_id
WHERE r.name = 'Main Canteen (Academic Canteen)';

-- Q3.4: List active pending/preparing orders with customer role hierarchy
SELECT o.order_id, c.name AS customer_name, c.user_role, r.name AS canteen_name, o.status, o.created_at
FROM "order" o
JOIN customer c ON o.customer_id = c.customer_id
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
WHERE o.status IN ('PENDING', 'PREPARING', 'IN_TRANSIT');

-- Q3.5: Dynamic Order Invoice Calculation View (3NF Compliance)
SELECT ot.order_id, ot.total_amount AS final_invoice_total, o.delivery_fee, o.status
FROM order_total ot
JOIN "order" o ON ot.order_id = o.order_id
ORDER BY ot.order_id;

-- Q3.6: Fleet Bag Capacity Audit
SELECT * FROM driver_bag_capacity_view
ORDER BY current_items_in_bag DESC;

-- Q3.7: Staged Drivers per Dining Hub Verification (2 units per hub guarantee)
SELECT r.name AS dining_hub, COUNT(d.driver_id) AS staged_driver_count
FROM restaurant r
LEFT JOIN driver d ON r.restaurant_id = d.staging_restaurant_id
GROUP BY r.restaurant_id, r.name
ORDER BY r.restaurant_id;