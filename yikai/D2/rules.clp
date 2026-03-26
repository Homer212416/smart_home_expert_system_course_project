; ================================================
; Smart Home Expert System - Rules  (D2 FuzzyCLIPS)
;
; Load order (via run.clp):
;   (load "templates.clp")
;   (load "rules.clp")
;   (load "facts.clp")
;   (reset)
;   (run)
;
; Run with FuzzyCLIPS:  fzclips -f run.clp
;
; Salience levels:
;    90  Safety alarms — MYCIN Certainty Factor model
;    80  Fuzzification: env → fuzzy-env (get-fs-value)
;    55  Uncertain occupancy → safe thermostat default
;    50  Fuzzy temperature control (Mamdani-style)
;    40  Humidity control (fuzzy-labelled)
;    35  Window / outdoor AQHI control (fuzzy-labelled)
;    30  Indoor air quality (IAQI) assessment
;    25  Low-CF sensor quality notices
;   -10  Print grouped recommendations (fires last)
;
; Fuzzy inference method:
;   Fuzzification  : FuzzyCLIPS get-fs-value on Z/PI/S primary terms
;   Rule evaluation: Mamdani min-based activation via dominant label
;   Defuzzification: crisp target-temp weighted by membership degree
; ================================================


(deffunction print-grouped ()
   "Print all msg facts grouped by date in chronological order."
   (do-for-all-facts ((?e env)) TRUE
      (bind ?d (fact-slot-value ?e date))
      (if (any-factp ((?m msg)) (eq (fact-slot-value ?m date) ?d))
          then
             (printout t crlf "=== " ?d " ===" crlf)
             (do-for-all-facts ((?m msg)) (eq (fact-slot-value ?m date) ?d)
                (printout t "  " (fact-slot-value ?m text) crlf)
             )
      )
   )
   (printout t crlf)
)


; ================================================
; CERTAINTY FACTORS — Safety Alarms  (salience 90)
;
; MYCIN CF model.
;   CF >= 0.70  → high confidence  → full emergency
;   CF  0.30-0.69 → moderate      → warning, investigate
;   CF < 0.30   → low confidence  → likely false positive
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
        "Ventilate and inspect the CO sensor for faults."
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
    "Both CO and fire alarm on: CF_combined = CF1 + CF2*(1-CF1)."
    (declare (salience 90))
    (env (date ?date) (co-alarm on) (co-alarm-cf ?cf1) (fire-alarm on) (fire-alarm-cf ?cf2))
    (not (emergency ?date))
    =>
    (bind ?combined (+ ?cf1 (* ?cf2 (- 1 ?cf1))))
    (if (>= ?combined 0.70)
        then
        (assert (emergency ?date))
        (assert (msg (date ?date) (text (str-cat
            "LIFE-THREATENING EMERGENCY: Both CO (CF=" ?cf1 ") and fire (CF=" ?cf2
            ") sensors triggered. Combined CF=" ?combined ". Evacuate immediately."
        ))))
        else
        (assert (msg (date ?date) (text (str-cat
            "WARNING: Both CO and fire sensors triggered. Combined CF=" ?combined
            ". Investigate immediately even though confidence is below 0.70."
        ))))
    )
)


; ================================================
; FUZZIFICATION  (salience 80)
;
; For each env fact, computes membership degrees for
; every primary term in fz-temp, fz-humidity, fz-aqhi
; using the FuzzyCLIPS function:
;
;   (get-fs-value ?fact-address crisp-value)
;
; The sequential assert → get-fs-value → retract pattern
; is used for each term to avoid FuzzyCLIPS global
; contribution (union) interference between terms.
;
; Results are stored in a regular (non-fuzzy) fuzzy-env
; fact keyed by date so all downstream rules have per-day
; membership data available without fuzzy fact conflicts.
; ================================================

