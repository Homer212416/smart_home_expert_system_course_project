# D2 Implementation Walkthrough

Smart Home Expert System — COMP 474/6741, Winter 2026  
Deliverable 2: Uncertain Knowledge

---

## Overview

D2 extends the D1 certain-knowledge expert system with two forms of uncertainty:

- **Probabilistic uncertainty** (D2 TODO 2) — modelled with Certainty Factors (MYCIN CF theory)
- **Possibilistic uncertainty** (D2 TODO 3) — modelled with Fuzzy Logic (FuzzyCLIPS)

The system is now run with **FuzzyCLIPS** instead of standard CLIPS:

```bash
fzclips -f run.clp
```

Or to regenerate fresh sensor data first:

```bash
conda activate crawler
python data_scripts/crawler.py
python data_scripts/generate_indoor_facts.py
python data_scripts/combine_facts.py
fzclips -f run.clp
```

---

## File Map

| File | Role |
|---|---|
| `templates.clp` | All deftemplate definitions: `env`, `device`, `themostat`, `msg`, `fuzzy-env`, and FuzzyCLIPS deftemplates `fz-temp`, `fz-humidity`, `fz-aqhi` |
| `facts.clp` | 10-day deffacts — one `env` + one `fuzzy-env` + four `device` facts + one `themostat` per day |
| `rules.clp` | All 41 rules across four groups: CF safety, fuzzification, D1 crisp rules, fuzzy device control |
| `run.clp` | Entry point: loads templates → rules → facts, calls `(reset)` then `(run)` |
| `data_scripts/crawler.py` | Fetches real Montreal weather + AQHI from Environment Canada |
| `data_scripts/generate_indoor_facts.py` | Simulates indoor sensor readings with Gaussian noise; generates per-day CF values |
| `data_scripts/combine_facts.py` | Merges outdoor + indoor data into `facts.clp` |
| `report/report.tex` | Full LaTeX report covering D1 TODO 1–4 and D2 TODO 1–4 |

---

## D2 TODO 1 — Improvements from D1

Three issues were identified and fixed:

1. **Missing `cool-sleep` rule.** D1 covered `awake` and `gone` cooling states in summer but not `sleep`. Rule `cool-sleep` (salience 60) was added — cools to 26°C when the occupant is sleeping and indoor temperature exceeds 26°C.

2. **Threshold mismatch in R6 description.** The D1 report said "25.5°C" but the rule checked `(> ?t 25)` and targeted 25°C. The report text was corrected to 25°C.

3. **Incomplete occupancy coverage in facts.** The D1 10-day dataset contained only `awake` and `gone` states. The data pipeline was updated to also produce `sleep` days.

All changes are independently verifiable in git history.

---

## D2 TODO 2 — Certainty Factors (Probabilistic Uncertainty)

### Theory

Certainty Factors were introduced in the MYCIN expert system (Shortliffe, 1976). Each sensor reading carries a CF ∈ [0.0, 1.0] reflecting its reliability. When two independent evidence sources support the same hypothesis:

```
CF_combined = CF1 + CF2 × (1 − CF1)
```

Action thresholds used in this system:

| CF range | Interpretation | Action |
|---|---|---|
| ≥ 0.70 | High confidence | Full emergency response |
| 0.30 – 0.69 | Moderate confidence | Warning — investigate |
| < 0.30 | Low confidence | Notice — likely false positive |

### Fact Changes (`templates.clp`, `facts.clp`)

Five new slots were added to the `env` deftemplate:

```clips
(slot co-alarm-cf    (type FLOAT) (range 0.0 1.0) (default 0.85))
(slot fire-alarm-cf  (type FLOAT) (range 0.0 1.0) (default 0.90))
(slot occupancy-cf   (type FLOAT) (range 0.0 1.0) (default 0.75))
(slot iaqi-cf        (type FLOAT) (range 0.0 1.0) (default 0.80))
(slot aqhi-cf        (type FLOAT) (range 0.0 1.0) (default 0.70))
```

Base values come from manufacturer specifications and domain knowledge. `generate_indoor_facts.py` adds Gaussian noise (σ = 0.05) around each base, modelling day-to-day sensor drift. This yields 50 CF data points (5 slots × 10 days).

### Rule Changes (`rules.clp`, salience 90 and 25)

Ten rules replaced the D1 binary alarm rules:

