-- ============================================================================
-- 13_database_views.sql
-- Fleet Proximity & Financial Audit Execution Views
-- ============================================================================

-- View 1: Real-time Fleet Proximity
CREATE OR REPLACE VIEW view_active_fleet_canteen_distance AS
SELECT d.driver_id, d.name AS driver_name, d.status AS driver_status, r.restaurant_id, r.name AS canteen_name,
ROUND(ST_Distance(lt.location::geography, r.location::geography)::numeric, 1) AS distance_meters
FROM driver d
JOIN (
    SELECT DISTINCT ON (driver_id) driver_id, location, recorded_at 
    FROM location_trace 
    ORDER BY driver_id, recorded_at DESC
) lt ON d.driver_id = lt.driver_id
CROSS JOIN restaurant r;

-- View 2: Financial Audit Ledger (Dynamic Surge Payout Model)
CREATE OR REPLACE VIEW view_financial_audit_ledger AS
SELECT o.order_id, o.created_at, r.name AS canteen_name, c.name AS customer_name, d.name AS driver_name, o.delivery_fee AS customer_paid_fee,
o.surge_bonus AS restaurant_funded_bonus,
(o.delivery_fee + o.surge_bonus) AS driver_total_earnings
FROM "order" o
JOIN restaurant r ON o.restaurant_id = r.restaurant_id
JOIN customer c ON o.customer_id = c.customer_id
LEFT JOIN driver d ON o.driver_id = d.driver_id;
