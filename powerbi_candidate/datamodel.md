# Data Model (POWERBI_DWH)

This schema is a star model centered on shipments, with supporting facts and dimensions.

- FACT_SHIPMENT (grain: shipment_id + leg_id)
  - Foreign keys: customer_id, carrier_id, equipment_id, origin_loc_id, dest_loc_id, lane_id
  - Core timestamps: tender_ts, pickup_plan_ts, pickup_actual_ts, delivery_plan_ts, delivery_actual_ts
  - Quantities: planned_miles, actual_miles, pieces, weight_lbs, cube
  - Financials: revenue, total_cost, fuel_surcharge, accessorial_cost
  - Flags: status, isdeliveredontime, isinfull, isotif, cancel_flag

- FACT_EVENT (grain: shipment_id + event_seq)
  - Event_type (Tendered, Accepted, AtOrigin, PickedUp, AtDest, Delivered, Exception, ...)
  - Event_ts, facility_loc_id, notes (exception details)

- FACT_COST (grain: shipment_id + cost_type + rate_ref)
  - calc_method (flat, per-mile, index), cost_amount, currency

- DIM_CUSTOMER (customer_id)
- DIM_CARRIER (carrier_id)
- DIM_EQUIPMENT (equipment_id)
- DIM_LOCATION (loc_id)
- DIM_LANE (lane_id, origin_loc_id → DIM_LOCATION.loc_id, dest_loc_id → DIM_LOCATION.loc_id)
- DIM_DATE (date_key → date; use for calendar/time intelligence)

## Recommended Relationships in Power BI
- DIM_CUSTOMER[customer_id] → FACT_SHIPMENT[customer_id] (one-to-many)
- DIM_CARRIER[carrier_id] → FACT_SHIPMENT[carrier_id]
- DIM_EQUIPMENT[equipment_id] → FACT_SHIPMENT[equipment_id]
- DIM_LOCATION[loc_id] → FACT_SHIPMENT[origin_loc_id]
- DIM_LOCATION[loc_id] → FACT_SHIPMENT[dest_loc_id]
- DIM_LANE[lane_id] → FACT_SHIPMENT[lane_id]
- DIM_DATE[date] (or date_key) → FACT_SHIPMENT[delivery_actual_ts] (create a Date table and relate on date if preferred)
- FACT_SHIPMENT[shipment_id] → FACT_EVENT[shipment_id] (one-to-many)
- FACT_SHIPMENT[shipment_id] → FACT_COST[shipment_id]

Note: If you model both origin and destination location relationships, use inactive relationship for one side and USERELATIONSHIP() in measures when needed, or precompute a lane label in FACT_SHIPMENT to avoid ambiguity.

## Common Derived Fields
- Lane label = Origin City + " → " + Dest City (via DIM_LANE join to DIM_LOCATION twice)
- On‑Time flag (with grace minutes) computed from plan vs actual timestamps
- GM per Mile = (Revenue - Total Cost) / Planned Miles

