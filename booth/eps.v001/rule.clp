; =========================
; rules.clp
; Smart Home Expert System - Rulebase
; =========================

; ----------
; Utilities
; ----------

; Before each round of reasoning begins, clear the explanation information left over from the previous reasoning.
; System housekeeping rules.
(defrule clear-old-messages
    (declare (salience 200))
    ?m <- (msg (text ?t))
    =>
    (retract ?m)
)

; -------------------------
; R1: Comfort assessment
; -------------------------

; Locate an evaluation record containing the comfort field and note its current value (which may be unknown, cold, hot, etc.).
; Store the entire assessment fact itself (which you can think of as a reference or handle to this record/object) into the variable ?a.
; Because (assessment (comfort unknown) (energy unknown))
; Whenever there is an (assessment (comfort ...)) in working memory, update it based on the environment:
; If the environment appears comfortable → comfort = comfortable
; If any uncomfortable conditions (cold/hot/dry/humid) are detected → comfort = uncomfortable

(defrule comfort-comfortable
    (declare (salience 50))
    (env (temp comfortable) (humidity normal))
    ?a <- (assessment (comfort ?c))
    =>
    (modify ?a (comfort comfortable))
    (assert (msg (text "Comfort assessed: comfortable (temperature comfortable + humidity normal).")))
)

(defrule comfort-uncomfortable-cold
    (declare (salience 50))
    (env (temp cold))
    ?a <- (assessment (comfort ?c))
    =>
    (modify ?a (comfort uncomfortable))
    (assert (msg (text "Comfort assessed: uncomfortable due to cold.")))
)

(defrule comfort-uncomfortable-hot
    (declare (salience 50))
    (env (temp hot))
    ?a <- (assessment (comfort ?c))
    =>
    (modify ?a (comfort uncomfortable))
    (assert (msg (text "Comfort assessed: uncomfortable due to heat.")))
)

(defrule comfort-uncomfortable-dry
    (declare (salience 50))
    (env (humidity dry))
    ?a <- (assessment (comfort ?c))
    =>
    (modify ?a (comfort uncomfortable))
    (assert (msg (text "Comfort assessed: uncomfortable due to dryness.")))
)

(defrule comfort-uncomfortable-humid
    (declare (salience 50))
    (env (humidity humid))
    ?a <- (assessment (comfort ?c))
    =>
    (modify ?a (comfort uncomfortable))
    (assert (msg (text "Comfort assessed: uncomfortable due to humidity.")))
)

; -------------------------
; R2: Energy assessment
; -------------------------

