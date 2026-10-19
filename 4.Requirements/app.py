import streamlit as st
import pandas as pd
import psycopg2
import graphviz

# ============================================================================
# PAGE CONFIGURATION
# ============================================================================
st.set_page_config(
    page_title="Campus DB Flow Simulator",
    page_icon="🛰️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ============================================================================
# DATABASE CONNECTION
# ============================================================================
def get_connection():
    try:
        return psycopg2.connect(
            host="localhost",
            port=5432,
            dbname="campus_delivery",
            user="postgres",
            password="postgres"
        )
    except Exception as e:
        st.error(f"❌ Database Connection Failed: {e}")
        return None

def run_query(query, params=None, fetch_results=True):
    conn = get_connection()
    if not conn:
        return None
    try:
        with conn.cursor() as cur:
            cur.execute(query, params)
            if fetch_results and cur.description:
                colnames = [desc[0] for desc in cur.description]
                data = cur.fetchall()
                conn.commit()
                return pd.DataFrame(data, columns=colnames)
            conn.commit()
            return True
    except Exception as e:
        conn.rollback()
        st.error(f"SQL Error: {e}")
        return None
    finally:
        conn.close()

# ============================================================================
# SESSION STATE INITIALIZATION
# ============================================================================
if 'sim_step' not in st.session_state:
    st.session_state.sim_step = 0
if 'active_order_id' not in st.session_state:
    st.session_state.active_order_id = None
if 'active_driver_id' not in st.session_state:
    st.session_state.active_driver_id = None
if 'selected_canteen_id' not in st.session_state:
    st.session_state.selected_canteen_id = 1
if 'selected_dest_id' not in st.session_state:
    st.session_state.selected_dest_id = 1
if 'order_item_ids' not in st.session_state:
    st.session_state.order_item_ids = [1]

# ============================================================================
# DYNAMIC ER DIAGRAM GENERATOR
# ============================================================================
def render_er_diagram(active_tables):
    dot = graphviz.Digraph(comment='Live Database ER Flow')
    dot.attr(rankdir='LR', bgcolor='transparent')
    
    tables = {
        'CAMPUS_ZONE': 'Zone Geofences\n(POLYGON)',
        'DELIVERY_LOCATION': 'Drop-off Points\n(POINT)',
        'RESTAURANT': 'Canteens\n(POINT)',
        'MENU_ITEM': 'Catalog Items',
        'ORDER': 'Order State',
        'ORDER_ITEM': 'Line Items',
        'DRIVER': 'Driver Status',
        'LOCATION_TRACE': 'GPS Telemetry\n(POINT Append-Only)'
    }
    
    for tbl, label in tables.items():
        if tbl in active_tables:
            dot.node(tbl, label, shape='box', style='filled', fillcolor='#22c55e', fontcolor='white', penwidth='3')
        else:
            dot.node(tbl, label, shape='box', style='filled,rounded', fillcolor='#1e293b', fontcolor='#94a3b8', penwidth='1')
            
    # Relationships
    dot.edge('CAMPUS_ZONE', 'DELIVERY_LOCATION', label='ST_Contains')
    dot.edge('RESTAURANT', 'MENU_ITEM', label='offers')
    dot.edge('DELIVERY_LOCATION', 'ORDER', label='receives')
    dot.edge('RESTAURANT', 'ORDER', label='originates')
    dot.edge('ORDER', 'ORDER_ITEM', label='contains FK')
    dot.edge('DRIVER', 'ORDER', label='assigned')
    dot.edge('DRIVER', 'LOCATION_TRACE', label='emits GPS')
    
    return dot

# ============================================================================
# HEADER & NAVIGATION
# ============================================================================
st.title("🛰️ Campus Spatiotemporal Delivery Engine")
st.caption("Advanced Database Systems (CS G516) — Conceptual DB Design & Live Flow Inspector")

tab_client, tab_inspector = st.tabs(["🛒 Client Order Simulator", "🔍 Developer DB Inspector & ER Flow"])

# Fetch reference data
restaurants = run_query("SELECT restaurant_id, name FROM restaurant ORDER BY restaurant_id;")
destinations = run_query("SELECT location_id, name FROM delivery_location ORDER BY location_id;")

# ============================================================================
# TAB 1: CLIENT ORDER SIMULATOR
# ============================================================================
with tab_client:
    st.subheader("Simulate New Customer Order")
    col1, col2 = st.columns([1, 1])
    
    with col1:
        if restaurants is not None and not restaurants.empty:
            rest_dict = dict(zip(restaurants['name'], restaurants['restaurant_id']))
            sel_rest = st.selectbox("1. Choose Canteen:", list(rest_dict.keys()))
            st.session_state.selected_canteen_id = rest_dict[sel_rest]
            
            # Fetch menu items for chosen canteen
            menu = run_query("SELECT item_id, name, price FROM menu_item WHERE restaurant_id = %s;", (st.session_state.selected_canteen_id,))
            if menu is not None and not menu.empty:
                menu_dict = dict(zip(menu['name'] + " (₹" + menu['price'].astype(str) + ")", menu['item_id']))
                sel_items = st.multiselect("2. Select Menu Items:", list(menu_dict.keys()), default=[list(menu_dict.keys())[0]])
                st.session_state.order_item_ids = [menu_dict[i] for i in sel_items]

    with col2:
        if destinations is not None and not destinations.empty:
            dest_dict = dict(zip(destinations['name'], destinations['location_id']))
            sel_dest = st.selectbox("3. Select Delivery Drop-Off:", list(dest_dict.keys()))
            st.session_state.selected_dest_id = dest_dict[sel_dest]
        
        st.write("")
        st.write("")
        if st.button("🚀 Initialize Transaction Pipeline", type="primary", use_container_width=True):
            st.session_state.sim_step = 1
            st.session_state.active_order_id = None
            st.session_state.active_driver_id = None
            st.success("Pipeline initialized! Switch to the **Developer DB Inspector** tab to step through DB execution.")

# ============================================================================
# TAB 2: DEVELOPER DB INSPECTOR & LIVE FLOW
# ============================================================================
with tab_inspector:
    st.subheader("Database Lifecycle & Conceptual Execution Flow")
    
    # Control Panel
    ctrl1, ctrl2, ctrl3, ctrl4 = st.columns([1, 1, 1, 2])
    
    with ctrl1:
        if st.button("◀ Reset Pipeline", use_container_width=True):
            st.session_state.sim_step = 0
            st.session_state.active_order_id = None
            st.session_state.active_driver_id = None
            
    with ctrl2:
        if st.button("▶ Next DB Step", type="primary", use_container_width=True):
            if st.session_state.sim_step < 4:
                st.session_state.sim_step += 1
            else:
                st.info("Pipeline complete. Reset to run again.")
                
    with ctrl3:
        st.metric("Active Lifecycle Step", f"Step {st.session_state.sim_step} / 4")

    st.divider()

    # Step Execution Logic
    active_tables = []
    sql_executed = ""
    step_title = ""
    step_description = ""

    # ------------------------------------------------------------------------
    # STEP 0: IDLE
    # ------------------------------------------------------------------------
    if st.session_state.sim_step == 0:
        step_title = "Step 0: System Idle"
        step_description = "Waiting for an order trigger from the client portal."
        active_tables = []

    # ------------------------------------------------------------------------
    # STEP 1: RELATIONAL STATE INSERTION
    # ------------------------------------------------------------------------
    elif st.session_state.sim_step == 1:
        step_title = "Step 1: Relational Order & Foreign Key Insertion"
        step_description = "Writing static transaction state. Creates a parent tuple in 'order' and dependent tuples in 'order_item'."
        active_tables = ['ORDER', 'ORDER_ITEM', 'RESTAURANT', 'DELIVERY_LOCATION']
        
        if st.session_state.active_order_id is None:
            # Insert parent order
            res = run_query(
                'INSERT INTO "order" (customer_id, restaurant_id, destination_id, status, created_at) '
                'VALUES (1, %s, %s, \'PENDING\', CURRENT_TIMESTAMP) RETURNING order_id;',
                (st.session_state.selected_canteen_id, st.session_state.selected_dest_id)
            )
            if res is not None and not res.empty:
                st.session_state.active_order_id = int(res.iloc[0]['order_id'])
                
                # Insert order items
                for item_id in st.session_state.order_item_ids:
                    run_query(
                        'INSERT INTO order_item (order_id, item_id, quantity, price_at_order) '
                        'VALUES (%s, %s, 1, 100.00);',
                        (st.session_state.active_order_id, item_id),
                        fetch_results=False
                    )

        sql_executed = f"""-- 1. Insert Parent Order Header
INSERT INTO "order" (customer_id, restaurant_id, destination_id, status, created_at)
VALUES (1, {st.session_state.selected_canteen_id}, {st.session_state.selected_dest_id}, 'PENDING', CURRENT_TIMESTAMP)
RETURNING order_id; -- Generated ID: {st.session_state.active_order_id}

-- 2. Insert Dependent Line Items (Cascading FK Constraint)
INSERT INTO order_item (order_id, item_id, quantity, price_at_order)
VALUES ({st.session_state.active_order_id}, {st.session_state.order_item_ids[0]}, 1, 100.00);"""

    # ------------------------------------------------------------------------
    # STEP 2: POSTGIS SPATIAL KNN MATCHING (<->)
    # ------------------------------------------------------------------------
    elif st.session_state.sim_step == 2:
        step_title = "Step 2: PostGIS Nearest-Driver Allocation (GiST Index KNN)"
        step_description = "Executing $O(\\log N)$ spatial index lookup using the bounding-box distance operator (<->) to pair the nearest available driver."
        active_tables = ['DRIVER', 'LOCATION_TRACE', 'ORDER']
        
        knn_res = run_query("""
            SELECT d.driver_id, d.name AS driver_name,
                   lt.location <-> r.location AS spatial_bounding_distance
            FROM driver d
            JOIN location_trace lt ON d.driver_id = lt.driver_id
            CROSS JOIN restaurant r
            WHERE r.restaurant_id = %s
              AND d.status = 'AVAILABLE'
            ORDER BY lt.location <-> r.location
            LIMIT 1;
        """, (st.session_state.selected_canteen_id,))
        
        if knn_res is not None and not knn_res.empty:
            st.session_state.active_driver_id = int(knn_res.iloc[0]['driver_id'])
            
            run_query(
                'UPDATE "order" SET driver_id = %s, status = \'PREPARING\' WHERE order_id = %s;',
                (st.session_state.active_driver_id, st.session_state.active_order_id),
                fetch_results=False
            )
            
        sql_executed = f"""-- PostGIS K-Nearest Neighbor (KNN) Search via GiST Index
SELECT d.driver_id, d.name AS driver_name,
       lt.location <-> r.location AS spatial_bounding_distance
FROM driver d
JOIN location_trace lt ON d.driver_id = lt.driver_id
CROSS JOIN restaurant r
WHERE r.restaurant_id = {st.session_state.selected_canteen_id} AND d.status = 'AVAILABLE'
ORDER BY lt.location <-> r.location
LIMIT 1;

-- Assign Driver & Transition Order State
UPDATE "order" 
SET driver_id = {st.session_state.active_driver_id}, status = 'PREPARING' 
WHERE order_id = {st.session_state.active_order_id};"""

    # ------------------------------------------------------------------------
    # STEP 3: SPATIAL CONTAINMENT VERIFICATION (ST_Contains)
    # ------------------------------------------------------------------------
    elif st.session_state.sim_step == 3:
        step_title = "Step 3: Spatial Polygon Containment & Zone Analytics"
        step_description = "Evaluating ST_Contains(campus_zone.boundary, delivery_location.point) to aggregate zone performance."
        active_tables = ['CAMPUS_ZONE', 'DELIVERY_LOCATION', 'ORDER']
        
        sql_executed = f"""-- Verify Destination Polygon Containment (EPSG:4326)
SELECT z.zone_name, dl.name AS dropoff_point,
       ST_Contains(z.boundary, dl.point) AS is_enclosed
FROM campus_zone z
JOIN delivery_location dl ON dl.location_id = {st.session_state.selected_dest_id}
WHERE ST_Contains(z.boundary, dl.point);"""

    # ------------------------------------------------------------------------
    # STEP 4: TELEMETRY APPEND & ORDER FULFILLMENT
    # ------------------------------------------------------------------------
    elif st.session_state.sim_step == 4:
        step_title = "Step 4: Append-Only Telemetry Ingestion & Fulfillment"
        step_description = "Appending new GPS pings to location_trace without row-locking. Transitioning state to DELIVERED."
        active_tables = ['LOCATION_TRACE', 'ORDER', 'DRIVER']
        
        if st.session_state.active_driver_id:
            # Append GPS ping
            run_query(
                'INSERT INTO location_trace (driver_id, location, recorded_at) '
                'VALUES (%s, ST_SetSRID(ST_MakePoint(78.348, 17.458), 4326), CURRENT_TIMESTAMP);',
                (st.session_state.active_driver_id,),
                fetch_results=False
            )
            # Fulfill order
            run_query(
                'UPDATE "order" SET status = \'DELIVERED\', fulfilled_at = CURRENT_TIMESTAMP WHERE order_id = %s;',
                (st.session_state.active_order_id,),
                fetch_results=False
            )
            
        sql_executed = f"""-- 1. Append High-Frequency Telemetry Ping (Non-locking time-series write)
INSERT INTO location_trace (driver_id, location, recorded_at)
VALUES ({st.session_state.active_driver_id}, ST_SetSRID(ST_MakePoint(78.348, 17.458), 4326), CURRENT_TIMESTAMP);

-- 2. Complete Order Lifecycle
UPDATE "order" 
SET status = 'DELIVERED', fulfilled_at = CURRENT_TIMESTAMP 
WHERE order_id = {st.session_state.active_order_id};"""

    # Layout: ER Diagram on Left, Live DB Data & Queries on Right
    vis_left, vis_right = st.columns([1.2, 1])
    
    with vis_left:
        st.markdown(f"#### 🌐 Live ER State Diagram: `{step_title}`")
        st.caption(step_description)
        st.graphviz_chart(render_er_diagram(active_tables), use_container_width=True)
        
    with vis_right:
        st.markdown("#### 📝 Executed PostGIS / SQL Query")
        if sql_executed:
            st.code(sql_executed, language="sql")
        else:
            st.info("No query active. Advance to Step 1.")
            
        st.markdown("#### 📊 Affected Table Tuples (Real-Time State)")
        if st.session_state.active_order_id:
            order_data = run_query(
                'SELECT order_id, customer_id, driver_id, restaurant_id, status, created_at, fulfilled_at '
                'FROM "order" WHERE order_id = %s;',
                (st.session_state.active_order_id,)
            )
            st.write("**`order` Table State:**")
            st.dataframe(order_data, use_container_width=True)
            
            items_data = run_query(
                'SELECT order_id, item_id, quantity, price_at_order FROM order_item WHERE order_id = %s;',
                (st.session_state.active_order_id,)
            )
            st.write("**`order_item` Foreign Key State:**")
            st.dataframe(items_data, use_container_width=True)