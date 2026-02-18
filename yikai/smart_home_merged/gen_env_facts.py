#!/usr/bin/env python3
"""
Generate 10 days of random but sensible indoor sensor data
for the `env` template defined in templates.clp.

env slots:
    temp     INTEGER  range -100..100  (indoor °C, comfort zone 18–26)
    humidity INTEGER  range 0..100     (%, comfort zone 30–60)
    IAQI     INTEGER  range 0..500     (Indoor Air Quality Index; 0–50 good, 51–100 moderate,
                                        101–150 unhealthy for sensitive groups)

Output: env_facts.clp  (load after templates.clp)
"""

import json
import os
import random
from datetime import date, timedelta

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CLIPS_OUTPUT = os.path.join(SCRIPT_DIR, "env_facts.clp")
JSON_OUTPUT  = os.path.join(SCRIPT_DIR, "env_data.json")

DAYS = 10

# Comfort-zone starting points
TEMP_START     = 22   # °C
HUMIDITY_START = 45   # %
IAQI_START     = 50   # index

# Day-to-day random-walk step sizes (σ of gaussian noise)
TEMP_STEP     = 1.5
HUMIDITY_STEP = 4.0
IAQI_STEP     = 10.0

# Hard bounds (stay within sensible indoor ranges)
TEMP_MIN, TEMP_MAX         = 16, 28
HUMIDITY_MIN, HUMIDITY_MAX = 25, 70
IAQI_MIN, IAQI_MAX         = 0, 150

# Alarm trigger probabilities per day (low frequency)
CO_ALARM_PROB   = 0.05   # 5 % chance of a CO event on any given day
FIRE_ALARM_PROB = 0.03   # 3 % chance of a fire/smoke event on any given day


def _walk(current, step, lo, hi):
    """Gaussian random walk clamped to [lo, hi]."""
    next_val = current + random.gauss(0, step)
    return max(lo, min(hi, next_val))


def generate_days(seed=None):
    if seed is not None:
        random.seed(seed)

    temp     = float(TEMP_START)
    humidity = float(HUMIDITY_START)
    iaqi     = float(IAQI_START)

    today = date.today()
    records = []

    for i in range(DAYS):
        day_date = today - timedelta(days=DAYS - 1 - i)  # oldest first
        temp     = _walk(temp,     TEMP_STEP,     TEMP_MIN,     TEMP_MAX)
        humidity = _walk(humidity, HUMIDITY_STEP, HUMIDITY_MIN, HUMIDITY_MAX)
        iaqi     = _walk(iaqi,     IAQI_STEP,     IAQI_MIN,     IAQI_MAX)
        records.append({
            "date":       str(day_date),
            "temp":       int(round(temp)),
            "humidity":   int(round(humidity)),
            "iaqi":       int(round(iaqi)),
            "co_alarm":   "on" if random.random() < CO_ALARM_PROB   else "off",
            "fire_alarm": "on" if random.random() < FIRE_ALARM_PROB else "off",
        })

    return records


def to_clips(records):
    from datetime import datetime
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = [
        "; ===============================================",
        f"; {DAYS}-Day Indoor Sensor Data (env template)",
        f"; Generated: {now}",
        "; Requires: templates.clp loaded first",
        "; ===============================================",
        "",
        f'(deffacts ten-day-env "{DAYS}-day indoor sensor data"',
    ]
    for r in records:
        lines.append(
            f"    (env (date \"{r['date']}\") (temp {r['temp']}) (humidity {r['humidity']})"
            f" (IAQI {r['iaqi']}) (co-alarm {r['co_alarm']}) (fire-alarm {r['fire_alarm']}))"
        )
    lines += [")", ""]
    return "\n".join(lines)


def main():
    records = generate_days()

    # CLIPS output
    clips_text = to_clips(records)
    with open(CLIPS_OUTPUT, "w") as f:
        f.write(clips_text)
    print(f"CLIPS facts saved to {CLIPS_OUTPUT}")

    # JSON output
    with open(JSON_OUTPUT, "w") as f:
        json.dump({"days": records}, f, indent=2)
    print(f"JSON saved to {JSON_OUTPUT}")

    # Summary
    print()
    print(f"{'Date':<12}  {'Temp':>5}  {'Humidity':>8}  {'IAQI':>6}  {'CO':>4}  {'Fire':>6}")
    print("-" * 54)
    for r in records:
        co   = "ALARM" if r["co_alarm"]   == "on" else "-"
        fire = "ALARM" if r["fire_alarm"] == "on" else "-"
        print(f"{r['date']:<12}  {r['temp']:>4}°C  {r['humidity']:>7}%  {r['iaqi']:>6}  {co:>4}  {fire:>6}")


if __name__ == "__main__":
    main()
