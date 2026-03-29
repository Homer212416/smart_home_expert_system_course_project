; ================================================
; Smart Home Expert System - Rules
;
; Load order:
;   (load "templates.clp")
;   (load "rules.clp")
;   (load "facts.clp")
;   (reset)
;   (run)
;
; D2 list
; Salience levels:
;   100  Carbon monoxide / fire safety (D1, certain knowledge) [old rules, will be removed/commented]
;    90  Certainty Factors — probabilistic uncertainty (D2 TODO 2)
;    80  Fuzzy Logic — fuzzification (D2 TODO 3)
;    60  Temperature control (D1)
;    50  Fuzzy Logic — inference and defuzzification (D2 TODO 3)
;    40  Humidity control (D1)
;    35  Window / outdoor AQHI control (D1)
;    30  Indoor air quality IAQI assessment (D1)
;    25  CF uncertainty notices (D2 TODO 2)
;   -10  Print grouped recommendations (fires last)
;
; msg convention:
;   Every (assert (msg ...)) carries a (date ...) slot so the final
;   print function can group all recommendations by date.
;   Rules without a specific date use (date "general").
; ================================================

; D2
; The old co-emergency and fire-emergency.D1 rules have been disabled:
; co-emergency
; fire-emergency
; These rules would trigger an emergency immediately whenever they detected alarm = on.
; However, the CF version in D2 will classify events based on `co-alarm-cf` and `fire-alarm-cf` as follows:
; high confidence → full emergency
; moderate confidence → warning
; low confidence → likely false positive
; Therefore, these two old rules cannot coexist with the new CF safety rules, otherwise they would trigger simultaneously.

; ================================================
; Smart Home Expert System - Rules
;
; Load order:
;   (load "templates.clp")
;   (load "rules.clp")
;   (load "facts.clp")
;   (reset)
;   (run)
;
; Salience levels:
;   90   Certainty Factors — probabilistic uncertainty (D2 TODO 2)
;   80   Fuzzy Logic — fuzzification (D2 TODO 3)
;   60   Temperature control (D1)
;   50   Fuzzy Logic — inference and defuzzification (D2 TODO 3)
;   40   Humidity control
;   35   Window / outdoor AQHI control
;   30   Indoor air quality (IAQI) per-day assessment
;   25   CF uncertainty notices (D2 TODO 2)
;   -10  Print grouped recommendations (fires last)
;
; msg convention:
;   Every (assert (msg ...)) carries a (date ...) slot so the final
;   print function can group all recommendations by date.
;   Rules without a specific date use (date "general").
; ================================================


