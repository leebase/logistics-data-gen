#!/usr/bin/env python3
"""
Generate synthetic logistics data CSVs.

- Produces dims: Customer, Carrier, Equipment, Location, Lane, Date
- Produces facts: Shipment (leg grain), Event, Cost
- Deterministic via seed; UTC timestamps
- Weekly diesel price curve influences fuel surcharge
- Seasonality (EOM/holidays), dwell lognormal, exceptions 6–9%
"""

from __future__ import annotations

import argparse
import csv
import math
import random
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover
    yaml = None  # Will error later with a friendly message


UTC = timezone.utc


@dataclass
class Config:
    start_date: date
    months: int
    seed: int
    shipments_target: int
    num_customers: int
    num_carriers: int
    isfull_rate: float
    exception_rate_low: float
    exception_rate_high: float
    eom_ramp: float
    holidays: List[date]
    dwell_mu_minutes: float
    dwell_sigma_minutes: float
    diesel_start_price: float
    diesel_weekly_sigma: float
    acceptance_rate: float


def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser(description="Generate synthetic logistics CSVs to data/out/")
    ap.add_argument("--config", type=str, default="data/config.yaml", help="Path to config.yaml")
    return ap.parse_args()


def load_config(path: Path) -> Config:
    if yaml is None:
        raise RuntimeError(
            "PyYAML is required. Please run: python -m pip install pyyaml, or use `make venv`."
        )
    with path.open("r", encoding="utf-8") as f:
        raw = yaml.safe_load(f)

    def d(s: str) -> date:
        return datetime.strptime(s, "%Y-%m-%d").date()

    holidays = [d(x) for x in raw.get("holidays", [])]
    return Config(
        start_date=d(raw.get("start_date", "2024-01-01")),
        months=int(raw.get("months", 6)),
        seed=int(raw.get("seed", 42)),
        shipments_target=int(raw.get("shipments_target", 8000)),
        num_customers=int(raw.get("num_customers", 25)),
        num_carriers=int(raw.get("num_carriers", 15)),
        isfull_rate=float(raw.get("isfull_rate", 0.96)),
        exception_rate_low=float(raw.get("exception_rate_low", 0.06)),
        exception_rate_high=float(raw.get("exception_rate_high", 0.09)),
        eom_ramp=float(raw.get("eom_ramp", 0.12)),
        holidays=holidays,
        dwell_mu_minutes=float(raw.get("dwell_lognormal_mu_minutes", 3.0)),
        dwell_sigma_minutes=float(raw.get("dwell_lognormal_sigma_minutes", 0.8)),
        diesel_start_price=float(raw.get("diesel_weekly_start", 4.10)),
        diesel_weekly_sigma=float(raw.get("diesel_weekly_sigma", 0.05)),
        acceptance_rate=float(raw.get("acceptance_rate", 0.92)),
    )


def ensure_out_dir() -> Path:
    out = Path("data/out")
    out.mkdir(parents=True, exist_ok=True)
    return out


def now_utc() -> datetime:
    return datetime.now(tz=UTC)


# Hub cities (name, state, lat, lon, tz)
HUBS: List[Tuple[str, str, float, float, str]] = [
    ("Atlanta", "GA", 33.749, -84.388, "America/New_York"),
    ("Chicago", "IL", 41.878, -87.629, "America/Chicago"),
    ("Dallas", "TX", 32.776, -96.797, "America/Chicago"),
    ("Los Angeles", "CA", 34.052, -118.244, "America/Los_Angeles"),
    ("New York", "NY", 40.712, -74.006, "America/New_York"),
    ("Columbus", "OH", 39.961, -82.999, "America/New_York"),
    ("Memphis", "TN", 35.149, -90.049, "America/Chicago"),
    ("Denver", "CO", 39.739, -104.990, "America/Denver"),
    ("Seattle", "WA", 47.606, -122.332, "America/Los_Angeles"),
    ("Miami", "FL", 25.761, -80.191, "America/New_York"),
    ("Phoenix", "AZ", 33.448, -112.074, "America/Phoenix"),
    ("Kansas City", "MO", 39.099, -94.578, "America/Chicago"),
    ("Houston", "TX", 29.760, -95.369, "America/Chicago"),
    ("Nashville", "TN", 36.162, -86.781, "America/Chicago"),
    ("Charlotte", "NC", 35.227, -80.843, "America/New_York"),
]


