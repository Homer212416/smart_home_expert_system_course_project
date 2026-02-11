#!/usr/bin/env python3
"""
Smart Home Expert System - Web Crawler
Fetches real Montreal weather and AQHI data from Environment Canada
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

WEATHER_API_URL = (
    "https://api.weather.gc.ca/collections/climate-hourly/items"
    "?f=json&limit=1&sortby=-LOCAL_DATE"
    "&STATION_NAME=MONTREAL%20INTL%20A"
)

AQHI_PAGE_URL = "https://weather.gc.ca/airquality/pages/qcaq-001_e.html"

JSON_OUTPUT = os.path.join(SCRIPT_DIR, "crawled_data.json")
CLIPS_OUTPUT = os.path.join(SCRIPT_DIR, "crawled_facts.clp")


def fetch_weather():
    """Fetch temperature and humidity from Environment Canada climate API."""
    print("Fetching weather data from Environment Canada API...")
    resp = requests.get(WEATHER_API_URL, timeout=30)
    resp.raise_for_status()
    data = resp.json()

    features = data.get("features", [])
    if not features:
        raise RuntimeError("No weather data returned from API")

    props = features[0]["properties"]
    temp = props.get("TEMP")
    humidity = props.get("RELATIVE_HUMIDITY")
    station = props.get("STATION_NAME", "unknown")
    local_date = props.get("LOCAL_DATE", "unknown")

    print(f"  Station: {station}")
    print(f"  Date: {local_date}")
    print(f"  Temperature: {temp}°C")
    print(f"  Humidity: {humidity}%")

    return {
        "temperature": temp,
        "humidity": humidity,
        "station": station,
        "observation_date": local_date,
    }


def fetch_aqhi():
    """Scrape AQHI forecast value from Environment Canada Montreal page."""
    print("Fetching AQHI data from Environment Canada...")
    resp = requests.get(AQHI_PAGE_URL, timeout=30)
    resp.raise_for_status()

    soup = BeautifulSoup(resp.text, "html.parser")

    # Look for the AQHI forecast value in the page.
    # The page contains forecast values in elements with class "text-center"
    # or in table cells. We try several strategies.

    aqhi_value = None

    # Strategy 1: Look for "Current AQHI" or forecast number in bold/strong tags
    for tag in soup.find_all(["strong", "b"]):
        text = tag.get_text(strip=True)
        match = re.match(r"^(\d+)$", text)
        if match:
            val = int(match.group(1))
            if 1 <= val <= 10:
                aqhi_value = val
                break

    # Strategy 2: Look for the AQHI value in the forecast section
    if aqhi_value is None:
        for td in soup.find_all("td"):
            text = td.get_text(strip=True)
            match = re.match(r"^(\d+)$", text)
            if match:
                val = int(match.group(1))
                if 1 <= val <= 10:
                    aqhi_value = val
                    break

    # Strategy 3: Search for any AQHI-related number pattern in the page text
    if aqhi_value is None:
        page_text = soup.get_text()
        matches = re.findall(r"AQHI[:\s]+(\d+)", page_text, re.IGNORECASE)
        if matches:
            aqhi_value = int(matches[0])

    if aqhi_value is not None:
        print(f"  AQHI: {aqhi_value}")
    else:
        print("  AQHI: Could not find value, using default of 3")
        aqhi_value = 3

    return {"aqhi": aqhi_value}


def generate_clips_facts(data):
    """Generate a CLIPS deffacts block from crawled data."""
    temp = data.get("temperature")
    humidity = data.get("humidity")
    aqhi = data.get("aqhi")

    # Format temperature: use integer if whole number, else float
    if temp is not None:
        temp_str = str(int(temp)) if temp == int(temp) else str(temp)
    else:
        temp_str = "20"

    humidity_str = str(int(humidity)) if humidity is not None else "45"
    aqhi_str = str(int(aqhi)) if aqhi is not None else "3"

    clips = f"""; ===============================================
; Crawled Weather Data from Environment Canada
; Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
; ===============================================

(deffacts crawled-weather-data "Real data from Environment Canada"
    (current-temp {temp_str})
    (humidity {humidity_str})
    (AQHI {aqhi_str})
    ; Static defaults for sensor-only data:
    (occupancy home)
    (sleep-status awake)
    (carbon-monoxide-alarm idle)
    (IAQI 85)
)
"""
    return clips


def save_json(data):
    """Save crawled data as JSON."""
    output = {
        "fetched_at": datetime.now().isoformat(),
        "source": "Environment Canada",
        "weather": {
            "temperature_c": data.get("temperature"),
            "relative_humidity_pct": data.get("humidity"),
            "station": data.get("station"),
            "observation_date": data.get("observation_date"),
        },
        "air_quality": {
            "aqhi": data.get("aqhi"),
        },
    }
    with open(JSON_OUTPUT, "w") as f:
        json.dump(output, f, indent=2)
    print(f"JSON saved to {JSON_OUTPUT}")


def main():
    print("=" * 50)
    print("Smart Home Expert System - Web Crawler")
    print("=" * 50)

    data = {}

    # Fetch weather data
    try:
        weather = fetch_weather()
        data.update(weather)
    except Exception as e:
        print(f"ERROR fetching weather: {e}", file=sys.stderr)
        print("Using default values for temperature and humidity.")
        data["temperature"] = 20
        data["humidity"] = 45

    # Fetch AQHI data
    try:
        aqhi = fetch_aqhi()
        data.update(aqhi)
    except Exception as e:
        print(f"ERROR fetching AQHI: {e}", file=sys.stderr)
        print("Using default AQHI value.")
        data["aqhi"] = 3

    # Generate outputs
    clips_text = generate_clips_facts(data)
    with open(CLIPS_OUTPUT, "w") as f:
        f.write(clips_text)
    print(f"CLIPS facts saved to {CLIPS_OUTPUT}")

    save_json(data)

    print()
    print("=" * 50)
    print("Crawled data summary:")
    print(f"  Temperature: {data.get('temperature')}°C")
    print(f"  Humidity:    {data.get('humidity')}%")
    print(f"  AQHI:        {data.get('aqhi')}")
    print("=" * 50)
    print()
    print("To use in CLIPS:")
    print('  (load "crawled_facts.clp")')
    print('  (load "rules.clp")')
    print("  (reset)")
    print("  (run)")


if __name__ == "__main__":
    main()
