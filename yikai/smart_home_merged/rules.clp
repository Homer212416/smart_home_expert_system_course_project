; ================================================
; Smart Home Expert System - Rules
;
; Load order:
;   (load "templates.clp")
;   (load "crawled_facts.clp")   ; outdoor facts
;   (load "env_facts.clp")       ; env facts
;   (load "user.clp")            ; set-occupancy / ask-occupancy
;   (load "rules.clp")
;   (reset)
;   (set-occupancy awake)        ; or sleep / gone
;   (run)
;
; Salience levels:
;   100  Carbon monoxide / fire safety (emergency)
;    60  Temperature control
;    50  Combined multi-factor rules
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


; ================================================
; GROUPED OUTPUT FUNCTION  (called by print-all-grouped rule)
; ================================================

(deffunction print-grouped ()
    "Print all msg facts grouped by date.
     Env-date groups appear first in chronological order (oldest->newest),
     followed by outdoor-only dates, then general messages."

    ; Build the ordered list of env dates (fact-index order = chronological)
    (bind ?env-dates (create$))
    (do-for-all-facts ((?e env)) TRUE
        (bind ?env-dates (create$ ?env-dates (fact-slot-value ?e date)))
    )

    ; 1. One section per env date
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

    ; 2. Outdoor-only dates (not present in env facts)
    (if (any-factp ((?m msg))
            (and (neq (fact-slot-value ?m date) "general")
                 (not (member$ (fact-slot-value ?m date) ?env-dates))))
        then
            (printout t crlf "=== Outdoor ===" crlf)
            (do-for-all-facts ((?m msg))
                (and (neq (fact-slot-value ?m date) "general")
                     (not (member$ (fact-slot-value ?m date) ?env-dates)))
                (printout t "  [" (fact-slot-value ?m date) "] "
                             (fact-slot-value ?m text) crlf)
            )
    )

    ; 3. General messages (no specific date)
    (if (any-factp ((?m msg)) (eq (fact-slot-value ?m date) "general"))
        then
            (printout t crlf "=== General ===" crlf)
            (do-for-all-facts ((?m msg)) (eq (fact-slot-value ?m date) "general")
                (printout t "  " (fact-slot-value ?m text) crlf)
            )
    )

    (printout t crlf)
)


; ================================================
; SAFETY ALARMS - Emergency  (salience 100)
; Fires once per env fact where the sensor is on.
; ================================================

(defrule co-emergency
    "Trigger emergency alert on any day where the CO sensor fired."
    (declare (salience 100))
    (env (date ?date) (co-alarm on))
    =>
    (assert (msg (date ?date) (text
        "EMERGENCY: Carbon monoxide detected. Evacuate immediately and call 911."
    )))
    (printout t "*** [" ?date "] EMERGENCY: CO detected. Evacuate and call 911. ***" crlf)
)

(defrule fire-emergency
    "Trigger emergency alert on any day where the fire/smoke sensor fired."
    (declare (salience 100))
    (env (date ?date) (fire-alarm on))
    =>
    (assert (msg (date ?date) (text
        "EMERGENCY: Fire/smoke detected. Evacuate immediately and call 911."
    )))
    (printout t "*** [" ?date "] EMERGENCY: Fire/smoke detected. Evacuate and call 911. ***" crlf)
)


; ================================================
; TEMPERATURE CONTROL - Heating  (salience 60)
; Source: Natural Resources Canada heating guidelines
; ================================================

(defrule heat-awake
    "Heater on: home occupied and awake, indoor temp below 20 C."
    (declare (salience 60))
    (env (date ?date) (temp ?t))
    (occupancy (date ?date) (status awake))
    (test (< ?t 20))
    (not (device (name heater)))
    =>
    (assert (device (name heater) (status on)))
    (assert (msg (date ?date) (text (str-cat
        "Heater ON: indoor temperature " ?t
        "C is below the 20C comfort target for an occupied home (Natural Resources Canada)."
    ))))
)

(defrule heat-sleep
    "Heater on: occupant sleeping, indoor temp below 17 C."
    (declare (salience 60))
    (env (date ?date) (temp ?t))
    (occupancy (date ?date) (status sleep))
    (test (< ?t 17))
    (not (device (name heater)))
    =>
    (assert (device (name heater) (status on)))
    (assert (msg (date ?date) (text (str-cat
        "Heater ON: indoor temperature " ?t
        "C is below the 17C sleep target (Natural Resources Canada)."
    ))))
)

(defrule heater-off-gone
    "Heater off: home unoccupied, energy-saving mode."
    (declare (salience 60))
    (occupancy (date ?date) (status gone))
    (not (device (name heater)))
    =>
    (assert (device (name heater) (status off)))
    (assert (msg (date ?date) (text
        "Heater OFF: home is unoccupied. Energy-saving mode active."
    )))
)


; ================================================
; TEMPERATURE CONTROL - Cooling  (salience 60)
; Source: Natural Resources Canada cooling guidelines
; ================================================

(defrule cool-awake
    "AC on: home occupied and awake, indoor temp exceeds 25.5 C."
    (declare (salience 60))
    (env (date ?date) (temp ?t))
    (occupancy (date ?date) (status awake))
    (test (> ?t 25))
    (not (device (name air-conditioner)))
    =>
    (assert (device (name air-conditioner) (status on)))
    (assert (msg (date ?date) (text (str-cat
        "AC ON: indoor temperature " ?t
        "C exceeds the 25.5C occupied comfort limit (Natural Resources Canada)."
    ))))
)

