; =========================
; facts.clp
; Smart Home Expert System - Factbase (Templates + Startup Facts)
; =========================

; ---------
; Templates
; ---------

; env is template name, "Environment percepts" is documentation string
; slot something is attribute
; allowed-values is constraint, temp only can take value cold / comfortable / hot
; template is same like class
(deftemplate env
    "Environment percepts"
    (slot temp     (type INTEGER) (range -40 60)(default 23))
    (slot humidity (type INTEGER) (range 0 100)(default 45))

    ; light: environment brightness
    (slot light    (allowed-values dark normal bright))
    (slot outdoor  (allowed-values cold mild hot))
    (slot tod      (allowed-values morning afternoon evening night))

    ; Air quality
    (slot IAQI     (type INTEGER) (default 50)) ; didnt check valid number just put some number for placeholder
    (slot AQHI     (type INTEGER) (default 3))
)

(deftemplate occupancy
    "Home occupancy status"
    ; make values explicit + consistent
    (slot status (allowed-values home-sleep home-awake outside))
)

; safe
(deftemplate carbon-monoxide-alarm
    "Carbon Monoxide Alarm Status"
    (slot power (allowed-values on off) (default on))
    (slot level (allowed-values low medium high) (default low))
)

(deftemplate fire-alarm
    "Fire alarm device and alarm status"
    (slot power       (allowed-values on off) (default on))     ; turn on or not
    (slot triggered   (allowed-values yes no) (default no))     ; is fire or not
    (slot sounding    (allowed-values yes no) (default no))     ; is sounding or not
)

; Devices controlled
(deftemplate device
  "Controllable devices"
  (slot name
        (allowed-values heater ac humidifier dehumidifier window light))
  (slot state
        (allowed-values on off open closed))
)

; user setting
; user setting neet to check is valid or not
; or do not allow to setting some important setting, like safe
(deftemplate user
    "User preferences"
    ; lighting-pref is preference
    (slot lighting-pref (allowed-values dark normal bright) (default normal))
    (slot priority      (allowed-values comfort-first energy-saving)) ; maybe delete this one?

    ; allow user setting temp or humidity? user input need to be valid
    (slot temp-pref     (type INTEGER) (range 10 35) (default 23))   ; target temp
    (slot humidity-pref (type INTEGER) (range 0 100) (default 45))   ; target humidity %
)

; we dont need this 
; (deftemplate assessment
;   "Derived assessments (system conclusions)"
;   (slot comfort (allowed-values ok warning bad) (default ok))
;   (slot energy  (allowed-values ok warning bad) (default ok))
;   (slot safety  (allowed-values ok warning danger) (default ok))
;   (slot air     (allowed-values ok warning bad) (default ok))
; )


; after result show why
(deftemplate msg
    "Explanation messages"
    (slot text)
)

; -------------------------
; Startup / Test Fact Set
; -------------------------

; current just for test
; 
(deffacts startup-facts
    ; --- percepts ---
    ; current just for test, should read from env(maybe a txt file)
    (env
        (temp 30)
        (humidity 75)
        (light dark)
        (outdoor mild)
        (tod night)
        (IAQI 120)
        (AQHI 7)
    )

    ; must match allowed-values
    (occupancy (status home-awake))

    ; --- safety devices ---
    (carbon-monoxide-alarm (power on) (level low))
    (fire-alarm (power on) (triggered no) (sounding no))

    ; --- devices (initial states) ---
    (device (name heater)        (state off))
    (device (name ac)            (state off))
    (device (name humidifier)    (state off))
    (device (name dehumidifier)  (state off))
    (device (name window)        (state closed))
    (device (name light)    (state off))

    ; --- user preferences ---
    ; current just for test, should read from user
    (user (lighting-pref normal) (priority energy-saving) (temp-pref 23) (humidity-pref 45))
)