(defrule fuzzify-env
    "Fuzzify crisp sensor readings into FuzzyCLIPS membership degrees.
     Fires once per env fact; populates fuzzy-env for that date."
    (declare (salience 80))
    (env (date ?date) (temp ?t) (humidity ?h) (AQHI ?a))
    (not (fuzzy-env (date ?date)))
    =>
    (bind ?ft (float ?t))
    (bind ?fh (float ?h))
    (bind ?fa (float ?a))

    ; --- indoor temperature fuzzification ---
    ; Each term is asserted, queried via get-fs-value, then retracted
    ; to prevent global-contribution unions between different terms.
    (bind ?f (assert (fz-temp cold)))
    (bind ?mu-cold  (get-fs-value ?f ?ft))
    (retract ?f)

    (bind ?f (assert (fz-temp cool)))
    (bind ?mu-cool  (get-fs-value ?f ?ft))
    (retract ?f)

    (bind ?f (assert (fz-temp comfortable)))
    (bind ?mu-comf  (get-fs-value ?f ?ft))
    (retract ?f)

    (bind ?f (assert (fz-temp warm)))
    (bind ?mu-warm  (get-fs-value ?f ?ft))
    (retract ?f)

    (bind ?f (assert (fz-temp hot)))
    (bind ?mu-hot   (get-fs-value ?f ?ft))
    (retract ?f)

    ; dominant temperature label (argmax)
    (bind ?temp-label "comfortable")
    (bind ?max-mu     ?mu-comf)
    (if (> ?mu-cold ?max-mu) then (bind ?temp-label "cold") (bind ?max-mu ?mu-cold))
    (if (> ?mu-cool ?max-mu) then (bind ?temp-label "cool") (bind ?max-mu ?mu-cool))
    (if (> ?mu-warm ?max-mu) then (bind ?temp-label "warm") (bind ?max-mu ?mu-warm))
    (if (> ?mu-hot  ?max-mu) then (bind ?temp-label "hot")  (bind ?max-mu ?mu-hot))

    ; --- indoor humidity fuzzification ---
    (bind ?f (assert (fz-humidity dry)))
    (bind ?mu-dry   (get-fs-value ?f ?fh))
    (retract ?f)

    (bind ?f (assert (fz-humidity comfortable)))
    (bind ?mu-chum  (get-fs-value ?f ?fh))
    (retract ?f)

    (bind ?f (assert (fz-humidity humid)))
    (bind ?mu-humid (get-fs-value ?f ?fh))
    (retract ?f)

    (bind ?hum-label "comfortable")
    (bind ?max-mu    ?mu-chum)
    (if (> ?mu-dry   ?max-mu) then (bind ?hum-label "dry")   (bind ?max-mu ?mu-dry))
    (if (> ?mu-humid ?max-mu) then (bind ?hum-label "humid") (bind ?max-mu ?mu-humid))

    ; --- outdoor AQHI fuzzification ---
    (bind ?f (assert (fz-aqhi good)))
    (bind ?mu-agood (get-fs-value ?f ?fa))
    (retract ?f)

    (bind ?f (assert (fz-aqhi moderate)))
    (bind ?mu-amod  (get-fs-value ?f ?fa))
    (retract ?f)

    (bind ?f (assert (fz-aqhi poor)))
    (bind ?mu-apoor (get-fs-value ?f ?fa))
    (retract ?f)

    (bind ?aqhi-label "good")
    (bind ?max-mu     ?mu-agood)
    (if (> ?mu-amod  ?max-mu) then (bind ?aqhi-label "moderate") (bind ?max-mu ?mu-amod))
    (if (> ?mu-apoor ?max-mu) then (bind ?aqhi-label "poor")     (bind ?max-mu ?mu-apoor))

    ; store all membership degrees in fuzzy-env for this date
    (assert (fuzzy-env
        (date ?date)
        (mu-cold             ?mu-cold)
        (mu-cool             ?mu-cool)
        (mu-comfortable-temp ?mu-comf)
        (mu-warm             ?mu-warm)
        (mu-hot              ?mu-hot)
        (mu-dry              ?mu-dry)
        (mu-comfortable-hum  ?mu-chum)
        (mu-humid            ?mu-humid)
        (mu-aqhi-good        ?mu-agood)
        (mu-aqhi-moderate    ?mu-amod)
        (mu-aqhi-poor        ?mu-apoor)
        (temp-label          ?temp-label)
        (hum-label           ?hum-label)
        (aqhi-label          ?aqhi-label)
    ))
)


; ================================================
; UNCERTAIN OCCUPANCY  (salience 55)
;
; Fires between fuzzification (80) and fuzzy temp rules
; (50).  If the occupancy sensor confidence is too low to
; trust, defaults to the energy-saving 17 C target so we
; do not accidentally over-heat an empty home.
; ================================================

(defrule occupancy-uncertain-thermostat
    "Occupancy CF < 0.60 and indoor temp below 20 C: default to 17 C."
    (declare (salience 55))
    (env (date ?date) (temp ?t) (occupancy awake) (occupancy-cf ?cf) (season winter))
    (not (emergency ?date))
    (test (< ?cf 0.60))
    (test (< ?t 20))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 17))
    (assert (msg (date ?date) (text (str-cat
        "Thermostat set to energy-saving 17 C. "
        "Reason: occupancy sensor CF=" ?cf
        " is below 0.60; defaulting to away/sleep target to save energy."
    ))))
)


