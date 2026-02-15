; =========================
; rules.clp
; Smart Home Expert System - Basic Rulebase (Fixed Threshold, NO user)
; =========================

; -------------------------
; Safety rules (highest priority)
; -------------------------

(defrule safety-fire-start-siren
  (declare (salience 200))
  ?fa <- (fire-alarm (power on) (triggered yes) (sounding no))
  =>
  (modify ?fa (sounding yes))
  (assert (msg (text "[SAFETY] Fire detected -> siren ON.")))
)

; when fire turn off everything
(defrule safety-fire-shutdown-heater
  (declare (salience 190))
  (fire-alarm (triggered yes))
  ?h  <- (device (name heater) (power on))
  =>
  (modify ?h (power off))
  (assert (msg (text "[SAFETY] Fire -> heater OFF.")))
)

(defrule safety-fire-shutdown-ac
  (declare (salience 190))
  (fire-alarm (triggered yes))
  ?ac <- (device (name ac) (power on))
  =>
  (modify ?ac (power off))
  (assert (msg (text "[SAFETY] Fire -> AC OFF.")))
)

(defrule safety-fire-shutdown-humidifier
  (declare (salience 190))
  (fire-alarm (triggered yes))
  ?hu <- (device (name humidifier) (power on))
  =>
  (modify ?hu (power off))
  (assert (msg (text "[SAFETY] Fire -> humidifier OFF.")))
)

(defrule safety-fire-shutdown-dehumidifier
  (declare (salience 190))
  (fire-alarm (triggered yes))
  ?dh <- (device (name dehumidifier) (power on))
  =>
  (modify ?dh (power off))
  (assert (msg (text "[SAFETY] Fire -> dehumidifier OFF.")))
)

; Fire -> close window (reasonable + prevents feeding fire / smoke spread)
(defrule safety-fire-close-window
  (declare (salience 185))
  (fire-alarm (triggered yes))
  ?w <- (device (name window) (position open))
  =>
  (modify ?w (position closed))
  (assert (msg (text "[SAFETY] Fire -> window CLOSED.")))
)

(defrule safety-co-high-open-window
  (declare (salience 180))
  (carbon-monoxide-alarm (power on) (level high))
  ?w <- (device (name window) (position closed))
  =>
  (modify ?w (position open))
  (assert (msg (text "[SAFETY] CO level HIGH -> window OPEN for ventilation.")))
)

(defrule safety-co-high-turn-off-heater
  (declare (salience 175))
  (carbon-monoxide-alarm (power on) (level high))
  ?h <- (device (name heater) (power on))
  =>
  (modify ?h (power off))
  (assert (msg (text "[SAFETY] CO level HIGH -> heater OFF.")))
)

; -------------------------
; Occupancy rules
; -------------------------

(defrule occupancy-outside-shutdown-heater
  (declare (salience 120))
  (occupancy (status outside))
  ?h <- (device (name heater) (power on))
  =>
  (modify ?h (power off))
  (assert (msg (text "[OCCUPANCY] Nobody home -> heater OFF.")))
)

(defrule occupancy-outside-shutdown-ac
  (declare (salience 120))
  (occupancy (status outside))
  ?ac <- (device (name ac) (power on))
  =>
  (modify ?ac (power off))
  (assert (msg (text "[OCCUPANCY] Nobody home -> AC OFF.")))
)

(defrule occupancy-outside-shutdown-humidifier
  (declare (salience 115))
  (occupancy (status outside))
  ?hu <- (device (name humidifier) (power on))
  =>
  (modify ?hu (power off))
  (assert (msg (text "[OCCUPANCY] Nobody home -> humidifier OFF.")))
)

(defrule occupancy-outside-shutdown-dehumidifier
  (declare (salience 115))
  (occupancy (status outside))
  ?dh <- (device (name dehumidifier) (power on))
  =>
  (modify ?dh (power off))
  (assert (msg (text "[OCCUPANCY] Nobody home -> dehumidifier OFF.")))
)

(defrule occupancy-outside-close-window
  (declare (salience 110))
  ; fix also here
  (not (carbon-monoxide-alarm (level high)))
  (occupancy (status outside))
  ?w <- (device (name window) (position open))
  =>
  (modify ?w (position closed))
  (assert (msg (text "[OCCUPANCY] Nobody home -> window CLOSED.")))
)

; -------------------------
; Temperature control (Fixed thresholds)
; deadband to avoid rapid toggling
; Comfort band: 21-25
; Turn ON:
;   AC if temp > 25
;   heater if temp < 21
; Turn OFF (deadband):
;   AC off if temp <= 24
;   heater off if temp >= 22
; -------------------------

(defrule temp-too-hot-turn-on-ac
  (declare (salience 80))
  (fire-alarm (triggered no))
  (occupancy (status home-awake|home-sleep))
  (env (temp ?t))
  ?ac <- (device (name ac) (power off))
  (test (> ?t 25))
  =>
  (modify ?ac (power on))
  (assert (msg (text "[TEMP] Temp > 25 -> AC ON.")))
)

(defrule temp-too-cold-turn-on-heater
  (declare (salience 80))
  (fire-alarm (triggered no))
  (occupancy (status home-awake|home-sleep))
  (env (temp ?t))
  ?h <- (device (name heater) (power off))
  (test (< ?t 21))
  =>
  (modify ?h (power on))
  (assert (msg (text "[TEMP] Temp < 21 -> heater ON.")))
)

