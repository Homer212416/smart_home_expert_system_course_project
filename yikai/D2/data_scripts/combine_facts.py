"""
#!/usr/bin/env python3
Generate facts.clp from generated_indoor_data.json and outdoor_data.json.

Produces 10 deffacts blocks — one per day — each containing:
  - one env fact (indoor + outdoor + occupancy + season combined)
  - thermostat initialised to off
  - all controllable devices (humidifier, dehumidifier, window, air-purifier) initialised to off

Usage:
    python3 combine_facts.py
Requires generated_indoor_data.json and outdoor_data.json to exist.
"""

import json
import os
from datetime import datetime

SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
INDOOR_JSON  = os.path.join(SCRIPT_DIR, "generated_indoor_data.json")
OUTDOOR_JSON = os.path.join(SCRIPT_DIR, "outdoor_data.json")
CLIPS_OUTPUT = os.path.join(SCRIPT_DIR, "../facts.clp")


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


def main():
    indoor_raw  = load_json(INDOOR_JSON)
    outdoor_raw = load_json(OUTDOOR_JSON)

    indoor_by_date  = {d["date"]: d for d in indoor_raw["days"]}
    outdoor_by_date = {d["date"]: d for d in outdoor_raw["days"]}

    dates = sorted(indoor_by_date.keys())

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = [
        "; ===============================================",
        "; 10-Day Combined Facts (env template)",
        f"; Generated: {now}",
        "; Requires: templates.clp loaded first",
        "; Each deffacts block initialises thermostat and devices to off",
        "; ===============================================",
        "",
    ]

    for date_str in dates:
        ind = indoor_by_date[date_str]
        od  = outdoor_by_date.get(date_str, {})

        temp       = _to_int(ind.get("temp"),       23)
        humidity   = _to_int(ind.get("humidity"),   45)
        iaqi       = _to_int(ind.get("iaqi"),       50)
        co_alarm   = ind.get("co_alarm",   "off")
        fire_alarm = ind.get("fire_alarm", "off")
        occupancy  = ind.get("occupancy",  "awake")
        season     = ind.get("season",     "winter")
        high       = _to_int(od.get("max_temp_c"),  20)
        low        = _to_int(od.get("min_temp_c"),  10)
        aqhi       = _to_int(od.get("aqhi"),         3)

        co_cf    = ind.get("co_alarm_cf",   0.85)
        fire_cf  = ind.get("fire_alarm_cf", 0.90)
        occ_cf   = ind.get("occupancy_cf",  0.75)
        iaqi_cf  = ind.get("iaqi_cf",       0.80)
        aqhi_cf  = ind.get("aqhi_cf",       0.70)

        label = date_str.replace("-", "")
        lines += [
            f'(deffacts day-{label} "Facts for {date_str}"',
            f'    (env (date "{date_str}") (temp {temp}) (humidity {humidity})'
            f' (IAQI {iaqi}) (co-alarm {co_alarm}) (fire-alarm {fire_alarm})'
            f' (occupancy {occupancy}) (season {season})'
            f' (high-temp {high}) (low-temp {low}) (AQHI {aqhi})'
            f' (co-alarm-cf {co_cf}) (fire-alarm-cf {fire_cf})'
            f' (occupancy-cf {occ_cf}) (iaqi-cf {iaqi_cf}) (aqhi-cf {aqhi_cf}))',
            f'    (themostat (date "{date_str}") (mode off) (target-temp 22))',
            f'    (device (date "{date_str}") (name humidifier)   (status off))',
            f'    (device (date "{date_str}") (name dehumidifier) (status off))',
            f'    (device (date "{date_str}") (name window)       (status off))',
            f'    (device (date "{date_str}") (name air-purifier) (status off))',
            f')',
            "",
        ]

    with open(CLIPS_OUTPUT, "w") as f:
        f.write("\n".join(lines))

    print(f"Written {len(dates)} env facts to {CLIPS_OUTPUT}")
    print()
    print(f"{'Date':<12}  {'Occ':<6}  {'Temp':>5}  {'Hum':>4}  {'IAQI':>4}  {'High':>5}  {'Low':>5}  {'AQHI':>4}  CO / Fire   occ_cf  iaqi_cf  aqhi_cf  co_cf  fire_cf")
    print("-" * 115)
    for date_str in dates:
        ind  = indoor_by_date[date_str]
        od   = outdoor_by_date.get(date_str, {})
        high = _to_int(od.get("max_temp_c"), 20)
        low  = _to_int(od.get("min_temp_c"), 10)
        aqhi = _to_int(od.get("aqhi"),        3)
        occ  = ind.get("occupancy", "awake")
        co   = "CO!"   if ind.get("co_alarm")   == "on" else "-"
        fire = "FIRE!" if ind.get("fire_alarm") == "on" else "-"
        co_cf    = ind.get("co_alarm_cf",   0.85)
        fire_cf  = ind.get("fire_alarm_cf", 0.90)
        occ_cf   = ind.get("occupancy_cf",  0.75)
        iaqi_cf  = ind.get("iaqi_cf",       0.80)
        aqhi_cf  = ind.get("aqhi_cf",       0.70)
        print(
            f"{date_str:<12}  {occ:<6}  {_to_int(ind.get('temp'), 23):>4}°C"
            f"  {_to_int(ind.get('humidity'), 45):>3}%"
            f"  {_to_int(ind.get('iaqi'), 50):>4}  {high:>4}°C  {low:>4}°C  {aqhi:>4}"
            f"  {co:<3} / {fire:<5}   {occ_cf:>6.2f}  {iaqi_cf:>7.2f}  {aqhi_cf:>7.2f}  {co_cf:>5.2f}  {fire_cf:>7.2f}"
        )


if __name__ == "__main__":
    main()