; ================================================
; FUZZY TEMPERATURE CONTROL  (salience 50)
;
; Mamdani-style fuzzy inference.  The dominant linguistic
; label (argmax of membership degrees stored in fuzzy-env)
; drives rule selection.  Target temperatures are chosen
; to reflect heating/cooling intensity:
;
;   WINTER
;     cold   + awake  → HEAT 21 C  (high demand)
;     cold   + sleep  → HEAT 18 C  (reduced at night)
;     cold   + gone   → HEAT 17 C  (anti-freeze setback)
;     cool   + awake  → HEAT 19 C  (moderate demand)
;     cool   + sleep/gone → HEAT 17 C
;     comfortable     → no thermostat action
;
;   SUMMER
;     warm   + awake  → COOL 25 C  (moderate cooling)
;     hot    + awake  → COOL 23 C  (high cooling)
;     comfortable/below + gone → thermostat OFF (energy saving)
; ================================================

; --- WINTER / COLD + AWAKE ---
(defrule fuzzy-heat-cold-awake
    "Indoor temp = COLD, occupant awake, winter: heat to 21 C."
    (declare (salience 50))
    (fuzzy-env (date ?date) (mu-cold ?mc) (temp-label "cold"))
    (env (date ?date) (temp ?t) (occupancy awake) (season winter))
    (not (emergency ?date))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 21))
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: " ?t "C -> cold (mu=" (format nil "%.2f" ?mc)
        "). Thermostat -> HEAT 21 C [Mamdani: high heating demand]."
    ))))
)

; --- WINTER / COLD + SLEEP ---
(defrule fuzzy-heat-cold-sleep
    "Indoor temp = COLD, occupant sleeping, winter: heat to 18 C."
    (declare (salience 50))
    (fuzzy-env (date ?date) (mu-cold ?mc) (temp-label "cold"))
    (env (date ?date) (temp ?t) (occupancy sleep) (season winter))
    (not (emergency ?date))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 18))
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: " ?t "C -> cold (mu=" (format nil "%.2f" ?mc)
        "). Thermostat -> HEAT 18 C [Mamdani: cold + sleep mode]."
    ))))
)

; --- WINTER / COLD + GONE ---
(defrule fuzzy-heat-cold-gone
    "Indoor temp = COLD, home unoccupied, winter: anti-freeze heat to 17 C."
    (declare (salience 50))
    (fuzzy-env (date ?date) (mu-cold ?mc) (temp-label "cold"))
    (env (date ?date) (temp ?t) (occupancy gone) (season winter))
    (not (emergency ?date))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 17))
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: " ?t "C -> cold (mu=" (format nil "%.2f" ?mc)
        "). Thermostat -> HEAT 17 C [Mamdani: cold + unoccupied, anti-freeze]."
    ))))
)

; --- WINTER / COOL + AWAKE ---
(defrule fuzzy-heat-cool-awake
    "Indoor temp = COOL, occupant awake, winter: heat to 19 C."
    (declare (salience 50))
    (fuzzy-env (date ?date) (mu-cool ?ml) (temp-label "cool"))
    (env (date ?date) (temp ?t) (occupancy awake) (season winter))
    (not (emergency ?date))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 19))
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: " ?t "C -> cool (mu=" (format nil "%.2f" ?ml)
        "). Thermostat -> HEAT 19 C [Mamdani: moderate heating demand]."
    ))))
)

; --- WINTER / COOL + SLEEP OR GONE ---
(defrule fuzzy-heat-cool-sleep-gone
    "Indoor temp = COOL, sleep or gone, winter: heat to 17 C setback."
    (declare (salience 50))
    (fuzzy-env (date ?date) (mu-cool ?ml) (temp-label "cool"))
    (env (date ?date) (temp ?t) (occupancy ?occ) (season winter))
    (test (or (eq ?occ sleep) (eq ?occ gone)))
    (not (emergency ?date))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 17))
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: " ?t "C -> cool (mu=" (format nil "%.2f" ?ml)
        "), occupancy=" ?occ ". Thermostat -> HEAT 17 C [setback mode]."
    ))))
)

; --- COMFORTABLE TEMPERATURE ---
(defrule fuzzy-comfortable-temp
    "Indoor temp = COMFORTABLE: no thermostat action needed."
    (declare (salience 50))
    (fuzzy-env (date ?date) (mu-comfortable-temp ?mc) (temp-label "comfortable"))
    (env (date ?date) (temp ?t))
    (not (emergency ?date))
    (themostat (date ?date) (mode off))
    =>
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: " ?t "C -> comfortable (mu=" (format nil "%.2f" ?mc)
        "). No heating or cooling needed."
    ))))
)

