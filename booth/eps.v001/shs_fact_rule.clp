(deffacts startup-facts
    (temperature hot)
    (humidity humid)
    (light dark)
    (outdoor mild)
    (time night)
    (occupied yes)
    (season winter)
    (user-priority energy-saving)
    (lighting-pref warm)
    (window closed)
)

; -------------------------
; Comfort / Temperature rules
; -------------------------

(defrule comfort-temp-hot
    (temperature hot)
    =>
    (printout t "[Comfort] Temperature is HOT -> may feel uncomfortable." crlf)
)

(defrule comfort-temp-cold
    (temperature cold)
    =>
    (printout t "[Comfort] Temperature is COLD -> may feel uncomfortable." crlf)
)

(defrule advise-heater-when-cold-winter
    (temperature cold)
    (season winter)
    (occupied yes)
    =>
    (printout t "[Advice] Winter + occupied + cold -> turn ON heater." crlf)
)

(defrule advise-ac-when-hot-summer
    (temperature hot)
    (season summer)
    (occupied yes)
    =>
    (printout t "[Advice] Summer + occupied + hot -> consider AC cooling." crlf)
)

(defrule advise-window-when-hot-outdoor-mild-energy
    (temperature hot)
    (outdoor mild)
    (user-priority energy-saving)
    (occupied yes)
    =>
    (printout t "[Advice] Indoor hot + outdoor mild + energy-saving -> open window first (instead of AC)." crlf)
)

(defrule warn-window-open-bad-when-cold-winter
    (temperature cold)
    (season winter)
    (window closed) ; even if closed, we can still warn as policy
    =>
    (printout t "[Policy] Winter + cold -> keep window CLOSED to avoid heat loss." crlf)
)

(defrule policy-occupied-general-comfort
    (occupied yes)
    =>
    (printout t "[Info] Home is occupied -> comfort actions are allowed." crlf)
)

; -------------------------
; Humidity rules
; -------------------------

(defrule comfort-humidity-humid
    (humidity humid)
    =>
    (printout t "[Comfort] Humidity is HUMID -> may feel uncomfortable." crlf)
)

(defrule comfort-humidity-too-low
    (humidity hulow)
    =>
    (printout t "[Comfort] Humidity is LOW -> may cause dryness." crlf)
)

(defrule comfort-humidity-too-high
    (humidity huhigh)
    =>
    (printout t "[Comfort] Humidity is HIGH -> may cause mold risk." crlf)
)

(defrule advise-ventilation-when-humid-mild
    (humidity humid)
    (outdoor mild)
    (occupied yes)
    =>
    (printout t "[Advice] Humid + outdoor mild -> open window periodically." crlf)
)

(defrule warn-humidity-high-winter
    (humidity huhigh)
    (season winter)
    =>
    (printout t "[Warning] High humidity in winter -> watch for condensation on windows." crlf)
)

(defrule advise-humidity-low-winter
    (humidity hulow)
    (season winter)
    =>
    (printout t "[Advice] Low humidity in winter -> consider humidifier." crlf)
)

; -------------------------
; Lighting / Time rules
; -------------------------

(defrule lighting-dark
    (light dark)
    (time night)
    (occupied yes)
    =>
    (printout t "[Lighting] It is dark -> lights may be needed." crlf)
)

(defrule night-mode-general
    (time night)
    =>
    (printout t "[Mode] Night mode -> prefer softer lighting." crlf)
)

(defrule night-warm-preference
    (time night)
    (lighting-pref warm)
    =>
    (printout t "[Advice] Night + warm preference -> use WARM ambient light." crlf)
)

(defrule energy-saving-night-lighting
    (time night)
    (light dark)
    (user-priority energy-saving)
    =>
    (printout t "[Advice] Night + dark + energy-saving -> use ambient light instead of strong main light." crlf)
)

(defrule winter-dark-earlier
    (season winter)
    (time night)
    =>
    (printout t "[Info] Winter nights are long -> plan lighting for comfort + energy." crlf)
)

; -------------------------
; Energy / Priority rules
; -------------------------

(defrule policy-energy-saving
    (user-priority energy-saving)
    =>
    (printout t "[Policy] Priority: ENERGY-SAVING -> choose low-energy actions first." crlf)
)

(defrule advise-energy-saving-hot
    (user-priority energy-saving)
    (temperature hot)
    =>
    (printout t "[Advice] Energy-saving + hot -> try shade/ventilation before AC." crlf)
)

(defrule advise-energy-saving-cold
    (user-priority energy-saving)
    (temperature cold)
    =>
    (printout t "[Advice] Energy-saving + cold -> close window, use heater efficiently." crlf)
)

(defrule advise-energy-saving-humidity
    (user-priority energy-saving)
    (humidity huhigh)
    =>
    (printout t "[Advice] Energy-saving + high humidity -> short burst ventilation is better than long open window." crlf)
)

; -------------------------
; Window rules
; -------------------------

(defrule window-state-closed
    (window closed)
    =>
    (printout t "[State] Window is CLOSED." crlf)
)

(defrule advise-open-window-not-at-night-if-mild-and_hot
    (not (time night))
    (temperature hot)
    (outdoor mild)
    =>
    (printout t "[Advice] Not night + indoor hot + outdoor mild -> open window for cooling (if safe)." crlf)
)

(defrule advise-keep-window-closed-when-humidity-high
    (humidity huhigh)
    (window closed)
    =>
    (printout t "[Advice] High humidity -> keep window mostly CLOSED; ventilate strategically." crlf)
)

; -------------------------
; Season-specific guidance
; -------------------------

(defrule season-winter-general
    (season winter)
    =>
    (printout t "[Season] WINTER -> reduce heat loss, manage dry air." crlf)
)

(defrule season-summer-general
    (season summer)
    =>
    (printout t "[Season] SUMMER -> manage heat gain, prevent overcooling." crlf)
)

(defrule summer-humidity-note
    (season summer)
    (humidity humid)
    =>
    (printout t "[Note] Summer + humid -> dehumidifying/ventilation improves comfort." crlf)
)

(defrule winter-cold-note
    (season winter)
    (temperature cold)
    =>
    (printout t "[Note] Winter + cold -> heating is main comfort lever." crlf)
)
