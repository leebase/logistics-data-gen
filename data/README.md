# Dataset Description

Synthetic logistics dataset with dims and facts designed for a shipment-leg grain star schema. Default volume: ~8,000 shipments across 6 months (configurable).

## Files

- DIM_CUSTOMER.csv
- DIM_CARRIER.csv
- DIM_EQUIPMENT.csv
- DIM_LOCATION.csv
- DIM_LANE.csv
- DIM_DATE.csv
- FACT_SHIPMENT.csv
- FACT_EVENT.csv
- FACT_COST.csv

All timestamps are UTC in ISO 8601 format. Numeric fields use `.` decimal separator.

## Column Dictionary (selected)

- FactShipment
  - shipment_id (STRING), leg_id (INT)
  - customer_id, carrier_id, equipment_id
  - origin_loc_id, dest_loc_id, lane_id
  - tender_ts, pickup_plan_ts, pickup_actual_ts, delivery_plan_ts, delivery_actual_ts (TIMESTAMP UTC)
  - planned_miles, actual_miles (NUMERIC)
  - pieces (INT), weight_lbs, cube (NUMERIC)
  - revenue, total_cost, fuel_surcharge, accessorial_cost (NUMERIC USD)
  - status (STRING)
  - isdeliveredontime, isinfull, isotif, cancel_flag (BOOLEAN)
  - load_date, update_date (TIMESTAMP UTC)

- FactEvent
  - shipment_id, event_seq (INT), event_type (STRING)
  - event_ts (TIMESTAMP UTC), facility_loc_id (INT), notes (STRING)
  - load_date, update_date

- FactCost
  - shipment_id, cost_type (STRING), calc_method (STRING), rate_ref (STRING)
  - cost_amount (NUMERIC USD), currency (STRING)
  - load_date, update_date

- Dimensions
  - As listed in `requirements.md` with `load_date`, `update_date`

## Distributions & Realism

- 10–15 hub cities; lanes drawn between hubs; miles via Haversine.
- Transit days bucketed by distance and mode.
- Seasonality: +12% volume at end-of-month; holidays have ramps.
- Carrier `score_tier` affects OTD variance and dwell.
- Cost model: revenue = base per mile * miles + fuel + accessorials (10–15% affected).
- Cost ≈ 72–88% of revenue; weekly diesel curve via random walk influences fuel surcharge.
- Exceptions: 6–9% shipments; weighted types; paired dwell events.
- Deterministic RNG with seed.

## Volumes

- Shipments: ~8k by default (configurable)
- Events: ~6–10 per shipment (tender, accept, at origin/dest, pickup, delivery, dwell, exception)
- Costs: 2–3 rows per shipment (base, fuel, optional accessorial)

