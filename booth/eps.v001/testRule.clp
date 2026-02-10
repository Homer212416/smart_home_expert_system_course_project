; =========================
; Temperature Control
; <=19 cold，>=26 hot，20~25 ok
; =========================

(defrule temp-hot-turn-on-ac
    (declare (salience 40))
    (env (temp ?t))
    (occupancy (status home-awake home-sleep))
    (test (>= ?t 26))
    ?ac <- (device (name ac) (state off))
    =>
    (assert (msg (text "[TEMP] temp>=26 & someone home -> AC ON.")))
    (printout t "[TEMP] " ?t "C >=26 -> AC ON" crlf)
    (modify ?ac (state on))
)

(defrule temp-hot-turn-off-heater
    (declare (salience 39))
    (env (temp ?t))
    (test (>= ?t 26))
    ?h <- (device (name heater) (state on))
    =>
    (assert (msg (text "[TEMP] temp>=26 -> Heater OFF (avoid heating).")))
    (printout t "[TEMP] " ?t "C >=26 -> Heater OFF" crlf)
    (modify ?h (state off))
)

(defrule temp-cold-turn-on-heater
    (declare (salience 40))
    (env (temp ?t))
    (occupancy (status home-awake home-sleep))
    (test (<= ?t 19))
    ?h <- (device (name heater) (state off))
    =>
    (assert (msg (text "[TEMP] temp<=19 & someone home -> Heater ON.")))
    (printout t "[TEMP] " ?t "C <=19 -> Heater ON" crlf)
    (modify ?h (state on))
)

(defrule temp-cold-turn-off-ac
    (declare (salience 39))
    (env (temp ?t))
    (test (<= ?t 19))
    ?ac <- (device (name ac) (state on))
    =>
    (assert (msg (text "[TEMP] temp<=19 -> AC OFF (avoid cooling).")))
    (printout t "[TEMP] " ?t "C <=19 -> AC OFF" crlf)
    (modify ?ac (state off))
)

(defrule temp-comfortable-turn-off-ac
    (declare (salience 30))
    (env (temp ?t))
    (test (and (>= ?t 20) (<= ?t 25)))
    ?ac <- (device (name ac) (state on))
    =>
    (assert (msg (text "[TEMP] 20<=temp<=25 -> AC OFF (save energy).")))
    (printout t "[TEMP] " ?t "C in[20..25] -> AC OFF" crlf)
    (modify ?ac (state off))
)

(defrule temp-comfortable-turn-off-heater
    (declare (salience 30))
    (env (temp ?t))
    (test (and (>= ?t 20) (<= ?t 25)))
    ?h <- (device (name heater) (state on))
    =>
    (assert (msg (text "[TEMP] 20<=temp<=25 -> Heater OFF (save energy).")))
    (printout t "[TEMP] " ?t "C in[20..25] -> Heater OFF" crlf)
    (modify ?h (state off))
)

; =========================
; Humidity Control 
; <=35 dry，>=60 wet，40~55 ok
; =========================

(defrule humidity-dry-turn-on-humidifier
    (declare (salience 35))
    (env (humidity ?h))
    (occupancy (status home-awake home-sleep))
    (test (<= ?h 35))
    ?hu <- (device (name humidifier) (state off))
    =>
    (assert (msg (text "[HUM] humidity<=35% & someone home -> humidifier ON.")))
    (printout t "[HUM] " ?h "% <=35 -> humidifier ON" crlf)
    (modify ?hu (state on))
)

(defrule humidity-dry-turn-off-dehumidifier
    (declare (salience 34))
    (env (humidity ?h))
    (test (<= ?h 35))
    ?de <- (device (name dehumidifier) (state on))
    =>
    (assert (msg (text "[HUM] humidity<=35% -> dehumidifier OFF.")))
    (printout t "[HUM] " ?h "% <=35 -> dehumidifier OFF" crlf)
    (modify ?de (state off))
)

(defrule humidity-humid-turn-on-dehumidifier
    (declare (salience 35))
    (env (humidity ?h))
    (occupancy (status home-awake home-sleep))
    (test (>= ?h 60))
    ?de <- (device (name dehumidifier) (state off))
    =>
    (assert (msg (text "[HUM] humidity>=60% & someone home -> dehumidifier ON.")))
    (printout t "[HUM] " ?h "% >=60 -> dehumidifier ON" crlf)
    (modify ?de (state on))
)

