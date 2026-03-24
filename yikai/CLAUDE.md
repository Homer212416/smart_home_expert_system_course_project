# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A smart home environmental control expert system using CLIPS (C Language Integrated Production System) for rule-based inference and Python for data acquisition. The system makes automated recommendations about temperature, humidity, air quality, and safety based on real Montreal weather data and simulated indoor sensor readings.

## Running the System

### Full Pipeline
```bash
# From the yikai/ directory
conda activate crawler
python data_scripts/crawler.py              # Fetch Montreal weather + AQHI → outdoor_data.json
python data_scripts/generate_indoor_facts.py # Generate indoor sensor data → generated_indoor_data.json
python data_scripts/combine_facts.py        # Merge into CLIPS facts → facts.clp
clips -f run.clp                            # Run the expert system
```

### Run only CLIPS (using existing facts)
```bash
clips -f run.clp
```

### Compile LaTeX report
```bash
cd report && ./compile_tex.sh
```

## Architecture

### Data Flow
```
crawler.py ──────────────────────────────────────────────────┐
(Env Canada API + web scrape)                                │
→ outdoor_data.json                                          │
                                                             ▼
generate_indoor_facts.py                          combine_facts.py
(Gaussian noise simulation)                       → facts.clp
→ generated_indoor_data.json ────────────────────────────────┘
                                                             │
                                                             ▼
templates.clp + rules.clp + facts.clp ──→ run.clp ──→ CLIPS inference
```

### CLIPS File Loading Order (run.clp)
1. `templates.clp` — deftemplate definitions (`env`, `device`, `themostat`, `msg`)
2. `rules.clp` — inference rules
3. `facts.clp` — 10-day deffacts (one block per day)

### Rule Salience (Priority)
| Salience | Domain |
|----------|--------|
| 100 | Safety (CO alarm, fire alarm — blocks all other actions) |
| 60 | Temperature (thermostat mode/target, occupancy-aware) |
| 40 | Humidity (humidifier/dehumidifier) |
| 35 | Window control (outdoor AQHI threshold) |
| 30 | Air purifier (indoor IAQI) |
| -10 | Output (print grouped recommendations) |

### Key Decision Thresholds
- **Temperature targets**: 20°C (occupied/awake), 17°C (sleep/away), winter season
- **Humidity comfort zone**: 30–50%
- **Window control**: Close when outdoor AQHI > 6
- **IAQI scale**: Good (81–100), Moderate (61–80), Polluted (41–60), Very Polluted (21–40), Severely Polluted (0–20)
- **Alarms**: CO and fire have 10% trigger probability in simulation

### Data Source
- Montreal Pierre Elliott Trudeau International Airport (Environment Canada station ID: 7025251)
- 10-day historical weather window; season is hardcoded as `winter` in `combine_facts.py`