| Rule name | Salience | Condition | Action |
|---|---|---|---|
| `co-high-cf` | 90 | CO on, CF ≥ 0.70 | Assert `emergency`, full evacuation alert |
| `co-moderate-cf` | 90 | CO on, 0.30 ≤ CF < 0.70 | Warning — ventilate, inspect sensor |
| `co-low-cf` | 90 | CO on, CF < 0.30 | Notice — likely false positive |
| `fire-high-cf` | 90 | Fire on, CF ≥ 0.70 | Assert `emergency`, full evacuation alert |
| `fire-moderate-cf` | 90 | Fire on, 0.30 ≤ CF < 0.70 | Warning — check for actual smoke |
| `fire-low-cf` | 90 | Fire on, CF < 0.30 | Notice — inspect sensor |
| `co-and-fire-combined-cf` | 90 | Both alarms on | Compute combined CF; emergency if ≥ 0.70 |
| `occupancy-uncertain-thermostat` | 55 | Occupancy awake, CF < 0.60, winter, temp < 20°C | Default thermostat to 17°C setback |
| `iaqi-uncertain-reading` | 25 | iaqi-cf < 0.60 | Qualify IAQI recommendation with recalibration notice |
| `aqhi-uncertain-reading` | 25 | aqhi-cf < 0.60 | Qualify AQHI advisory with distance-to-station notice |

The D1 rules `co-emergency` and `fire-emergency` (unconditional salience 100) were **removed** and replaced by CF1–CF7 to avoid duplicate emergency messages.

---

## D2 TODO 3 — Fuzzy Logic (Possibilistic Uncertainty)

### Theory

Fuzzy Logic (Zadeh, 1965) allows a crisp sensor value to simultaneously belong to multiple linguistic sets with partial membership degrees μ ∈ [0.0, 1.0]. This system uses **FuzzyCLIPS 6.10d** (NRC Canada), which provides native fuzzy deftemplates and three membership function shapes:

- **Z-function** `(z a c)` — μ = 1 at x ≤ a, ramps to 0 at x = c
- **S-function** `(s a c)` — μ = 0 at x ≤ a, ramps to 1 at x = c
- **PI-function** `(pi d b)` — bell centred at b with half-width d; μ = 1 at b

Inference follows the **Mamdani** method: membership degrees are computed with `get-fs-value`; the **dominant label** (argmax) drives rule selection; the heating/cooling target reflects the degree of coldness or warmth.

### Fuzzy Linguistic Variables (`templates.clp`)

**Indoor Temperature** — universe [−10, 35] °C:

| Term | Shape | Interpretation |
|---|---|---|
| `cold` | Z(10, 20) | μ=1 at ≤10°C; μ=0 at 20°C |
| `cool` | PI(5, 15) | bell peak at 15°C |
| `comfortable` | PI(3, 21) | bell peak at 21°C |
| `warm` | PI(3, 25) | bell peak at 25°C |
| `hot` | S(26, 35) | μ=0 at 26°C; μ=1 at 35°C |

**Indoor Humidity** — universe [0, 100] %:

| Term | Shape | Interpretation |
|---|---|---|
| `dry` | Z(20, 35) | μ=1 at ≤20%; μ=0 at 35% |
| `comfortable` | PI(10, 40) | bell peak at 40% |
| `humid` | S(50, 70) | μ=0 at 50%; μ=1 at 70% |

**Outdoor AQHI** — universe [1, 10]:

| Term | Shape | Interpretation |
|---|---|---|
| `good` | Z(2, 5) | μ=1 at ≤2; μ=0 at 5 |
| `moderate` | PI(2, 5) | bell peak at 5 |
| `poor` | S(5, 9) | μ=0 at 5; μ=1 at 9 |

### Fact Changes (`templates.clp`, `facts.clp`)

A new `fuzzy-env` deftemplate stores per-day fuzzified values:

- 5 temperature membership slots: `mu-cold`, `mu-cool`, `mu-comfortable-temp`, `mu-warm`, `mu-hot`
- 3 humidity membership slots: `mu-dry`, `mu-comfortable-hum`, `mu-humid`
- 3 AQHI membership slots: `mu-aqhi-good`, `mu-aqhi-moderate`, `mu-aqhi-poor`
- 3 dominant-label slots: `temp-label`, `hum-label`, `aqhi-label`

Each day's deffacts block now asserts one blank `fuzzy-env` (all 0.0) which is filled in at inference time by the fuzzification rule. Ten `fuzzy-env` facts satisfy the ≥5 requirement.

### Rule Changes (`rules.clp`)

Fifteen fuzzy rules were added (FZ1–FZ15):