(defrule humidity-humid-turn-off-humidifier
    (declare (salience 34))
    (env (humidity ?h))
    (test (>= ?h 60))
    ?hu <- (device (name humidifier) (state on))
    =>
    (assert (msg (text "[HUM] humidity>=60% -> humidifier OFF.")))
    (printout t "[HUM] " ?h "% >=60 -> humidifier OFF" crlf)
    (modify ?hu (state off))
)

(defrule humidity-normal-turn-off-humidifier
    (declare (salience 25))
    (env (humidity ?h))
    (test (and (>= ?h 40) (<= ?h 55)))
    ?hu <- (device (name humidifier) (state on))
    =>
    (assert (msg (text "[HUM] 40%<=humidity<=55% -> humidifier OFF.")))
    (printout t "[HUM] " ?h "% in[40..55] -> humidifier OFF" crlf)
    (modify ?hu (state off))
)

(defrule humidity-normal-turn-off-dehumidifier
    (declare (salience 25))
    (env (humidity ?h))
    (test (and (>= ?h 40) (<= ?h 55)))
    ?de <- (device (name dehumidifier) (state on))
    =>
    (assert (msg (text "[HUM] 40%<=humidity<=55% -> dehumidifier OFF.")))
    (printout t "[HUM] " ?h "% in[40..55] -> dehumidifier OFF" crlf)
    (modify ?de (state off))
)

; =========================
; Lighting Control
; =========================

; Night + dark + home-awake -> Light ON <== this one may be ppl dont want to open ?
(defrule light-night-dark-home-awake-on
    (declare (salience 20))
    (env (tod night) (light dark))
    (occupancy (status home-awake))
    ?l <- (device (name light) (state off))
    =>
    (assert (msg (text "[LIGHT] Night + dark + home-awake -> light ON (visibility).")))
    (printout t "[LIGHT] Night+dark+awake -> light ON" crlf)
    (modify ?l (state on))
)

; Evening + dark + home-awake -> Light ON
(defrule light-evening-dark-home-awake-on
    (declare (salience 18))
    (env (tod evening) (light dark))
    (occupancy (status home-awake))
    ?l <- (device (name light) (state off))
    =>
    (assert (msg (text "[LIGHT] Evening + dark + home-awake -> light ON.")))
    (printout t "[LIGHT] Evening+dark+awake -> light ON" crlf)
    (modify ?l (state on))
)

; Home-sleep -> Light OFF
(defrule light-sleep-off
    (declare (salience 25)) ; higher than turning on
    (occupancy (status home-sleep))
    ?l <- (device (name light) (state on))
    =>
    (assert (msg (text "[LIGHT] home-sleep -> light OFF (do not disturb).")))
    (printout t "[LIGHT] sleep -> light OFF" crlf)
    (modify ?l (state off))
)

; Outside -> Light OFF (energy saving)
(defrule light-outside-off
    (declare (salience 22))
    (occupancy (status outside))
    ?l <- (device (name light) (state on))
    =>
    (assert (msg (text "[LIGHT] outside -> light OFF (energy saving).")))
    (printout t "[LIGHT] outside -> light OFF" crlf)
    (modify ?l (state off))
)

; User prefers BRIGHT & awake -> Light ON
(defrule light-user-pref-bright-awake-on
    (declare (salience 16))
    (user (lighting-pref bright))
    (occupancy (status home-awake))
    ?l <- (device (name light) (state off))
    =>
    (assert (msg (text "[LIGHT] User prefers bright + home-awake -> light ON.")))
    (printout t "[LIGHT] user bright + awake -> light ON" crlf)
    (modify ?l (state on))
)

; Daytime (morning/afternoon) + environment bright -> Light OFF
(defrule light-daytime-bright-off
    (declare (salience 15))
    (env (tod morning|afternoon) (light bright))
    ?l <- (device (name light) (state on))
    =>
    (assert (msg (text "[LIGHT] Daytime + bright -> light OFF (use natural light).")))
    (printout t "[LIGHT] daytime+bright -> light OFF" crlf)
    (modify ?l (state off))
)

; =========================
; Safety Rules (Fire / CO)
; =========================

; i do not know this, i think if just keep trigger or not, we may do not need alarm. So we can cut some rules

; -------------------------
; FIRE: if triggered -> sound alarm
; -------------------------
(defrule fire-triggered-sound-alarm
    (declare (salience 100))
    ?f <- (fire-alarm (power on) (triggered yes) (sounding no))
    =>
    (assert (msg (text "[SAFETY] Fire detected -> sound alarm NOW.")))
    (printout t "[SAFETY] FIRE -> sounding YES" crlf)
    (modify ?f (sounding yes))
)

