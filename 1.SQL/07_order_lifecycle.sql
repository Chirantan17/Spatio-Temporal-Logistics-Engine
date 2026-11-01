-- ============================================================================
-- CS G516: Advanced Database Systems - Studio Capstone
-- 07_order_lifecycle.sql: Transactional State Machine & Atomic Dispatch
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. ATOMIC DISPATCH WITH ROW-LEVEL LOCKING & METRIC DISTANCE KNN
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dispatch_order_atomic(
    p_order_id VARCHAR(20),
    p_rejecting_driver_id INT DEFAULT NULL
)
RETURNS TABLE (
    assigned_driver_id INT,
    driver_name VARCHAR(100),
    assigned_status VARCHAR(25),
    surge_incentive NUMERIC(8,2),
    distance_meters NUMERIC
) AS $$
DECLARE
    v_restaurant_id INT;
    v_order_status VARCHAR(25);
    v_order_items INT;
    v_rest_geom geometry;
    v_selected_driver_id INT;
    v_selected_driver_name VARCHAR(100);
    v_dist_m NUMERIC;
    v_eligible_count INT;
    v_surge_payout NUMERIC(8,2) := 0.00;
BEGIN
    -- 1. Validate order state
    SELECT restaurant_id, status 
    INTO v_restaurant_id, v_order_status
    FROM "order" 
    WHERE order_id = p_order_id;

    IF v_order_status IS NULL THEN
        RAISE EXCEPTION 'Order % does not exist.', p_order_id;
    END IF;

    IF v_order_status NOT IN ('READY', 'PREPARING') THEN
        RAISE EXCEPTION 'Order % is in status %, dispatch requires READY or PREPARING.', p_order_id, v_order_status;
    END IF;

    -- 2. Count bag item volume
    SELECT COALESCE(SUM(quantity), 1) INTO v_order_items
    FROM order_item
    WHERE order_id = p_order_id;

    SELECT location INTO v_rest_geom 
    FROM restaurant 
    WHERE restaurant_id = v_restaurant_id;

    -- 3. Check available driver pool (respecting capacity <= 5 and exclusions)
    SELECT COUNT(*) INTO v_eligible_count
    FROM driver d
    WHERE d.status = 'AVAILABLE'
      AND (p_rejecting_driver_id IS NULL OR d.driver_id != p_rejecting_driver_id)
      AND (
          SELECT COALESCE(SUM(oi.quantity), 0)
          FROM "order" o
          JOIN order_item oi ON o.order_id = oi.order_id
          WHERE o.driver_id = d.driver_id 
            AND o.status = 'IN_TRANSIT'
      ) + v_order_items <= d.max_bag_capacity;

    IF v_eligible_count = 0 THEN
        -- Fallback: No eligible drivers available
        UPDATE "order"
        SET status = 'READY_FOR_PICKUP',
            driver_id = NULL,
            delivery_fee = 0.00
        WHERE order_id = p_order_id;

        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, 'READY_FOR_PICKUP'::VARCHAR, 0.00::NUMERIC, 0.0::NUMERIC;
        RETURN;
    END IF;

    IF v_eligible_count = 1 THEN
        v_surge_payout := 50.00; -- Last-driver escalation incentive
    END IF;

    -- 4. True Metric Distance KNN Selection with Row Locking (FOR UPDATE SKIP LOCKED)
    WITH latest_telemetry AS (
        SELECT DISTINCT ON (lt.driver_id)
            lt.driver_id,
            lt.location
        FROM location_trace lt
        ORDER BY lt.driver_id, lt.recorded_at DESC
    ),
    candidate AS (
        SELECT 
            d.driver_id,
            d.name,
            ST_Distance(lt.location::geography, v_rest_geom::geography) AS exact_dist_m
        FROM driver d
        JOIN latest_telemetry lt ON d.driver_id = lt.driver_id
        WHERE d.status = 'AVAILABLE'
          AND (p_rejecting_driver_id IS NULL OR d.driver_id != p_rejecting_driver_id)
          AND (
              SELECT COALESCE(SUM(oi.quantity), 0)
              FROM "order" o
              JOIN order_item oi ON o.order_id = oi.order_id
              WHERE o.driver_id = d.driver_id 
                AND o.status = 'IN_TRANSIT'
          ) + v_order_items <= d.max_bag_capacity
        ORDER BY lt.location <-> v_rest_geom -- GiST index assist
        FOR UPDATE OF d SKIP LOCKED
        LIMIT 1
    )
    SELECT c.driver_id, c.name, c.exact_dist_m 
    INTO v_selected_driver_id, v_selected_driver_name, v_dist_m
    FROM candidate c;

    IF v_selected_driver_id IS NOT NULL THEN
        -- Atomically assign order
        UPDATE "order"
        SET driver_id = v_selected_driver_id,
            status = 'IN_TRANSIT',
            surge_bonus = v_surge_payout,
            dispatched_at = CURRENT_TIMESTAMP
        WHERE order_id = p_order_id;

        -- Check if driver capacity is now full
        IF (
            SELECT COALESCE(SUM(oi.quantity), 0)
            FROM "order" o
            JOIN order_item oi ON o.order_id = oi.order_id
            WHERE o.driver_id = v_selected_driver_id 
              AND o.status = 'IN_TRANSIT'
        ) >= 5 THEN
            UPDATE driver SET status = 'BUSY' WHERE driver_id = v_selected_driver_id;
        END IF;

        RETURN QUERY SELECT 
            v_selected_driver_id, 
            v_selected_driver_name, 
            'IN_TRANSIT'::VARCHAR, 
            v_surge_payout, 
            ROUND(v_dist_m, 1);
    ELSE
        -- Fallback triggered if row lock contention blocked candidates
        UPDATE "order"
        SET status = 'READY_FOR_PICKUP',
            driver_id = NULL,
            delivery_fee = 0.00
        WHERE order_id = p_order_id;

        RETURN QUERY SELECT NULL::INT, NULL::VARCHAR, 'READY_FOR_PICKUP'::VARCHAR, 0.00::NUMERIC, 0.0::NUMERIC;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 2. VERIFIED FULFILLMENT WITH GEOFENCE VALIDATION
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION complete_order_handover(
    p_order_id VARCHAR(20)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_driver_id INT;
    v_dest_point geometry;
    v_driver_loc geometry;
    v_within_geofence BOOLEAN;
BEGIN
    SELECT o.driver_id, dl.point
    INTO v_driver_id, v_dest_point
    FROM "order" o
    JOIN delivery_location dl ON o.destination_id = dl.location_id
    WHERE o.order_id = p_order_id AND o.status = 'IN_TRANSIT';

    IF v_driver_id IS NULL THEN
        RAISE EXCEPTION 'Order % is not currently in transit or does not exist.', p_order_id;
    END IF;

    -- Retrieve latest GPS ping for driver
    SELECT location INTO v_driver_loc
    FROM location_trace
    WHERE driver_id = v_driver_id
    ORDER BY recorded_at DESC
    LIMIT 1;

    IF v_driver_loc IS NULL THEN
        RAISE EXCEPTION 'Fulfillment rejected: No recent telemetry found for driver %.', v_driver_id;
    END IF;

    -- Evaluate geofence proximity (100m radius)
    v_within_geofence := ST_DWithin(v_driver_loc::geography, v_dest_point::geography, 100.0);

    IF NOT v_within_geofence THEN
        RAISE EXCEPTION 'Fulfillment rejected: Driver is outside the 100m authorized drop-off gate radius.';
    END IF;

    -- Complete order
    UPDATE "order"
    SET status = 'DELIVERED',
        fulfilled_at = CURRENT_TIMESTAMP
    WHERE order_id = p_order_id;

    -- Release driver back to AVAILABLE pool
    UPDATE driver SET status = 'AVAILABLE' WHERE driver_id = v_driver_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
