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

    ; TODO2 add 5 CF slots
    ; Certainty Factors
    ; All subsequent CF rules will read these values directly from the environment variables
    (slot co-alarm-cf    (type FLOAT) (range 0.0 1.0) (default 0.85))
    (slot fire-alarm-cf  (type FLOAT) (range 0.0 1.0) (default 0.90))
    (slot occupancy-cf   (type FLOAT) (range 0.0 1.0) (default 0.75))
    (slot iaqi-cf        (type FLOAT) (range 0.0 1.0) (default 0.80))
    (slot aqhi-cf        (type FLOAT) (range 0.0 1.0) (default 0.70))
)

; controllable devices (alarms are sensors in env, not listed here)
(deftemplate device
    "Controllable devices"
    (slot date   (type STRING) (default "unknown"))
    (slot name   (allowed-values humidifier dehumidifier window air-purifier))
    (slot status (allowed-values on off) (default off))
)

(deftemplate thermostat
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

; TODO3 
; fuzzy-env is a new template used to store fuzzy memberships calculated from crisp values
; Fuzzy membership degrees — computed from crisp env values
(deftemplate fuzzy-env
    (slot date (type STRING) (default "unknown"))

    ; Temperature memberships
    (slot mu-temp-cold        (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-temp-cool        (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-temp-comfortable (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-temp-warm        (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-temp-hot         (type FLOAT) (range 0.0 1.0) (default 0.0))

    ; Humidity memberships
    (slot mu-hum-dry          (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-hum-comfortable  (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-hum-humid        (type FLOAT) (range 0.0 1.0) (default 0.0))

    ; AQHI memberships
    (slot mu-aqhi-good        (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-aqhi-moderate    (type FLOAT) (range 0.0 1.0) (default 0.0))
    (slot mu-aqhi-poor        (type FLOAT) (range 0.0 1.0) (default 0.0))

    ; Defuzzified output
    (slot fuzzy-target-temp   (type FLOAT) (range 10.0 30.0) (default 20.0))
)




