; ---------
; Templates
; ---------

; data from sensors
(deftemplate env
    ; indoor data
    (slot date      (type STRING)  (default "unknown"))
    (slot temp      (type INTEGER) (range -100 100) (default 23))
    (slot humidity  (type INTEGER) (range 0 100)    (default 45))
    (slot IAQI      (type INTEGER) (range 0 500)    (default 50)) ; Indoor Air Quality Index
    (slot co-alarm   (allowed-values on off) (default off)) ; carbon monoxide sensor
    (slot fire-alarm (allowed-values on off) (default off)) ; smoke / fire sensor
    (slot occupancy (allowed-values sleep awake gone) (default awake))
    (slot season    (allowed-values winter spring summer fall) (default winter))
    ; outdoor data
    (slot high-temp (type INTEGER) (range -100 100)) ; outdoor high temp
    (slot low-temp  (type INTEGER) (range -100 100)) ; outdoor low temp
    (slot AQHI      (type INTEGER) (range 1 11) (default 3)) ; outdoor Air Quality Health Index
)

; controllable devices (alarms are sensors in env, not listed here)
(deftemplate device
    "Controllable devices"
    (slot date   (type STRING) (default "unknown"))
    (slot name   (allowed-values humidifier dehumidifier window air-purifier))
    (slot status (allowed-values on off) (default off))
)

(deftemplate themostat
    "Thermostat settings"
    (slot date       (type STRING) (default "unknown"))
    (slot mode       (allowed-values heat cool off) (default off))
    (slot target-temp (type INTEGER) (range 10 30) (default 22))
)

; after result show why
(deftemplate msg
    "Explanation messages"
    (slot date (type STRING) (default "general")) ; date the triggering data came from
    (slot text)
)

; ================================================
; templates.clp  (D1 + D2 coexist version)
; Keep all original templates, then ADD these below
; ================================================

; ---------- D2 mode switch ----------
(deftemplate system-flag
   (slot name))

; ---------- D2 uncertain intermediate facts ----------
(deftemplate belief
    "Intermediate uncertain conclusion"
    (slot date   (type STRING) (default "unknown"))
    (slot type)
    (slot cf     (type FLOAT) (range 0.0 1.0))
    (slot source (type STRING) (default "rule"))
)

(deftemplate advice
    "Recommended action with certainty factor"
    (slot date   (type STRING) (default "unknown"))
    (slot action)
    (slot cf     (type FLOAT) (range 0.0 1.0))
    (slot reason (type STRING) (default ""))
)






