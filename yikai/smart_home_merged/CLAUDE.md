# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A rule-based smart home expert system with two layers:
1. **Python crawler** — fetches real-time Montreal weather (Environment Canada API) and AQHI (Air Quality Health Index) data, outputs CLIPS facts
2. **CLIPS expert system** — reasons over environmental data to recommend device actions (heater, AC, humidifier, windows, etc.) and generates user-facing explanations

## Commands

```bash
# Install dependencies
pip install -r requirements.txt

# Run crawler to generate CLIPS input files
python3 crawler.py
# Produces: crawled_facts.clp, crawled_data.json

# Run the full expert system in CLIPS (after crawler):
# clips
# (load "crawled_facts.clp")
# (load "templates.clp")
# (load "rules.clp")
# (reset)
# (run)
```

No test framework, Makefile, or lint configuration exists.

## Architecture

```
Environment Canada API + AQHI web page
        ↓
crawler.py  →  crawled_facts.clp  +  crawled_data.json
                        ↓
        CLIPS engine: templates.clp + rules.clp
                        ↓
        Device control decisions + msg explanations
```

### CLIPS Templates (`templates.clp`)

| Template   | Key slots |
|------------|-----------|
| `env`      | temp (-100..100, default 23), humidity (0..100, default 45), IAQI (0..500, default 50) |
| `outdoor`  | high-temp, low-temp, AQHI (1..11, default 3) |
| `occupancy`| status: `sleep \| awake \| gone` |
| `device`   | name (heater/air-conditioner/humidifier/dehumidifier/window/CO-alarm/fire-alarm), status (on/off) |
| `msg`      | text — explanation messages shown to the user |

### Domain Rules (to be implemented in `rules.clp`)

From the project spec (`report.tex`):
- **Temperature:** heat to 20°C when awake/occupied; 17°C when sleeping or away; cool if above 25.5°C (occupied) or 28°C (away)
- **Humidity:** maintain 30–50%; use humidifier below 30%, dehumidifier above 50%
- **Air quality:** close windows when outdoor AQHI > 6; alert when indoor IAQI > 100
- **CO safety:** trigger CO-alarm on carbon monoxide detection

### crawler.py Key Details

- `fetch_weather()` — queries Environment Canada climate API, timeout 30s
- `fetch_aqhi()` — scrapes AQHI forecast page with 3-strategy HTML fallback
- `generate_clips_facts(data)` — converts JSON → CLIPS `deffacts` block
- Default values are used if any API call fails (graceful degradation)
- Output paths are hardcoded at the top of the file (lines 27–28)

## Missing / To Be Built

- `rules.clp` — the core expert system rules (main missing component)
