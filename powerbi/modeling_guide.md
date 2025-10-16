# Power BI Modeling Guide

## Star Schema

- Facts
  - `FACT_SHIPMENT` (shipment-leg grain)
  - `FACT_EVENT` (shipment_id, event_seq)
  - `FACT_COST` (one row per cost component)
- Dimensions
  - `DIM_CUSTOMER`, `DIM_CARRIER`, `DIM_EQUIPMENT`, `DIM_LOCATION`, `DIM_LANE`, `DIM_DATE`

## Relationships

- `FACT_SHIPMENT[customer_id]` -> `DIM_CUSTOMER[customer_id]` (Many-to-One)
- `FACT_SHIPMENT[carrier_id]` -> `DIM_CARRIER[carrier_id]`
- `FACT_SHIPMENT[equipment_id]` -> `DIM_EQUIPMENT[equipment_id]`
- `FACT_SHIPMENT[origin_loc_id]` -> `DIM_LOCATION[loc_id]`
- `FACT_SHIPMENT[dest_loc_id]` -> `DIM_LOCATION[loc_id]` (active to origin OR use role-play dimension; preferred: inactive relationship to `DIM_LOCATION` for dest and use USERELATIONSHIP in measures)
- `FACT_SHIPMENT[lane_id]` -> `DIM_LANE[lane_id]`
- `FACT_EVENT[shipment_id]` -> `FACT_SHIPMENT[shipment_id]` (Many-to-One)
- `FACT_COST[shipment_id]` -> `FACT_SHIPMENT[shipment_id]`
- `DIM_DATE[date_key]` relates to `FACT_SHIPMENT` date fields using separate role-play date tables or inactive relationships:
  - `pickup_actual_ts` (Date from timestamp)
  - `delivery_actual_ts`
  - For simplicity, use one `DIM_DATE` and create a date column in the fact with `DATE(pickup_actual_ts)` or `DATE(delivery_actual_ts)` then make the relationship active for the chosen analysis date.

## Modeling Notes

- Timestamps: use UTC; derive `Date` columns in Power Query or DAX using `DATEVALUE(FACT_SHIPMENT[delivery_actual_ts])`.
- Role-play dimensions:
  - Option A: Duplicate `DIM_DATE` as `DimDatePickup` and `DimDateDelivery` (recommended).
  - Option B: Keep inactive relationship to delivery date and activate in measures with `USERELATIONSHIP`.

## Measures

- Use `powerbi/dax_measures.md`. Provide a Grace Minutes What-If parameter (0–120) for OTD and OTIF.
- Exception counts: derived from `FACT_EVENT[event_type] = "Exception"`.

## Visuals

- KPI tiles: OTD% (Last 30 vs Prior 30 delta), GM/Mile (YTD vs target).
- Lane performance: Column (Avg Transit Days), Line (OTD%).
- Exception heatmap: Exception Type × Customer.
- Drill-through: Shipment detail table; slicers for Date/Customer/Carrier/Equipment/Lane.

## Performance Tips

- Avoid bi-directional relationships; keep single direction from dims to facts.
- Use composite models only if necessary; import curated EDW tables if size allows.
- Summarize `FACT_EVENT` if it becomes large; or filter to recent period for visuals.

