#!/usr/bin/env python3
"""
Generate facts.clp from crawled_data.json (outdoor), env_data.json (indoor),
and user_data.json (per-day occupancy).

Produces 10 deffacts blocks — one per day — each containing:
  - an env        fact  (indoor: temp, humidity, IAQI, co-alarm, fire-alarm)
  - an outdoor    fact  (outdoor: high-temp, low-temp, AQHI)
  - an occupancy  fact  (per-day: sleep | awake | gone)

user_data.json is auto-created with "awake" defaults if it does not exist.
Edit it to set the occupancy for each day before re-running this script.

Usage:
    python3 gen_facts.py
Requires crawled_data.json and env_data.json to exist (run crawler.py and
gen_env_facts.py first).
"""

import json
import os
from datetime import datetime

SCRIPT_DIR    = os.path.dirname(os.path.abspath(__file__))
CRAWLED_JSON  = os.path.join(SCRIPT_DIR, "crawled_data.json")
ENV_JSON      = os.path.join(SCRIPT_DIR, "env_data.json")
USER_JSON     = os.path.join(SCRIPT_DIR, "user_data.json")
CLIPS_OUTPUT  = os.path.join(SCRIPT_DIR, "facts.clp")

VALID_STATUSES = {"sleep", "awake", "gone"}


def _to_int(val, default):
    if val is None:
        return default
    try:
        return int(round(float(val)))
    except (ValueError, TypeError):
        return default


def load_json(path):
    with open(path) as f:
        return json.load(f)


def load_or_create_user_data(dates):
    """Load user_data.json, or create it with 'awake' defaults for all dates."""
    if os.path.exists(USER_JSON):
        data = load_json(USER_JSON)
        by_date = {d["date"]: d["occupancy"] for d in data["days"]}
        # Fill in any dates missing from the file
        for d in dates:
            if d not in by_date:
                by_date[d] = "awake"
        return by_date
    else:
        records = [{"date": d, "occupancy": "awake"} for d in dates]
        with open(USER_JSON, "w") as f:
            json.dump({"days": records}, f, indent=2)
        print(f"Created {USER_JSON} with default occupancy 'awake' for all days.")
        print(f"  Edit it to set per-day occupancy (sleep / awake / gone), then re-run.")
        return {d: "awake" for d in dates}


def main():
    outdoor_raw = load_json(CRAWLED_JSON)
    env_raw     = load_json(ENV_JSON)

    outdoor_by_date = {d["date"]: d for d in outdoor_raw["days"]}
    env_by_date     = {d["date"]: d for d in env_raw["days"]}

    # Use env dates as primary (most-recent 10 days, oldest-first)
    dates = sorted(env_by_date.keys())

    occupancy_by_date = load_or_create_user_data(dates)

    # Validate occupancy values
    for d, occ in occupancy_by_date.items():
        if occ not in VALID_STATUSES:
            print(f"WARNING: invalid occupancy '{occ}' for {d}, defaulting to 'awake'")
            occupancy_by_date[d] = "awake"

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = [
        "; ===============================================",
        "; 10-Day Combined Facts (env + outdoor + occupancy)",
        f"; Generated: {now}",
        "; Requires: templates.clp loaded first",
        "; ===============================================",
        "",
    ]

    for date_str in dates:
        env = env_by_date[date_str]
        od  = outdoor_by_date.get(date_str, {})

        high       = _to_int(od.get("max_temp_c"), 20)
        low        = _to_int(od.get("min_temp_c"), 10)
        aqhi       = _to_int(od.get("aqhi"),       3)
        temp       = env["temp"]
        humidity   = env["humidity"]
        iaqi       = env["iaqi"]
        co_alarm   = env["co_alarm"]
        fire_alarm = env["fire_alarm"]
        occ        = occupancy_by_date.get(date_str, "awake")

        label = date_str.replace("-", "")   # e.g. 20260209
        lines += [
            f'(deffacts day-{label} "Facts for {date_str}"',
            f'    (env        (date "{date_str}") (temp {temp}) (humidity {humidity})'
            f' (IAQI {iaqi}) (co-alarm {co_alarm}) (fire-alarm {fire_alarm}))',
            f'    (outdoor    (date "{date_str}") (high-temp {high}) (low-temp {low}) (AQHI {aqhi}))',
            f'    (occupancy  (date "{date_str}") (status {occ}))',
            f')',
            "",
        ]

    with open(CLIPS_OUTPUT, "w") as f:
        f.write("\n".join(lines))

    print(f"CLIPS facts saved to {CLIPS_OUTPUT}")
    print(f"  {len(dates)} daily deffacts blocks")
    print()
    print(f"{'Date':<12}  {'Occ':<6}  {'Temp':>5}  {'Hum':>4}  {'IAQI':>4}  {'High':>5}  {'Low':>5}  {'AQHI':>4}  CO / Fire")
    print("-" * 80)
    for date_str in dates:
        env  = env_by_date[date_str]
        od   = outdoor_by_date.get(date_str, {})
        high = _to_int(od.get("max_temp_c"), 20)
        low  = _to_int(od.get("min_temp_c"), 10)
        aqhi = _to_int(od.get("aqhi"),       3)
        occ  = occupancy_by_date.get(date_str, "awake")
        co   = "CO!"   if env["co_alarm"]   == "on" else "-"
        fire = "FIRE!" if env["fire_alarm"] == "on" else "-"
        print(
            f"{date_str:<12}  {occ:<6}  {env['temp']:>4}°C  {env['humidity']:>3}%"
            f"  {env['iaqi']:>4}  {high:>4}°C  {low:>4}°C  {aqhi:>4}  {co} / {fire}"
        )
    print()
    print("To use in CLIPS:  (batch \"run.clp\")")
    print("To change occupancy: edit user_data.json and re-run gen_facts.py")


if __name__ == "__main__":
    main()
