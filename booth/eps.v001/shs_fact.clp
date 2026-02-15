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
    (slot temp     (allowed-values cold comfortable hot))
    (slot humidity (allowed-values dry normal humid))
    (slot light    (allowed-values dark normal bright))
    (slot outdoor  (allowed-values cold mild hot))
    (slot tod      (allowed-values morning afternoon evening night))
)

(deftemplate occupancy
    "Home occupancy status"
    (slot status (allowed-values occupied empty))
)

(deftemplate device
    "Device states"
    (slot name  (allowed-values heater ac window main-light ambient-light))
    (slot state)
)

(deftemplate user
    "User preferences"
    (slot lighting-pref (allowed-values warm cool))
    (slot priority      (allowed-values comfort-first energy-saving))
)

(deftemplate assessment
    "Derived assessments"
    (slot comfort (allowed-values comfortable uncomfortable unknown))
    (slot energy  (allowed-values efficient wasteful acceptable unknown))
)

; after result show why
(deftemplate msg
    "Explanation messages"
    (slot text)
)

; -------------------------
; Startup / Test Fact Set
; (You can change these)
; -------------------------

(deffacts startup-facts
    ; percepts
    (env (temp hot) (humidity humid) (light dark) (outdoor mild) (tod night))
    (occupancy (status occupied))

    ; devices
    (device (name heater)        (state off))
    (device (name ac)            (state off))
    (device (name window)        (state closed))
    (device (name main-light)    (state on))
    (device (name ambient-light) (state off))

    ; user preferences
    (user (lighting-pref warm) (priority energy-saving))

    ; initial assessment (unknown until rules derive)
    (assessment (comfort unknown) (energy unknown))
)


