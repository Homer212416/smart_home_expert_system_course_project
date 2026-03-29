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
;   100  Carbon monoxide / fire safety (emergency)
;    60  Temperature control (heating/cooling)
;    40  Humidity control
;    35  Window / outdoor AQHI control
;    30  Indoor air quality (IAQI) per-day assessment
;   -10  Print grouped recommendations (fires last)
;
; msg convention:
;   Every (assert (msg ...)) carries a (date ...) slot so the final
;   print function can group all recommendations by date.
;   Rules without a specific date use (date "general").
; ================================================

(defrule d2-info-no-major-action
    (declare (salience 5))
    (system-flag (name use-uncertain))
    (env (date ?date))
    (not (emergency ?date))
    (not (advice (date ?date) (action ?a)))
    (not (msg (date ?date) (text ?t)))
    =>
    (assert (msg (date ?date)
        (text "[D2] No major action recommended. Conditions are within acceptable range.")))
)

(defrule d2-info-purifier-instead-of-window
    (declare (salience 37))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type ventilation-beneficial) (cf ?cf))
    (device (date ?date) (name air-purifier) (status on))
    (not (advice (date ?date) (action open-window)))
    =>
    (assert (msg (date ?date) (text
        "[D2] The system keeps the window closed and relies on the air purifier instead."
    )))
)

(deffunction print-grouped ()
   "Print all msg facts grouped by date in chronological order.
    Iterates env facts (loaded oldest-first by deffacts) to drive ordering."

   ; Walk env facts in fact-index order = deffacts order = chronological
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

; for D1 and D2
(deffunction cf-and (?a ?b)
   "CF for conjunction: use the weaker support."
   (if (< ?a ?b) then ?a else ?b)
)

(deffunction cf-combine-positive (?a ?b)
   "Combine two positive certainty factors."
   (- (+ ?a ?b) (* ?a ?b))
)

; ================================================
; SAFETY ALARMS - Emergency  (salience 100)
; Fires once per env fact where the sensor is on.
; ================================================

(defrule co-emergency
    "Trigger emergency alert on any day where the CO sensor fired.
     Asserts (emergency ?date) sentinel to block all lower-salience rules for that day."
    (declare (salience 100))
    (env (date ?date) (co-alarm on))
    =>
    (assert (emergency ?date))
    (assert (msg (date ?date) (text
        "EMERGENCY: Carbon monoxide detected. Evacuate immediately and call 911. All other actions are blocked until the emergency is resolved."
    )))
)

(defrule fire-emergency
    "Trigger emergency alert on any day where the fire/smoke sensor fired.
     Asserts (emergency ?date) sentinel to block all lower-salience rules for that day."
    (declare (salience 100))
    (env (date ?date) (fire-alarm on))
    =>
    (assert (emergency ?date))
    (assert (msg (date ?date) (text
        "EMERGENCY: Fire/smoke detected. Evacuate immediately and call 911. All other actions are blocked until the emergency is resolved."
    )))
)

; add (not (system-flag (name use-uncertain))) for each rules

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

    (not (system-flag (name use-uncertain)))

    (test (< ?t 20))
    ?th <- (themostat (date ?date) (mode off))
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

    (not (system-flag (name use-uncertain)))
    
    (test (< ?t 17))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 17))
    (assert (msg (date ?date) (text (str-cat
        "The system has set the thermostat to HEAT mode with 17C target. Reason: indoor temperature " ?t
        "C is below the 17C sleep target."
    ))))
)

(defrule heat-gone
    "Thermostat heat 17C: home unoccupied, indoor temp below 17 C. Winter only.
     Domain: 17C target applies when sleeping OR away from home."
    (declare (salience 60))
    (env (date ?date) (temp ?t) (occupancy gone) (season winter))
    (not (emergency ?date))

    (not (system-flag (name use-uncertain)))

    (test (< ?t 17))
    ?th <- (themostat (date ?date) (mode off))
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

; change msg 25.5 -> 25
(defrule cool-awake
    "Thermostat cool 25C: home occupied and awake, indoor temp exceeds 25 C. Summer only."
    (declare (salience 60))
    (env (date ?date) (temp ?t) (occupancy awake) (season summer))
    (not (emergency ?date))

    (not (system-flag (name use-uncertain)))

    (test (> ?t 25))
    ?th <- (themostat (date ?date) (mode off))
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

    (not (system-flag (name use-uncertain)))

    (test (> ?t 28))
    ?th <- (themostat (date ?date) (mode off))
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

    (not (system-flag (name use-uncertain)))

    (test (<= ?t 28))
    (themostat (date ?date) (mode off))
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

    (not (system-flag (name use-uncertain)))

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

    (not (system-flag (name use-uncertain)))

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

    (not (system-flag (name use-uncertain)))

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

    (not (system-flag (name use-uncertain)))

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

    (not (system-flag (name use-uncertain)))

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

    (not (system-flag (name use-uncertain)))

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

    (not (system-flag (name use-uncertain)))

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

    (not (system-flag (name use-uncertain)))

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

    (not (system-flag (name use-uncertain)))

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

    (not (system-flag (name use-uncertain)))

    (test (< ?i 21))
    ?d <- (device (date ?date) (name air-purifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "The system has turned on the air purifier. Reason: indoor IAQI " ?i " is severely polluted. Urgent intervention required."
    ))))
)