def haversine_miles(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    # Radius of earth in miles
    R = 3958.8
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


def estimate_transit_days(miles: float, mode: str) -> int:
    # Rough buckets by distance and mode
    base = 1
    if miles < 300:
        base = 1
    elif miles < 600:
        base = 2
    elif miles < 1000:
        base = 3
    else:
        base = 4
    if mode == "Intermodal":
        base += 1
    return max(1, base)


def weighted_dates(cfg: Config, rng: random.Random) -> List[date]:
    """Generate a list of dates over the range with EOM/holiday ramps."""
    start = cfg.start_date
    end = start + timedelta(days=cfg.months * 31)
    dates: List[date] = []
    d = start
    while d < end:
        # Skip beyond precise months range
        if (d - start).days >= cfg.months * 30 + 5:
            break
        weight = 1.0
        # EOM ramp: last 4 days of month
        if d.day >= 27:
            weight += cfg.eom_ramp
        # Holiday ramp: same day and +/-1 day
        if d in cfg.holidays or (d - timedelta(days=1)) in cfg.holidays or (d + timedelta(days=1)) in cfg.holidays:
            weight += 0.10
        # Weekends slightly lower shipping
        if d.weekday() >= 5:
            weight *= 0.8
        # Repeat date proportional to weight (discretized)
        repeats = max(1, int(round(weight * 10)))
        dates.extend([d] * repeats)
        d += timedelta(days=1)
    rng.shuffle(dates)
    return dates


def build_customers(cfg: Config, rng: random.Random, load_dt: datetime) -> List[Dict]:
    segments = ["Retail", "Manufacturing", "E-Commerce", "Automotive", "CPG"]
    regions = ["Northeast", "Midwest", "South", "West"]
    rows = []
    for cid in range(1, cfg.num_customers + 1):
        name = f"Customer {cid:03d}"
        rows.append(
            {
                "customer_id": cid,
                "name": name,
                "segment": rng.choice(segments),
                "region": rng.choice(regions),
                "load_date": load_dt.isoformat(),
                "update_date": load_dt.isoformat(),
            }
        )
    return rows


def build_carriers(cfg: Config, rng: random.Random, load_dt: datetime) -> List[Dict]:
    modes = ["TL", "LTL", "Intermodal"]
    tiers = ["Bronze", "Silver", "Gold", "Platinum"]
    rows = []
    for cid in range(1, cfg.num_carriers + 1):
        mode = rng.choices(modes, weights=[0.55, 0.30, 0.15])[0]
        tier = rng.choices(tiers, weights=[0.25, 0.35, 0.30, 0.10])[0]
        rows.append(
            {
                "carrier_id": cid,
                "name": f"Carrier {cid:03d}",
                "mode": mode,
                "mc_number": f"MC{rng.randint(100000, 999999)}",
                "score_tier": tier,
                "load_date": load_dt.isoformat(),
                "update_date": load_dt.isoformat(),
            }
        )
    return rows


def build_equipment(load_dt: datetime) -> List[Dict]:
    types = [("Van", 45000), ("Reefer", 44000), ("Flat", 48000)]
    rows = []
    for eid, (typ, cap) in enumerate(types, start=1):
        rows.append(
            {
                "equipment_id": eid,
                "type": typ,
                "capacity_lbs": cap,
                "load_date": load_dt.isoformat(),
                "update_date": load_dt.isoformat(),
            }
        )
    return rows


def build_locations(rng: random.Random, load_dt: datetime) -> List[Dict]:
    rows = []
    for i, (city, state, lat, lon, tz) in enumerate(HUBS, start=1):
        for kind in ["Origin", "Dest", "Terminal", "DC"]:
            loc_id = (i - 1) * 4 + ["Origin", "Dest", "Terminal", "DC"].index(kind) + 1
            rows.append(
                {
                    "loc_id": loc_id,
                    "name": f"{city} {kind}",
                    "city": city,
                    "state": state,
                    "country": "USA",
                    "timezone": tz,
                    "type": kind,
                    "lat": lat,  # internal only
                    "lon": lon,  # internal only
                    "load_date": load_dt.isoformat(),
                    "update_date": load_dt.isoformat(),
                }
            )
    return rows


def build_lanes(locations: List[Dict], load_dt: datetime) -> List[Dict]:
    # Build lanes only between "Origin" and "Dest" of different hubs
    origins = [l for l in locations if l["type"] == "Origin"]
    dests = [l for l in locations if l["type"] == "Dest"]
    rows = []
    lane_id = 1
    for o in origins:
        for d in dests:
            if o["city"] == d["city"]:
                continue
            miles = haversine_miles(o["lat"], o["lon"], d["lat"], d["lon"])
            # Standard transit for TL baseline; can be adjusted later by mode in facts
            std_days = estimate_transit_days(miles, mode="TL")
            rows.append(
                {
                    "lane_id": lane_id,
                    "origin_loc_id": o["loc_id"],
                    "dest_loc_id": d["loc_id"],
                    "standard_miles": round(miles, 2),
                    "std_transit_days": std_days,
                    "load_date": load_dt.isoformat(),
                    "update_date": load_dt.isoformat(),
                    # convenience
                    "_o_city": o["city"],
                    "_d_city": d["city"],
                }
            )
            lane_id += 1
    return rows


def diesel_curve(start_date: date, months: int, start_price: float, sigma: float, rng: random.Random) -> Dict[date, float]:
    """Weekly diesel price (Monday anchors) via random walk."""
    start_monday = start_date - timedelta(days=start_date.weekday())
    weeks = months * 5 + 3
    prices = {}
    price = start_price
    for w in range(weeks):
        dt = start_monday + timedelta(weeks=w)
        price = max(2.50, price + rng.gauss(0.0, sigma))
        prices[dt] = round(price, 3)
    return prices


def nearest_week(dt: date, anchors: Dict[date, float]) -> float:
    # Find most recent Monday anchor
    monday = dt - timedelta(days=dt.weekday())
    # If not present, shift back until found
    while monday not in anchors:
        monday -= timedelta(weeks=1)
    return anchors[monday]


def rpm_for(mode: str, miles: float, rng: random.Random) -> float:
    # Base revenue per mile with mild noise
    if mode == "TL":
        base = 2.20 if miles > 500 else 2.50
    elif mode == "LTL":
        base = 1.80 if miles > 500 else 2.00
    else:
        base = 1.60 if miles > 500 else 1.80
    return round(base * rng.uniform(0.95, 1.10), 3)


def simulate_shipments(
    cfg: Config,
    rng: random.Random,
    customers: List[Dict],
    carriers: List[Dict],
    equipment: List[Dict],
    locations: List[Dict],
    lanes: List[Dict],
    date_pool: List[date],
    diesel_weekly: Dict[date, float],
    load_dt: datetime,
) -> Tuple[List[Dict], List[Dict], List[Dict]]:
    events: List[Dict] = []
    costs: List[Dict] = []
    shipments: List[Dict] = []

    exception_rate = rng.uniform(cfg.exception_rate_low, cfg.exception_rate_high)
    loc_by_id = {l["loc_id"]: l for l in locations}
    carriers_by_id = {c["carrier_id"]: c for c in carriers}

    # Choose random lanes for shipments with some bias for shorter lanes
    lane_weights = []
    for ln in lanes:
        miles = ln["standard_miles"]
        weight = 1.2 if miles < 600 else (0.9 if miles < 1200 else 0.6)
        lane_weights.append(weight)

    # Build a schedule of shipment dates matching target volume
    if not date_pool:
        raise RuntimeError("No dates available for shipment generation.")
    chosen_dates = [rng.choice(date_pool) for _ in range(cfg.shipments_target)]

    # Helper event seq
    def add_event(sid: str, seq: int, typ: str, ts: datetime, loc_id: int, notes: str = "") -> None:
        events.append(
            {
                "shipment_id": sid,
                "event_seq": seq,
                "event_type": typ,
                "event_ts": ts.isoformat(),
                "facility_loc_id": loc_id,
                "notes": notes,
                "load_date": load_dt.isoformat(),
                "update_date": load_dt.isoformat(),
            }
        )

    for i in range(cfg.shipments_target):
        sid = f"S{i+1:06d}"
        cust = rng.choice(customers)
        car = rng.choices(carriers, weights=[1.0] * len(carriers))[0]
        eq = rng.choice(equipment)
        lane = rng.choices(lanes, weights=lane_weights, k=1)[0]
        o_loc = loc_by_id[lane["origin_loc_id"]]
        d_loc = loc_by_id[lane["dest_loc_id"]]
        mode = carriers_by_id[car["carrier_id"]]["mode"]
        tier = carriers_by_id[car["carrier_id"]]["score_tier"]

        miles = lane["standard_miles"] * rng.uniform(0.98, 1.05)
        planned_miles = round(miles, 2)
        std_days = estimate_transit_days(miles, mode=mode)
        plan_pickup = datetime.combine(chosen_dates[i], datetime.min.time(), tzinfo=UTC) + timedelta(
            hours=rng.randint(6, 18), minutes=rng.randint(0, 59)
        )
        tender_ts = plan_pickup - timedelta(hours=rng.randint(4, 24))
        accept = rng.random() < cfg.acceptance_rate
        status = "Tendered"

        seq = 1
        add_event(sid, seq, "Tendered", tender_ts, o_loc["loc_id"])
        seq += 1
        if accept:
            add_event(sid, seq, "Accepted", tender_ts + timedelta(hours=rng.randint(1, 3)), o_loc["loc_id"])
            status = "Accepted"
            seq += 1
        else:
            # Not accepted; mark TONU-like scenario
            status = "Cancelled"
            shipments.append(
                {
                    "shipment_id": sid,
                    "leg_id": 1,
                    "customer_id": cust["customer_id"],
                    "carrier_id": car["carrier_id"],
                    "equipment_id": eq["equipment_id"],
                    "origin_loc_id": o_loc["loc_id"],
                    "dest_loc_id": d_loc["loc_id"],
                    "lane_id": lane["lane_id"],
                    "tender_ts": tender_ts.isoformat(),
                    "pickup_plan_ts": plan_pickup.isoformat(),
                    "pickup_actual_ts": "",
                    "delivery_plan_ts": (plan_pickup + timedelta(days=std_days)).isoformat(),
                    "delivery_actual_ts": "",
                    "planned_miles": planned_miles,
                    "actual_miles": 0.0,
                    "pieces": rng.randint(1, 24),
                    "weight_lbs": round(rng.uniform(500.0, 44000.0), 2),
                    "cube": round(rng.uniform(50.0, 3500.0), 2),
                    "revenue": 0.0,
                    "total_cost": 0.0,
                    "fuel_surcharge": 0.0,
                    "accessorial_cost": 0.0,
                    "status": status,
                    "isdeliveredontime": False,
                    "isinfull": False,
                    "isotif": False,
                    "cancel_flag": True,
                    "load_date": load_dt.isoformat(),
                    "update_date": load_dt.isoformat(),
                }
            )
            # Cost for TONU (accessorial)
            tonu_cost = round(rng.uniform(75, 200), 2)
            costs.append(
                {
                    "shipment_id": sid,
                    "cost_type": "Accessorial: TONU",
                    "calc_method": "flat",
                    "rate_ref": "TONU",
                    "cost_amount": tonu_cost,
                    "currency": "USD",
                    "load_date": load_dt.isoformat(),
                    "update_date": load_dt.isoformat(),
                }
            )
            add_event(sid, seq, "Exception", tender_ts + timedelta(hours=2), o_loc["loc_id"], notes="Tender Not Used")
            continue

        # Actual pickup/delivery with carrier tier variance and exceptions
        pickup_delay_hours = 0
        if tier in ("Bronze", "Silver"):
            pickup_delay_hours = rng.choice([0, 0, 1, 2, 3])
        pickup_actual = plan_pickup + timedelta(hours=pickup_delay_hours)

        plan_delivery = plan_pickup + timedelta(days=std_days, hours=rng.randint(1, 8))
        dwell_events = rng.random() < 0.25  # 25% have dwell
        exception = rng.random() < exception_rate

        add_event(sid, seq, "AtOrigin", pickup_actual - timedelta(hours=1), o_loc["loc_id"])
        seq += 1
        add_event(sid, seq, "PickedUp", pickup_actual, o_loc["loc_id"])
        seq += 1

        dwell_minutes = 0
        if dwell_events:
            # Lognormal minutes
            mu = math.log(cfg.dwell_mu_minutes)
            sigma = cfg.dwell_sigma_minutes
            dwell_minutes = int(random.lognormvariate(mu, sigma) * 10)  # long tail
            start = pickup_actual + timedelta(hours=rng.randint(1, 12))
            add_event(sid, seq, "DwellStart", start, o_loc["loc_id"], notes="Facility dwell")
            seq += 1
            add_event(sid, seq, "DwellEnd", start + timedelta(minutes=dwell_minutes), o_loc["loc_id"])
            seq += 1

        transit_hours = std_days * 24 + rng.randint(-6, 10)
        if exception:
            transit_hours += rng.randint(6, 36)  # delay
        at_dest = pickup_actual + timedelta(hours=transit_hours)
        add_event(sid, seq, "AtDest", at_dest, d_loc["loc_id"])
        seq += 1

        # Fuel surcharge calculation
        diesel_price = nearest_week(plan_pickup.date(), diesel_weekly)
        base_rpm = rpm_for(mode, planned_miles, rng)
        fuel_per_mile = max(0.05, 0.12 + 0.05 * (diesel_price - 3.5))
        fuel_surcharge = round(fuel_per_mile * planned_miles, 2)
        accessorial_cost = 0.0

        # Accessorials 10–15%
        if rng.random() < rng.uniform(0.10, 0.15):
            acc_type = rng.choice(["Detention", "Lumper", "Layover"])
            accessorial_cost = round(rng.uniform(50.0, 350.0), 2)
            costs.append(
                {
                    "shipment_id": sid,
                    "cost_type": f"Accessorial: {acc_type}",
                    "calc_method": "flat",
                    "rate_ref": acc_type.upper(),
                    "cost_amount": accessorial_cost,
                    "currency": "USD",
                    "load_date": load_dt.isoformat(),
                    "update_date": load_dt.isoformat(),
                }
            )

        revenue_base = round(base_rpm * planned_miles, 2)
        revenue = round(revenue_base + fuel_surcharge + accessorial_cost, 2)

        # Cost ratio by mode/length
        cost_ratio = rng.uniform(0.72, 0.88)
        total_cost_target = round(revenue * cost_ratio, 2)

        # Split costs into base + fuel (+ accessorial already added)
        fuel_cost = round(fuel_surcharge * rng.uniform(0.9, 1.1), 2)
        base_cost = max(0.0, round(total_cost_target - fuel_cost - accessorial_cost, 2))

        costs.append(
            {
                "shipment_id": sid,
                "cost_type": "Base",
                "calc_method": "per-mile",
                "rate_ref": f"RPM {base_rpm:.2f}",
                "cost_amount": base_cost,
                "currency": "USD",
                "load_date": load_dt.isoformat(),
                "update_date": load_dt.isoformat(),
            }
        )
        costs.append(
            {
                "shipment_id": sid,
                "cost_type": "Fuel",
                "calc_method": "index",
                "rate_ref": f"DOE {diesel_price:.2f}",
                "cost_amount": fuel_cost,
                "currency": "USD",
                "load_date": load_dt.isoformat(),
                "update_date": load_dt.isoformat(),
            }
        )

        # Actual delivery time
        delivery_actual = at_dest + timedelta(hours=rng.randint(1, 6))
        delivered = True
        if exception and rng.random() < 0.2:
            # Severe exception: not delivered within window (still delivered for dataset completeness)
            delivery_actual += timedelta(hours=rng.randint(12, 36))

        add_event(sid, seq, "Delivered", delivery_actual, d_loc["loc_id"])
        seq += 1

        # Exception record (if any)
        if exception:
            ex_type = rng.choice(["Weather", "Mechanical", "Traffic", "Facility Delay", "Capacity"])
            add_event(sid, seq, "Exception", at_dest - timedelta(hours=rng.randint(1, 5)), d_loc["loc_id"], notes=ex_type)
            seq += 1
            status = "Exception"
        else:
            status = "Delivered"

        # Compute flags
        grace_minutes = rng.choice([30, 60, 90, 120])
        is_otd = delivered and (delivery_actual <= plan_delivery + timedelta(minutes=grace_minutes))
        is_full = rng.random() < cfg.isfull_rate
        is_otif = is_otd and is_full

        shipments.append(
            {
                "shipment_id": sid,
                "leg_id": 1,
                "customer_id": cust["customer_id"],
                "carrier_id": car["carrier_id"],
                "equipment_id": eq["equipment_id"],
                "origin_loc_id": o_loc["loc_id"],
                "dest_loc_id": d_loc["loc_id"],
                "lane_id": lane["lane_id"],
                "tender_ts": tender_ts.isoformat(),
                "pickup_plan_ts": plan_pickup.isoformat(),
                "pickup_actual_ts": pickup_actual.isoformat(),
                "delivery_plan_ts": plan_delivery.isoformat(),
                "delivery_actual_ts": delivery_actual.isoformat() if delivered else "",
                "planned_miles": round(planned_miles, 2),
                "actual_miles": round(planned_miles * rng.uniform(0.98, 1.05), 2),
                "pieces": rng.randint(1, 24),
                "weight_lbs": round(rng.uniform(500.0, 44000.0), 2),
                "cube": round(rng.uniform(50.0, 3500.0), 2),
                "revenue": revenue,
                "total_cost": round(base_cost + fuel_cost + accessorial_cost, 2),
                "fuel_surcharge": fuel_surcharge,
                "accessorial_cost": accessorial_cost,
                "status": status if delivered else "In-Transit",
                "isdeliveredontime": is_otd,
                "isinfull": is_full,
                "isotif": is_otif,
                "cancel_flag": False,
                "load_date": load_dt.isoformat(),
                "update_date": load_dt.isoformat(),
            }
        )

    return shipments, events, costs


def write_csv(path: Path, fieldnames: List[str], rows: List[Dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            # Remove internal columns if present
            r = {k: v for k, v in r.items() if not k.startswith("_")}
            w.writerow(r)


def generate(cfg: Config) -> None:
    rng = random.Random(cfg.seed)
    out_dir = ensure_out_dir()
    load_dt = now_utc()

    customers = build_customers(cfg, rng, load_dt)
    carriers = build_carriers(cfg, rng, load_dt)
    equipment = build_equipment(load_dt)
    locations = build_locations(rng, load_dt)
    lanes = build_lanes(locations, load_dt)

    # Date dim
    dates: List[Dict] = []
    d = cfg.start_date
    end = cfg.start_date + timedelta(days=cfg.months * 31)
    while d <= end:
        dates.append(
            {
                "date_key": int(d.strftime("%Y%m%d")),
                "date": d.isoformat(),
                "year": d.year,
                "quarter": (d.month - 1) // 3 + 1,
                "month": d.month,
                "week": int(d.strftime("%U")),
                "dow": d.weekday(),
                "is_weekend": d.weekday() >= 5,
                "load_date": load_dt.isoformat(),
                "update_date": load_dt.isoformat(),
            }
        )
        d += timedelta(days=1)

    # Weighted date pool and diesel curve
    dates_pool = weighted_dates(cfg, rng)
    diesel_prices = diesel_curve(cfg.start_date, cfg.months, cfg.diesel_start_price, cfg.diesel_weekly_sigma, rng)

    shipments, events, costs = simulate_shipments(
        cfg, rng, customers, carriers, equipment, locations, lanes, dates_pool, diesel_prices, load_dt
    )

    # Strip internal columns
    for loc in locations:
        loc.pop("lat", None)
        loc.pop("lon", None)
    for lane in lanes:
        lane.pop("_o_city", None)
        lane.pop("_d_city", None)

    # Write CSVs
    write_csv(
        out_dir / "DIM_CUSTOMER.csv",
        ["customer_id", "name", "segment", "region", "load_date", "update_date"],
        customers,
    )
    write_csv(
        out_dir / "DIM_CARRIER.csv",
        ["carrier_id", "name", "mode", "mc_number", "score_tier", "load_date", "update_date"],
        carriers,
    )
    write_csv(
        out_dir / "DIM_EQUIPMENT.csv",
        ["equipment_id", "type", "capacity_lbs", "load_date", "update_date"],
        equipment,
    )
    write_csv(
        out_dir / "DIM_LOCATION.csv",
        ["loc_id", "name", "city", "state", "country", "timezone", "type", "load_date", "update_date"],
        locations,
    )
    write_csv(
        out_dir / "DIM_LANE.csv",
        ["lane_id", "origin_loc_id", "dest_loc_id", "standard_miles", "std_transit_days", "load_date", "update_date"],
        lanes,
    )
    write_csv(
        out_dir / "DIM_DATE.csv",
        ["date_key", "date", "year", "quarter", "month", "week", "dow", "is_weekend", "load_date", "update_date"],
        dates,
    )
    write_csv(
        out_dir / "FACT_SHIPMENT.csv",
        [
            "shipment_id",
            "leg_id",
            "customer_id",
            "carrier_id",
            "equipment_id",
            "origin_loc_id",
            "dest_loc_id",
            "lane_id",
            "tender_ts",
            "pickup_plan_ts",
            "pickup_actual_ts",
            "delivery_plan_ts",
            "delivery_actual_ts",
            "planned_miles",
            "actual_miles",
            "pieces",
            "weight_lbs",
            "cube",
            "revenue",
            "total_cost",
            "fuel_surcharge",
            "accessorial_cost",
            "status",
            "isdeliveredontime",
            "isinfull",
            "isotif",
            "cancel_flag",
            "load_date",
            "update_date",
        ],
        shipments,
    )
    write_csv(
        out_dir / "FACT_EVENT.csv",
        ["shipment_id", "event_seq", "event_type", "event_ts", "facility_loc_id", "notes", "load_date", "update_date"],
        events,
    )
    write_csv(
        out_dir / "FACT_COST.csv",
        ["shipment_id", "cost_type", "calc_method", "rate_ref", "cost_amount", "currency", "load_date", "update_date"],
        costs,
    )


def main() -> None:
    args = parse_args()
    cfg = load_config(Path(args.config))
    generate(cfg)
    print("Data generated to data/out/*.csv")


if __name__ == "__main__":
    main()

