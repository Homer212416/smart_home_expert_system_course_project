"""
#!/usr/bin/env python3
Smart Home Expert System - Web Crawler
Fetches 10 days of Montreal weather and AQHI data from Environment Canada
and generates CLIPS facts and JSON output.
"""

import json
import os
import re
import sys
from datetime import datetime

import requests
from bs4 import BeautifulSoup

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# CLIMATE_IDENTIFIER 7025251 = Montreal Pierre Elliott Trudeau Intl A (unique station ID).
# Using this instead of STATION_NAME avoids duplicate records from similarly-named stations.
# limit=20 gives a buffer so deduplication always yields 10 distinct dates.
WEATHER_API_URL = (
    "https://api.weather.gc.ca/collections/climate-daily/items"
    "?f=json&limit=20&sortby=-LOCAL_DATE"
    "&CLIMATE_IDENTIFIER=7025251"
)

AQHI_PAGE_URL = "https://weather.gc.ca/airquality/pages/qcaq-001_e.html"

JSON_OUTPUT = os.path.join(SCRIPT_DIR, "crawled_data.json")
CLIPS_OUTPUT = os.path.join(SCRIPT_DIR, "crawled_facts.clp")

DAYS_TO_FETCH = 10


def fetch_weather():
    """Fetch 10 days of daily temperature data from Environment Canada climate-daily API."""
    print(f"Fetching {DAYS_TO_FETCH}-day weather data from Environment Canada API...")
    resp = requests.get(WEATHER_API_URL, timeout=30)
    resp.raise_for_status()
    data = resp.json()

    features = data.get("features", [])
    if not features:
        raise RuntimeError("No weather data returned from API")

    seen_dates = set()
    days = []
    for feature in features:
        props = feature["properties"]
        date_key = str(props.get("LOCAL_DATE", "unknown"))[:10]
        if date_key in seen_dates:
            continue  # skip duplicate station records for the same date
        seen_dates.add(date_key)
        days.append({
            "date": date_key,
            "station": props.get("STATION_NAME", "unknown"),
            "max_temp": props.get("MAX_TEMPERATURE"),
            "min_temp": props.get("MIN_TEMPERATURE"),
            "mean_temp": props.get("MEAN_TEMPERATURE"),
        })
        if len(days) == DAYS_TO_FETCH:
            break

    station = days[0]["station"] if days else "unknown"
    print(f"  Station: {station}")
    print(f"  Date range: {days[-1]['date']} to {days[0]['date']}")
    print(f"  Days fetched: {len(days)}")

    return days


def fetch_aqhi():
    """Scrape all available AQHI forecast values from Environment Canada Montreal page."""
    print("Fetching AQHI data from Environment Canada...")
    resp = requests.get(AQHI_PAGE_URL, timeout=30)
    resp.raise_for_status()

    soup = BeautifulSoup(resp.text, "html.parser")
    aqhi_values = []

    # Strategy 1: bold/strong tags containing a single integer 1–10
    for tag in soup.find_all(["strong", "b"]):
        text = tag.get_text(strip=True)
        match = re.match(r"^(\d+)$", text)
        if match:
            val = int(match.group(1))
            if 1 <= val <= 10:
                aqhi_values.append(val)

    # Strategy 2: table cells containing a single integer 1–10
    if not aqhi_values:
        for td in soup.find_all("td"):
            text = td.get_text(strip=True)
            match = re.match(r"^(\d+)$", text)
            if match:
                val = int(match.group(1))
                if 1 <= val <= 10:
                    aqhi_values.append(val)

    # Strategy 3: explicit "AQHI: N" patterns in page text
    if not aqhi_values:
        page_text = soup.get_text()
        matches = re.findall(r"AQHI[:\s]+(\d+)", page_text, re.IGNORECASE)
        aqhi_values = [int(m) for m in matches if 1 <= int(m) <= 10]

    if aqhi_values:
        print(f"  AQHI values found: {aqhi_values[:10]}")
        return aqhi_values
    else:
        print("  AQHI: could not find value, using default of 3")
        return [3]


