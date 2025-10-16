# Power BI Visual Spec

## Report Pages

- Overview
  - KPI Card: OTD % (Last 30 vs Prior 30 delta)
    - Measure: `[OTD % Last 30 Days]` with a delta label using `[OTD % 30d Delta]`
  - KPI Card: GM/Mile (YTD vs Target)
    - Measure: `[GM/Mile YTD]` and `[GM/Mile vs Target (pp)]`
  - KPI Card: Tender Acceptance %
    - Measure: `[Tender Acceptance %]`
  - KPI Card: Avg Transit Days
    - Measure: `[Avg Transit Days]`
  - Slicers: Date (DIM_DATE), Customer, Carrier, Equipment, Lane

- Lane Performance
  - Combo Chart
    - Axis: Lane (DIM_LANE lane_id or "Origin → Dest")
    - Column: `[Avg Transit Days]`
    - Line: `[OTD %]`
    - Tooltip: GM/Mile, Exception Count

- Exceptions
  - Heatmap (Matrix)
    - Rows: Exception Type (from FACT_EVENT[event_type] where type = Exception with notes)
    - Columns: Customer
    - Values: `[Exceptions Count]`
  - Clustered bar: Exceptions by Carrier
  - Slicers: Date, Lane

- Drill-through: Shipment Detail
  - Table: Shipment-level fields (shipment_id, customer, carrier, origin/dest, status, planned/actual dates, OTD flag, InFull flag, OTIF flag, miles, revenue, cost)
  - Allow drill from Overview visual elements
  - Slicers: Date, Customer, Carrier, Equipment, Lane

## Object-level Guidance

- Formatting
  - Use percentage format for OTD/OTIF/Tender Acceptance with 1 decimal
  - Currency: USD $ with 0 decimals for GM/Mile and financials
  - Date hierarchy disabled (use date only)
- Interactions
  - Slicers cross-filter all visuals
  - Drill-through enabled on shipment table
- Parameters
  - What-If parameter: `Grace Minutes` (0–120, step 5)
  - What-If parameter: `GM/Mile Target` (0.10–1.00, step 0.05)