; --- SUMMER / WARM + AWAKE ---
(defrule fuzzy-cool-warm-awake
    "Indoor temp = WARM, occupant awake, summer: cool to 25 C."
    (declare (salience 50))
    (fuzzy-env (date ?date) (mu-warm ?mw) (temp-label "warm"))
    (env (date ?date) (temp ?t) (occupancy awake) (season summer))
    (not (emergency ?date))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode cool) (target-temp 25))
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: " ?t "C -> warm (mu=" (format nil "%.2f" ?mw)
        "). Thermostat -> COOL 25 C [Mamdani: moderate cooling demand]."
    ))))
)

; --- SUMMER / HOT + AWAKE ---
(defrule fuzzy-cool-hot-awake
    "Indoor temp = HOT, occupant awake, summer: cool to 23 C."
    (declare (salience 50))
    (fuzzy-env (date ?date) (mu-hot ?mh) (temp-label "hot"))
    (env (date ?date) (temp ?t) (occupancy awake) (season summer))
    (not (emergency ?date))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode cool) (target-temp 23))
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: " ?t "C -> hot (mu=" (format nil "%.2f" ?mh)
        "). Thermostat -> COOL 23 C [Mamdani: high cooling demand]."
    ))))
)

; --- SUMMER / UNOCCUPIED within comfortable range ---
(defrule fuzzy-thermostat-off-gone-summer
    "Unoccupied home + comfortable/cool/cold temp in summer: thermostat stays OFF."
    (declare (salience 50))
    (fuzzy-env (date ?date) (temp-label ?lbl))
    (test (or (eq ?lbl "comfortable") (eq ?lbl "cool") (eq ?lbl "cold")))
    (env (date ?date) (temp ?t) (occupancy gone) (season summer))
    (not (emergency ?date))
    (themostat (date ?date) (mode off))
    =>
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: Home unoccupied, " ?t "C (" ?lbl
        "). Thermostat stays OFF [energy saving]."
    ))))
)


; ================================================
; HUMIDITY CONTROL  (salience 40)
;
; Uses the dominant fuzzy label from fuzzy-env to drive
; humidifier/dehumidifier decisions and include membership
; degree context in the explanation messages.
; Source: Health Canada Healthy Home Guide (30-50 % target)
; ================================================

(defrule humidify
    "Humidity dominant label = dry: turn on humidifier."
    (declare (salience 40))
    (env (date ?date) (humidity ?h))
    (fuzzy-env (date ?date) (mu-dry ?md) (hum-label "dry"))
    (not (emergency ?date))
    ?d <- (device (date ?date) (name humidifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: Humidity " ?h "% -> dry (mu=" (format nil "%.2f" ?md)
        "). Humidifier ON — low humidity aggravates respiratory issues."
    ))))
)

(defrule dehumidify
    "Humidity dominant label = humid: turn on dehumidifier."
    (declare (salience 40))
    (env (date ?date) (humidity ?h))
    (fuzzy-env (date ?date) (mu-humid ?mh) (hum-label "humid"))
    (not (emergency ?date))
    ?d <- (device (date ?date) (name dehumidifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: Humidity " ?h "% -> humid (mu=" (format nil "%.2f" ?mh)
        "). Dehumidifier ON — high humidity promotes mould growth."
    ))))
)

(defrule humidity-comfortable
    "Humidity dominant label = comfortable: no device action needed."
    (declare (salience 40))
    (env (date ?date) (humidity ?h))
    (fuzzy-env (date ?date) (mu-comfortable-hum ?mc) (hum-label "comfortable"))
    (not (emergency ?date))
    =>
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: Humidity " ?h "% -> comfortable (mu=" (format nil "%.2f" ?mc)
        "). No humidity control needed."
    ))))
)


; ================================================
; WINDOW / OUTDOOR AQHI  (salience 35)
;
; Uses fuzzy AQHI label from fuzzy-env to decide whether
; to keep windows closed and to include context in messages.
; Source: Health Canada — close windows when AQHI > 6.
; ================================================

(defrule close-window-poor-outdoor-air
    "AQHI dominant label = poor: window should remain closed."
    (declare (salience 35))
    (env (date ?date) (AQHI ?a))
    (fuzzy-env (date ?date) (mu-aqhi-poor ?mp) (aqhi-label "poor"))
    (not (emergency ?date))
    (device (date ?date) (name window) (status off))
    =>
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: Outdoor AQHI " ?a " -> poor (mu=" (format nil "%.2f" ?mp)
        "). Window stays CLOSED — block outdoor pollutants."
    ))))
)

