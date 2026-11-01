-- ============================================================================
-- CS G516: Advanced Database Systems - Studio Capstone
-- 01_schema.sql: Authoritative Relational & Spatiotemporal Schema (3NF)
-- ============================================================================

\c campus_delivery;

CREATE EXTENSION IF NOT EXISTS postgis;

-- ----------------------------------------------------------------------------
-- 1. MASTER DOMAIN ENTITIES (Canonical Vocabulary Enforced)
-- ----------------------------------------------------------------------------

CREATE TABLE customer (
    customer_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    campus_role VARCHAR(20) NOT NULL CHECK (campus_role IN ('STUDENT', 'FACULTY', 'STAFF', 'DIRECTOR')),
    gender VARCHAR(10) CHECK (gender IN ('MALE', 'FEMALE', 'OTHER')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE restaurant (
    restaurant_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    facility_type VARCHAR(50) NOT NULL,
    target_demographic VARCHAR(50) DEFAULT 'All',
    student_rating NUMERIC(3,2) CHECK (student_rating BETWEEN 1.0 AND 5.0),
    phone VARCHAR(20) NOT NULL,
    location geometry(Point, 4326) NOT NULL
);

CREATE TABLE menu_item (
    item_id SERIAL PRIMARY KEY,
    restaurant_id INT NOT NULL REFERENCES restaurant(restaurant_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    price NUMERIC(8,2) NOT NULL CHECK (price >= 0),
    serve_start TIME NOT NULL DEFAULT '06:00:00',
    serve_end TIME NOT NULL DEFAULT '23:00:00',
    prep_time_minutes INT NOT NULL DEFAULT 10 CHECK (prep_time_minutes > 0),
    stove_units INT NOT NULL DEFAULT 1 CHECK (stove_units BETWEEN 0 AND 4),
    CONSTRAINT uq_restaurant_item UNIQUE (restaurant_id, name)
);

CREATE TABLE driver (
    driver_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE' CHECK (status IN ('AVAILABLE', 'BUSY', 'OFFLINE')),
    staged_hub_id INT REFERENCES restaurant(restaurant_id),
    max_bag_capacity INT NOT NULL DEFAULT 5 CHECK (max_bag_capacity > 0)
);

-- ----------------------------------------------------------------------------
-- 2. SPATIAL GEOMETRIES & GEOFENCES (Canonical Vocabulary: AUTHORIZED_CORRIDOR)
-- ----------------------------------------------------------------------------

CREATE TABLE campus_zone (
    zone_id SERIAL PRIMARY KEY,
    zone_name VARCHAR(100) NOT NULL UNIQUE,
    zone_type VARCHAR(30) NOT NULL CHECK (zone_type IN ('AUTHORIZED_CORRIDOR', 'RESTRICTED_INTERIOR', 'RESIDENTIAL_BUFFER')),
    boundary geometry(Polygon, 4326) NOT NULL
);

CREATE TABLE delivery_location (
    location_id SERIAL PRIMARY KEY,
    zone_id INT NOT NULL REFERENCES campus_zone(zone_id),
    name VARCHAR(100) NOT NULL UNIQUE,
    point geometry(Point, 4326) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 3. TRANSACTIONS & TELEMETRY
-- ----------------------------------------------------------------------------

CREATE TABLE "order" (
    order_id VARCHAR(20) PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customer(customer_id),
    restaurant_id INT NOT NULL REFERENCES restaurant(restaurant_id),
    driver_id INT REFERENCES driver(driver_id),
    destination_id INT NOT NULL REFERENCES delivery_location(location_id),
    status VARCHAR(25) NOT NULL DEFAULT 'PENDING' CHECK (
        status IN ('PENDING', 'PREPARING', 'READY', 'IN_TRANSIT', 'READY_FOR_PICKUP', 'DELIVERED', 'CANCELLED')
    ),
    delivery_fee NUMERIC(8,2) NOT NULL DEFAULT 15.00 CHECK (delivery_fee >= 0),
    surge_bonus NUMERIC(8,2) NOT NULL DEFAULT 0.00 CHECK (surge_bonus >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ready_at TIMESTAMP,
    dispatched_at TIMESTAMP,
    fulfilled_at TIMESTAMP,
    CONSTRAINT uq_order_restaurant UNIQUE (order_id, restaurant_id)
);

CREATE TABLE order_item (
    order_id VARCHAR(20) NOT NULL,
    item_id INT NOT NULL,
    restaurant_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    price_at_order NUMERIC(8,2) NOT NULL CHECK (price_at_order >= 0),
    PRIMARY KEY (order_id, item_id),
    FOREIGN KEY (order_id, restaurant_id) REFERENCES "order"(order_id, restaurant_id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES menu_item(item_id)
);

CREATE TABLE location_trace (
    trace_id BIGSERIAL PRIMARY KEY,
    driver_id INT NOT NULL REFERENCES driver(driver_id) ON DELETE CASCADE,
    location geometry(Point, 4326) NOT NULL,
    speed_kmh NUMERIC(5,2) DEFAULT 0.00,
    recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE security_breach_log (
    log_id BIGSERIAL PRIMARY KEY,
    driver_id INT NOT NULL REFERENCES driver(driver_id),
    order_id VARCHAR(20) REFERENCES "order"(order_id),
    breached_zone_id INT NOT NULL REFERENCES campus_zone(zone_id),
    breached_zone_name VARCHAR(100) NOT NULL,
    breach_point geometry(Point, 4326) NOT NULL,
    detected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