; FIRE: if triggered -> turn OFF heater (reduce risk)
(defrule fire-triggered-turn-off-heater
    (declare (salience 95))
    (fire-alarm (power on) (triggered yes))
    ?h <- (device (name heater) (state on))
    =>
    (assert (msg (text "[SAFETY] Fire detected -> heater OFF.")))
    (printout t "[SAFETY] FIRE -> heater OFF" crlf)
    (modify ?h (state off))
)

; FIRE: if triggered -> turn OFF AC (stop airflow feeding fire/smoke spread)
(defrule fire-triggered-turn-off-ac
    (declare (salience 95))
    (fire-alarm (power on) (triggered yes))
    ?ac <- (device (name ac) (state on))
    =>
    (assert (msg (text "[SAFETY] Fire detected -> AC OFF.")))
    (printout t "[SAFETY] FIRE -> AC OFF" crlf)
    (modify ?ac (state off))
)

; FIRE: if triggered -> turn ON light (help evacuation) when awake
(defrule fire-triggered-turn-on-light
    (declare (salience 92))
    (fire-alarm (power on) (triggered yes))
    (occupancy (status home-awake))
    ?l <- (device (name light) (state off))
    =>
    (assert (msg (text "[SAFETY] Fire detected -> turn ON light to help evacuation.")))
    (printout t "[SAFETY] FIRE -> light ON" crlf)
    (modify ?l (state on))
)

; FIRE: optional -> open window (vent smoke) ONLY if outdoor is mild
(defrule fire-triggered-open-window-if-outdoor-mild
    (declare (salience 90))
    (fire-alarm (power on) (triggered yes))
    (env (outdoor mild))
    ?w <- (device (name window) (state closed))
    =>
    (assert (msg (text "[SAFETY] Fire detected + outdoor mild -> open window for ventilation (if safe).")))
    (printout t "[SAFETY] FIRE + outdoor mild -> window OPEN" crlf)
    (modify ?w (state open))
)

; -------------------------
; CO: medium/high -> open window + turn OFF heater
; -------------------------

(defrule co-medium-high-open-window
    (declare (salience 98))
    (carbon-monoxide-alarm (power on) (level medium|high))
    ?w <- (device (name window) (state closed))
    =>
    (assert (msg (text "[SAFETY] CO level MEDIUM/HIGH -> open window for fresh air.")))
    (printout t "[SAFETY] CO MED/HIGH -> window OPEN" crlf)
    (modify ?w (state open))
)

(defrule co-medium-high-turn-off-heater
    (declare (salience 97))
    (carbon-monoxide-alarm (power on) (level medium|high))
    ?h <- (device (name heater) (state on))
    =>
    (assert (msg (text "[SAFETY] CO level MEDIUM/HIGH -> heater OFF.")))
    (printout t "[SAFETY] CO MED/HIGH -> heater OFF" crlf)
    (modify ?h (state off))
)

; CO: if power off -> warn (no device action, just explanation)
(defrule co-alarm-off-warning
    (declare (salience 80))
    (carbon-monoxide-alarm (power off))
    =>
    (assert (msg (text "[SAFETY] WARNING: CO alarm is OFF. Turn it ON for safety.")))
    (printout t "[SAFETY] WARNING: CO alarm OFF" crlf)
)

; =========================
; Air Quality Rules (IAQI / AQHI)
; =========================

; if IAQI>=101 OR AQHI>=7 => poor air 

; Poor air + outdoor mild -> OPEN window
(defrule air-poor-open-window-when-outdoor-mild
    (declare (salience 70))
    (env (IAQI ?i) (AQHI ?a) (outdoor mild))
    (test (or (>= ?i 101) (>= ?a 7)))
    ?w <- (device (name window) (state closed))
    =>
    (assert (msg (text "[AIR] Poor air (IAQI>=101 or AQHI>=7) + outdoor mild -> OPEN window for ventilation.")))
    (printout t "[AIR] poor air + outdoor mild -> window OPEN" crlf)
    (modify ?w (state open))
)

