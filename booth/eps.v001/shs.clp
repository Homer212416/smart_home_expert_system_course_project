; ========= templates =========
(deftemplate env
  (slot temp (type NUMBER))     ; take numbers
  (slot humidity (type NUMBER)) ; take number % 
  (slot light (type SYMBOL))
  (slot outdoor (type SYMBOL))
  (slot time (type SYMBOL))
  (slot season (type SYMBOL))
  (slot occupied (type SYMBOL))
  (slot user-priority (type SYMBOL))
  (slot lighting (type SYMBOL))
  (slot window (type SYMBOL))
)

(deftemplate device
  (slot name (type SYMBOL))
  (slot state (type SYMBOL)) ; on/off
)

; ========= facts =========
(deffacts startup-facts
    (env 
        (temp 32) 
        (humidity 68) 
        (light dark) 
        (outdoor mild)
        (time night) 
        (occupied yes) 
        (season summer)
        (user-priority energy-saving) 
        (lighting warm) 
        (window closed)
    )

    (device 
        (name ac) 
        (state off)
    )

    (device 
        (name heater) 
        (state off)
    )
)

; ========= AC rules =========
(defrule ac-turn-on-when-hot-in-summer
    ?e <- (env (temp ?t) (season summer)) ; can just use (env (temp ?t) (season summer)), but we may need to modify it so i put ?e
    ?ac <- (device (name ac) (state off))
    (test (> ?t 32)) 
    =>
    (printout t "Temp = " ?t " > 32 in SUMMER -> AC ON" crlf)
    (modify ?ac (state on)) ; turn on ac
)

(defrule ac-turn-off-at-setpoint
    ?e <- (env (temp ?t) (season summer))
    ?ac <- (device (name ac) (state on))
    (test (<= ?t 23))
    =>
    (printout t "Temp = " ?t " <= 23 -> AC OFF" crlf)
    (modify ?ac (state off)) ; turn ac off
)

; ========= heater rules =========
(defrule heater-turn-on-when-cold-in-winter
    ?e <- (env (temp ?t) (season winter))
    ?h <- (device (name heater) (state off))
    (test (< ?t 6))
    =>
    (printout t "Temp = " ?t " < 6 in WINTER -> HEATER ON" crlf)
    (modify ?h (state on)) ; turn on heater
)

(defrule heater-turn-off-at-setpoint
    ?e <- (env (temp ?t) (season winter))
    ?h <- (device (name heater) (state on))
    (test (>= ?t 23))
    =>
    (printout t "Temp = " ?t " >= 23 -> HEATER OFF" crlf)
    (modify ?h (state off)) ; turn off heater
)

; ========= humidifier rules =========
(defrule humidifier-turn-on-when-too-dry
    (env (humidity ?hum))
    ?d <- (device (name humidifier) (state off))
    (test (< ?hum 30))
    =>
    (printout t "Humidity = " ?hum "% < 30% -> HUMIDIFIER ON" crlf)
    (modify ?d (state on))
)

(defrule humidifier-turn-off-when-normal
    (env (humidity ?hum))
    ?d <- (device (name humidifier) (state on))
    (test (>= ?hum 45))
    =>
    (printout t "Humidity = " ?hum "% >= 45% -> HUMIDIFIER OFF" crlf)
    (modify ?d (state off))
)

; ========= lighting rules =========
