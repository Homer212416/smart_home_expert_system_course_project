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
    (slot co-alarm   (allowed-values on off) (default off))       ; carbon monoxide sensor
    (slot fire-alarm (allowed-values on off) (default off))       ; smoke / fire sensor
    (slot occupancy (allowed-values sleep awake gone) (default awake))
    (slot season    (allowed-values winter spring summer fall) (default winter))
    ; outdoor data
    (slot high-temp (type INTEGER) (range -100 100))
    (slot low-temp  (type INTEGER) (range -100 100))
    (slot AQHI      (type INTEGER) (range 1 11) (default 3))      ; Air Quality Health Index

    ; -------
    ; Certainty Factors  (0.0 = no confidence, 1.0 = full confidence)
    (slot co-alarm-cf    (type FLOAT) (range 0.0 1.0) (default 0.85))
    (slot fire-alarm-cf  (type FLOAT) (range 0.0 1.0) (default 0.90))
    (slot occupancy-cf   (type FLOAT) (range 0.0 1.0) (default 0.75))
    (slot iaqi-cf        (type FLOAT) (range 0.0 1.0) (default 0.80))
    (slot aqhi-cf        (type FLOAT) (range 0.0 1.0) (default 0.70))
    ; -------
)

; controllable devices
(deftemplate device
    "Controllable devices"
    (slot date   (type STRING) (default "unknown"))
    (slot name   (allowed-values humidifier dehumidifier window air-purifier))
    (slot status (allowed-values on off) (default off))
)

(deftemplate themostat
    "Thermostat settings"
    (slot date        (type STRING)  (default "unknown"))
    (slot mode        (allowed-values heat cool off) (default off))
    (slot target-temp (type INTEGER) (range 10 30)  (default 22))
)

; explanation messages (grouped by date for output)
(deftemplate msg
    "Explanation messages"
    (slot date (type STRING) (default "general"))
    (slot text)
)


; =====================================================
; FuzzyCLIPS Fuzzy Deftemplates
;
; These define linguistic variables for sensor readings
; using FuzzyCLIPS-native standard function shapes:
;
;   (z  a c)   Z-function : 1 at u<=a, ramps to 0 at u=c
;   (s  a c)   S-function : 0 at u<=a, ramps to 1 at u=c
;   (pi d b)   PI-function: bell centred at b, half-width d
;                           (0 at b-d and b+d, 1 at b)
;
; Reference: FuzzyCLIPS 6.10d User Guide §6.1.1.2
; Run with: fzclips -f run.clp
; =====================================================

; Indoor temperature  (universe: -10 … 35 °C)
(deftemplate fz-temp  -10 35  Celsius
  (
    (cold        (z  10 20))   ; μ=1 at ≤10°C; μ=0 at 20°C
    (cool        (pi  5 15))   ; bell peak at 15°C; zeros at 10 and 20°C
    (comfortable (pi  3 21))   ; bell peak at 21°C; zeros at 18 and 24°C
    (warm        (pi  3 25))   ; bell peak at 25°C; zeros at 22 and 28°C
    (hot         (s  26 35))   ; μ=0 at 26°C; μ=1 at 35°C
  )
)

; Indoor relative humidity  (universe: 0 … 100 %)
(deftemplate fz-humidity  0 100  percent
  (
    (dry         (z  20 35))   ; μ=1 at ≤20%; μ=0 at 35%
    (comfortable (pi 10 40))   ; bell peak at 40%; zeros at 30 and 50%
    (humid       (s  50 70))   ; μ=0 at 50%; μ=1 at 70%
  )
)

; Outdoor Air Quality Health Index  (universe: 1 … 10)
(deftemplate fz-aqhi  1 10  index
  (
    (good        (z   2  5))   ; μ=1 at AQHI≤2; μ=0 at 5
    (moderate    (pi  2  5))   ; bell peak at AQHI=5; zeros at 3 and 7
    (poor        (s   5  9))   ; μ=0 at AQHI=5; μ=1 at 9
  )
)


; =====================================================
; fuzzy-env — per-day record of fuzzified sensor values
;
; Populated at salience 80 by the fuzzify-env rule.
; Stores FuzzyCLIPS-computed membership degrees for
; every primary term, plus the dominant linguistic
; label (argmax) for use in downstream pattern matching.
; =====================================================
(deftemplate fuzzy-env
  (slot date                (type STRING) (default "unknown"))
  ; temperature memberships
  (slot mu-cold             (type FLOAT)  (range 0.0 1.0) (default 0.0))
  (slot mu-cool             (type FLOAT)  (range 0.0 1.0) (default 0.0))
  (slot mu-comfortable-temp (type FLOAT)  (range 0.0 1.0) (default 0.0))
  (slot mu-warm             (type FLOAT)  (range 0.0 1.0) (default 0.0))
  (slot mu-hot              (type FLOAT)  (range 0.0 1.0) (default 0.0))
  ; humidity memberships
  (slot mu-dry              (type FLOAT)  (range 0.0 1.0) (default 0.0))
  (slot mu-comfortable-hum  (type FLOAT)  (range 0.0 1.0) (default 0.0))
  (slot mu-humid            (type FLOAT)  (range 0.0 1.0) (default 0.0))
  ; outdoor AQHI memberships
  (slot mu-aqhi-good        (type FLOAT)  (range 0.0 1.0) (default 0.0))
  (slot mu-aqhi-moderate    (type FLOAT)  (range 0.0 1.0) (default 0.0))
  (slot mu-aqhi-poor        (type FLOAT)  (range 0.0 1.0) (default 0.0))
  ; dominant linguistic labels (argmax over each variable's terms)
  (slot temp-label          (type STRING) (default "comfortable"))
  (slot hum-label           (type STRING) (default "comfortable"))
  (slot aqhi-label          (type STRING) (default "good"))
)
