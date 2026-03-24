# D2 Implementation Guide

This guide walks you through every change needed for Deliverable 2.
It is written so you can follow it top-to-bottom without having to figure anything out yourself.
Each section starts with the theory you need, then gives exact instructions.

---

## What D2 asks for (plain summary)

| TODO | Marks | What it is |
|---|---|---|
| D2 TODO 1 | 10 | Fix things from D1 feedback |
| D2 TODO 2 | 40 | Add **probabilistic** uncertainty using Certainty Factors |
| D2 TODO 3 | 40 | Add **possibilistic** uncertainty using Fuzzy Logic |
| D2 TODO 4 | 30 | Pick 4 quality attributes and show you applied quality guidelines |

Total new rules needed: ≥10 (CF) + ≥10 (Fuzzy) = ≥20 new rules in `rules.clp`
Total new facts needed: ≥5 (CF) + ≥5 (Fuzzy) = ≥10 new fact slots/templates in `templates.clp` + `facts.clp`

---

---

# PART 0 — What D1 Already Gives You

D2 does **not** replace D1. It **extends** it. Every file, template, fact, and rule from D1
carries forward unchanged (unless you are fixing a D1 TODO 1 issue). The D2 minimums
(≥5 facts, ≥10 rules for TODO 2 and TODO 3) are **additions on top of D1**, not replacements.

D2 TODO 4 explicitly says to apply quality guidelines to the **entire** knowledge base —
meaning D1 facts + D2 facts, D1 rules + D2 rules all together.

---

## Templates — all 4 reused, 1 extended, 1 new

| Template | D1 status | D2 action |
|---|---|---|
| `env` | Core data fact — indoor + outdoor sensor readings | **Extended**: add 5 CF slots (Step A2.1) |
| `device` | Controllable devices: humidifier, dehumidifier, window, air-purifier | **Unchanged**: fuzzy rules modify it the same way D1 rules do |
| `themostat` | Thermostat mode (heat/cool/off) and target-temp | **Unchanged**: fuzzy rules call `modify` on it just like D1 rules |
| `msg` | Explanation messages grouped by date | **Unchanged**: all new CF and fuzzy rules reuse `assert (msg ...)` |
| `fuzzy-env` | Does not exist in D1 | **New in D2**: holds computed fuzzy membership degrees (Step B2.1) |

---

## Facts — all D1 facts reused, each extended with new slots

Each day's deffacts block in `facts.clp` currently has 6 facts:

```
(env ...)          ← extended with 5 CF slots
(themostat ...)    ← unchanged
(device humidifier ...)    ← unchanged
(device dehumidifier ...)  ← unchanged
(device window ...)        ← unchanged
(device air-purifier ...)  ← unchanged
```

In D2 you add one more fact per day:
```
(fuzzy-env ...)    ← new blank fact; fuzzification rules fill in the values
```

The 10 `env` facts with their new CF slots count as the **≥5 new useful facts** required by
D2 TODO 2 (each `env` fact now carries 5 CF fields = 50 new CF data points across 10 days).
The 10 `fuzzy-env` facts count as the **≥5 new useful facts** required by D2 TODO 3.

---

## Rules — all 20 D1 rules reused in D2

These rules do not change (except two safety rules that get superseded — see note below):

| Group | Rules | Salience | D2 interaction |
|---|---|---|---|
| Safety | `co-emergency`, `fire-emergency` | 100 | **Superseded** by CF rules at salience 90. Comment these two out. |
| Heating | `heat-awake`, `heat-sleep`, `heat-gone` | 60 | Still fire for certain-knowledge days; fuzzy rules at salience 50 may also fire but check `(mode off)` guard — only one fires |
| Cooling | `cool-awake`, `cool-gone`, `thermostat-off-gone` | 60 | Unchanged; fuzzy cooling rules can be added later |
| Humidity | `humidify`, `dehumidify`, `humidity-comfortable` | 40 | Still fire; fuzzy humidity rules at salience 50 fire first but also check `(status off)` guard |
| Window | `close-window-bad-outdoor-air`, `good-outdoor-air` | 35 | Still fire; fuzzy AQHI advisory at salience 50 adds graduated advice before these |
| IAQI | `iaqi-good`, `iaqi-moderate`, `iaqi-polluted`, `iaqi-very-polluted`, `iaqi-severely-polluted`, `both-air-quality-poor` | 30 | Unchanged |
| Output | `print-all-grouped` | -10 | Unchanged; all new CF and fuzzy `msg` facts are automatically printed |

**Note on the two commented-out safety rules:** `co-emergency` and `fire-emergency` from D1
check `(co-alarm on)` unconditionally. The new CF rules at salience 90 do the same check
but also inspect the CF value. If you leave both, they will **both** fire on a day with
`co-alarm on`, giving duplicate emergency messages. Comment out the D1 versions.

---

## Python pipeline — all 3 scripts reused, 2 extended

| Script | D1 role | D2 action |
|---|---|---|
| `crawler.py` | Fetches Montreal weather + AQHI | **Unchanged** |
| `generate_indoor_facts.py` | Generates indoor sensor readings | **Extended**: add `_cf()` helper and 5 CF fields per record (Step A2.2) |
| `combine_facts.py` | Merges JSON into `facts.clp` | **Extended**: read CF fields, write to `env` fact, add blank `fuzzy-env` fact (Steps A2.3, B2.2) |

---

## `run.clp` — unchanged

`run.clp` loads `templates.clp`, `rules.clp`, `facts.clp` in that order, then runs the engine.
No changes needed: the new `fuzzy-env` template is in `templates.clp`, and the new facts are
in `facts.clp` — both already loaded by `run.clp`.

---

## Rule count summary (for your report)