; change (not (air-purifier-recommended)) -> (not (air-purifier-recommended ?date))
; change (assert (air-purifier-recommended)) -> (assert (air-purifier-recommended ?date))
(defrule both-air-quality-poor
    "Air purifier on when both indoor (IAQI < 61) and outdoor (AQHI > 6)
     air quality are poor. Window closing is handled separately by close-window-bad-outdoor-air."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i) (AQHI ?a))
    (not (emergency ?date))

    (not (system-flag (name use-uncertain)))

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

; add a new rule
(defrule cool-sleep
    "Thermostat cool 27C: occupant sleeping, indoor temp above 27 C. Summer only."
    (declare (salience 60))
    (env (date ?date) (temp ?t) (occupancy sleep) (season summer))
    (not (emergency ?date))

    (not (system-flag (name use-uncertain)))

    (test (> ?t 27))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode cool) (target-temp 27))
    (assert (msg (date ?date) (text (str-cat
        "The system has set the thermostat to COOL mode with 27C target. Reason: indoor temperature " ?t
        "C exceeds the 27C sleep comfort limit."
    ))))
)


; D2 =======================================================================
; run D1 use (reset) -> (run)
; run D2 use (reset) -> (assert (use-uncertain)) -> (run)

; ================================================
; D2 uncertain inference layer
; Fires only when (system-flag (name use-uncertain)) exists
; ================================================

; D2 inference layer: env -> belief

(defrule d2-infer-cold-awake
    (declare (salience 80))
    (system-flag (name use-uncertain))
    (env (date ?date) (temp ?t) (occupancy awake) (season winter))
    (not (emergency ?date))
    (test (< ?t 20))
    =>
    (assert (belief (date ?date) (type cold-room) (cf 0.85) (source "temp<20 awake winter")))
)

(defrule d2-infer-cold-sleep
    (declare (salience 80))
    (system-flag (name use-uncertain))
    (env (date ?date) (temp ?t) (occupancy sleep) (season winter))
    (not (emergency ?date))
    (test (< ?t 17))
    =>
    (assert (belief (date ?date) (type cold-room) (cf 0.80) (source "temp<17 sleep winter")))
)

(defrule d2-infer-cold-gone
    (declare (salience 80))
    (system-flag (name use-uncertain))
    (env (date ?date) (temp ?t) (occupancy gone) (season winter))
    (not (emergency ?date))
    (test (< ?t 17))
    =>
    (assert (belief (date ?date) (type cold-room) (cf 0.75) (source "temp<17 gone winter")))
)

(defrule d2-infer-hot-awake
    (declare (salience 80))
    (system-flag (name use-uncertain))
    (env (date ?date) (temp ?t) (occupancy awake) (season summer))
    (not (emergency ?date))
    (test (> ?t 25))
    =>
    (assert (belief (date ?date) (type hot-room) (cf 0.85) (source "temp>25 awake summer")))
)

(defrule d2-infer-hot-sleep
    (declare (salience 80))
    (system-flag (name use-uncertain))
    (env (date ?date) (temp ?t) (occupancy sleep) (season summer))
    (not (emergency ?date))
    (test (> ?t 27))
    =>
    (assert (belief (date ?date) (type hot-room) (cf 0.80) (source "temp>27 sleep summer")))
)

(defrule d2-infer-hot-gone
    (declare (salience 80))
    (system-flag (name use-uncertain))
    (env (date ?date) (temp ?t) (occupancy gone) (season summer))
    (not (emergency ?date))
    (test (> ?t 28))
    =>
    (assert (belief (date ?date) (type hot-room) (cf 0.75) (source "temp>28 gone summer")))
)

