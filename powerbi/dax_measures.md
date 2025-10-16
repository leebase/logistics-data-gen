-- DAX Measures for Logistics KPIs

-- Base counts
Delivered Shipments =
CALCULATE(
    DISTINCTCOUNT(FACT_SHIPMENT[shipment_id]),
    NOT ISBLANK(FACT_SHIPMENT[delivery_actual_ts])
)

OTD Deliveries =
VAR GraceMinutes = SELECTEDVALUE('Parameters'[Grace Minutes], 60)
RETURN
CALCULATE(
    DISTINCTCOUNT(FACT_SHIPMENT[shipment_id]),
    FACT_SHIPMENT[delivery_actual_ts]
        <= FACT_SHIPMENT[delivery_plan_ts] + (GraceMinutes / 1440.0)
)

OTIF Deliveries =
VAR GraceMinutes = SELECTEDVALUE('Parameters'[Grace Minutes], 60)
RETURN
CALCULATE(
    DISTINCTCOUNT(FACT_SHIPMENT[shipment_id]),
    FACT_SHIPMENT[isinfull] = TRUE(),
    FACT_SHIPMENT[delivery_actual_ts]
        <= FACT_SHIPMENT[delivery_plan_ts] + (GraceMinutes / 1440.0)
)

-- KPIs
OTD % =
DIVIDE([OTD Deliveries], [Delivered Shipments])

OTIF % =
DIVIDE([OTIF Deliveries], [Delivered Shipments])

Gross Margin =
SUM(FACT_SHIPMENT[revenue]) - SUM(FACT_SHIPMENT[total_cost])

GM per Mile =
DIVIDE([Gross Margin], SUM(FACT_SHIPMENT[planned_miles]))

Tendered Count =
CALCULATE(
    DISTINCTCOUNT(FACT_SHIPMENT[shipment_id]),
    FACT_SHIPMENT[status] IN {"Tendered", "Accepted", "In-Transit", "Delivered", "Exception", "Cancelled"}
)

Accepted Count =
CALCULATE(
    DISTINCTCOUNT(FACT_SHIPMENT[shipment_id]),
    FACT_SHIPMENT[status] IN {"Accepted", "In-Transit", "Delivered", "Exception"}
)

Tender Acceptance % =
DIVIDE([Accepted Count], [Tendered Count])

Avg Transit Days =
AVERAGEX(
    FILTER(
        FACT_SHIPMENT,
        NOT ISBLANK(FACT_SHIPMENT[pickup_actual_ts]) && NOT ISBLANK(FACT_SHIPMENT[delivery_actual_ts])
    ),
    DATEDIFF(FACT_SHIPMENT[pickup_actual_ts], FACT_SHIPMENT[delivery_actual_ts], DAY)
)

Exceptions Count =
CALCULATE(
    COUNTROWS(FACT_EVENT),
    FACT_EVENT[event_type] = "Exception"
)

-- Time intelligence helpers (assumes delivery date role-play is active)
OTD % Last 30 Days =
CALCULATE([OTD %], DATESINPERIOD('DIM_DATE'[date], MAX('DIM_DATE'[date]), -30, DAY))

OTD % Prior 30 Days =
VAR MaxDate = MAX('DIM_DATE'[date])
RETURN
CALCULATE([OTD %], DATESBETWEEN('DIM_DATE'[date], MaxDate - 60, MaxDate - 31))

OTD % 30d Delta =
[OTD % Last 30 Days] - [OTD % Prior 30 Days]

GM/Mile YTD =
CALCULATE([GM per Mile], DATESYTD('DIM_DATE'[date]))

GM/Mile vs Target (pp) =
VAR Target = SELECTEDVALUE('Parameters'[GM/Mile Target], 0.40)
RETURN [GM/Mile YTD] - Target