(deffunction print-grouped ()
   "Print all msg facts grouped by date in chronological order.
    Iterates env facts (loaded oldest-first by deffacts) to drive ordering."

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

; TODO3
; ================================================
; FUZZY MEMBERSHIP FUNCTIONS
; ================================================

(deffunction mu-trapezoid (?x ?a ?b ?c ?d)
    "Trapezoidal membership function.
     For left-open sets use a=b=-999.
     For right-open sets use c=d=999."
    (if (<= ?x ?a) then
        (return 0.0))

    (if (and (> ?x ?a) (< ?x ?b)) then
        (return (/ (- ?x ?a) (- ?b ?a))))

    (if (and (>= ?x ?b) (<= ?x ?c)) then
        (return 1.0))

    (if (and (> ?x ?c) (< ?x ?d)) then
        (return (/ (- ?d ?x) (- ?d ?c))))

    (return 0.0)
)


; ================================================
; CERTAINTY FACTORS - Probabilistic Uncertainty  (salience 90 / 25)
; Based on MYCIN Certainty Factors Theory.
; CF thresholds:
;   CF >= 0.70           high confidence      -> full emergency/action
;   0.30 <= CF < 0.70   moderate confidence  -> warning / cautious action
;   CF < 0.30           low confidence       -> likely false positive
; ================================================

(defrule co-high-cf
    "CO alarm on and high certainty: full emergency."
    (declare (salience 90))
    (env (date ?date) (co-alarm on) (co-alarm-cf ?cf))
    (test (>= ?cf 0.70))
    (not (emergency ?date))
    =>
    (assert (emergency ?date))
    (assert (msg (date ?date) (text (str-cat
        "[D2] EMERGENCY (CF=" ?cf "): Carbon monoxide detected with high confidence. "
        "Evacuate immediately and call 911."
    ))))
)

(defrule co-moderate-cf
    "CO alarm on and moderate certainty: investigate."
    (declare (salience 90))
    (env (date ?date) (co-alarm on) (co-alarm-cf ?cf))
    (test (and (>= ?cf 0.30) (< ?cf 0.70)))
    (not (emergency ?date))
    =>
    (assert (msg (date ?date) (text (str-cat
        "[D2] WARNING (CF=" ?cf "): CO sensor triggered with moderate confidence. "
        "Ventilate the home and inspect the sensor before taking further action."
    ))))
)

(defrule co-low-cf
    "CO alarm on but low certainty: likely false positive."
    (declare (salience 90))
    (env (date ?date) (co-alarm on) (co-alarm-cf ?cf))
    (test (< ?cf 0.30))
    (not (emergency ?date))
    =>
    (assert (msg (date ?date) (text (str-cat
        "[D2] NOTICE (CF=" ?cf "): CO sensor triggered with very low confidence. "
        "Likely a false positive. Check battery and calibration."
    ))))
)

(defrule fire-high-cf
    "Fire alarm on and high certainty: full emergency."
    (declare (salience 90))
    (env (date ?date) (fire-alarm on) (fire-alarm-cf ?cf))
    (test (>= ?cf 0.70))
    (not (emergency ?date))
    =>
    (assert (emergency ?date))
    (assert (msg (date ?date) (text (str-cat
        "[D2] EMERGENCY (CF=" ?cf "): Fire/smoke detected with high confidence. "
        "Evacuate immediately and call 911."
    ))))
)

(defrule fire-moderate-cf
    "Fire alarm on and moderate certainty: investigate."
    (declare (salience 90))
    (env (date ?date) (fire-alarm on) (fire-alarm-cf ?cf))
    (test (and (>= ?cf 0.30) (< ?cf 0.70)))
    (not (emergency ?date))
    =>
    (assert (msg (date ?date) (text (str-cat
        "[D2] WARNING (CF=" ?cf "): Smoke/fire sensor triggered with moderate confidence. "
        "Check for actual smoke or cooking fumes first."
    ))))
)

(defrule fire-low-cf
    "Fire alarm on but low certainty: likely false positive."
    (declare (salience 90))
    (env (date ?date) (fire-alarm on) (fire-alarm-cf ?cf))
    (test (< ?cf 0.30))
    (not (emergency ?date))
    =>
    (assert (msg (date ?date) (text (str-cat
        "[D2] NOTICE (CF=" ?cf "): Smoke/fire sensor triggered with very low confidence. "
        "Likely a false positive. Inspect the sensor."
    ))))
)

(defrule co-and-fire-combined-cf
    "Both alarms on: combine CFs using CFcombined = CF1 + CF2*(1-CF1)."
    (declare (salience 90))
    (env (date ?date)
         (co-alarm on) (co-alarm-cf ?cf1)
         (fire-alarm on) (fire-alarm-cf ?cf2))
    (not (emergency ?date))
    =>
    (bind ?combined (+ ?cf1 (* ?cf2 (- 1 ?cf1))))
    (if (>= ?combined 0.70)
        then
        (assert (emergency ?date))
        (assert (msg (date ?date) (text (str-cat
            "[D2] EMERGENCY: Both CO (CF=" ?cf1 ") and fire (CF=" ?cf2
            ") sensors triggered. Combined CF=" ?combined
            ". Evacuate immediately."
        ))))
        else
        (assert (msg (date ?date) (text (str-cat
            "[D2] WARNING: Both CO and fire sensors triggered. Combined CF="
            ?combined ". Investigate immediately."
        ))))
    )
)

(defrule occupancy-uncertain-thermostat
    "If occupancy confidence is low, use conservative energy-saving heat target."
    (declare (salience 55))
    (env (date ?date) (occupancy awake) (occupancy-cf ?cf) (season winter))
    (not (emergency ?date))
    (test (< ?cf 0.60))
    ?th <- (thermostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 17))
    (assert (msg (date ?date) (text (str-cat
        "[D2] Thermostat set to HEAT 17C. Reason: occupancy sensor confidence CF="
        ?cf " is low, so the system defaults to an energy-saving target."
    ))))
)