(defrule d2-infer-air-dry
    (declare (salience 78))
    (system-flag (name use-uncertain))
    (env (date ?date) (humidity ?h))
    (not (emergency ?date))
    (test (< ?h 30))
    =>
    (assert (belief (date ?date) (type air-too-dry) (cf 0.85) (source "humidity<30")))
)

(defrule d2-infer-air-humid
    (declare (salience 78))
    (system-flag (name use-uncertain))
    (env (date ?date) (humidity ?h))
    (not (emergency ?date))
    (test (> ?h 50))
    =>
    (assert (belief (date ?date) (type air-too-humid) (cf 0.80) (source "humidity>50")))
)

(defrule d2-infer-air-very-humid
    (declare (salience 78))
    (system-flag (name use-uncertain))
    (env (date ?date) (humidity ?h))
    (not (emergency ?date))
    (test (> ?h 70))
    =>
    (assert (belief (date ?date) (type air-too-humid) (cf 0.92) (source "humidity>70")))
)

(defrule d2-infer-indoor-air-moderate
    (declare (salience 76))
    (system-flag (name use-uncertain))
    (env (date ?date) (IAQI ?i))
    (not (emergency ?date))
    (test (and (>= ?i 61) (< ?i 81)))
    =>
    (assert (belief (date ?date) (type indoor-air-moderate) (cf 0.60) (source "61<=IAQI<81")))
)

(defrule d2-infer-indoor-air-poor
    (declare (salience 76))
    (system-flag (name use-uncertain))
    (env (date ?date) (IAQI ?i))
    (not (emergency ?date))
    (test (and (>= ?i 41) (< ?i 61)))
    =>
    (assert (belief (date ?date) (type indoor-air-poor) (cf 0.80) (source "41<=IAQI<61")))
)

(defrule d2-infer-indoor-air-very-poor
    (declare (salience 76))
    (system-flag (name use-uncertain))
    (env (date ?date) (IAQI ?i))
    (not (emergency ?date))
    (test (and (>= ?i 21) (< ?i 41)))
    =>
    (assert (belief (date ?date) (type indoor-air-poor) (cf 0.90) (source "21<=IAQI<41")))
)

(defrule d2-infer-indoor-air-severe
    (declare (salience 76))
    (system-flag (name use-uncertain))
    (env (date ?date) (IAQI ?i))
    (not (emergency ?date))
    (test (< ?i 21))
    =>
    (assert (belief (date ?date) (type indoor-air-poor) (cf 0.98) (source "IAQI<21")))
)

(defrule d2-infer-outdoor-air-good
    (declare (salience 76))
    (system-flag (name use-uncertain))
    (env (date ?date) (AQHI ?a))
    (not (emergency ?date))
    (test (<= ?a 3))
    =>
    (assert (belief (date ?date) (type outdoor-air-good) (cf 0.85) (source "AQHI<=3")))
)

(defrule d2-infer-outdoor-air-fair
    (declare (salience 76))
    (system-flag (name use-uncertain))
    (env (date ?date) (AQHI ?a))
    (not (emergency ?date))
    (test (and (> ?a 3) (<= ?a 6)))
    =>
    (assert (belief (date ?date) (type outdoor-air-good) (cf 0.60) (source "3<AQHI<=6")))
)

(defrule d2-infer-outdoor-air-poor
    (declare (salience 76))
    (system-flag (name use-uncertain))
    (env (date ?date) (AQHI ?a))
    (not (emergency ?date))
    (test (> ?a 6))
    =>
    (assert (belief (date ?date) (type outdoor-air-poor) (cf 0.90) (source "AQHI>6")))
)

; D2 higher-level belief combination

(defrule d2-infer-uncomfortable-room
    (declare (salience 70))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type hot-room) (cf ?c1))
    (belief (date ?date) (type air-too-humid) (cf ?c2))
    =>
    (bind ?cf (cf-and ?c1 ?c2))
    (assert (belief (date ?date) (type uncomfortable-room) (cf ?cf) (source "hot AND humid")))
)

(defrule d2-infer-ventilation-beneficial
    (declare (salience 70))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type indoor-air-poor) (cf ?c1))
    (belief (date ?date) (type outdoor-air-good) (cf ?c2))
    =>
    (bind ?cf (cf-and ?c1 ?c2))
    (assert (belief (date ?date) (type ventilation-beneficial) (cf ?cf) (source "indoor poor AND outdoor good")))
)

(defrule d2-infer-keep-window-closed
    (declare (salience 70))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type indoor-air-poor) (cf ?c1))
    (belief (date ?date) (type outdoor-air-poor) (cf ?c2))
    =>
    (bind ?cf (cf-and ?c1 ?c2))
    (assert (belief (date ?date) (type keep-window-closed) (cf ?cf) (source "indoor poor AND outdoor poor")))
)

