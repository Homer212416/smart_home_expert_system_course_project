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

(defrule cool-awake
    "Thermostat cool 25C: home occupied and awake, indoor temp exceeds 25 C. Summer only."
    (declare (salience 60))
    (env (date ?date) (temp ?t) (occupancy awake) (season summer))
    (not (emergency ?date))
    (test (> ?t 25))
    ?th <- (themostat (date ?date) (mode off))
    =>
    (modify ?th (mode cool) (target-temp 25))
    (assert (msg (date ?date) (text (str-cat
        "The system has set the thermostat to COOL mode with 25C target. Reason: indoor temperature " ?t
        "C exceeds the 25.5C occupied comfort limit."
    ))))
)

(defrule cool-gone
    "Thermostat cool 28C: home unoccupied, indoor temp above 28 C. Summer only."
    (declare (salience 60))
    (env (date ?date) (temp ?t) (occupancy gone) (season summer))
    (not (emergency ?date))
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
    (not (air-purifier-recommended))
    =>
    (assert (air-purifier-recommended))
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