(defrule iaqi-uncertain-reading
    "Low IAQI confidence: qualify the recommendation."
    (declare (salience 25))
    (env (date ?date) (IAQI ?i) (iaqi-cf ?cf))
    (not (emergency ?date))
    (test (< ?cf 0.60))
    =>
    (assert (msg (date ?date) (text (str-cat
        "[D2] NOTE: indoor IAQI reading " ?i " has low confidence (CF="
        ?cf "). Recalibrate or verify the air quality sensor."
    ))))
)

(defrule aqhi-uncertain-reading
    "Low AQHI confidence: qualify the recommendation."
    (declare (salience 25))
    (env (date ?date) (AQHI ?a) (aqhi-cf ?cf))
    (not (emergency ?date))
    (test (< ?cf 0.60))
    =>
    (assert (msg (date ?date) (text (str-cat
        "[D2] NOTE: outdoor AQHI reading " ?a " has low confidence (CF="
        ?cf "). Treat window advice as advisory."
    ))))
)

; TODO3
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
    ; cold: left-open, full membership up to 14, then down to 0 at 18
    (bind ?cold (mu-trapezoid ?t -999 -999 14 18))
    ; cool: [14,18,20,22]
    (bind ?cool (mu-trapezoid ?t 14 18 20 22))
    ; comfortable: [20,21,23,24]
    (bind ?comfortable (mu-trapezoid ?t 20 21 23 24))
    ; warm: [23,25,27,29]
    (bind ?warm (mu-trapezoid ?t 23 25 27 29))
    ; hot: right-open, starts rising at 27, full by 30
    (bind ?hot (mu-trapezoid ?t 27 30 999 999))

    (modify ?fe
        (mu-temp-cold ?cold)
        (mu-temp-cool ?cool)
        (mu-temp-comfortable ?comfortable)
        (mu-temp-warm ?warm)
        (mu-temp-hot ?hot))
)

(defrule fuzzify-humidity
    "Compute fuzzy humidity membership degrees and store in fuzzy-env."
    (declare (salience 80))
    (env (date ?date) (humidity ?h))
    ?fe <- (fuzzy-env (date ?date))
    =>
    ; dry: left-open, full up to 25, down to 0 at 35
    (bind ?dry (mu-trapezoid ?h -999 -999 25 35))
    ; comfortable: [30,40,50,60]
    (bind ?comfy (mu-trapezoid ?h 30 40 50 60))
    ; humid: right-open, rises at 55, full by 65
    (bind ?humid (mu-trapezoid ?h 55 65 999 999))

    (modify ?fe
        (mu-hum-dry ?dry)
        (mu-hum-comfortable ?comfy)
        (mu-hum-humid ?humid))
)

(defrule fuzzify-aqhi
    "Compute fuzzy AQHI membership degrees and store in fuzzy-env."
    (declare (salience 80))
    (env (date ?date) (AQHI ?a))
    ?fe <- (fuzzy-env (date ?date))
    =>
    ; good: left-open, full up to 3, down to 0 at 5
    (bind ?good (mu-trapezoid ?a -999 -999 3 5))
    ; moderate: [4,5,6,7]
    (bind ?moderate (mu-trapezoid ?a 4 5 6 7))
    ; poor: right-open, rises at 6, full by 8
    (bind ?poor (mu-trapezoid ?a 6 8 999 999))

    (modify ?fe
        (mu-aqhi-good ?good)
        (mu-aqhi-moderate ?moderate)
        (mu-aqhi-poor ?poor))
)

; ================================================
; FUZZY LOGIC — Inference / Defuzzification
; Uses fuzzy memberships to produce smoother decisions.
; ================================================

(defrule fuzzy-defuzzify-thermostat
    "Winter occupied heating: compute fuzzy target temperature from temperature memberships."
    (declare (salience 65))
    (env (date ?date) (occupancy awake) (season winter))
    ?fe <- (fuzzy-env (date ?date)
                      (mu-temp-cold ?mc)
                      (mu-temp-cool ?mco)
                      (mu-temp-comfortable ?mcomf))
    (not (emergency ?date))
    ?th <- (thermostat (date ?date) (mode off))
    =>
    ; Output mapping:
    ; cold -> 21C
    ; cool -> 19C
    ; comfortable -> 18C
    (bind ?numerator (+ (* ?mc 21.0) (* ?mco 19.0) (* ?mcomf 18.0)))
    (bind ?denominator (+ ?mc ?mco ?mcomf))

    (if (> ?denominator 0.0)
        then
        (bind ?target (/ ?numerator ?denominator))
        (modify ?fe (fuzzy-target-temp ?target))
        (modify ?th (mode heat) (target-temp (integer (round ?target))))
        (assert (msg (date ?date) (text (str-cat
            "[D2] Fuzzy defuzzification: thermostat set to HEAT "
            (integer (round ?target)) "C "
            "(cold=" ?mc ", cool=" ?mco ", comfortable=" ?mcomf ")."
        ))))
    )
)

