# Measures (DAX) Reference

Copy/paste into Power BI and adjust table/column names as needed.

Delivered Shipments =
  COUNTROWS( FILTER( FACT_SHIPMENT, NOT ISBLANK( FACT_SHIPMENT[DELIVERY_ACTUAL_TS] ) ) )

On-Time (60m) =
VAR plan = FACT_SHIPMENT[DELIVERY_PLAN_TS]
VAR act  = FACT_SHIPMENT[DELIVERY_ACTUAL_TS]
RETURN IF( NOT ISBLANK(act) && act <= ( plan + TIME(0,60,0) ), 1, 0 )

OTD % (60m) =
  DIVIDE( SUMX( FACT_SHIPMENT, [On-Time (60m)] ), [Delivered Shipments] )

Avg Transit Days =
  AVERAGEX(
    FILTER( FACT_SHIPMENT, NOT ISBLANK( FACT_SHIPMENT[PICKUP_ACTUAL_TS] ) && NOT ISBLANK( FACT_SHIPMENT[DELIVERY_ACTUAL_TS] ) ),
    DATEDIFF( FACT_SHIPMENT[PICKUP_ACTUAL_TS], FACT_SHIPMENT[DELIVERY_ACTUAL_TS], DAY )
  )

Revenue = SUM( FACT_SHIPMENT[REVENUE] )

Total Cost = SUM( FACT_SHIPMENT[TOTAL_COST] )

Planned Miles = SUM( FACT_SHIPMENT[PLANNED_MILES] )

GM per Mile =
  DIVIDE( [Revenue] - [Total Cost], [Planned Miles] )

Tendered Shipments (events) =
  DISTINCTCOUNT( FILTER( FACT_EVENT, FACT_EVENT[EVENT_TYPE] = "Tendered" )[SHIPMENT_ID] )

Accepted Shipments (events) =
  DISTINCTCOUNT( FILTER( FACT_EVENT, FACT_EVENT[EVENT_TYPE] = "Accepted" )[SHIPMENT_ID] )

Tender Acceptance % =
  DIVIDE( [Accepted Shipments (events)], [Tendered Shipments (events)] )

-- Date intelligence (requires a Date table; use DIM_DATE)

OTD % Last 30d =
  CALCULATE( [OTD % (60m)], DATESINPERIOD( DIM_DATE[DATE], MAX( DIM_DATE[DATE] ), -30, DAY ) )

OTD % Prior 30d =
  CALCULATE( [OTD % (60m)], DATESBETWEEN( DIM_DATE[DATE], MAX( DIM_DATE[DATE] ) - 60, MAX( DIM_DATE[DATE] ) - 31 ) )

OTD Δ pp = [OTD % Last 30d] - [OTD % Prior 30d]

