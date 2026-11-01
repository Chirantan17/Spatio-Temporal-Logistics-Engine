# 🛰️ Campus Spatiotemporal Delivery Engine
> **Course:** Advanced Database Systems (CS G516)  
> **Evaluation Milestone:** Mid-Semester (Labs 1–3 Deliverables)  
> **Live DB Execution Inspector:** [https://chirantan17.github.io/campus-spatiotemporal-delivery-Mid-Sem/](https://chirantan17.github.io/campus-spatiotemporal-delivery-Mid-Sem/)

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?style=for-the-badge&logo=postgresql&logoColor=white)
![PostGIS](https://img.shields.io/badge/PostGIS-3.3-22c55e?style=for-the-badge&logo=postgis&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-24.0-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Streamlit](https://img.shields.io/badge/Streamlit-1.28-FF4B4B?style=for-the-badge&logo=streamlit&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.10-3776AB?style=for-the-badge&logo=python&logoColor=white)

---

## 📌 Executive Summary

![Dashboard Preview](dashboard_demo.png)

This repository contains the mid-semester spatiotemporal engine baseline for a campus last-mile delivery system. Built using **PostgreSQL/PostGIS**, the system addresses high-concurrency spatial data ingestion by decoupling static transactional state tables from append-only high-frequency telemetry streams. 

The implementation covers physical schema generation, EPSG:4326 coordinate reference system (CRS) standardizations, spatial Generalized Search Tree (GiST) indexing, native PostGIS spatial operators, and an interactive step-by-step Execution Flow Inspector.

---

## 📑 Lab-Wise Accomplishments Breakdown

| Lab Milestone | Core Objectives | Technical Implementation & Deliverables |
| :--- | :--- | :--- |
| **Lab 1: Schema & Indexing** | Physical schema modeling, Spatial CRS configuration, Indexing strategies | • Containerized PostgreSQL 15 + PostGIS 3.3 engine via Docker.<br>• Mapped geometries using `EPSG:4326` (WGS 84).<br>• Constructed `GEOMETRY(POLYGON)` and `GEOMETRY(POINT)` entities.<br>• Applied Generalized Search Tree (**GiST**) spatial indexes across geometry columns. |
| **Lab 2: Ingestion & Telemetry** | Spatial seeding, Boundary definition, Decoupled ingestion | • Seeded complex campus zone polygons via WKT (`ST_GeomFromText`).<br>• Linked delivery drop-offs (`delivery_location`) to zone foreign keys.<br>• Designed an **append-only time-series telemetry table** (`location_trace`) to eliminate row-locking during concurrent GPS pings. |
| **Lab 3: Operators & UI** | PostGIS query execution, Spatial mechanics, Interactive visualization | • Evaluated zone spatial containment via `ST_Contains`.<br>• Performed 30m proximity checks using `ST_DWithin`.<br>• Implemented $O(\log N)$ nearest-driver matching via KNN (`<->` operator).<br>• Built an interactive Execution Flow Inspector (`index.html`) & Streamlit dashboard (`app.py`). |

---

## 🗄️ Database Architecture & Entity-Relationship Model

```mermaid
erDiagram
    CUSTOMER ||--o{ ORDER : "places (1:N)"
    RESTAURANT ||--o{ ORDER : "receives (1:N)"
    RESTAURANT ||--o{ MENU_ITEM : "offers (1:N)"
    ORDER ||--o{ ORDER_ITEM : "contains (1:N)"
    MENU_ITEM ||--o{ ORDER_ITEM : "included_in (1:N)"
    DRIVER ||--o{ ORDER : "fulfills (1:N)"
    DRIVER ||--o{ LOCATION_TRACE : "emits telemetry (1:N)"
    CAMPUS_ZONE ||--o{ DELIVERY_LOCATION : "encloses (1:N)"
    DELIVERY_LOCATION ||--o{ ORDER : "destination_for (1:N)"

    CUSTOMER {
        int customer_id PK
        string name
        string phone
    }
    RESTAURANT {
        int restaurant_id PK
        string name
        geometry location "POINT (SRID 4326)"
    }
    MENU_ITEM {
        int item_id PK
        int restaurant_id FK
        string name
        numeric price
    }
    ORDER {
        int order_id PK
        int customer_id FK
        int restaurant_id FK
        int driver_id FK
        int destination_id FK
        string status
    }
    ORDER_ITEM {
        int order_id FK
        int item_id FK
        int quantity
        numeric price_at_order
    }
    DRIVER {
        int driver_id PK
        string name
        string status
    }
    LOCATION_TRACE {
        bigint trace_id PK
        int driver_id FK
        geometry location "POINT (SRID 4326)"
        timestamp recorded_at
    }
    DELIVERY_LOCATION {
        int location_id PK
        int zone_id FK
        geometry point "POINT (SRID 4326)"
    }
    CAMPUS_ZONE {
        int zone_id PK
        string zone_name
        geometry boundary "POLYGON (SRID 4326)"
    }