(defrule cool-gone
    "AC on at energy-saving threshold: home unoccupied, indoor temp above 28 C."
    (declare (salience 60))
    (env (date ?date) (temp ?t))
    (occupancy (date ?date) (status gone))
    (test (> ?t 28))
    (not (device (name air-conditioner)))
    =>
    (assert (device (name air-conditioner) (status on)))
    (assert (msg (date ?date) (text (str-cat
        "AC ON (energy-saving): indoor temperature " ?t
        "C exceeds the 28C unoccupied limit (Natural Resources Canada)."
    ))))
)

(defrule ac-off-gone
    "AC off: home unoccupied and indoor temp within the 28 C limit."
    (declare (salience 60))
    (env (date ?date) (temp ?t))
    (occupancy (date ?date) (status gone))
    (test (<= ?t 28))
    (not (device (name air-conditioner)))
    =>
    (assert (device (name air-conditioner) (status off)))
    (assert (msg (date ?date) (text (str-cat
        "AC OFF: home is unoccupied and indoor temperature " ?t
        "C is within the 28C energy-saving limit."
    ))))
)


; ================================================
; COMBINED MULTI-FACTOR RULES  (salience 50)
; ================================================

(defrule both-air-quality-poor
    "Recommend an air purifier when both indoor (IAQI < 61) and outdoor (AQHI > 6)
     air quality are poor. Fires once via sentinel ordered fact."
    (declare (salience 50))
    (env (date ?edate) (IAQI ?i))
    (outdoor (date ?odate) (AQHI ?a))
    (test (< ?i 61))
    (test (> ?a 6))
    (not (air-purifier-recommended))
    =>
    (assert (air-purifier-recommended))
    (assert (msg (date ?edate) (text (str-cat
        "Air purifier recommended: indoor IAQI " ?i
        " is poor and outdoor AQHI " ?a " (as of " ?odate
        ") exceeds 6. Keep windows closed to avoid worsening indoor air quality."
    ))))
)

(defrule high-humidity-poor-iaqi
    "High humidity (> 50%) with poor indoor air quality (IAQI < 61):
     balance dehumidification with ventilation. Fires once per matching day."
    (declare (salience 50))
    (env (date ?date) (humidity ?h) (IAQI ?i))
    (test (> ?h 50))
    (test (< ?i 61))
    =>
    (assert (msg (date ?date) (text (str-cat
        "High humidity (" ?h
        "%) with poor indoor air quality (IAQI " ?i
        "): dehumidifier active. Open windows for ventilation only if outdoor AQHI is 6 or below."
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
    (test (< ?h 30))
    (not (device (name humidifier)))
    =>
    (assert (device (name humidifier) (status on)))
    (assert (msg (date ?date) (text (str-cat
        "Humidifier ON: humidity " ?h
        "% is below 30%. Low humidity may aggravate skin allergies and respiratory infections (Health Canada)."
    ))))
)

(defrule dehumidify
    "Dehumidifier on: indoor humidity above 50%."
    (declare (salience 40))
    (env (date ?date) (humidity ?h))
    (test (> ?h 50))
    (not (device (name dehumidifier)))
    =>
    (assert (device (name dehumidifier) (status on)))
    (assert (msg (date ?date) (text (str-cat
        "Dehumidifier ON: humidity " ?h
        "% exceeds 50%. High humidity promotes mould growth (Health Canada)."
    ))))
)

(defrule humidity-comfortable
    "Humidity within the comfortable 30-50% range. Fires once per matching day."
    (declare (salience 40))
    (env (date ?date) (humidity ?h))
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
    (outdoor (date ?date) (AQHI ?a))
    (test (> ?a 6))
    (not (device (name window)))
    =>
    (assert (device (name window) (status off)))
    (assert (msg (date ?date) (text (str-cat
        "Window CLOSED: outdoor AQHI " ?a
        " exceeds 6. Keep windows sealed to block outdoor pollutants (Health Canada)."
    ))))
)

(defrule open-window-for-ventilation
    "Open windows when outdoor AQHI <= 6."
    (declare (salience 35))
    (outdoor (date ?date) (AQHI ?a))
    (test (<= ?a 6))
    (not (device (name window)))
    =>
    (assert (device (name window) (status on)))
    (assert (msg (date ?date) (text (str-cat
        "Window OPEN: outdoor AQHI " ?a
        " is acceptable. Ventilate if indoor air quality needs improvement."
    ))))
)


; ================================================
; INDOOR AIR QUALITY - IAQI ASSESSMENT  (salience 30)
; Fires once per env fact (one message per day).
; Atmotube scale: 0-100, higher = cleaner air.
; ================================================

(defrule iaqi-good
    "IAQI 81-100: indoor air quality is optimal."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i))
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
    (test (and (>= ?i 61) (< ?i 81)))
    =>
    (assert (msg (date ?date) (text (str-cat
        "Indoor air quality: Moderate (IAQI " ?i "). Improvement recommended."
    ))))
)

(defrule iaqi-polluted
    "IAQI 41-60: poor air quality, ventilation needed."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i))
    (test (and (>= ?i 41) (< ?i 61)))
    =>
    (assert (msg (date ?date) (text (str-cat
        "Indoor air quality: Polluted (IAQI " ?i "). Ventilation needed."
    ))))
)

(defrule iaqi-very-polluted
    "IAQI 21-40: serious air quality issues, immediate action required."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i))
    (test (and (>= ?i 21) (< ?i 41)))
    =>
    (assert (msg (date ?date) (text (str-cat
        "Indoor air quality: Very Polluted (IAQI " ?i "). Immediate action required."
    ))))
)

(defrule iaqi-severely-polluted
    "IAQI 0-20: critical air quality, urgent intervention required."
    (declare (salience 30))
    (env (date ?date) (IAQI ?i))
    (test (< ?i 21))
    =>
    (assert (msg (date ?date) (text (str-cat
        "Indoor air quality: Severely Polluted (IAQI " ?i "). Urgent intervention required."
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
