#!/usr/bin/env python3
"""
Generate 10 days of random but sensible indoor sensor data
for the `env` template defined in templates.clp.

env slots:
    temp     INTEGER  range -100..100  (indoor °C, comfort zone 18–26)
    humidity INTEGER  range 0..100     (%, comfort zone 30–60)
    IAQI     INTEGER  range 0..500     (Indoor Air Quality Index; 0–50 good, 51–100 moderate,
                                        101–150 unhealthy for sensitive groups)

Output: env_data.json
"""

import json
import os
import random
from datetime import date, timedelta

SCRIPT_DIRECTORY  = os.path.dirname(os.path.abspath(__file__))
JSON_OUTPUT_PATH = os.path.join(SCRIPT_DIRECTORY, "generated_indoor_data.json")

NUMBER_OF_DAYS = 10

# Base values
TEMP_BASE     = 15.0   # °C
HUMIDITY_BASE = 40.0   # %
IAQI_BASE     = 60.0   # index

# Gaussian fluctuation standard deviation (σ of gaussian noise)
TEMP_SIGMA     = 5.0
HUMIDITY_SIGMA = 25.0
IAQI_SIGMA     = 20.0

# Hard bounds (stay within sensible indoor ranges)
TEMP_MIN, TEMP_MAX         = 0, 30
HUMIDITY_MIN, HUMIDITY_MAX = 0, 100
IAQI_MIN, IAQI_MAX         = 0, 100

# Alarm trigger probabilities per day (low frequency)
CO_ALARM_PROB   = 0.10   # 10 % chance of a CO event on any given day
FIRE_ALARM_PROB = 0.10   # 10 % chance of a fire/smoke event on any given day

# Certainty Factor base values
# -------
CO_CF_BASE    = 0.85
FIRE_CF_BASE  = 0.90
OCC_CF_BASE   = 0.75
IAQI_CF_BASE  = 0.80
AQHI_CF_BASE  = 0.70
CF_SIGMA      = 0.05 
# -------

# Season
SEASON = "winter" 

# Occupancy status probabilities (per day)
OCCUPANCY_PROBS = {
    "sleep": 0.30,  # 30 % chance of sleeping on any given day
    "awake": 0.50,  # 50 % chance of being awake at home on any given day
    "gone":  0.20,  # 20 % chance of being away from home on any given day
}

def _fluctuate(base_value, standard_deviation, lower_bound, upper_bound):
    """Gaussian random fluctuation clamped to [lower_bound, upper_bound]."""
    fluctuated_value = base_value + random.gauss(0, standard_deviation)
    return max(lower_bound, min(upper_bound, fluctuated_value))

# -------
def _cf(base, sigma=0.05):
    return round(_fluctuate(base, sigma, 0.1, 1.0), 2)
# -------

def generate_daily_records(seed=None):
    if seed is not None:
        random.seed(seed)

    yesterday = date.today() - timedelta(days=1) # end with yesterday's date
    records = []

    for day_index in range(NUMBER_OF_DAYS):
        day_date = yesterday  - timedelta(days=NUMBER_OF_DAYS - 1 - day_index)  # oldest first
        temperature = _fluctuate(TEMP_BASE, TEMP_SIGMA, TEMP_MIN, TEMP_MAX)
        humidity = _fluctuate(HUMIDITY_BASE, HUMIDITY_SIGMA, HUMIDITY_MIN, HUMIDITY_MAX)
        indoor_air_quality_index = _fluctuate(IAQI_BASE, IAQI_SIGMA, IAQI_MIN, IAQI_MAX)

        records.append({
            "date":       str(day_date),
            "temp":       int(round(temperature)),
            "humidity":   int(round(humidity)),
            "iaqi":       int(round(indoor_air_quality_index)),
            "co_alarm":   "on" if random.random() < CO_ALARM_PROB   else "off",
            "fire_alarm": "on" if random.random() < FIRE_ALARM_PROB else "off",
            "season":     SEASON,
            "occupancy":  random.choices(population=list(OCCUPANCY_PROBS.keys()), weights=list(OCCUPANCY_PROBS.values()))[0],
        
            # ----
            "co_alarm_cf":   _cf(CO_CF_BASE),
            "fire_alarm_cf": _cf(FIRE_CF_BASE),
            "occupancy_cf":  _cf(OCC_CF_BASE),
            "iaqi_cf":       _cf(IAQI_CF_BASE),
            "aqhi_cf":       _cf(AQHI_CF_BASE),
            # ----

        })

    return records



def main():
    records = generate_daily_records()

    # JSON output
    with open(JSON_OUTPUT_PATH, "w") as output_file:
        json.dump({"days": records}, output_file, indent=2)
    print(f"JSON saved to {JSON_OUTPUT_PATH}")

    # Summary
    print()
    print(f"{'Date':<12}  {'Temp':>5}  {'Humidity':>8}  {'IAQI':>6}  {'CO':>4}  {'Fire':>6}  {'Season':>8}  {'Occupancy':>10}  occ_cf  iaqi_cf  aqhi_cf  co_cf  fire_cf")
    print("-" * 105)
    for record in records:
        co_status = "ALARM" if record["co_alarm"] == "on" else "-"
        fire_status = "ALARM" if record["fire_alarm"] == "on" else "-"
        print(
            f"{record['date']:<12}  {record['temp']:>4}°C  {record['humidity']:>7}%"
            f"  {record['iaqi']:>6}  {co_status:>4}  {fire_status:>6}  {record['season']:>8} {record['occupancy']:>10}"
            f"  {record['occupancy_cf']:>6.2f}  {record['iaqi_cf']:>7.2f}  {record['aqhi_cf']:>7.2f}  {record['co_alarm_cf']:>5.2f}  {record['fire_alarm_cf']:>7.2f}"
        )


if __name__ == "__main__":
    main()