(defrule temp-back-to-normal-turn-off-ac
  (declare (salience 75))
  (env (temp ?t))
  ?ac <- (device (name ac) (power on))
  (test (<= ?t 24))
  =>
  (modify ?ac (power off))
  (assert (msg (text "[TEMP] Temp <= 24 -> AC OFF.")))
)

(defrule temp-back-to-normal-turn-off-heater
  (declare (salience 75))
  (env (temp ?t))
  ?h <- (device (name heater) (power on))
  (test (>= ?t 22))
  =>
  (modify ?h (power off))
  (assert (msg (text "[TEMP] Temp >= 22 -> heater OFF.")))
)

(defrule temp-prevent-heater-and-ac-both-on
  (declare (salience 90))
  ?h  <- (device (name heater) (power on))
  ?ac <- (device (name ac) (power on))
  =>
  ; policy: turn heater off if conflict
  (modify ?h (power off))
  (assert (msg (text "[TEMP] Conflict: heater & AC both ON -> heater OFF.")))
)

; -------------------------
; Humidity control (Fixed thresholds)
; Comfort band: 40-60
; Turn ON:
;   dehumidifier if humidity > 60
;   humidifier if humidity < 40
; Turn OFF (deadband):
;   dehumidifier off if humidity <= 55
;   humidifier off if humidity >= 45
; -------------------------

(defrule humidity-too-high-turn-on-dehumidifier
  (declare (salience 70))
  (fire-alarm (triggered no))
  (occupancy (status home-awake|home-sleep))
  (env (humidity ?h))
  ?dh <- (device (name dehumidifier) (power off))
  (test (> ?h 60))
  =>
  (modify ?dh (power on))
  (assert (msg (text "[HUM] Humidity > 60 -> dehumidifier ON.")))
)

(defrule humidity-too-low-turn-on-humidifier
  (declare (salience 70))
  (fire-alarm (triggered no))
  (occupancy (status home-awake|home-sleep))
  (env (humidity ?h))
  ?hu <- (device (name humidifier) (power off))
  (test (< ?h 40))
  =>
  (modify ?hu (power on))
  (assert (msg (text "[HUM] Humidity < 40 -> humidifier ON.")))
)

(defrule humidity-back-to-normal-turn-off-dehumidifier
  (declare (salience 65))
  (env (humidity ?h))
  ?dh <- (device (name dehumidifier) (power on))
  (test (<= ?h 55))
  =>
  (modify ?dh (power off))
  (assert (msg (text "[HUM] Humidity <= 55 -> dehumidifier OFF.")))
)

(defrule humidity-back-to-normal-turn-off-humidifier
  (declare (salience 65))
  (env (humidity ?h))
  ?hu <- (device (name humidifier) (power on))
  (test (>= ?h 45))
  =>
  (modify ?hu (power off))
  (assert (msg (text "[HUM] Humidity >= 45 -> humidifier OFF.")))
)

(defrule humidity-prevent-both-humidifiers-on
  (declare (salience 85))
  ?hu <- (device (name humidifier) (power on))
  ?dh <- (device (name dehumidifier) (power on))
  =>
  ; policy: turn humidifier off if conflict
  (modify ?hu (power off))
  (assert (msg (text "[HUM] Conflict: humidifier & dehumidifier both ON -> humidifier OFF.")))
)

; -------------------------
; Window / Air Quality (simple)
; -------------------------

(defrule air-quality-bad-close-window
  (declare (salience 95))
  ; fix here also
  (not (carbon-monoxide-alarm (level high)))
  (env (IAQI ?i) (AQHI ?a))
  ?w <- (device (name window) (position open))
  (test (or (>= ?a 7) (>= ?i 150)))
  =>
  (modify ?w (position closed))
  (assert (msg (text "[AIR] Poor air quality -> window CLOSED.")))
)

; Free cooling: if indoor hot and outdoor mild and air ok -> open window
(defrule free-cooling-open-window
  (declare (salience 60))
  (fire-alarm (triggered no))
  (carbon-monoxide-alarm (level low|medium))
  (occupancy (status home-awake|home-sleep))
  (env (temp ?t) (outdoor mild) (AQHI ?a) (IAQI ?i))
  ?w <- (device (name window) (position closed))
  (test (and (> ?t 25) (< ?a 7) (< ?i 150)))
  =>
  (modify ?w (position open))
  (assert (msg (text "[VENT] Outdoor mild & air OK + indoor hot -> window OPEN (free cooling).")))
)

; If window open and HVAC running, turn HVAC off (avoid fighting)
(defrule window-open-turn-off-ac
  (declare (salience 62))
  ?w <- (device (name window) (position open))
  ?ac <- (device (name ac) (power on))
  =>
  (modify ?ac (power off))
  (assert (msg (text "[VENT] Window open -> AC OFF (avoid conflict).")))
)

(defrule window-open-turn-off-heater
  (declare (salience 62))
  ?w <- (device (name window) (position open))
  ?h <- (device (name heater) (power on))
  =>
  (modify ?h (power off))
  (assert (msg (text "[VENT] Window open -> heater OFF (avoid conflict).")))
)

(defrule close-window-when-comfort-restored
  (declare (salience 55))
  ; fix here
  (not (carbon-monoxide-alarm (level high)))
  (env (temp ?t) (outdoor mild))
  ?w <- (device (name window) (position open))
  (test (<= ?t 24))
  =>
  (modify ?w (position closed))
  (assert (msg (text "[VENT] Temp back near normal -> window CLOSED.")))
)


; print rules
(defrule print-msg
  ?m <- (msg (text ?t))
  =>
  (printout t ?t crlf)
  (retract ?m)
)