| Rule | Salience | Description |
|---|---|---|
| `fuzzify-env` (FZ1) | 80 | Computes all 11 membership degrees via `get-fs-value`; finds argmax label for each variable; stores in `fuzzy-env` |
| `fuzzy-heat-cold-awake` (FZ2) | 50 | Cold + awake + winter → HEAT 21°C |
| `fuzzy-heat-cold-sleep` (FZ3) | 50 | Cold + sleep + winter → HEAT 18°C |
| `fuzzy-heat-cold-gone` (FZ4) | 50 | Cold + gone + winter → HEAT 17°C (anti-freeze) |
| `fuzzy-heat-cool-awake` (FZ5) | 50 | Cool + awake + winter → HEAT 19°C |
| `fuzzy-heat-cool-sleep-gone` (FZ6) | 50 | Cool + sleep/gone + winter → HEAT 17°C |
| `fuzzy-comfortable-temp` (FZ7) | 50 | Comfortable → no thermostat action |
| `fuzzy-cool-warm-awake` (FZ8) | 50 | Warm + awake + summer → COOL 25°C |
| `fuzzy-cool-hot-awake` (FZ9) | 50 | Hot + awake + summer → COOL 23°C |
| `fuzzy-thermostat-off-gone-summer` (FZ10) | 50 | Comfortable/cool/cold + gone + summer → thermostat OFF |
| `humidify` (FZ11) | 40 | Dry label → humidifier ON |
| `dehumidify` (FZ12) | 40 | Humid label → dehumidifier ON |
| `humidity-comfortable` (FZ13) | 40 | Comfortable label → no humidity action |
| `close-window-poor-outdoor-air` (FZ14) | 35 | AQHI poor → window stays closed |
| `good-outdoor-air` (FZ15) | 35 | AQHI good/moderate → outdoor air acceptable |

Fuzzy rules fire at salience 50/40/35, **after** CF safety rules (90) and fuzzification (80), but **before** the D1 crisp rules at salience 60. Because all thermostat rules guard on `(themostat (date ?date) (mode off))`, only one thermostat rule fires per day.

---

## Rule Salience Overview (all 41 rules)

| Salience | Group | Rules |
|---|---|---|
| 90 | CF safety alarms | CF1–CF7 (7 rules) |
| 80 | Fuzzification | FZ1 (1 rule) |
| 60 | D1 crisp temperature control | heat-awake, heat-sleep, heat-gone, cool-awake, cool-sleep, cool-gone, thermostat-off-gone (7 rules) |
| 55 | Uncertain occupancy default | occupancy-uncertain-thermostat (CF8) |
| 50 | Fuzzy temperature control | FZ2–FZ10 (9 rules) |
| 40 | Fuzzy humidity control | FZ11–FZ13 (3 rules) |
| 35 | Fuzzy window/AQHI control | FZ14–FZ15 (2 rules) |
| 30 | D1 indoor air quality (IAQI) | iaqi-good, iaqi-moderate, iaqi-polluted, iaqi-very-polluted, iaqi-severely-polluted, both-air-quality-poor (6 rules) |
| 25 | Low-CF sensor notices | CF9 (iaqi-uncertain-reading), CF10 (aqhi-uncertain-reading) |
| −10 | Grouped output | print-all-grouped (1 rule) |

**Total: 41 rules** (D1: 20 crisp → D2: +7 CF + 15 fuzzy - 1 removed = 41)

---

## D2 TODO 4 — Quality Attributes

Four quality attributes were applied and are verifiable in the code:

| Attribute | Where applied | Impact |
|---|---|---|
| **Explainability** | Every `=>` consequent embeds the triggering value, threshold, CF, and/or μ in the `msg` text | Positive — residents see why each action fired |
| **Reliability** | CF8 defaults thermostat to setback when occupancy CF < 0.60; CF9/CF10 qualify uncertain readings; CF1–CF7 distinguish real emergencies from sensor faults | Positive — system degrades gracefully on bad sensors |
| **Accuracy** | Fuzzy MF boundaries (templates.clp) match human comfort literature; heating target varies with degree of coldness (17–21°C) instead of a single crisp cutoff | Positive — eliminates abrupt D1 cliff at 20°C |
| **Maintainability** | CF base values are named constants in `generate_indoor_facts.py`; fuzzy MF parameters defined once in template deftemplates; `fuzzy-env` separates raw readings from derived memberships | Neutral-to-positive — larger KB offset by centralised definitions and structured comments |

---

## Requirement Checklist

| Requirement | Status | Evidence |
|---|---|---|
| D2 TODO 1: ≥1 D1 improvement identified | ✅ | 3 items in report §D2 TODO 1 |
| D2 TODO 1: changes verifiable | ✅ | git history; `cool-sleep` in rules.clp |
| D2 TODO 2: F ≥ 5 new facts | ✅ | 5 CF slots × 10 days = 50 data points |
| D2 TODO 2: R ≥ 10 new rules | ✅ | CF1–CF10 = 10 rules |
| D2 TODO 3: F ≥ 5 new facts | ✅ | 10 `fuzzy-env` facts (one per day) |
| D2 TODO 3: R ≥ 10 new rules | ✅ | FZ1–FZ15 = 15 rules |
| D2 TODO 4: ≥ 4 quality attributes | ✅ | Explainability, Reliability, Accuracy, Maintainability |
| D2 TODO 4: guidelines applied, verifiable | ✅ | Specific file/rule citations in report §D2 TODO 4 |
| D2 TODO 4: impact explained | ✅ | Report §Impact on Quality |
| General TODO 4: LaTeX report | ✅ | `report/report.tex` + `report/report.pdf` |
| General TODO 2: citations | ✅ | `\cite{}` throughout; `references.bib` present |