(defrule fuzzy-heat-strong-msg
    "Explain cold membership contribution."
    (declare (salience 64))
    (env (date ?date) (occupancy awake) (season winter))
    (fuzzy-env (date ?date) (mu-temp-cold ?mu-cold))
    (not (emergency ?date))
    (test (> ?mu-cold 0.0))
    =>
    (assert (msg (date ?date) (text (str-cat
        "[D2] Fuzzy inference: temperature membership in 'cold' = "
        ?mu-cold ". Strong heating contribution applied."
    ))))
)

(defrule fuzzy-heat-moderate-msg
    "Explain cool membership contribution."
    (declare (salience 64))
    (env (date ?date) (occupancy awake) (season winter))
    (fuzzy-env (date ?date) (mu-temp-cool ?mu-cool))
    (not (emergency ?date))
    (test (> ?mu-cool 0.0))
    =>
    (assert (msg (date ?date) (text (str-cat
        "[D2] Fuzzy inference: temperature membership in 'cool' = "
        ?mu-cool ". Moderate heating contribution applied."
    ))))
)

(defrule fuzzy-humidifier-strong
    "If humidity is strongly dry, turn on humidifier."
    (declare (salience 50))
    (env (date ?date))
    (fuzzy-env (date ?date) (mu-hum-dry ?mu-dry))
    (not (emergency ?date))
    (test (> ?mu-dry 0.5))
    ?d <- (device (date ?date) (name humidifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "[D2] Fuzzy humidity control: dry membership = " ?mu-dry
        " (> 0.5). Humidifier turned ON."
    ))))
)

(defrule fuzzy-humidifier-mild
    "If humidity is mildly dry, turn on humidifier."
    (declare (salience 50))
    (env (date ?date))
    (fuzzy-env (date ?date) (mu-hum-dry ?mu-dry))
    (not (emergency ?date))
    (test (and (> ?mu-dry 0.0) (<= ?mu-dry 0.5)))
    ?d <- (device (date ?date) (name humidifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "[D2] Fuzzy humidity control: dry membership = " ?mu-dry
        " (<= 0.5). Humidifier turned ON with mild need."
    ))))
)

(defrule fuzzy-dehumidifier
    "If humidity is humid, turn on dehumidifier."
    (declare (salience 50))
    (env (date ?date))
    (fuzzy-env (date ?date) (mu-hum-humid ?mu-humid))
    (not (emergency ?date))
    (test (> ?mu-humid 0.0))
    ?d <- (device (date ?date) (name dehumidifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "[D2] Fuzzy humidity control: humid membership = " ?mu-humid
        ". Dehumidifier turned ON."
    ))))
)

(defrule fuzzy-window-poor-aqhi
    "If AQHI is poor, give strong window warning."
    (declare (salience 50))
    (env (date ?date))
    (fuzzy-env (date ?date) (mu-aqhi-poor ?mu-poor))
    (not (emergency ?date))
    (test (> ?mu-poor 0.5))
    =>
    (assert (msg (date ?date) (text (str-cat
        "[D2] Fuzzy air quality: AQHI poor membership = " ?mu-poor
        ". Outdoor air is clearly poor; keep windows closed."
    ))))
)

(defrule fuzzy-window-moderate-aqhi
    "If AQHI is moderate, give advisory."
    (declare (salience 50))
    (env (date ?date))
    (fuzzy-env (date ?date) (mu-aqhi-moderate ?mu-mod))
    (not (emergency ?date))
    (test (> ?mu-mod 0.3))
    =>
    (assert (msg (date ?date) (text (str-cat
        "[D2] Fuzzy air quality advisory: AQHI moderate membership = " ?mu-mod
        ". Consider limiting ventilation."
    ))))
)

