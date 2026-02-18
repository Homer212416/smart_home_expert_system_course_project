; ---------
; Templates
; ---------


(deftemplate env
    "Environment percepts"
    (slot temp     (type INTEGER) (range -100 100)(default 23))
    (slot humidity (type INTEGER) (range 0 100)(default 45))

    (slot outdor-high-temp (type INTEGER) (range -100 100)) ; outdoor high temp
    (slot outdoor-low-temp (type INTEGER) (range -100 100)) ; outdoor low temp

    (slot IAQI     (type INTEGER) (range 0 500)(default 50)) ; Indoor Air Quality Index 
    (slot AQHI     (type INTEGER) (range 1 11)(default 3)) ; outdoor Air Quality Health Index (1-10, 10+ is very high risk)
)

; devices 
(deftemplate device
    "Controllable devices"
    (slot name (allowed-values heater air-conditioner humidifier dehumidifier window carbon-monoxide-alarm fire-alarm))
    (slot status (allowed-values on off) (default off))
)

; after result show why
(deftemplate msg
    "Explanation messages"
    (slot text)
)





