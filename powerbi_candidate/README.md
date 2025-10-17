# Power BI Candidate Exercise: Logistics KPIs

Build a Power BI dashboard on top of prepared Snowflake model tables. You do not need to load data. Your focus is on data modeling, measures (DAX), and clear visuals.

## Connection Details
You will receive a connection card with:
- Account URL: `https://<ACCOUNT_LOCATOR>.<REGION>.snowflakecomputing.com`
- Username / Temporary password (MUST CHANGE on first login)
- Role: `ETL_Cxx_ROLE` (or a reviewer role)
- Warehouse: `ETL_INTERVIEW_WH`
- Database: `ETL_INTERVIEW`
- Schema: `POWERBI_DWH` (read-only, shared across candidates)

In Power BI Desktop:
- Get Data → Snowflake
- Server: `<ACCOUNT_LOCATOR>.<REGION>.snowflakecomputing.com`
- Warehouse: `ETL_INTERVIEW_WH` (if prompted)
- Navigate to database `ETL_INTERVIEW`, schema `POWERBI_DWH`, select all DIM and FACT tables, then Load (Import recommended).

## Tables Available (POWERBI_DWH)
- Dimensions: `DIM_CUSTOMER`, `DIM_CARRIER`, `DIM_EQUIPMENT`, `DIM_LOCATION`, `DIM_LANE`, `DIM_DATE`
- Facts: `FACT_SHIPMENT`, `FACT_EVENT`, `FACT_COST`

These tables form a star schema centered on `FACT_SHIPMENT`. See `powerbi_candidate/datamodel.md` for relationships.

## Required Pages & Visuals
Create 4 pages with slicers (Customer, Carrier, Equipment, Lane, Date range) and the visuals below.

1) Overview
- KPIs: Delivered Shipments, OTD Rate (last 30 days), OTD vs Prior 30d Δ, Avg Transit Days, Tender Acceptance Rate, GM per Mile.
- Trend: OTD% by day (last 60 days) and Delivered Shipments by day as columns.

2) Lane Performance
- Bar: Avg Transit Days by Lane (Origin → Dest label).
- Dot/line overlay: OTD% by Lane.
- Optionally filter lanes with at least N shipments.

3) Exceptions
- Matrix (heatmap): Customer × Exception Type (counts from `FACT_EVENT` where `EVENT_TYPE='Exception'`).
- Table: Top Exception Types with counts.

4) Shipment Details
- Table with: Shipment ID, Leg, Customer, Carrier, Lane, Status, Pickup/Delivery Plan+Actual, On‑Time flag, In‑Full flag, OTIF flag, Planned/Actual Miles, Revenue, Total Cost, GM per Mile.

## Measures (DAX) — Guidance
You can implement exact names flexibly; ensure logic matches.

- Delivered Shipments = COUNTROWS(FILTER(FACT_SHIPMENT, NOT ISBLANK(FACT_SHIPMENT[DELIVERY_ACTUAL_TS])))
- On‑Time (60m) = VAR plan = FACT_SHIPMENT[DELIVERY_PLAN_TS] VAR act = FACT_SHIPMENT[DELIVERY_ACTUAL_TS] RETURN IF(NOT ISBLANK(act) && act <= (plan + TIME(0,60,0)), 1, 0)
- OTD % (60m) = DIVIDE(SUMX(FACT_SHIPMENT, [On‑Time (60m)]), [Delivered Shipments])
- Avg Transit Days = AVERAGEX(FILTER(FACT_SHIPMENT, NOT ISBLANK(FACT_SHIPMENT[DELIVERY_ACTUAL_TS]) && NOT ISBLANK(FACT_SHIPMENT[PICKUP_ACTUAL_TS])), DATEDIFF(FACT_SHIPMENT[PICKUP_ACTUAL_TS], FACT_SHIPMENT[DELIVERY_ACTUAL_TS], DAY))
- GM per Mile = DIVIDE(SUM(FACT_SHIPMENT[REVENUE]) - SUM(FACT_SHIPMENT[TOTAL_COST]), SUM(FACT_SHIPMENT[PLANNED_MILES]))
- Tendered Shipments (events) = DISTINCTCOUNT(FILTER(FACT_EVENT, FACT_EVENT[EVENT_TYPE] = "Tendered")[SHIPMENT_ID])
- Accepted Shipments (events) = DISTINCTCOUNT(FILTER(FACT_EVENT, FACT_EVENT[EVENT_TYPE] = "Accepted")[SHIPMENT_ID])
- Tender Acceptance % = DIVIDE([Accepted Shipments (events)], [Tendered Shipments (events)])

Trailing window variants (use DIM_DATE for date filtering):
- OTD % Last 30d = CALCULATE([OTD % (60m)], DATESINPERIOD(DIM_DATE[DATE], MAX(DIM_DATE[DATE]), -30, DAY))
- OTD % Prior 30d = CALCULATE([OTD % (60m)], DATESBETWEEN(DIM_DATE[DATE], MAX(DIM_DATE[DATE]) - 60, MAX(DIM_DATE[DATE]) - 31))
- OTD Δ pp = ([OTD % Last 30d] - [OTD % Prior 30d])

Lane label:
- Lane = RELATED(DIM_LOCATION[CITY], FACT_SHIPMENT[ORIGIN_LOC_ID]) & " → " & RELATED(DIM_LOCATION[CITY], FACT_SHIPMENT[DEST_LOC_ID])
  or precompute via relationship from `FACT_SHIPMENT[LANE_ID]` to `DIM_LANE` and then through to location names.

Tip: Create a ‘Parameters’ table for Grace Minutes (default 60) if you want to make OTD sensitivity interactive.

## Deliverables
- A `.pbix` file with the model, measures, and the four pages above.
- A short `README.md` describing assumptions, key measures, and any model decisions.

## Acceptance Criteria
- Relationships reflect the star schema (one-to-many from DIMs to FACTs; FACT_EVENT and FACT_COST relate to FACT_SHIPMENT by `SHIPMENT_ID`).
- Measures compute as expected; OTD trend and Lane Performance align with logic.
- Visuals are responsive to slicers and date range.