def _to_int(val, default):
    """Convert a value to integer for CLIPS slots typed INTEGER, falling back to default."""
    if val is None:
        return default
    try:
        return int(round(float(val)))
    except (ValueError, TypeError):
        return default


def generate_clips_facts(days, aqhi_values):
    """Generate outdoor CLIPS facts using the outdoor template from templates.clp."""
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    def get_aqhi(i):
        return aqhi_values[i % len(aqhi_values)]

    lines = [
        "; ===============================================",
        f"; {DAYS_TO_FETCH}-Day Crawled Outdoor Data from Environment Canada",
        f"; Generated: {now}",
        "; Requires: templates.clp loaded first",
        "; ===============================================",
        "",
        f'(deffacts ten-day-outdoor "{DAYS_TO_FETCH}-day outdoor data from Environment Canada"',
    ]

    for i, day in enumerate(days):
        date_str = day.get("date", "unknown")
        high = _to_int(day.get("max_temp"), 20)
        low  = _to_int(day.get("min_temp"), 10)
        aqhi = get_aqhi(i)
        lines.append(f'    (outdoor (date "{date_str}") (high-temp {high}) (low-temp {low}) (AQHI {aqhi}))')

    lines += [")", ""]
    return "\n".join(lines)


def save_json(days, aqhi_values):
    """Save 10-day crawled data as JSON."""
    def get_aqhi(i):
        return aqhi_values[i % len(aqhi_values)]

    records = []
    for i, day in enumerate(days):
        records.append({
            "date":       day.get("date", "unknown"),
            "station":    day.get("station", "unknown"),
            "max_temp_c": day.get("max_temp"),
            "min_temp_c": day.get("min_temp"),
            "aqhi":       get_aqhi(i),
        })

    output = {
        "fetched_at": datetime.now().isoformat(),
        "source":     "Environment Canada",
        "days":       records,
    }
    with open(JSON_OUTPUT, "w") as f:
        json.dump(output, f, indent=2)
    print(f"JSON saved to {JSON_OUTPUT}")


def main():
    print("=" * 50)
    print("Smart Home Expert System - Web Crawler")
    print(f"Fetching {DAYS_TO_FETCH} days of data")
    print("=" * 50)

    days = []
    aqhi_values = [3]

    # Fetch weather
    try:
        days = fetch_weather()
    except Exception as e:
        print(f"ERROR fetching weather: {e}", file=sys.stderr)
        print("Using default values.")
        days = [{
            "date": datetime.now().strftime("%Y-%m-%d"),
            "station": "default",
            "max_temp": 20, "min_temp": 10, "mean_temp": 15,
        }]

    # Fetch AQHI
    try:
        aqhi_values = fetch_aqhi()
    except Exception as e:
        print(f"ERROR fetching AQHI: {e}", file=sys.stderr)
        print("Using default AQHI value.")
        aqhi_values = [3]

    # Generate outputs
    clips_text = generate_clips_facts(days, aqhi_values)
    with open(CLIPS_OUTPUT, "w") as f:
        f.write(clips_text)
    print(f"CLIPS facts saved to {CLIPS_OUTPUT}")

    save_json(days, aqhi_values)

    print()
    print("=" * 50)
    print(f"{DAYS_TO_FETCH}-day data summary:")
    for i, day in enumerate(days):
        aqhi = aqhi_values[i % len(aqhi_values)]
        date = str(day.get("date", "?"))
        print(
            f"  {date}: "
            f"high={day.get('max_temp')}°C  "
            f"low={day.get('min_temp')}°C  "
            f"AQHI={aqhi}"
        )
    print("=" * 50)
    print()
    print("To use in CLIPS:")
    print('  (load "templates.clp")')
    print('  (load "crawled_facts.clp")')
    print('  (load "rules.clp")')
    print("  (reset)")
    print("  (run)")


if __name__ == "__main__":
    main()