(defrule good-outdoor-air
    "AQHI dominant label = good or moderate: outdoor air is acceptable."
    (declare (salience 35))
    (env (date ?date) (AQHI ?a))
    (fuzzy-env (date ?date) (mu-aqhi-good ?mg) (aqhi-label ?lbl))
    (test (or (eq ?lbl "good") (eq ?lbl "moderate")))
    (not (emergency ?date))
    (device (date ?date) (name window) (status off))
    =>
    (assert (msg (date ?date) (text (str-cat
        "FUZZY: Outdoor AQHI " ?a " -> " ?lbl " (mu_good=" (format nil "%.2f" ?mg)
        "). Outdoor air quality acceptable."
    ))))
)


; ================================================
; INDOOR AIR QUALITY — IAQI  (salience 30)
; Atmotube scale: 0-100, higher = cleaner air.
; ================================================

(defrule iaqi-good
    "IAQI 81-100: indoor air quality is optimal."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i))
    (not (emergency ?date))
    (test (>= ?i 81))
    =>
    (assert (msg (date ?date) (text (str-cat
        "Indoor air quality: Good (IAQI " ?i "). No action needed."
    ))))
)

(defrule iaqi-moderate
    "IAQI 61-80: acceptable air quality."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i))
    (not (emergency ?date))
    (test (and (>= ?i 61) (< ?i 81)))
    =>
    (assert (msg (date ?date) (text (str-cat
        "Indoor air quality: Moderate (IAQI " ?i "). Acceptable, no action needed."
    ))))
)

(defrule iaqi-polluted
    "IAQI 41-60: poor air quality — air purifier on."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i))
    (not (emergency ?date))
    (test (and (>= ?i 41) (< ?i 61)))
    ?d <- (device (date ?date) (name air-purifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "Air purifier ON. Reason: indoor IAQI " ?i " is poor (41-60)."
    ))))
)

(defrule iaqi-very-polluted
    "IAQI 21-40: serious air quality issues — air purifier on."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i))
    (not (emergency ?date))
    (test (and (>= ?i 21) (< ?i 41)))
    ?d <- (device (date ?date) (name air-purifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "Air purifier ON. Reason: indoor IAQI " ?i " is very polluted (21-40)."
    ))))
)

(defrule iaqi-severely-polluted
    "IAQI 0-20: critical air quality — air purifier on, urgent."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i))
    (not (emergency ?date))
    (test (< ?i 21))
    ?d <- (device (date ?date) (name air-purifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "Air purifier ON. URGENT: indoor IAQI " ?i " is severely polluted (0-20)."
    ))))
)

(defrule both-air-quality-poor
    "Both indoor IAQI < 61 and outdoor AQHI > 6: air purifier on, keep windows closed."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i) (AQHI ?a))
    (not (emergency ?date))
    (test (< ?i 61))
    (test (> ?a 6))
    ?d <- (device (date ?date) (name air-purifier) (status off))
    (not (air-purifier-recommended ?date))
    =>
    (assert (air-purifier-recommended ?date))
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "Air purifier ON. Both indoor IAQI " ?i
        " and outdoor AQHI " ?a " are poor. Keep windows closed."
    ))))
)


; ================================================
; LOW-CF SENSOR QUALITY NOTICES  (salience 25)
; ================================================

(defrule iaqi-uncertain-reading
    "IAQI sensor CF below 0.60: qualify the air quality recommendation."
    (declare (salience 25))
    (env (date ?date) (IAQI ?i) (iaqi-cf ?cf))
    (not (emergency ?date))
    (test (< ?cf 0.60))
    =>
    (assert (msg (date ?date) (text (str-cat
        "NOTE: Indoor IAQI reading of " ?i " has low sensor confidence (CF=" ?cf
        "). Consider recalibrating the air quality sensor before acting."
    ))))
)

(defrule aqhi-uncertain-reading
    "AQHI CF below 0.60: qualify the outdoor air quality advisory."
    (declare (salience 25))
    (env (date ?date) (AQHI ?a) (aqhi-cf ?cf))
    (not (emergency ?date))
    (test (< ?cf 0.60))
    =>
    (assert (msg (date ?date) (text (str-cat
        "NOTE: Outdoor AQHI reading of " ?a " has low confidence (CF=" ?cf
        "). Nearest monitoring station may be far away. Treat window advice as advisory."
    ))))
)


; ================================================
; PRINT GROUPED OUTPUT  (salience -10, fires last)
; ================================================

(defrule print-all-grouped
    "After all rules have fired, print every recommendation grouped by date."
    (declare (salience -10))
    =>
    (print-grouped)
)
