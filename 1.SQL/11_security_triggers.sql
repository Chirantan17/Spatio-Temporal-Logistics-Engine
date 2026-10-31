-- ============================================================================
-- 11_security_triggers.sql
-- Server-Side Security Triggers & State-Machine Enforcement
-- ============================================================================

\c campus_delivery;

-- ----------------------------------------------------------------------------
-- 1. SPATIAL PERIMETER BREACH TRIGGER
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_audit_spatial_breach()
RETURNS TRIGGER AS $$
DECLARE
    v_zone_id INT;
    v_zone_name VARCHAR(100);
    v_active_order_id VARCHAR(20);
BEGIN
    -- Corrected boolean precedence using explicit parentheses
    SELECT cz.zone_id, cz.zone_name 
    INTO v_zone_id, v_zone_name
    FROM campus_zone cz
    WHERE ST_Contains(cz.boundary, NEW.location)
      AND (cz.zone_type = 'RESTRICTED_INTERIOR' OR cz.zone_name LIKE '%Residential%' OR cz.zone_name LIKE '%Directorate%')
    LIMIT 1;

    IF v_zone_id IS NOT NULL THEN
        -- Find driver's active in-flight order
        SELECT order_id INTO v_active_order_id
        FROM "order"
        WHERE driver_id = NEW.driver_id AND status = 'IN_TRANSIT'
        LIMIT 1;

        -- Insert audit entry matching schema
        INSERT INTO security_breach_log (
            driver_id,
            order_id,
            breached_zone_id,
            breached_zone_name,
            breach_point,
            detected_at
        ) VALUES (
            NEW.driver_id,
            v_active_order_id,
            v_zone_id,
            v_zone_name,
            NEW.location,
            NEW.recorded_at
        );

        RAISE WARNING '[POSTGIS SECURITY AUDIT] Driver % entered restricted zone % at %',
            NEW.driver_id, v_zone_name, NEW.recorded_at;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_spatial_breach ON location_trace;
CREATE TRIGGER trg_audit_spatial_breach
AFTER INSERT ON location_trace
FOR EACH ROW
EXECUTE FUNCTION fn_audit_spatial_breach();

-- ----------------------------------------------------------------------------
-- 2. CANONICAL FINITE STATE MACHINE (FSM) TRIGGER
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_enforce_order_state_transitions()
RETURNS TRIGGER AS $$
BEGIN
    -- Allow no-op status updates
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    -- Strict allowable state transitions
    IF OLD.status = 'PENDING' AND NEW.status NOT IN ('PREPARING', 'CANCELLED') THEN
        RAISE EXCEPTION 'Illegal order transition: PENDING -> %', NEW.status;
    ELSIF OLD.status = 'PREPARING' AND NEW.status NOT IN ('READY', 'CANCELLED') THEN
        RAISE EXCEPTION 'Illegal order transition: PREPARING -> %', NEW.status;
    ELSIF OLD.status = 'READY' AND NEW.status NOT IN ('IN_TRANSIT', 'READY_FOR_PICKUP', 'CANCELLED') THEN
        RAISE EXCEPTION 'Illegal order transition: READY -> %', NEW.status;
    ELSIF OLD.status = 'READY_FOR_PICKUP' AND NEW.status NOT IN ('DELIVERED', 'CANCELLED') THEN
        RAISE EXCEPTION 'Illegal order transition: READY_FOR_PICKUP -> %', NEW.status;
    ELSIF OLD.status = 'IN_TRANSIT' AND NEW.status NOT IN ('DELIVERED', 'CANCELLED') THEN
        RAISE EXCEPTION 'Illegal order transition: IN_TRANSIT -> %', NEW.status;
    ELSIF OLD.status IN ('DELIVERED', 'CANCELLED') THEN
        RAISE EXCEPTION 'Terminal state % is immutable. Cannot transition to %.', OLD.status, NEW.status;
    END IF;

    -- Automatically handle timestamping
    IF NEW.status = 'PREPARING' AND OLD.status = 'PENDING' THEN
        -- Preparation begun
    ELSIF NEW.status = 'READY' THEN
        NEW.ready_at := CURRENT_TIMESTAMP;
    ELSIF NEW.status = 'IN_TRANSIT' THEN
        NEW.dispatched_at := CURRENT_TIMESTAMP;
    ELSIF NEW.status = 'DELIVERED' THEN
        NEW.fulfilled_at := CURRENT_TIMESTAMP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_state_transition ON "order";
CREATE TRIGGER trg_order_state_transition
BEFORE UPDATE OF status ON "order"
FOR EACH ROW
EXECUTE FUNCTION fn_enforce_order_state_transitions();