; Poor air + outdoor extreme (cold/hot) -> keep/close window + warning
(defrule air-poor-outdoor-extreme-close-window
    (declare (salience 69))
    (env (IAQI ?i) (AQHI ?a) (outdoor cold|hot))
    (test (or (>= ?i 101) (>= ?a 7)))
    ?w <- (device (name window) (state open))
    =>
    (assert (msg (text "[AIR] Poor air BUT outdoor is extreme (cold/hot) -> CLOSE window; consider internal filtration (not modeled).")))
    (printout t "[AIR] poor air + outdoor extreme -> window CLOSE" crlf)
    (modify ?w (state closed))
)

(defrule air-poor-outdoor-extreme-message
    (declare (salience 68))
    (env (IAQI ?i) (AQHI ?a) (outdoor cold|hot))
    (test (or (>= ?i 101) (>= ?a 7)))
    =>
    (assert (msg (text "[AIR] Air quality is poor, but outdoor is extreme. Ventilation decision is constrained.")))
    (printout t "[AIR] poor air but outdoor extreme -> message only" crlf)
)

; Air OK -> message (optional, helps explanation)
(defrule air-ok-message
    (declare (salience 20))
    (env (IAQI ?i) (AQHI ?a))
    (test (and (< ?i 101) (< ?a 7)))
    =>
    (assert (msg (text "[AIR] Air quality is acceptable (IAQI<101 and AQHI<7).")))
    (printout t "[AIR] air OK" crlf)
)

; Energy-saving: if air OK + window open + outdoor not mild -> close window
(defrule air-ok-energy-saving-close-window-when-outdoor-extreme
    (declare (salience 30))
    (env (IAQI ?i) (AQHI ?a) (outdoor cold|hot))
    (test (and (< ?i 101) (< ?a 7)))
    (user (priority energy-saving))
    ?w <- (device (name window) (state open))
    =>
    (assert (msg (text "[AIR] Air OK + energy-saving + outdoor extreme -> CLOSE window to save energy.")))
    (printout t "[AIR] air OK + energy-saving + outdoor extreme -> window CLOSE" crlf)
    (modify ?w (state closed))
)

; =========================
; Window / Ventilation Rules
; =========================

; Nobody home -> CLOSE window (security + energy)
(defrule window-outside-close
    (declare (salience 50))
    (occupancy (status outside))
    ?w <- (device (name window) (state open))
    =>
    (assert (msg (text "[VENT] Nobody home -> CLOSE window (security/energy).")))
    (printout t "[VENT] outside -> window CLOSE" crlf)
    (modify ?w (state closed))
)

; Outdoor extreme (cold/hot) -> CLOSE window (keep comfort)
(defrule window-outdoor-extreme-close
    (declare (salience 35))
    (env (outdoor cold|hot))
    ?w <- (device (name window) (state open))
    =>
    (assert (msg (text "[VENT] Outdoor is extreme (cold/hot) -> CLOSE window to maintain comfort/energy.")))
    (printout t "[VENT] outdoor extreme -> window CLOSE" crlf)
    (modify ?w (state closed))
)

; Humidity high + outdoor mild + home-awake -> OPEN window (natural ventilation)
(defrule window-open-for-humidity-when-mild-awake
    (declare (salience 32))
    (env (humidity ?h) (outdoor mild))
    (occupancy (status home-awake))
    (test (>= ?h 60))
    ?w <- (device (name window) (state closed))
    =>
    (assert (msg (text "[VENT] Humidity>=60% + outdoor mild + home-awake -> OPEN window for natural ventilation.")))
    (printout t "[VENT] humid>=60 + mild + awake -> window OPEN" crlf)
    (modify ?w (state open))
)

; If humidity back to comfortable range AND energy-saving -> CLOSE window
(defrule window-close-when-humidity-normal-energy-saving
    (declare (salience 28))
    (env (humidity ?h))
    (test (and (>= ?h 40) (<= ?h 55)))
    (user (priority energy-saving))
    ?w <- (device (name window) (state open))
    =>
    (assert (msg (text "[VENT] Humidity normal (40-55%) + energy-saving -> CLOSE window.")))
    (printout t "[VENT] humidity normal + energy-saving -> window CLOSE" crlf)
    (modify ?w (state closed))
)

; Night + home-sleep -> CLOSE window (comfort + security)
(defrule window-sleep-close
    (declare (salience 27))
    (occupancy (status home-sleep))
    ?w <- (device (name window) (state open))
    =>
    (assert (msg (text "[VENT] home-sleep -> CLOSE window (comfort/security).")))
    (printout t "[VENT] sleep -> window CLOSE" crlf)
    (modify ?w (state closed))
)
