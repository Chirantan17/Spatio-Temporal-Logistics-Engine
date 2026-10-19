-- ============================================================================
-- 1. BASIC RELATIONAL / OPERATIONAL QUERIES
-- ============================================================================

-- Q3.0:DIAGNOSTIC & ANOMALY DETECTION
-- Problem Solved: This query demonstrates the system's ability to actively audit 
-- and flag cross-table logical inconsistencies (IUD anomalies).
--
-- What is the "Driver Mismatch Anomaly"?
-- It is a severe logistical contradiction where an order is actively progressing 
-- (status: 'PENDING', 'PREPARING', or 'IN_TRANSIT') and is assigned to a specific driver, 
-- but that driver's workforce status in the database is incorrectly set to 'OFFLINE'.
--
-- Our Assumption:
-- We assume a strict state-machine dependency between workforce availability and logistics: 
-- an active delivery absolutely requires a driver in an active state. 
-- If a driver drops 'OFFLINE' while holding an order, the system inherently loses telemetry 
-- tracking capabilities, creating a stalled "ghost" delivery.--THIEF!!!
-- This diagnostic view immediately catches that exact breakdown.
--
-- By running this and returning an empty set, we prove  that our 
-- current database state is 100% consistent and free of logistical state-machine corruption.
SELECT * FROM integrity_audit;

-- ============================================================================
-- SYSTEM INTRODUCTION & OVERVIEW
-- ============================================================================

-- Q3.1: Campus Dining Infrastructure Summary (Count of Canteens vs Messes)
-- Provides an introductory count of how many operational facilities are currently in the system
SELECT facility_type, COUNT(*) AS total_facilities
FROM restaurant
GROUP BY facility_type
ORDER BY facility_type;

-- Q3.2: Complete List of Active Canteens
-- Generates a roster of all specific canteens available for active student ordering
SELECT restaurant_id, name AS canteen_name, target_demographic, phone
FROM restaurant
WHERE facility_type = 'Canteen'
ORDER BY restaurant_id;

-- ============================================================================
-- FOCUSED MENU & ORDER LOGIC
-- ============================================================================

-- Q3.3: Fetch full menu catalog for a specific canteen (Focusing on Canteen 1)
-- Includes temporal bounds (serve_start_time, serve_end_time) mapped to each item
SELECT mi.item_id, mi.name AS item_name, mi.category, mi.price, 
       mi.serve_start_time, mi.serve_end_time, r.name AS restaurant_name
FROM menu_item mi
JOIN restaurant r ON mi.restaurant_id = r.restaurant_id
WHERE r.name = 'Canteen 1 (Main Hub)';

-- Q3.4: List active pending/preparing orders of all canteens with customer details
SELECT o.order_id, c.name AS customer_name, c.phone, r.name AS canteen_name, o.status, o.created_at
FROM "order" o
JOIN customer c ON o.customer_id = c.customer_id
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
WHERE o.status IN ('PENDING', 'PREPARING');

-- Q3.5: Utilize the Order Total View 
-- Proves we eliminate storing redundant totals by calculating them dynamically via a VIEW.
-- WHY THIS MATTERS: Proves strict 3NF compliance (No Derived Data).
-- We DO NOT store a static 'total_amount' in the order table to avoid Update Anomalies.
-- This VIEW calculates the math live (SUM(qty * price) + fee) so it can never be out-of-sync.
SELECT ot.order_id, ot.total_amount AS final_invoice_total, o.delivery_fee, o.status
FROM order_total ot
JOIN "order" o ON ot.order_id = o.order_id
ORDER BY ot.order_id;

-- Q3.6: ANOMALY PROOF — Historical Price Snapshot Audit
-- Proves that updating current menu prices does not corrupt historical order totals.

SELECT oi.order_id, mi.name AS item_name,
       oi.price_at_order AS historical_price_paid,
       mi.price AS current_catalog_price,
       (mi.price - oi.price_at_order) AS price_drift_difference
FROM order_item oi
JOIN menu_item mi ON oi.item_id = mi.item_id
ORDER BY oi.order_id;

-- Q3.7: List all dining facilities and their ratings
-- Used later for predictive behavioral analysis based on student ratings.
SELECT r.restaurant_id, r.name, r.facility_type, r.target_demographic, r.student_rating
FROM restaurant r
ORDER BY r.student_rating DESC;