(defrule d2-infer-purifier-needed
    (declare (salience 70))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type indoor-air-poor) (cf ?c1))
    =>
    (assert (belief (date ?date) (type purifier-needed) (cf ?c1) (source "indoor poor")))
)

(defrule d2-infer-purifier-stronger
    (declare (salience 70))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type indoor-air-poor) (cf ?c1))
    (belief (date ?date) (type outdoor-air-poor) (cf ?c2))
    =>
    (bind ?cf (cf-combine-positive ?c1 ?c2))
    (assert (belief (date ?date) (type purifier-needed) (cf ?cf) (source "indoor poor + outdoor poor")))
)

; D2 belief -> advice

(defrule d2-advise-heat-awake
    (declare (salience 60))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type cold-room) (cf ?cf))
    (env (date ?date) (occupancy awake) (season winter))
    (test (>= ?cf 0.75))
    =>
    (assert (advice (date ?date) (action heat-20) (cf ?cf) (reason "cold room for awake winter occupant")))
)

(defrule d2-advise-heat-sleep
    (declare (salience 60))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type cold-room) (cf ?cf))
    (env (date ?date) (occupancy sleep) (season winter))
    (test (>= ?cf 0.75))
    =>
    (assert (advice (date ?date) (action heat-17) (cf ?cf) (reason "cold room for sleep winter occupant")))
)

(defrule d2-advise-heat-gone
    (declare (salience 60))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type cold-room) (cf ?cf))
    (env (date ?date) (occupancy gone) (season winter))
    (test (>= ?cf 0.70))
    =>
    (assert (advice (date ?date) (action heat-17) (cf ?cf) (reason "cold room for away winter occupant")))
)

(defrule d2-advise-cool-awake
    (declare (salience 60))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type hot-room) (cf ?cf))
    (env (date ?date) (occupancy awake) (season summer))
    (test (>= ?cf 0.75))
    =>
    (assert (advice (date ?date) (action cool-25) (cf ?cf) (reason "hot room for awake summer occupant")))
)

(defrule d2-advise-cool-sleep
    (declare (salience 60))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type hot-room) (cf ?cf))
    (env (date ?date) (occupancy sleep) (season summer))
    (test (>= ?cf 0.75))
    =>
    (assert (advice (date ?date) (action cool-27) (cf ?cf) (reason "hot room for sleep summer occupant")))
)

(defrule d2-advise-cool-gone
    (declare (salience 60))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type hot-room) (cf ?cf))
    (env (date ?date) (occupancy gone) (season summer))
    (test (>= ?cf 0.70))
    =>
    (assert (advice (date ?date) (action cool-28) (cf ?cf) (reason "hot room for away summer occupant")))
)

(defrule d2-advise-humidify
    (declare (salience 58))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type air-too-dry) (cf ?cf))
    (test (>= ?cf 0.75))
    =>
    (assert (advice (date ?date) (action humidify) (cf ?cf) (reason "air too dry")))
)

(defrule d2-advise-dehumidify
    (declare (salience 58))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type air-too-humid) (cf ?cf))
    (test (>= ?cf 0.75))
    =>
    (assert (advice (date ?date) (action dehumidify) (cf ?cf) (reason "air too humid")))
)

(defrule d2-advise-open-window
    (declare (salience 56))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type ventilation-beneficial) (cf ?cf))
    (env (date ?date) (season ?s) (high-temp ?ht) (low-temp ?lt))
    (test (>= ?cf 0.60))
    ; only open window when weather is suitable
    (test
        (or
            (eq ?s spring)
            (eq ?s fall)
            (and (eq ?s summer) (>= ?lt 15))
            (and (eq ?s winter) (>= ?ht 10))
        )
    )
    =>
    (assert (advice
        (date ?date)
        (action open-window)
        (cf ?cf)
        (reason "ventilation beneficial and outdoor weather suitable")))
)

(defrule d2-advise-close-window
    (declare (salience 56))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type keep-window-closed) (cf ?cf))
    (test (>= ?cf 0.60))
    =>
    (assert (advice (date ?date) (action close-window) (cf ?cf) (reason "outdoor air too poor")))
)

(defrule d2-advise-purifier
    (declare (salience 56))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type purifier-needed) (cf ?cf))
    (test (>= ?cf 0.70))
    =>
    (assert (advice (date ?date) (action purify-air) (cf ?cf) (reason "indoor air quality needs improvement")))
)

