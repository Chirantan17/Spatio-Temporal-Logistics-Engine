-- Enable PostGIS spatial extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Drop tables in clean cascade sequence
DROP TABLE IF EXISTS security_breach_log CASCADE;
DROP TABLE IF EXISTS location_trace CASCADE;
DROP TABLE IF EXISTS order_item CASCADE;
DROP TABLE IF EXISTS "order" CASCADE;
DROP TABLE IF EXISTS menu_item CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS delivery_location CASCADE;
DROP TABLE IF EXISTS restaurant CASCADE;
DROP TABLE IF EXISTS driver CASCADE;
DROP TABLE IF EXISTS campus_zone CASCADE;
DROP VIEW IF EXISTS integrity_audit CASCADE;
DROP VIEW IF EXISTS driver_bag_capacity_view CASCADE;
DROP VIEW IF EXISTS order_total CASCADE;

-- 1. Campus Zones (Geofences with Security Tiers)
CREATE TABLE campus_zone (
    zone_id SERIAL PRIMARY KEY,
    zone_name VARCHAR(100) NOT NULL,
    zone_type VARCHAR(50) DEFAULT 'PERMITTED_CORRIDOR' CHECK (zone_type IN ('PERMITTED_CORRIDOR', 'RESTRICTED_INTERIOR')),
    boundary GEOMETRY(Polygon, 4326) NOT NULL
);

-- 2. Restaurants & Dining Hubs (Must be created before driver for staging FK)
CREATE TABLE restaurant (
    restaurant_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    facility_type VARCHAR(20) DEFAULT 'Canteen' CHECK (facility_type IN ('Canteen', 'Mess')),
    phone VARCHAR(20) UNIQUE,
    student_rating NUMERIC(2,1) DEFAULT 4.5 CHECK (student_rating >= 0 AND student_rating <= 5.0),
    location GEOMETRY(Point, 4326) NOT NULL
);

-- 3. Drivers (Linked to Dedicated Staging Hubs with bag capacity standard)
CREATE TABLE driver (
    driver_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) UNIQUE,
    staging_restaurant_id INT REFERENCES restaurant(restaurant_id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'AVAILABLE' CHECK (status IN ('AVAILABLE', 'BUSY', 'OFFLINE')),
    max_bag_capacity INT DEFAULT 5 CHECK (max_bag_capacity = 5)
);

-- 4. Delivery Drop-Off Nodes (Authorized Gates)
CREATE TABLE delivery_location (
    location_id SERIAL PRIMARY KEY,
    zone_id INT REFERENCES campus_zone(zone_id) ON DELETE SET NULL,
    name VARCHAR(100) NOT NULL,
    point GEOMETRY(Point, 4326) NOT NULL
);

-- 5. Customers (Role-Based Hierarchy)
CREATE TABLE customer (
    customer_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) UNIQUE,
    email VARCHAR(100),
    user_role VARCHAR(20) NOT NULL DEFAULT 'STUDENT' CHECK (user_role IN ('STUDENT', 'FACULTY', 'STAFF', 'DIRECTOR')),
    gender VARCHAR(10) DEFAULT 'N/A' CHECK (gender IN ('MALE', 'FEMALE', 'OTHER', 'N/A')),
    designation_block VARCHAR(50) 
);

-- 6. Menu Items
CREATE TABLE menu_item (
    item_id SERIAL PRIMARY KEY,
    restaurant_id INT REFERENCES restaurant(restaurant_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) DEFAULT 'General',
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    serve_start_time TIME NOT NULL DEFAULT '00:00:00',
    serve_end_time TIME NOT NULL DEFAULT '23:59:59',
    prep_time_minutes INT DEFAULT 10,
    stove_units INT DEFAULT 1 CHECK (stove_units >= 0 AND stove_units <= 4),
    UNIQUE (item_id, restaurant_id) 
);

-- 7. Orders
CREATE TABLE "order" (
    order_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customer(customer_id) ON DELETE RESTRICT,
    restaurant_id INT REFERENCES restaurant(restaurant_id) ON DELETE RESTRICT,
    driver_id INT REFERENCES driver(driver_id) ON DELETE SET NULL,
    destination_id INT REFERENCES delivery_location(location_id) ON DELETE RESTRICT,
    status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'PREPARING', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED')),
    delivery_fee NUMERIC(10, 2) DEFAULT 15.00 CHECK (delivery_fee >= 0),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    fulfilled_at TIMESTAMPTZ,
    UNIQUE (order_id, restaurant_id)
);

-- 8. Order Line Items
CREATE TABLE order_item (
    order_id INT NOT NULL,
    item_id INT NOT NULL,
    restaurant_id INT NOT NULL, 
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0 AND quantity <= 5),
    price_at_order NUMERIC(10, 2) NOT NULL CHECK (price_at_order >= 0),
    PRIMARY KEY (order_id, item_id),
    FOREIGN KEY (order_id, restaurant_id) REFERENCES "order" (order_id, restaurant_id) ON DELETE CASCADE,
    FOREIGN KEY (item_id, restaurant_id) REFERENCES menu_item (item_id, restaurant_id) ON DELETE RESTRICT
);

