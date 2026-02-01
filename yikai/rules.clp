; ===============================================
; Smart Home Expert System
; ===============================================
; This expert system manages home climate control
; based on occupancy, sleep status, humidity,
; air quality, and safety conditions
; ===============================================

; ===============================================
; DEFFACTS - Initial Facts
; ===============================================

(deffacts initial-state "Initial home conditions"
    (occupancy home)           ; home or away
    (sleep-status awake)       ; awake or sleeping
    (humidity 45)              ; percentage
    (carbon-monoxide-alarm idle) ; idle or alert
    (IAQI 85)                  ; Indoor Air Quality Index (0-100)
    (AQHI 3)                   ; Air Quality Health Index (1-10)
    (current-temp 18)          ; current temperature in Celsius
)

; ===============================================
; RULES - Temperature Control
; ===============================================

(defrule set-temp-sleeping
    "Set temperature to 17°C when sleeping"
    (sleep-status sleeping)
    =>
    (printout t "Recommendation: Set thermostat to 17°C (sleeping)" crlf)
    (assert (recommended-temp 17))
)

(defrule set-temp-away
    "Set temperature to 17°C when away from home"
    (occupancy away)
    (sleep-status awake)
    =>
    (printout t "Recommendation: Set thermostat to 17°C (away from home)" crlf)
    (assert (recommended-temp 17))
)

(defrule set-temp-awake-home
    "Set temperature to 20°C when awake and at home"
    (occupancy home)
    (sleep-status awake)
    =>
    (printout t "Recommendation: Set thermostat to 20°C (awake and at home)" crlf)
    (assert (recommended-temp 20))
)

; ===============================================
; RULES - Humidity Control
; ===============================================

(defrule humidity-too-low
    "Alert when humidity is below 30%"
    (humidity ?h&:(< ?h 30))
    =>
    (printout t "WARNING: Humidity is too low (" ?h "%). Turn on humidifier." crlf)
    (printout t "Low humidity may cause skin allergies and respiratory infections." crlf)
    (assert (action use-humidifier))
)

(defrule humidity-too-high
    "Alert when humidity is above 50%"
    (humidity ?h&:(> ?h 50))
    =>
    (printout t "WARNING: Humidity is too high (" ?h "%). Turn on dehumidifier." crlf)
    (printout t "High humidity can lead to mould." crlf)
    (assert (action use-dehumidifier))
)

(defrule humidity-normal
    "Confirm when humidity is in healthy range"
    (humidity ?h&:(>= ?h 30)&:(<= ?h 50))
    =>
    (printout t "Humidity level is healthy (" ?h "%)." crlf)
)

; ===============================================
; RULES - Carbon Monoxide Safety
; ===============================================

(defrule carbon-monoxide-alert
    "Emergency alert for carbon monoxide detection"
    (carbon-monoxide-alarm alert)
    =>
    (printout t "EMERGENCY: Carbon monoxide detected!" crlf)
    (printout t "Evacuate immediately and call emergency services!" crlf)
    (printout t "CO exposure can cause tiredness, headaches, chest pain, or death." crlf)
    (assert (emergency evacuate))
)

(defrule carbon-monoxide-safe
    "Confirm CO levels are safe"
    (carbon-monoxide-alarm idle)
    =>
    (printout t "Carbon monoxide levels: Safe" crlf)
)

; ===============================================
; RULES - Indoor Air Quality (IAQI)
; ===============================================

(defrule iaqi-good
    "Indoor air quality is good"
    (IAQI ?i&:(>= ?i 81))
    =>
    (printout t "Indoor Air Quality: Good (IAQI: " ?i ")" crlf)
)

(defrule iaqi-moderate
    "Indoor air quality is moderate"
    (IAQI ?i&:(>= ?i 61)&:(< ?i 81))
    =>
    (printout t "Indoor Air Quality: Moderate (IAQI: " ?i ")" crlf)
    (printout t "Consider improving ventilation." crlf)
)

(defrule iaqi-polluted
    "Indoor air quality is polluted"
    (IAQI ?i&:(>= ?i 41)&:(< ?i 61))
    =>
    (printout t "WARNING: Indoor Air Quality is Polluted (IAQI: " ?i ")" crlf)
    (printout t "Improve ventilation and reduce pollution sources." crlf)
    (assert (action improve-ventilation))
)