; ================================================
; TEMPERATURE CONTROL - Heating  (salience 60)
; Source: Natural Resources Canada heating guidelines
; Thermostat set to heat mode with appropriate target.
; ================================================

(defrule heat-awake
    "Thermostat heat 20C: home occupied and awake, indoor temp below 20 C. Winter only."
    (declare (salience 60))
    (env (date ?date) (temp ?t) (occupancy awake) (season winter))
    (not (emergency ?date))
    (test (< ?t 20))
    ?th <- (thermostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 20))
    (assert (msg (date ?date) (text (str-cat
        "The system has set the thermostat to HEAT mode with 20C target. Reason: indoor temperature " ?t
        "C is below the 20C comfort target for an occupied home."
    ))))
)

(defrule heat-sleep
    "Thermostat heat 17C: occupant sleeping, indoor temp below 17 C. Winter only."
    (declare (salience 60))
    (env (date ?date) (temp ?t) (occupancy sleep) (season winter))
    (not (emergency ?date))
    (test (< ?t 17))
    ?th <- (thermostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 17))
    (assert (msg (date ?date) (text (str-cat
        "The system has set the thermostat to HEAT mode with 17C target. Reason: indoor temperature " ?t
        "C is below the 17C sleep target."
    ))))
)

(defrule heat-gone
    "Thermostat heat 17C: home unoccupied, indoor temp below 17 C. Winter only."
    (declare (salience 60))
    (env (date ?date) (temp ?t) (occupancy gone) (season winter))
    (not (emergency ?date))
    (test (< ?t 17))
    ?th <- (thermostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 17))
    (assert (msg (date ?date) (text (str-cat
        "The system has set the thermostat to HEAT mode with 17C target. Reason: indoor temperature " ?t
        "C is below the 17C away-from-home target."
    ))))
)


; ================================================
; TEMPERATURE CONTROL - Cooling  (salience 60)
; Source: Natural Resources Canada cooling guidelines
; Thermostat set to cool mode with appropriate target.
; ================================================

(defrule cool-awake
    "Thermostat cool 25C: home occupied and awake, indoor temp exceeds 25 C. Summer only."
    (declare (salience 60))
    (env (date ?date) (temp ?t) (occupancy awake) (season summer))
    (not (emergency ?date))
    (test (> ?t 25))
    ?th <- (thermostat (date ?date) (mode off))
    =>
    (modify ?th (mode cool) (target-temp 25))
    (assert (msg (date ?date) (text (str-cat
        "The system has set the thermostat to COOL mode with 25C target. Reason: indoor temperature " ?t
        "C exceeds the 25C occupied comfort limit."
    ))))
)

(defrule cool-gone
    "Thermostat cool 28C: home unoccupied, indoor temp above 28 C. Summer only."
    (declare (salience 60))
    (env (date ?date) (temp ?t) (occupancy gone) (season summer))
    (not (emergency ?date))
    (test (> ?t 28))
    ?th <- (thermostat (date ?date) (mode off))
    =>
    (modify ?th (mode cool) (target-temp 28))
    (assert (msg (date ?date) (text (str-cat
        "The system has set the thermostat to COOL mode with 28C target. Reason: indoor temperature " ?t
        "C exceeds the 28C unoccupied energy-saving limit."
    ))))
)

(defrule thermostat-off-gone
    "Thermostat off: home unoccupied and indoor temp within the 28 C limit. Summer only."
    (declare (salience 60))
    (env (date ?date) (temp ?t) (occupancy gone) (season summer))
    (not (emergency ?date))
    (test (<= ?t 28))
    (thermostat (date ?date) (mode off))
    =>
    (assert (msg (date ?date) (text (str-cat
        "The system has turned the thermostat OFF. Reason: home is unoccupied and indoor temperature " ?t
        "C is within the 28C energy-saving limit."
    ))))
)


; ================================================
; HUMIDITY CONTROL  (salience 40)
; Source: Health Canada Healthy Home Guide (30-50% target)
; ================================================

(defrule humidify
    "Humidifier on: indoor humidity below 30%."
    (declare (salience 40))
    (env (date ?date) (humidity ?h))
    (not (emergency ?date))
    (test (< ?h 30))
    ?d <- (device (date ?date) (name humidifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "The system has turned on the humidifier. Reason: indoor humidity " ?h
        "% is below 30%. Low humidity may aggravate skin allergies and respiratory infections."
    ))))
)