| Source | Rules | Facts (slots/templates) |
|---|---|---|
| D1 (certain knowledge) | 20 | `env` (11 slots) + `device` + `themostat` + `msg` |
| D2 TODO 2 (CF) | +10 | +5 CF slots on `env` |
| D2 TODO 3 (Fuzzy) | +11 | +1 `fuzzy-env` template (15 slots) |
| **Total** | **41** | **4 templates + 1 new template** |

This is well above all minimums. Document these counts in your report.

---

---

# PART A — Certainty Factors (D2 TODO 2)

## A1. Theory: What are Certainty Factors?

Certainty Factors (CF) were invented for **MYCIN** (Stanford, 1970s), one of the first medical
expert systems. The problem MYCIN solved: a doctor's sensor reading is never perfectly reliable.
A blood test can be wrong. A symptom can have multiple causes. How do you reason when your
facts are uncertain?

The idea: attach a number between **-1.0 and +1.0** to every piece of evidence and every hypothesis.

```
CF = +1.0   →  absolutely certain it is TRUE
CF =  0.0   →  no information either way
CF = -1.0   →  absolutely certain it is FALSE
```

In practice for sensor data you use **0.0 to 1.0** (you rarely need negative CFs for sensors —
a "negative" CF means evidence *against* a hypothesis, which we won't need here).

### A1.1 Where does a CF value come from?

You assign it based on domain knowledge or statistics. Examples for our smart home:

| Sensor | Typical CF | Reason |
|---|---|---|
| CO alarm | 0.85 | CO sensors have ~85% reliability per manufacturer specs |
| Fire/smoke alarm | 0.90 | Smoke sensors are highly reliable |
| Motion/occupancy sensor | 0.75 | Motion sensors have ~25% false-positive or miss rate |
| IAQI sensor (Atmotube) | 0.80 | Consumer-grade sensor, good but not lab-grade |
| Outdoor AQHI | 0.70 | Government reading, but may be from a distant station |

These numbers go into `facts.clp` as new slots on the `env` fact.

### A1.2 How do you combine two CFs?

When two independent pieces of evidence both support the same hypothesis, you combine them:

```
Both positive:
  CF_combined = CF1 + CF2 * (1 - CF1)

Both negative:
  CF_combined = CF1 + CF2 * (1 + CF1)

One positive, one negative:
  CF_combined = (CF1 + CF2) / (1 - min(|CF1|, |CF2|))
```

Example: CO alarm fires (CF=0.85) AND you also smell something (CF=0.60):
```
CF_combined = 0.85 + 0.60 * (1 - 0.85) = 0.85 + 0.09 = 0.94
```

In CLIPS, you implement this combination inside a rule using arithmetic.

### A1.3 How do CF values affect decisions?

You define thresholds for action:

```
CF >= 0.70  →  high confidence  → take full action
CF  0.30 to 0.69  →  moderate confidence  → take cautious action or warn
CF < 0.30   →  low confidence   → likely false alarm, do not act, alert user
```

These thresholds are your design choice — document them in your report.

### A1.4 How is this different from D1?

In D1, if `co-alarm = on`, you immediately triggered a full emergency.
In D2 with CF, you check *how confident* you are:
- High CF → full emergency (same as D1)
- Medium CF → "Possible CO, please investigate" (new)
- Low CF → "Sensor may be faulty" (new)

This is more realistic: real CO detectors do malfunction.

---

## A2. Step-by-step: Implementing Certainty Factors

### Step A2.1 — Add CF slots to `templates.clp`

Open `templates.clp`. Find the `env` deftemplate. Add these slots **after** the existing `AQHI` slot:

```clips
; Certainty Factors for sensor readings (range 0.0 to 1.0)
(slot co-alarm-cf    (type FLOAT) (range 0.0 1.0) (default 0.85))
(slot fire-alarm-cf  (type FLOAT) (range 0.0 1.0) (default 0.90))
(slot occupancy-cf   (type FLOAT) (range 0.0 1.0) (default 0.75))
(slot iaqi-cf        (type FLOAT) (range 0.0 1.0) (default 0.80))
(slot aqhi-cf        (type FLOAT) (range 0.0 1.0) (default 0.70))
```

**Why FLOAT, not INTEGER?** CF values are decimals like 0.85. CLIPS supports FLOAT for this.
**Why default values?** So existing facts that don't specify a CF still get a sensible value.

Your `env` deftemplate should now look like:

```clips
(deftemplate env
    (slot date      (type STRING)  (default "unknown"))
    (slot temp      (type INTEGER) (range -100 100) (default 23))
    (slot humidity  (type INTEGER) (range 0 100)    (default 45))
    (slot IAQI      (type INTEGER) (range 0 500)    (default 50))
    (slot co-alarm   (allowed-values on off) (default off))
    (slot fire-alarm (allowed-values on off) (default off))
    (slot occupancy (allowed-values sleep awake gone) (default awake))
    (slot season    (allowed-values winter spring summer fall) (default winter))
    (slot high-temp (type INTEGER) (range -100 100))
    (slot low-temp  (type INTEGER) (range -100 100))
    (slot AQHI      (type INTEGER) (range 1 11) (default 3))
    ; Certainty Factors (0.0 = no confidence, 1.0 = full confidence)
    (slot co-alarm-cf    (type FLOAT) (range 0.0 1.0) (default 0.85))
    (slot fire-alarm-cf  (type FLOAT) (range 0.0 1.0) (default 0.90))
    (slot occupancy-cf   (type FLOAT) (range 0.0 1.0) (default 0.75))
    (slot iaqi-cf        (type FLOAT) (range 0.0 1.0) (default 0.80))
    (slot aqhi-cf        (type FLOAT) (range 0.0 1.0) (default 0.70))
)
```

---

### Step A2.2 — Add CF generation to `generate_indoor_facts.py`

Open `data_scripts/generate_indoor_facts.py`.

After the `FIRE_ALARM_PROB` constant, add these constants:

```python
# Certainty Factor base values and noise
CO_CF_BASE    = 0.85
FIRE_CF_BASE  = 0.90
OCC_CF_BASE   = 0.75
IAQI_CF_BASE  = 0.80
AQHI_CF_BASE  = 0.70
CF_SIGMA      = 0.05   # small gaussian noise around base CF
```

Inside the `for` loop, after the line that computes `indoor_air_quality_index`, add:

```python
def _cf(base, sigma=0.05):
    """Gaussian noise around a base CF, clamped to [0.1, 1.0]."""
    return round(max(0.1, min(1.0, base + random.gauss(0, sigma))), 2)
```

Put this helper function **before** `generate_daily_records`, then inside the loop add to the `records.append({...})` dict:

```python
"co_alarm_cf":   _cf(CO_CF_BASE),
"fire_alarm_cf": _cf(FIRE_CF_BASE),
"occupancy_cf":  _cf(OCC_CF_BASE),
"iaqi_cf":       _cf(IAQI_CF_BASE),
"aqhi_cf":       _cf(AQHI_CF_BASE),
```

**Why add noise?** In reality, sensor reliability varies slightly day to day (battery level, dust on sensor, temperature affecting electronics). The Gaussian noise models this.

---

### Step A2.3 — Pass CF values through `combine_facts.py`

Open `data_scripts/combine_facts.py`.

In the `main()` function, inside the `for date_str in dates:` loop, after the line that reads `aqhi`, add:

```python
co_cf    = ind.get("co_alarm_cf",   0.85)
fire_cf  = ind.get("fire_alarm_cf", 0.90)
occ_cf   = ind.get("occupancy_cf",  0.75)
iaqi_cf  = ind.get("iaqi_cf",       0.80)
aqhi_cf  = ind.get("aqhi_cf",       0.70)
```

Then update the `env` fact line (the one that starts with `f'    (env (date ...'`) to also include the CF slots at the end:

```python
f'    (env (date "{date_str}") (temp {temp}) (humidity {humidity})'
f' (IAQI {iaqi}) (co-alarm {co_alarm}) (fire-alarm {fire_alarm})'
f' (occupancy {occupancy}) (season {season})'
f' (high-temp {high}) (low-temp {low}) (AQHI {aqhi})'
f' (co-alarm-cf {co_cf}) (fire-alarm-cf {fire_cf})'
f' (occupancy-cf {occ_cf}) (iaqi-cf {iaqi_cf}) (aqhi-cf {aqhi_cf}))',
```

**Why keep defaults in templates.clp?** The defaults mean old `facts.clp` files still work even
if you forget to regenerate them. New generated files override the defaults.

---

### Step A2.4 — Regenerate `facts.clp`

Run the full pipeline to get an updated `facts.clp`:

```bash
conda activate crawler
python data_scripts/generate_indoor_facts.py
python data_scripts/combine_facts.py
```

Open `facts.clp` and verify each `env` fact now has `co-alarm-cf`, `fire-alarm-cf`, etc.

---

### Step A2.5 — Add CF rules to `rules.clp`

Add a new section in `rules.clp` after the existing safety rules section.
Add these 10 rules (this satisfies the ≥10 rules requirement for D2 TODO 2):

```clips
; ================================================
; CERTAINTY FACTORS - Probabilistic Uncertainty  (salience 90)
; Based on MYCIN Certainty Factors Theory.
; CF thresholds: >= 0.70 high, 0.30-0.69 moderate, < 0.30 low.
; Salience 90: fires after templates load but before lower-priority rules,
; so CF-based emergencies can still block them.
; ================================================

(defrule co-high-cf
    "CO alarm on AND high certainty (CF >= 0.70): full emergency."
    (declare (salience 90))
    (env (date ?date) (co-alarm on) (co-alarm-cf ?cf))
    (test (>= ?cf 0.70))
    (not (emergency ?date))
    =>
    (assert (emergency ?date))
    (assert (msg (date ?date) (text (str-cat
        "EMERGENCY (CF=" ?cf "): CO detected with high confidence. Evacuate and call 911."
    ))))
)

(defrule co-moderate-cf
    "CO alarm on AND moderate certainty (0.30 <= CF < 0.70): investigate."
    (declare (salience 90))
    (env (date ?date) (co-alarm on) (co-alarm-cf ?cf))
    (test (and (>= ?cf 0.30) (< ?cf 0.70)))
    (not (emergency ?date))
    =>
    (assert (msg (date ?date) (text (str-cat
        "WARNING (CF=" ?cf "): CO sensor triggered with moderate confidence. "
        "Ventilate the home and inspect the CO sensor for faults."
    ))))
)

(defrule co-low-cf
    "CO alarm on AND low certainty (CF < 0.30): likely false positive."
    (declare (salience 90))
    (env (date ?date) (co-alarm on) (co-alarm-cf ?cf))
    (test (< ?cf 0.30))
    (not (emergency ?date))
    =>
    (assert (msg (date ?date) (text (str-cat
        "NOTICE (CF=" ?cf "): CO sensor triggered but confidence is very low. "
        "Likely a false positive. Check sensor battery and calibration."
    ))))
)

(defrule fire-high-cf
    "Fire alarm on AND high certainty (CF >= 0.70): full emergency."
    (declare (salience 90))
    (env (date ?date) (fire-alarm on) (fire-alarm-cf ?cf))
    (test (>= ?cf 0.70))
    (not (emergency ?date))
    =>
    (assert (emergency ?date))
    (assert (msg (date ?date) (text (str-cat
        "EMERGENCY (CF=" ?cf "): Fire/smoke detected with high confidence. Evacuate and call 911."
    ))))
)

(defrule fire-moderate-cf
    "Fire alarm on AND moderate certainty (0.30 <= CF < 0.70): investigate."
    (declare (salience 90))
    (env (date ?date) (fire-alarm on) (fire-alarm-cf ?cf))
    (test (and (>= ?cf 0.30) (< ?cf 0.70)))
    (not (emergency ?date))
    =>
    (assert (msg (date ?date) (text (str-cat
        "WARNING (CF=" ?cf "): Smoke sensor triggered with moderate confidence. "
        "Check for actual smoke or cooking fumes before evacuating."
    ))))
)

(defrule fire-low-cf
    "Fire alarm on AND low certainty (CF < 0.30): likely false positive."
    (declare (salience 90))
    (env (date ?date) (fire-alarm on) (fire-alarm-cf ?cf))
    (test (< ?cf 0.30))
    (not (emergency ?date))
    =>
    (assert (msg (date ?date) (text (str-cat
        "NOTICE (CF=" ?cf "): Smoke sensor triggered but confidence is very low. "
        "Likely a false positive. Inspect sensor."
    ))))
)

(defrule co-and-fire-combined-cf
    "Both CO and fire alarm on: combine CFs using CF_combined = CF1 + CF2*(1-CF1).
     If combined CF >= 0.70, assert emergency."
    (declare (salience 90))
    (env (date ?date) (co-alarm on) (co-alarm-cf ?cf1) (fire-alarm on) (fire-alarm-cf ?cf2))
    (not (emergency ?date))
    =>
    (bind ?combined (+ ?cf1 (* ?cf2 (- 1 ?cf1))))
    (if (>= ?combined 0.70)
        then
        (assert (emergency ?date))
        (assert (msg (date ?date) (text (str-cat
            "EMERGENCY: Both CO (CF=" ?cf1 ") and fire (CF=" ?cf2
            ") sensors triggered. Combined CF=" ?combined
            ". Evacuate immediately."
        ))))
        else
        (assert (msg (date ?date) (text (str-cat
            "WARNING: Both CO and fire sensors triggered. Combined CF=" ?combined
            ". Investigate immediately even though confidence is below 0.70."
        ))))
    )
)

(defrule occupancy-uncertain-thermostat
    "If occupancy CF is low (< 0.60), default to energy-saving mode instead of
     trusting the occupancy reading for thermostat decisions."
    (declare (salience 55))
    (env (date ?date) (occupancy awake) (occupancy-cf ?cf) (season winter))
    (not (emergency ?date))
    (test (< ?cf 0.60))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 17))
    (assert (msg (date ?date) (text (str-cat
        "Thermostat set to energy-saving 17C target. Reason: occupancy sensor confidence CF="
        ?cf " is below 0.60; defaulting to away/sleep target to save energy."
    ))))
)

(defrule iaqi-uncertain-reading
    "If IAQI sensor CF is low (< 0.60), qualify the air quality recommendation."
    (declare (salience 25))
    (env (date ?date) (IAQI ?i) (iaqi-cf ?cf))
    (not (emergency ?date))
    (test (< ?cf 0.60))
    =>
    (assert (msg (date ?date) (text (str-cat
        "NOTE: Indoor IAQI reading of " ?i " has low sensor confidence (CF=" ?cf
        "). Consider recalibrating the air quality sensor before acting on this reading."
    ))))
)

(defrule aqhi-uncertain-reading
    "If AQHI CF is low (< 0.60), qualify the outdoor air quality advisory."
    (declare (salience 25))
    (env (date ?date) (AQHI ?a) (aqhi-cf ?cf))
    (not (emergency ?date))
    (test (< ?cf 0.60))
    =>
    (assert (msg (date ?date) (text (str-cat
        "NOTE: Outdoor AQHI reading of " ?a " has low confidence (CF=" ?cf
        "). The nearest monitoring station may be far away. Treat window advice as advisory."
    ))))
)
```

**Count check:** 10 rules. Requirement met.

**Important — update the old safety rules:**
The original `co-emergency` and `fire-emergency` rules in D1 now overlap with the CF rules.
You have two options:
- Option A (easier): Add `(co-alarm-cf ?cf) (test (>= ?cf 0.70))` conditions to the existing D1 rules so they only fire for high-CF cases. The new CF rules handle the rest.
- Option B: Comment out the two old D1 rules entirely and let the CF rules handle everything.

Option B is cleaner. Comment out `co-emergency` and `fire-emergency` by wrapping them in `#|...|#` (CLIPS block comment syntax) or just delete them.

---

---

# PART B — Fuzzy Logic (D2 TODO 3)

## B1. Theory: What is Fuzzy Logic?

Fuzzy Logic was introduced by **Lotfi Zadeh** (UC Berkeley, 1965). The problem it solves:
classical logic is binary (true/false), but the real world is full of gradations.

Consider the temperature 19.5°C. Is it "cold"? In classical logic you must pick one answer.
In fuzzy logic, 19.5°C can be *partially* cold (say, membership = 0.3) and *partially* comfortable
(membership = 0.7) at the same time.

### B1.1 Membership Functions

A **membership function** maps a crisp input value to a degree of membership in [0.0, 1.0].
The most common shapes are **triangular** and **trapezoidal**.

**Triangular** (defined by three points: left, peak, right):
```
          1.0
           |      *
           |    /   \
           |  /       \
           | /           \
  0.0 ----*---------------*----
         left  peak     right

mu(x) = 0                          if x <= left or x >= right
      = (x - left)  / (peak - left)   if left < x <= peak
      = (right - x) / (right - peak)  if peak < x < right
```

**Trapezoidal** (defined by four points: a, b, c, d — flat top between b and c):
```
          1.0
           |      *-------*
           |    /           \
  0.0 ----*-------------------*----
          a    b             c    d

mu(x) = 0                      if x <= a or x >= d
      = (x - a) / (b - a)      if a < x < b
      = 1.0                    if b <= x <= c
      = (d - x) / (d - c)      if c < x < d
```

### B1.2 Fuzzy Temperature Sets for Smart Home

Indoor temperature range relevant to us: 0°C to 35°C.
We define five linguistic labels:

| Label | a | b | c | d | Shape |
|---|---|---|---|---|---|
| cold | -∞ | -∞ | 14 | 18 | trapezoidal (left-open) |
| cool | 14 | 18 | 20 | 22 | trapezoidal |
| comfortable | 20 | 21 | 23 | 24 | trapezoidal |
| warm | 23 | 25 | 27 | 29 | trapezoidal |
| hot | 27 | 30 | ∞ | ∞ | trapezoidal (right-open) |

For a left-open trapezoid: mu=1.0 when x <= b, then ramps down.
For a right-open trapezoid: mu=1.0 when x >= c, then ramps up.

### B1.3 Fuzzy Humidity Sets

Humidity range: 0% to 100%.

| Label | a | b | c | d | Shape |
|---|---|---|---|---|---|
| dry | -∞ | -∞ | 25 | 35 | left-open trapezoidal |
| comfortable | 30 | 40 | 50 | 60 | trapezoidal |
| humid | 55 | 65 | ∞ | ∞ | right-open trapezoidal |

### B1.4 Fuzzy AQHI Sets

AQHI range: 1 to 10+.

| Label | a | b | c | d | Shape |
|---|---|---|---|---|---|
| good | -∞ | -∞ | 3 | 5 | left-open |
| moderate | 4 | 5 | 6 | 7 | trapezoidal |
| poor | 6 | 8 | ∞ | ∞ | right-open |

### B1.5 Fuzzy Inference (Mamdani Method)

Once you have membership degrees, you write fuzzy rules:

```
IF temp IS cold AND occupancy IS awake THEN heating-strength IS strong
IF temp IS cool THEN heating-strength IS moderate
IF humidity IS dry THEN humidifier-intensity IS high
IF AQHI IS moderate THEN window-advice IS caution
```

The inference works as follows:
- The degree to which the rule fires = the membership degree of its conditions
- `AND` in fuzzy logic = `min(mu1, mu2)` (take the smaller)
- `OR` in fuzzy logic = `max(mu1, mu2)` (take the larger)

### B1.6 Defuzzification (Centroid Method)

Fuzzy inference produces a fuzzy output (like "heating-strength IS somewhat strong").
To get a **crisp value** (like a target temperature), you use **defuzzification**.

The centroid (center of gravity) method:

```
crisp_output = sum(mu_i * value_i) / sum(mu_i)
```

For example, for thermostat target temp:
- strong heating → target 21°C, mu=0.7
- moderate heating → target 19°C, mu=0.4
- weak heating → target 17°C, mu=0.1

```
target = (0.7*21 + 0.4*19 + 0.1*17) / (0.7 + 0.4 + 0.1)
       = (14.7 + 7.6 + 1.7) / 1.2
       = 24.0 / 1.2
       = 20.0°C
```

In CLIPS you implement this arithmetic directly using `bind` and slot modification.

### B1.7 How is this different from D1?

In D1, `temp < 20` → set thermostat to 20°C. Hard cutoff: at 19.9°C you heat, at 20.1°C you don't.
In D2 with Fuzzy Logic, a temperature of 19°C triggers strong heating, 20.5°C triggers mild heating,
21°C triggers no action — the transition is gradual and more realistic.

---

## B2. Step-by-step: Implementing Fuzzy Logic

### Step B2.1 — Add a new `fuzzy-env` template to `templates.clp`

Add this new deftemplate **after** the existing templates:

```clips
; Fuzzy membership degrees — computed from crisp env values by fuzzification rules.
; All slots are FLOAT in [0.0, 1.0].
(deftemplate fuzzy-env
    (slot date (type STRING) (default "unknown"))
    ; Temperature linguistic variables
    (slot mu-temp-cold        (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-temp-cool        (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-temp-comfortable (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-temp-warm        (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-temp-hot         (type FLOAT) (range 0.0 1.0) (default 0.0))
    ; Humidity linguistic variables
    (slot mu-hum-dry          (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-hum-comfortable  (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-hum-humid        (type FLOAT) (range 0.0 1.0) (default 0.0))
    ; AQHI linguistic variables
    (slot mu-aqhi-good        (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-aqhi-moderate    (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-aqhi-poor        (type FLOAT) (range 0.0 1.0) (default 0.0))
    ; Defuzzified thermostat output
    (slot fuzzy-target-temp   (type FLOAT) (range 10.0 30.0) (default 20.0))
)
```

**Why a separate template?** Fuzzy membership values are derived facts (computed from raw sensor
readings). Keeping them in a separate template makes the knowledge base modular and readable —
a key quality attribute.

---

### Step B2.2 — Add a `fuzzy-env` initial fact to `facts.clp` for each day

Open `data_scripts/combine_facts.py`. Inside the `for date_str in dates:` loop, add one more line
to the `lines +=` block, right after the last device line and before the closing `')'`:

```python
f'    (fuzzy-env (date "{date_str}"))',
```

This creates a blank `fuzzy-env` fact for each day. The fuzzification rules will fill in the values.

**Run the pipeline again** after this change:

```bash
python data_scripts/combine_facts.py
```

---

### Step B2.3 — Add the membership function helpers to `rules.clp`

CLIPS does not have built-in fuzzy functions, so you implement them using `deffunction`.
Add these **before** any fuzzy rules, near the top of `rules.clp` (after the existing
`print-grouped` function):

```clips
; ================================================
; FUZZY MEMBERSHIP FUNCTIONS
; ================================================

(deffunction mu-trapezoid (?x ?a ?b ?c ?d)
    "Trapezoidal membership function with support [a,d] and core [b,c].
     Pass a very small number for left-open (e.g. a=-999 b=-999).
     Pass a very large number for right-open (e.g. c=999 d=999)."
    (cond
        ((<= ?x ?a)                    (bind ?mu 0.0))
        ((and (> ?x ?a) (< ?x ?b))     (bind ?mu (/ (- ?x ?a) (- ?b ?a))))
        ((and (>= ?x ?b) (<= ?x ?c))   (bind ?mu 1.0))
        ((and (> ?x ?c) (< ?x ?d))     (bind ?mu (/ (- ?d ?x) (- ?d ?c))))
        ((>= ?x ?d)                    (bind ?mu 0.0))
    )
    ?mu
)
```

**Note on left-open / right-open:** pass `-999` for `a` and `b` for left-open shapes
(meaning: full membership for any very cold temperature). Pass `999` for `c` and `d` for
right-open shapes (full membership for any very hot temperature).

---

### Step B2.4 — Add fuzzification rules to `rules.clp`

Add a new section with salience 80 (runs before main rules but after CF rules):

```clips
; ================================================
; FUZZY LOGIC — Fuzzification  (salience 80)
; Reads crisp env values, computes membership degrees,
; writes them into the fuzzy-env fact for this date.
; ================================================

(defrule fuzzify-temperature
    "Compute fuzzy temperature membership degrees and store in fuzzy-env."
    (declare (salience 80))
    (env (date ?date) (temp ?t))
    ?fe <- (fuzzy-env (date ?date))
    =>
    ; cold:        left-open trapezoid, core (-inf, 14], ramp down at 18
    (bind ?cold        (mu-trapezoid ?t -999 -999 14 18))
    ; cool:        trapezoid [14, 18, 20, 22]
    (bind ?cool        (mu-trapezoid ?t 14 18 20 22))
    ; comfortable: trapezoid [20, 21, 23, 24]
    (bind ?comfortable (mu-trapezoid ?t 20 21 23 24))
    ; warm:        trapezoid [23, 25, 27, 29]
    (bind ?warm        (mu-trapezoid ?t 23 25 27 29))
    ; hot:         right-open trapezoid, ramp up at 27, core [30, +inf)
    (bind ?hot         (mu-trapezoid ?t 27 30 999 999))
    (modify ?fe
        (mu-temp-cold        ?cold)
        (mu-temp-cool        ?cool)
        (mu-temp-comfortable ?comfortable)
        (mu-temp-warm        ?warm)
        (mu-temp-hot         ?hot)
    )
)

(defrule fuzzify-humidity
    "Compute fuzzy humidity membership degrees and store in fuzzy-env."
    (declare (salience 80))
    (env (date ?date) (humidity ?h))
    ?fe <- (fuzzy-env (date ?date))
    =>
    ; dry:          left-open, core (-inf, 25], ramp down at 35
    (bind ?dry         (mu-trapezoid ?h -999 -999 25 35))
    ; comfortable:  [30, 40, 50, 60]
    (bind ?comfy       (mu-trapezoid ?h 30 40 50 60))
    ; humid:        right-open, ramp up at 55, core [65, +inf)
    (bind ?humid       (mu-trapezoid ?h 55 65 999 999))
    (modify ?fe
        (mu-hum-dry         ?dry)
        (mu-hum-comfortable ?comfy)
        (mu-hum-humid       ?humid)
    )
)

(defrule fuzzify-aqhi
    "Compute fuzzy AQHI membership degrees and store in fuzzy-env."
    (declare (salience 80))
    (env (date ?date) (AQHI ?a))
    ?fe <- (fuzzy-env (date ?date))
    =>
    ; good:     left-open, core (-inf, 3], ramp down at 5
    (bind ?good     (mu-trapezoid ?a -999 -999 3 5))
    ; moderate: [4, 5, 6, 7]
    (bind ?moderate (mu-trapezoid ?a 4 5 6 7))
    ; poor:     right-open, ramp up at 6, core [8, +inf)
    (bind ?poor     (mu-trapezoid ?a 6 8 999 999))
    (modify ?fe
        (mu-aqhi-good     ?good)
        (mu-aqhi-moderate ?moderate)
        (mu-aqhi-poor     ?poor)
    )
)
```

**Count so far for D2 TODO 3:** 3 rules (fuzzification). Need ≥10 total. Continue below.

---

### Step B2.5 — Add fuzzy inference rules to `rules.clp`

Add a section with salience 50 (between fuzzification and the original D1 rules):

```clips
; ================================================
; FUZZY LOGIC — Inference  (salience 50)
; Applies fuzzy IF-THEN rules to compute outputs.
; Uses min() for AND, reports linguistic conclusions,
; and computes defuzzified thermostat target.
; ================================================

(defrule fuzzy-heat-strong
    "Fuzzy rule: IF temp IS cold AND occupancy IS awake THEN heat strongly (target 21C).
     Fires when mu-temp-cold > 0.0 (any degree of cold membership)."
    (declare (salience 50))
    (env (date ?date) (occupancy awake) (season winter))
    (fuzzy-env (date ?date) (mu-temp-cold ?mu-cold))
    (not (emergency ?date))
    (test (> ?mu-cold 0.0))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 21))
    (assert (msg (date ?date) (text (str-cat
        "Fuzzy heating (strong): temperature membership in 'cold' = " ?mu-cold
        ". Setting thermostat to 21C."
    ))))
)

(defrule fuzzy-heat-moderate
    "Fuzzy rule: IF temp IS cool (but not cold) AND occupancy IS awake THEN heat moderately (target 19C)."
    (declare (salience 50))
    (env (date ?date) (occupancy awake) (season winter))
    (fuzzy-env (date ?date) (mu-temp-cold ?mu-cold) (mu-temp-cool ?mu-cool))
    (not (emergency ?date))
    (test (and (> ?mu-cool 0.0) (= ?mu-cold 0.0)))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 19))
    (assert (msg (date ?date) (text (str-cat
        "Fuzzy heating (moderate): temperature membership in 'cool' = " ?mu-cool
        ". Setting thermostat to 19C."
    ))))
)

(defrule fuzzy-defuzzify-thermostat
    "Defuzzification: compute weighted-average thermostat target from all fuzzy heating memberships.
     Updates fuzzy-env with the defuzzified target for reporting."
    (declare (salience 45))
    (env (date ?date) (season winter))
    ?fe <- (fuzzy-env (date ?date)
                      (mu-temp-cold ?mc)
                      (mu-temp-cool ?mco)
                      (mu-temp-comfortable ?mcomf))
    (not (emergency ?date))
    =>
    ; Output mapping: cold → 21C, cool → 19C, comfortable → 18C (no strong heat needed)
    (bind ?numerator   (+ (* ?mc 21.0) (* ?mco 19.0) (* ?mcomf 18.0)))
    (bind ?denominator (+ ?mc ?mco ?mcomf))
    (if (> ?denominator 0.0)
        then
        (bind ?target (/ ?numerator ?denominator))
        (modify ?fe (fuzzy-target-temp ?target))
        (assert (msg (date ?date) (text (str-cat
            "Fuzzy defuzzification: computed thermostat target = "
            (integer (round ?target)) "C "
            "(cold=" ?mc " cool=" ?mco " comfortable=" ?mcomf ")."
        ))))
    )
)

(defrule fuzzy-humidifier-strong
    "Fuzzy rule: IF humidity IS dry (mu > 0.5) THEN turn on humidifier with high-need advisory."
    (declare (salience 50))
    (env (date ?date))
    (fuzzy-env (date ?date) (mu-hum-dry ?mu-dry))
    (not (emergency ?date))
    (test (> ?mu-dry 0.5))
    ?d <- (device (date ?date) (name humidifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "Fuzzy humidity control: humidity membership in 'dry' = " ?mu-dry
        " (> 0.5). Humidifier activated at high intensity."
    ))))
)

(defrule fuzzy-humidifier-mild
    "Fuzzy rule: IF humidity IS dry (0.0 < mu <= 0.5) THEN turn on humidifier with mild advisory."
    (declare (salience 50))
    (env (date ?date))
    (fuzzy-env (date ?date) (mu-hum-dry ?mu-dry))
    (not (emergency ?date))
    (test (and (> ?mu-dry 0.0) (<= ?mu-dry 0.5)))
    ?d <- (device (date ?date) (name humidifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "Fuzzy humidity control: humidity membership in 'dry' = " ?mu-dry
        " (<= 0.5). Humidifier activated at mild intensity."
    ))))
)

(defrule fuzzy-dehumidifier
    "Fuzzy rule: IF humidity IS humid (mu > 0.0) THEN turn on dehumidifier."
    (declare (salience 50))
    (env (date ?date))
    (fuzzy-env (date ?date) (mu-hum-humid ?mu-humid))
    (not (emergency ?date))
    (test (> ?mu-humid 0.0))
    ?d <- (device (date ?date) (name dehumidifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "Fuzzy humidity control: humidity membership in 'humid' = " ?mu-humid
        ". Dehumidifier activated."
    ))))
)

(defrule fuzzy-window-poor-aqhi
    "Fuzzy rule: IF AQHI IS poor (mu > 0.5) THEN close window (strong action)."
    (declare (salience 50))
    (env (date ?date))
    (fuzzy-env (date ?date) (mu-aqhi-poor ?mu-poor))
    (not (emergency ?date))
    (test (> ?mu-poor 0.5))
    (device (date ?date) (name window) (status off))
    =>
    (assert (msg (date ?date) (text (str-cat
        "Fuzzy air quality: AQHI membership in 'poor' = " ?mu-poor
        " (> 0.5). Window closed — outdoor air quality is clearly poor."
    ))))
)

(defrule fuzzy-window-moderate-aqhi
    "Fuzzy rule: IF AQHI IS moderate (mu > 0.3) THEN advisory to consider closing window."
    (declare (salience 50))
    (env (date ?date))
    (fuzzy-env (date ?date) (mu-aqhi-moderate ?mu-mod))
    (not (emergency ?date))
    (test (> ?mu-mod 0.3))
    =>
    (assert (msg (date ?date) (text (str-cat
        "Fuzzy air quality advisory: AQHI membership in 'moderate' = " ?mu-mod
        ". Consider closing windows if staying indoors for extended periods."
    ))))
)
```

**Count check for D2 TODO 3:** 3 fuzzification + 8 inference/defuzz = **11 rules**. Requirement met (≥10).

**Count check for D2 TODO 2 (CF):** 10 rules from Step A2.5. Requirement met (≥10).

---

### Step B2.6 — Update salience header comment in `rules.clp`

At the top of `rules.clp`, update the salience table comment to include the new levels:

```clips
; Salience levels:
;   100  Carbon monoxide / fire safety (D1, certain knowledge)
;    90  Certainty Factors — probabilistic uncertainty (D2 TODO 2)
;    80  Fuzzy Logic — fuzzification  (D2 TODO 3)
;    60  Temperature control (D1)
;    50  Fuzzy Logic — inference and defuzzification (D2 TODO 3)
;    40  Humidity control (D1)
;    35  Window / outdoor AQHI control (D1)
;    30  Indoor air quality IAQI assessment (D1)
;    25  CF uncertainty notices (D2 TODO 2)
;   -10  Print grouped output (D1)
```

---

---

# PART C — Quality Attributes (D2 TODO 4)

## C1. Theory: Quality Attributes for Rule-Based Expert Systems

Quality attributes (also called quality factors or -ilities) describe non-functional properties
of a knowledge base. The standard reference for expert system quality is:
**Giarratano & Riley, "Expert Systems: Principles and Programming"** (the textbook for this course).

Common quality attributes for rule-based systems:

| Attribute | What it means in CLIPS |
|---|---|
| **Explainability** | Every action has a `msg` fact explaining why |
| **Maintainability** | Thresholds are defined as named constants, not magic numbers |
| **Reliability** | The system handles sensor faults (CF rules), not just happy paths |
| **Accuracy** | Fuzzy boundaries more closely model real comfort zones than hard cutoffs |
| **Portability** | Facts and rules are in separate files; load order is documented |
| **Readability** | Rules have docstrings, sections have comments, names are natural language |
| **Reusability** | `mu-trapezoid` is a generic function reusable for any domain |
| **Understandability** | Rule names like `fuzzy-heat-strong` are self-documenting |

## C2. Recommended 4 attributes for D2 TODO 4

Pick these four because they are most impacted by the D2 changes:

### 1. Explainability
**Justification:** This system controls physical devices in a home. Users must be able to audit
every decision. CF rules include the CF value in the message. Fuzzy rules include membership
degrees. Defuzzification shows the weighted calculation.
**Where applied:** Every `=>` consequent asserts a `msg` fact. The `print-grouped` function
displays all messages grouped by date.
**Impact:** Positive. The CF and fuzzy messages give more nuance than D1 messages (e.g., "CO
detected with CF=0.45, investigate" rather than just "EMERGENCY").

### 2. Reliability
**Justification:** Sensors fail. D1 assumed all sensor readings were correct. D2 adds CF to
model sensor uncertainty and distinguish emergencies from false positives.
**Where applied:** `co-high-cf`, `co-moderate-cf`, `co-low-cf`, `fire-high-cf`, etc.
`occupancy-uncertain-thermostat` defaults to energy-saving mode when occupancy sensor
confidence is low.
**Impact:** Positive. The system no longer panics on a sensor glitch.

### 3. Accuracy
**Justification:** Hard thresholds in D1 created abrupt behaviour. At 19.9°C the heater turns
on; at 20.0°C it stays off. Real human comfort is a gradual spectrum. Fuzzy membership
functions model this correctly.
**Where applied:** `fuzzify-temperature`, `fuzzy-heat-strong`, `fuzzy-heat-moderate`,
`fuzzy-defuzzify-thermostat`. The defuzzified thermostat target varies smoothly with temperature
rather than jumping between fixed values.
**Impact:** Positive. The thermostat target is proportional to how cold it is, not binary.

### 4. Maintainability
**Justification:** Thresholds (e.g., CF cutoff of 0.70, fuzzy boundary at 14°C for "cold")
must be easy to update as standards change or new sensors are deployed.
**Where applied:** CF thresholds are compared directly in rule conditions. Fuzzy boundaries
are arguments to `mu-trapezoid`. Both can be changed in one place without touching logic.
**Impact:** Neutral to positive. Slightly harder to read than D1 (more numeric parameters),
but much easier to tune than searching for magic numbers scattered throughout rules.

---

---

# PART D — D2 TODO 1: Addressing D1 Feedback

You need to wait for evaluator feedback. When you receive it:

1. Write a numbered list of all comments (even small ones).
2. For each comment, describe what you changed in the code or report.
3. Make the changes visible in the git history (commit after each change so it is independently verifiable).

Even before receiving formal feedback, here are **self-assessment improvements** you can already make:

| Potential D1 weakness | Suggested fix |
|---|---|
| `themostat` typo in template name | Consider noting it in the report; changing it would break all facts |
| `both-air-quality-poor` uses a global flag `(air-purifier-recommended)` without a date — could mismatch across days | Add `(date ?date)` to the flag: `(assert (air-purifier-recommended ?date))` |
| `cool-awake` message says "exceeds 25.5C" but the rule checks `> 25` (off-by one) | Fix the message text to say "exceeds 25C" |
| No handling of summer + sleep occupancy | Add a `cool-sleep` rule mirroring `heat-sleep` |
| Facts are hardcoded to `winter` only | Document this limitation in the report |

---

---

# PART E — File Change Summary

Here is every file you need to touch, in order:

| # | File | What to change |
|---|---|---|
| 1 | `templates.clp` | Add 5 CF slots to `env`; add new `fuzzy-env` deftemplate |
| 2 | `data_scripts/generate_indoor_facts.py` | Add `_cf()` helper; add 5 CF fields to each record |
| 3 | `data_scripts/combine_facts.py` | Read CF fields; write them into `env` fact; add `fuzzy-env` initial fact per day |
| 4 | Run pipeline | `python data_scripts/generate_indoor_facts.py && python data_scripts/combine_facts.py` |
| 5 | `rules.clp` | Add `mu-trapezoid` deffunction; add CF rules (×10); add fuzzification rules (×3); add fuzzy inference rules (×8); update salience header |
| 6 | `run.clp` | No changes needed (already loads all `.clp` files in correct order) |
| 7 | `report/report.tex` | Add D2 TODO 1–4 sections (theory, implementation description, quality analysis) |

---

# PART F — Testing Checklist

After all changes, run:

```bash
clips -f run.clp
```

Verify the output includes:
- [ ] CF-qualified emergency messages (e.g., "CO detected with high confidence CF=0.87")
- [ ] CF moderate/low warnings on days where CF values are in the 0.30–0.69 or <0.30 range
- [ ] Fuzzy membership values in temperature messages (e.g., "membership in 'cold' = 0.7")
- [ ] Defuzzification output (e.g., "computed thermostat target = 20C")
- [ ] Fuzzy humidity messages
- [ ] Fuzzy AQHI advisory messages
- [ ] No CLIPS errors (watch for `[CLIPS]` error lines in output)

If CLIPS throws a type error on a FLOAT comparison, make sure the CF slots are declared as
`(type FLOAT)` in the template and the facts write decimal values like `0.85` not integers like `1`.