(defrule iaqi-very-polluted
    "Indoor air quality is very polluted"
    (IAQI ?i&:(>= ?i 21)&:(< ?i 41))
    =>
    (printout t "ALERT: Indoor Air Quality is Very Polluted (IAQI: " ?i ")" crlf)
    (printout t "Take immediate action to improve air quality!" crlf)
    (assert (action improve-ventilation))
)

(defrule iaqi-severely-polluted
    "Indoor air quality is severely polluted"
    (IAQI ?i&:(< ?i 21))
    =>
    (printout t "CRITICAL: Indoor Air Quality is Severely Polluted (IAQI: " ?i ")" crlf)
    (printout t "Urgent action required to improve air quality!" crlf)
    (assert (action improve-ventilation))
)

; ===============================================
; RULES - Outdoor Air Quality (AQHI)
; ===============================================

(defrule aqhi-good
    "Outdoor air quality is good - safe to open windows"
    (AQHI ?a&:(<= ?a 3))
    =>
    (printout t "Outdoor Air Quality: Low risk (AQHI: " ?a ")" crlf)
    (printout t "Safe to open windows for ventilation." crlf)
)

(defrule aqhi-moderate
    "Outdoor air quality is moderate"
    (AQHI ?a&:(> ?a 3)&:(<= ?a 6))
    =>
    (printout t "Outdoor Air Quality: Moderate risk (AQHI: " ?a ")" crlf)
    (printout t "Consider keeping windows closed if sensitive to air quality." crlf)
)

(defrule aqhi-poor
    "Outdoor air quality is poor - keep windows closed"
    (AQHI ?a&:(> ?a 6))
    =>
    (printout t "WARNING: Outdoor Air Quality is Poor (AQHI: " ?a ")" crlf)
    (printout t "Keep windows closed. Ensure windows, doors, and skylights are sealed." crlf)
    (assert (action close-windows))
)

; ===============================================
; RULES - Cooling System (Summer)
; ===============================================

(defrule cooling-occupied
    "Set AC to comfortable temperature when occupied"
    (occupancy home)
    (current-temp ?t&:(> ?t 25.5))
    =>
    (printout t "Recommendation: Set AC to 25.5°C (occupied space)" crlf)
    (assert (recommended-cooling-temp 25.5))
)

(defrule cooling-short-absence
    "Adjust AC for short absence (less than 4 hours)"
    (occupancy away)
    (absence-duration ?d&:(< ?d 4))
    (current-temp ?t&:(> ?t 28))
    =>
    (printout t "Space occupied soon. Keep AC at moderate setting." crlf)
)

(defrule cooling-long-absence
    "Set AC higher for long absence (4-24 hours)"
    (occupancy away)
    (absence-duration ?d&:(>= ?d 4)&:(< ?d 24))
    =>
    (printout t "Recommendation: Set AC to 28°C (away 4-24 hours)" crlf)
    (assert (recommended-cooling-temp 28))
)

(defrule cooling-extended-absence
    "Turn off AC for extended absence (24+ hours)"
    (occupancy away)
    (absence-duration ?d&:(>= ?d 24))
    =>
    (printout t "Recommendation: Turn off AC (away 24+ hours)" crlf)
    (assert (action turn-off-cooling))
)

; ===============================================
; RULES - Combined Conditions
; ===============================================

(defrule poor-indoor-and-outdoor-air
    "Both indoor and outdoor air quality are poor"
    (IAQI ?i&:(< ?i 61))
    (AQHI ?a&:(> ?a 6))
    =>
    (printout t "ALERT: Both indoor and outdoor air quality are poor." crlf)
    (printout t "Keep windows closed and use air purifier if available." crlf)
    (assert (action use-air-purifier))
)

(defrule high-humidity-and-poor-ventilation
    "High humidity combined with poor air quality"
    (humidity ?h&:(> ?h 50))
    (IAQI ?i&:(< ?i 61))
    =>
    (printout t "WARNING: High humidity and poor air quality detected." crlf)
    (printout t "Use dehumidifier and improve ventilation carefully." crlf)
)

; ===============================================
; End of Smart Home Expert System
; ===============================================