; If no one is home but the heating or air conditioning is still running,
; the system will determine this is a waste of energy and provide an explanation.
; if no one at home
; or means (device (name heater) (state on)) and (device (name ac)     (state cooling) only need to match one
; Use assert(msg ...) not for printing, but to: make the interpretation part of the system's knowledge.

(defrule energy-wasteful-hvac-when-empty
    (declare (salience 60))
    (occupancy (status empty))
    (or (device (name heater) (state on))
        (device (name ac)     (state cooling)))
    ?a <- (assessment (energy ?e))
    =>
    (modify ?a (energy wasteful))
    (assert (msg (text "Energy waste detected: HVAC running while home is empty.")))
)

(defrule energy-wasteful-lights-when-empty
    (declare (salience 60))
    (occupancy (status empty))
    (or (device (name main-light)    (state on))
        (device (name ambient-light) (state warm))
        (device (name ambient-light) (state cool)))
    ?a <- (assessment (energy ?e))
    =>
    (modify ?a (energy wasteful))
    (assert (msg (text "Energy waste detected: lights on while home is empty.")))
)

; If someone is home and the current environment is uncomfortable,
; the system deems it acceptable to use energy to improve comfort.

(defrule energy-acceptable-when-occupied-and-uncomfortable
    (declare (salience 55))
    (occupancy (status occupied))
    (assessment (comfort uncomfortable))
    ?a <- (assessment (energy ?e))
    =>
    (modify ?a (energy acceptable))
    (assert (msg (text "Energy acceptable: occupied and comfort is uncomfortable.")))
)

(defrule energy-efficient-basic
    (declare (salience 40))
    (occupancy (status occupied))
    (env (light dark))
    (device (name heater)        (state off))
    (device (name ac)            (state off))
    (device (name window)        (state closed))
    (device (name ambient-light) (state off))
    ?a <- (assessment (energy ?e))
    =>
    (modify ?a (energy efficient))
    (assert (msg (text "Energy efficient: HVAC off, window closed, ambient light off while dark.")))
)

; --------------------------------
; R6: Conflict resolution (priority)
; --------------------------------

(defrule conflict-heater-vs-ac
    (declare (salience 120))
    ?h <- (device (name heater) (state on))
    ?ac <- (device (name ac) (state cooling))
    =>
    (modify ?h (state off))
    (assert (msg (text "Conflict resolved: heater turned OFF because AC is cooling.")))
)

; -------------------------
; R3: Temperature control
; -------------------------

(defrule heat-on-when-cold-and-occupied
    (declare (salience 80))
    (occupancy (status occupied))
    (env (temp cold))
    ?h <- (device (name heater) (state off))
    =>
    (modify ?h (state on))
    (assert (msg (text "Action: heater ON (occupied + temperature cold).")))
)

(defrule heat-off-when-comfortable
    (declare (salience 75))
    (occupancy (status occupied))
    (env (temp comfortable))
    ?h <- (device (name heater) (state on))
    =>
    (modify ?h (state off))
    (assert (msg (text "Action: heater OFF (temperature comfortable).")))
)

(defrule ac-on-when-hot-and-occupied
    (declare (salience 80))
    (occupancy (status occupied))
    (env (temp hot))
    ?ac <- (device (name ac) (state off))
    (user (priority comfort-first))
    =>
    (modify ?ac (state cooling))
    (assert (msg (text "Action: AC COOLING (comfort-first + occupied + temperature hot).")))
)

(defrule prefer-window-over-ac-when-energy-saving-and-mild
    (declare (salience 90))
    (occupancy (status occupied))
    (env (temp hot) (outdoor mild))
    (user (priority energy-saving))
    ?w <- (device (name window) (state closed))
    =>
    (modify ?w (state open))
    (assert (msg (text "Action: window OPEN (energy-saving + outdoor mild + indoor hot).")))
)

(defrule ac-off-when-comfortable
    (declare (salience 75))
    (occupancy (status occupied))
    (env (temp comfortable))
    ?ac <- (device (name ac) (state cooling))
    =>
    (modify ?ac (state off))
    (assert (msg (text "Action: AC OFF (temperature comfortable).")))
)

(defrule hvac-off-when-empty
    (declare (salience 110))
    (occupancy (status empty))
    ?h <- (device (name heater) (state on))
    =>
    (modify ?h (state off))
    (assert (msg (text "Action: heater OFF (home empty).")))
)

(defrule ac-off-when-empty
    (declare (salience 110))
    (occupancy (status empty))
    ?ac <- (device (name ac) (state cooling))
    =>
    (modify ?ac (state off))
    (assert (msg (text "Action: AC OFF (home empty).")))
)

; -------------------------
; R4: Ventilation & humidity
; -------------------------

(defrule open-window-when-humid-and-mild
    (declare (salience 85))
    (occupancy (status occupied))
    (env (humidity humid) (outdoor mild))
    ?w <- (device (name window) (state closed))
    =>
    (modify ?w (state open))
    (assert (msg (text "Action: window OPEN (occupied + humidity humid + outdoor mild).")))
)

(defrule close-window-when-humidity-normal
    (declare (salience 70))
    (env (humidity normal))
    ?w <- (device (name window) (state open))
    =>
    (modify ?w (state closed))
    (assert (msg (text "Action: window CLOSED (humidity normal).")))
)

(defrule close-window-when-ac-cooling-and-outdoor-hot
    (declare (salience 95))
    (occupancy (status occupied))
    (env (outdoor hot))
    (device (name ac) (state cooling))
    ?w <- (device (name window) (state open))
    =>
    (modify ?w (state closed))
    (assert (msg (text "Action: window CLOSED (AC cooling + outdoor hot).")))
)

(defrule close-window-when-empty
    (declare (salience 105))
    (occupancy (status empty))
    ?w <- (device (name window) (state open))
    =>
    (modify ?w (state closed))
    (assert (msg (text "Action: window CLOSED (home empty).")))
)

; -------------------------
; R5: Lighting control
; -------------------------

(defrule main-light-on-morning-when-dark-and-occupied
    (declare (salience 65))
    (occupancy (status occupied))
    (env (light dark) (tod morning))
    ?ml <- (device (name main-light) (state off))
    =>
    (modify ?ml (state on))
    (assert (msg (text "Action: main light ON (morning + dark + occupied).")))
)

(defrule main-light-off-when-bright
    (declare (salience 60))
    (env (light bright))
    ?ml <- (device (name main-light) (state on))
    =>
    (modify ?ml (state off))
    (assert (msg (text "Action: main light OFF (ambient bright).")))
)

(defrule lights-off-when-empty-main
    (declare (salience 110))
    (occupancy (status empty))
    ?ml <- (device (name main-light) (state on))
    =>
    (modify ?ml (state off))
    (assert (msg (text "Action: main light OFF (home empty).")))
)

(defrule lights-off-when-empty-ambient
    (declare (salience 110))
    (occupancy (status empty))
    ?al <- (device (name ambient-light) (state ?s&~off))
    =>
    (modify ?al (state off))
    (assert (msg (text "Action: ambient light OFF (home empty).")))
)

(defrule night-ambient-warm-preference
    (declare (salience 78))
    (occupancy (status occupied))
    (env (tod night))
    (user (lighting-pref warm))
    ?al <- (device (name ambient-light) (state ?s&~warm))
    ?ml <- (device (name main-light) (state ?m))
    =>
    (modify ?al (state warm))
    (modify ?ml (state off))
    (assert (msg (text "Action: ambient light WARM, main light OFF (night + preference warm).")))
)

(defrule night-ambient-cool-preference
    (declare (salience 78))
    (occupancy (status occupied))
    (env (tod night))
    (user (lighting-pref cool))
    ?al <- (device (name ambient-light) (state ?s&~cool))
    ?ml <- (device (name main-light) (state ?m))
    =>
    (modify ?al (state cool))
    (modify ?ml (state off))
    (assert (msg (text "Action: ambient light COOL, main light OFF (night + preference cool).")))
)

; -------------------------
; Explanation printing
; -------------------------

; Responsible for printing the stored msg information from the system and then deleting it to prevent duplicate printing.

(defrule print-messages
    (declare (salience 300))
    ?m <- (msg (text ?t))
    =>
    (printout t ?t crlf)
    (retract ?m)
)
