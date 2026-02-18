; ---------
; Templates
; ---------

; data from sensors
(deftemplate env
    "Environment percepts"
    (slot date      (type STRING)  (default "unknown"))
    (slot temp      (type INTEGER) (range -100 100) (default 23))
    (slot humidity  (type INTEGER) (range 0 100)    (default 45))
    (slot IAQI      (type INTEGER) (range 0 500)    (default 50)) ; Indoor Air Quality Index
    (slot co-alarm   (allowed-values on off) (default off)) ; carbon monoxide sensor
    (slot fire-alarm (allowed-values on off) (default off)) ; smoke / fire sensor
)

; data from government agency
(deftemplate outdoor
    (slot date      (type STRING)  (default "unknown"))
    (slot high-temp (type INTEGER) (range -100 100)) ; outdoor high temp
    (slot low-temp  (type INTEGER) (range -100 100)) ; outdoor low temp
    (slot AQHI      (type INTEGER) (range 1 11) (default 3)) ; outdoor Air Quality Health Index
)

; input from user
(deftemplate occupancy
    "Home occupancy status"
    (slot status (allowed-values sleep awake gone))
)

; controllable devices (alarms are sensors in env, not listed here)
(deftemplate device
    "Controllable devices"
    (slot name   (allowed-values heater air-conditioner humidifier dehumidifier window))
    (slot status (allowed-values on off) (default off))
)

; after result show why
(deftemplate msg
    "Explanation messages"
    (slot date (type STRING) (default "general")) ; date the triggering data came from
    (slot text)
)