(defrule dehumidify
    "Dehumidifier on: indoor humidity above 50%."
    (declare (salience 40))
    (env (date ?date) (humidity ?h))
    (not (emergency ?date))
    (test (> ?h 50))
    ?d <- (device (date ?date) (name dehumidifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "The system has turned on the dehumidifier. Reason: indoor humidity " ?h
        "% exceeds 50%. High humidity promotes mould growth."
    ))))
)

(defrule humidity-comfortable
    "Humidity within the comfortable 30-50% range. Fires once per matching day."
    (declare (salience 40))
    (env (date ?date) (humidity ?h))
    (not (emergency ?date))
    (test (and (>= ?h 30) (<= ?h 50)))
    =>
    (assert (msg (date ?date) (text (str-cat
        "Humidity " ?h "% is in the comfortable range (30-50%). No action needed."
    ))))
)


; ================================================
; WINDOW / OUTDOOR AIR QUALITY  (salience 35)
; Source: Health Canada - close windows when AQHI > 6
; Window decisions are based solely on outdoor AQHI.
; ================================================

(defrule close-window-bad-outdoor-air
    "Close windows when outdoor AQHI exceeds 6."
    (declare (salience 35))
    (env (date ?date) (AQHI ?a))
    (not (emergency ?date))
    (test (> ?a 6))
    (device (date ?date) (name window) (status off))
    =>
    (assert (msg (date ?date) (text (str-cat
        "The system has closed the window. Reason: outdoor AQHI " ?a
        " exceeds 6. Keep windows sealed to block outdoor pollutants."
    ))))
)

(defrule good-outdoor-air
    "AQHI <= 6. No action needed."
    (declare (salience 35))
    (env (date ?date) (AQHI ?a))
    (not (emergency ?date))
    (test (<= ?a 6))
    ?d <- (device (date ?date) (name window) (status off))
    =>
    (assert (msg (date ?date) (text (str-cat
        "Outdoor AQHI " ?a
        " is acceptable. No action needed."
    ))))
)


; ================================================
; INDOOR AIR QUALITY - IAQI ASSESSMENT  (salience 30)
; Fires once per env fact (one message per day).
; Atmotube scale: 0-100, higher = cleaner air.
; ================================================

(defrule iaqi-good
    "IAQI 81-100: indoor air quality is optimal. Air purifier starts off and stays off."
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
    "IAQI 61-80: acceptable but improvement recommended."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i))
    (not (emergency ?date))
    (test (and (>= ?i 61) (< ?i 81)))
    =>
    (assert (msg (date ?date) (text (str-cat
        "Indoor air quality: Moderate (IAQI " ?i "). The indoor air quality is acceptable, no action needed."
    ))))
)

(defrule iaqi-polluted
    "IAQI 41-60: poor air quality, air purifier on."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i))
    (not (emergency ?date))
    (test (and (>= ?i 41) (< ?i 61)))
    ?d <- (device (date ?date) (name air-purifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "The system has turned on the air purifier. Reason: indoor IAQI " ?i " is poor. Air purifier will help improve indoor air quality."
    ))))
)

(defrule iaqi-very-polluted
    "IAQI 21-40: serious air quality issues, air purifier on."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i))
    (not (emergency ?date))
    (test (and (>= ?i 21) (< ?i 41)))
    ?d <- (device (date ?date) (name air-purifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "The system has turned on the air purifier. Reason: indoor IAQI " ?i " is very polluted."
    ))))
)

(defrule iaqi-severely-polluted
    "IAQI 0-20: critical air quality, air purifier on, urgent intervention required."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i))
    (not (emergency ?date))
    (test (< ?i 21))
    ?d <- (device (date ?date) (name air-purifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "The system has turned on the air purifier. Reason: indoor IAQI " ?i " is severely polluted. Urgent intervention required."
    ))))
)

(defrule both-air-quality-poor
    "Air purifier on when both indoor (IAQI < 61) and outdoor (AQHI > 6)
     air quality are poor. Window closing is handled separately by close-window-bad-outdoor-air."
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
        "The system has turned on the air purifier. Reason: indoor IAQI " ?i
        " is poor and outdoor AQHI " ?a
        " exceeds 6. Keep windows closed to avoid worsening indoor air quality."
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

