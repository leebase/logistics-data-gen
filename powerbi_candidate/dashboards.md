# Dashboard Requirements

Build these pages in your Power BI report. Ensure slicers for Customer, Carrier, Equipment, Lane, and Date range are available and affect visuals.

## 1) Overview
- KPIs
  - Delivered Shipments
  - OTD % Last 30d and Δ vs Prior 30d
  - Avg Transit Days
  - Tender Acceptance %
  - GM per Mile (vs a target parameter)
- Trends
  - OTD % by day (last 60 days)
  - Delivered Shipments by day (columns)

## 2) Lane Performance
- Bar: Avg Transit Days by Lane (Origin → Dest)
- Overlay: OTD % by Lane (dots or secondary axis)
- Optional filter: Min Shipments per Lane

## 3) Exceptions
- Matrix heatmap: Customer × Exception Type (count of events where `FACT_EVENT[EVENT_TYPE]='Exception'`)
- Top Exception Types table

## 4) Shipment Details
- Table with: Shipment ID, Leg, Customer, Carrier, Lane, Status, Pickup/Delivery Plan+Actual, On‑Time, In‑Full, OTIF, Planned/Actual Miles, Revenue, Total Cost, GM per Mile.

## Suggested Slicers
- Customer Name, Carrier Name, Equipment Type, Lane (Origin → Dest), Date range (based on Delivery Actual Date).

## Performance Tips
- Use Import mode for faster slicer responsiveness.
- Hide surrogate/technical columns not needed in visuals.
- Create a Calendar table from DIM_DATE and mark it as Date Table for time-intelligence.