(defrule d2-info-ventilation-blocked-by-weather
    (declare (salience 55))
    (system-flag (name use-uncertain))
    (belief (date ?date) (type ventilation-beneficial) (cf ?cf))
    (env (date ?date) (season ?s) (high-temp ?ht) (low-temp ?lt))
    (not (advice (date ?date) (action open-window)))
    (test (>= ?cf 0.60))
    (test
        (not
            (or
                (eq ?s spring)
                (eq ?s fall)
                (and (eq ?s summer) (>= ?lt 15))
                (and (eq ?s winter) (>= ?ht 10))
            )
        )
    )
    =>
    (assert (msg (date ?date) (text (str-cat
        "[D2] Ventilation could help indoor air, but the weather is not suitable for opening the window right now."
    ))))
)
; D2 execution layer

(defrule d2-execute-heat-20
    (declare (salience 40))
    (system-flag (name use-uncertain))
    (advice (date ?date) (action heat-20) (cf ?cf))
    (not (emergency ?date))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 20))
    (assert (msg (date ?date) (text (str-cat
        "[D2] Thermostat set to HEAT 20C (CF=" ?cf ")."
    ))))
)

(defrule d2-execute-heat-17
    (declare (salience 40))
    (system-flag (name use-uncertain))
    (advice (date ?date) (action heat-17) (cf ?cf))
    (not (emergency ?date))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode heat) (target-temp 17))
    (assert (msg (date ?date) (text (str-cat
        "[D2] Thermostat set to HEAT 17C (CF=" ?cf ")."
    ))))
)

(defrule d2-execute-cool-25
    (declare (salience 40))
    (system-flag (name use-uncertain))
    (advice (date ?date) (action cool-25) (cf ?cf))
    (not (emergency ?date))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode cool) (target-temp 25))
    (assert (msg (date ?date) (text (str-cat
        "[D2] Thermostat set to COOL 25C (CF=" ?cf ")."
    ))))
)

(defrule d2-execute-cool-27
    (declare (salience 40))
    (system-flag (name use-uncertain))
    (advice (date ?date) (action cool-27) (cf ?cf))
    (not (emergency ?date))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode cool) (target-temp 27))
    (assert (msg (date ?date) (text (str-cat
        "[D2] Thermostat set to COOL 27C (CF=" ?cf ")."
    ))))
)

(defrule d2-execute-cool-28
    (declare (salience 40))
    (system-flag (name use-uncertain))
    (advice (date ?date) (action cool-28) (cf ?cf))
    (not (emergency ?date))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode cool) (target-temp 28))
    (assert (msg (date ?date) (text (str-cat
        "[D2] Thermostat set to COOL 28C (CF=" ?cf ")."
    ))))
)

(defrule d2-execute-humidify
    (declare (salience 38))
    (system-flag (name use-uncertain))
    (advice (date ?date) (action humidify) (cf ?cf))
    (not (emergency ?date))
    ?d <- (device (date ?date) (name humidifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "[D2] Humidifier turned ON (CF=" ?cf ")."
    ))))
)

(defrule d2-execute-dehumidify
    (declare (salience 38))
    (system-flag (name use-uncertain))
    (advice (date ?date) (action dehumidify) (cf ?cf))
    (not (emergency ?date))
    ?d <- (device (date ?date) (name dehumidifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "[D2] Dehumidifier turned ON (CF=" ?cf ")."
    ))))
)

(defrule d2-execute-open-window
    (declare (salience 36))
    (system-flag (name use-uncertain))
    (advice (date ?date) (action open-window) (cf ?cf))
    (not (emergency ?date))
    ?d <- (device (date ?date) (name window) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "[D2] Window opened (CF=" ?cf "). Indoor air is poor but outdoor air is acceptable."
    ))))
)

(defrule d2-execute-close-window
    (declare (salience 36))
    (system-flag (name use-uncertain))
    (advice (date ?date) (action close-window) (cf ?cf))
    (not (emergency ?date))
    =>
    (assert (msg (date ?date) (text (str-cat
        "[D2] Keep window closed (CF=" ?cf "). Outdoor air is too poor for ventilation."
    ))))
)

(defrule d2-execute-purifier
    (declare (salience 36))
    (system-flag (name use-uncertain))
    (advice (date ?date) (action purify-air) (cf ?cf))
    (not (emergency ?date))
    ?d <- (device (date ?date) (name air-purifier) (status off))
    =>
    (modify ?d (status on))
    (assert (msg (date ?date) (text (str-cat
        "[D2] Air purifier turned ON (CF=" ?cf ")."
    ))))
)