-- 9. GPS Telemetry Trace
CREATE TABLE location_trace (
    trace_id SERIAL PRIMARY KEY,
    driver_id INT REFERENCES driver(driver_id) ON DELETE CASCADE,
    location GEOMETRY(Point, 4326) NOT NULL,
    recorded_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 10. Security Breach Audit Log
CREATE TABLE security_breach_log (
    log_id SERIAL PRIMARY KEY,
    trace_id INT REFERENCES location_trace(trace_id) ON DELETE CASCADE,
    driver_id INT REFERENCES driver(driver_id) ON DELETE CASCADE,
    breach_type VARCHAR(100) NOT NULL,
    breach_location GEOMETRY(Point, 4326) NOT NULL,
    recorded_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Spatial Indexes
CREATE INDEX idx_campus_zone_boundary ON campus_zone USING GIST (boundary);
CREATE INDEX idx_restaurant_location ON restaurant USING GIST (location);
CREATE INDEX idx_delivery_location_point ON delivery_location USING GIST (point);
CREATE INDEX idx_location_trace_location ON location_trace USING GIST (location);

-- ============================================================================
-- BUSINESS VIEWS & CONSTRAINTS
-- ============================================================================

-- Dynamic Invoice View (3NF Compliance)
CREATE VIEW order_total AS
SELECT o.order_id, COALESCE(SUM(oi.quantity * oi.price_at_order), 0) + o.delivery_fee AS total_amount
FROM "order" o 
LEFT JOIN order_item oi ON o.order_id = oi.order_id 
GROUP BY o.order_id, o.delivery_fee;

-- Driver Real-Time Bag Load View
CREATE VIEW driver_bag_capacity_view AS
SELECT d.driver_id, d.name, d.status, d.max_bag_capacity,
       COALESCE(SUM(oi.quantity), 0) AS current_items_in_bag,
       (d.max_bag_capacity - COALESCE(SUM(oi.quantity), 0)) AS remaining_slots
FROM driver d
LEFT JOIN "order" o ON d.driver_id = o.driver_id AND o.status IN ('PREPARING', 'IN_TRANSIT')
LEFT JOIN order_item oi ON o.order_id = oi.order_id
GROUP BY d.driver_id, d.name, d.status, d.max_bag_capacity;

-- Comprehensive Integrity Audit (View Q3.0)
CREATE VIEW integrity_audit AS
-- 1. Missing Line Items (FK Orphan Integrity)
SELECT 'Order Missing Items' AS violation, order_id::text AS detail 
FROM "order" o 
WHERE NOT EXISTS (SELECT 1 FROM order_item oi WHERE oi.order_id = o.order_id)
UNION ALL
-- 2. Spatial Perimeter Check (Drop gate outside authorized boundary)
SELECT 'Spatial Inconsistency', dl.name 
FROM delivery_location dl 
JOIN campus_zone z ON dl.zone_id = z.zone_id 
WHERE NOT ST_Covers(z.boundary, dl.point)
UNION ALL
-- 3. Driver Offline Anomaly (Active delivery held by an offline driver)
SELECT 'Driver Offline With Order', d.name || ' (Order #' || o.order_id || ')' 
FROM "order" o 
JOIN driver d ON o.driver_id = d.driver_id 
WHERE o.status IN ('PREPARING', 'IN_TRANSIT') AND d.status = 'OFFLINE'
UNION ALL
-- 4. Bag Overfill Anomaly (> 5 physical items assigned to driver)
SELECT 'Bag Capacity Breach', name || ' holding ' || current_items_in_bag || ' items' 
FROM driver_bag_capacity_view 
WHERE current_items_in_bag > 5;

-- Triggers
CREATE OR REPLACE FUNCTION order_lifecycle_guard() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IN ('DELIVERED', 'CANCELLED') THEN
        RAISE EXCEPTION 'Update Anomaly: Cannot modify an already closed order.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_guard BEFORE UPDATE ON "order" FOR EACH ROW EXECUTE FUNCTION order_lifecycle_guard();

CREATE OR REPLACE FUNCTION prevent_trace_update_delete() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Update/Delete Anomaly: Location traces are immutable.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trace_append_only BEFORE UPDATE OR DELETE ON location_trace FOR EACH ROW EXECUTE FUNCTION prevent_trace_update_delete();

CREATE OR REPLACE FUNCTION detect_spatial_breach() RETURNS TRIGGER AS $$
DECLARE
    breached_zone VARCHAR;
BEGIN
    SELECT zone_name INTO breached_zone
    FROM campus_zone
    WHERE zone_type = 'RESTRICTED_INTERIOR' AND ST_Covers(boundary, NEW.location)
    LIMIT 1;

    IF FOUND THEN
        INSERT INTO security_breach_log (trace_id, driver_id, breach_type, breach_location)
        VALUES (NEW.trace_id, NEW.driver_id, 'UNAUTHORIZED ENTRY: ' || breached_zone, NEW.location);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER spatial_breach_monitor AFTER INSERT ON location_trace FOR EACH ROW EXECUTE FUNCTION detect_spatial_breach();