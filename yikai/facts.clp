; ===============================================
; Smart Home Expert System - Test Cases
; ===============================================
; This file contains different scenarios (cases)
; to test the smart home expert system.
; Load only ONE case at a time by uncommenting it.
; ===============================================

; ===============================================
; CASE 1: Normal Day - Awake and at Home
; ===============================================
; Person is awake, at home, with good conditions

;(deffacts case-1 "Normal day - awake and at home"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 40)
;    (carbon-monoxide-alarm idle)
;    (IAQI 85)
;    (AQHI 3)
;    (current-temp 18)
;)

; ===============================================
; CASE 2: Sleeping at Night
; ===============================================
; Person is sleeping, humidity and air quality good

;(deffacts case-2 "Sleeping at night"
;    (occupancy home)
;    (sleep-status sleeping)
;    (humidity 45)
;    (carbon-monoxide-alarm idle)
;    (IAQI 90)
;    (AQHI 2)
;    (current-temp 22)
;)

; ===============================================
; CASE 3: Away from Home - Short Trip
; ===============================================
; Person is away for 3 hours

;(deffacts case-3 "Away from home - short trip"
;    (occupancy away)
;    (sleep-status awake)
;    (humidity 42)
;    (carbon-monoxide-alarm idle)
;    (IAQI 82)
;    (AQHI 4)
;    (current-temp 20)
;    (absence-duration 3)
;)

; ===============================================
; CASE 4: Away from Home - Day Trip
; ===============================================
; Person is away for 8 hours

;(deffacts case-4 "Away from home - day trip"
;    (occupancy away)
;    (sleep-status awake)
;    (humidity 38)
;    (carbon-monoxide-alarm idle)
;    (IAQI 78)
;    (AQHI 5)
;    (current-temp 26)
;    (absence-duration 8)
;)

; ===============================================
; CASE 5: Away from Home - Vacation
; ===============================================
; Person is away for 48 hours (2 days)

;(deffacts case-5 "Away from home - vacation"
;    (occupancy away)
;    (sleep-status awake)
;    (humidity 35)
;    (carbon-monoxide-alarm idle)
;    (IAQI 75)
;    (AQHI 3)
;    (current-temp 27)
;    (absence-duration 48)
;)

; ===============================================
; CASE 6: Low Humidity Problem
; ===============================================
; Humidity is too low (winter problem)

;(deffacts case-6 "Low humidity problem"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 25)
;    (carbon-monoxide-alarm idle)
;    (IAQI 80)
;    (AQHI 2)
;    (current-temp 20)
;)

; ===============================================
; CASE 7: High Humidity Problem
; ===============================================
; Humidity is too high (can cause mould)

;(deffacts case-7 "High humidity problem"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 65)
;    (carbon-monoxide-alarm idle)
;    (IAQI 70)
;    (AQHI 3)
;    (current-temp 20)
;)

; ===============================================
; CASE 8: Carbon Monoxide Emergency
; ===============================================
; CRITICAL: CO alarm is triggered

;(deffacts case-8 "Carbon monoxide emergency"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 40)
;    (carbon-monoxide-alarm alert)
;    (IAQI 85)
;    (AQHI 3)
;    (current-temp 20)
;)

; ===============================================
; CASE 9: Poor Indoor Air Quality - Moderate
; ===============================================
; Indoor air quality is in the moderate range

;(deffacts case-9 "Poor indoor air - moderate"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 42)
;    (carbon-monoxide-alarm idle)
;    (IAQI 70)
;    (AQHI 3)
;    (current-temp 20)
;)

; ===============================================
; CASE 10: Poor Indoor Air Quality - Polluted
; ===============================================
; Indoor air quality is polluted

;(deffacts case-10 "Poor indoor air - polluted"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 45)
;    (carbon-monoxide-alarm idle)
;    (IAQI 50)
;    (AQHI 3)
;    (current-temp 20)
;)

; ===============================================
; CASE 11: Poor Indoor Air Quality - Very Polluted
; ===============================================
; Indoor air quality is very polluted

;(deffacts case-11 "Poor indoor air - very polluted"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 45)
;    (carbon-monoxide-alarm idle)
;    (IAQI 30)
;    (AQHI 2)
;    (current-temp 20)
;)

; ===============================================
; CASE 12: Poor Indoor Air Quality - Severely Polluted
; ===============================================
; Indoor air quality is severely polluted

;(deffacts case-12 "Poor indoor air - severely polluted"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 45)
;    (carbon-monoxide-alarm idle)
;    (IAQI 15)
;    (AQHI 2)
;    (current-temp 20)
;)

; ===============================================
; CASE 13: Poor Outdoor Air Quality - Wildfire
; ===============================================
; Outdoor air quality is poor (e.g., wildfire smoke)

;(deffacts case-13 "Poor outdoor air - wildfire"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 40)
;    (carbon-monoxide-alarm idle)
;    (IAQI 85)
;    (AQHI 8)
;    (current-temp 20)
;)

; ===============================================
; CASE 14: Both Indoor and Outdoor Air Poor
; ===============================================
; Both indoor and outdoor air quality are poor

;(deffacts case-14 "Both indoor and outdoor air poor"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 45)
;    (carbon-monoxide-alarm idle)
;    (IAQI 55)
;    (AQHI 9)
;    (current-temp 20)
;)

; ===============================================
; CASE 15: High Humidity and Poor Indoor Air
; ===============================================
; Combination of high humidity and poor air quality

;(deffacts case-15 "High humidity and poor indoor air"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 58)
;    (carbon-monoxide-alarm idle)
;    (IAQI 52)
;    (AQHI 4)
;    (current-temp 20)
;)

; ===============================================
; CASE 16: Hot Summer Day - Occupied
; ===============================================
; Hot day, person at home, needs cooling

(deffacts case-16 "Hot summer day - occupied"
    (occupancy home)
    (sleep-status awake)
    (humidity 48)
    (carbon-monoxide-alarm idle)
    (IAQI 82)
    (AQHI 3)
    (current-temp 28)
)

; ===============================================
; CASE 17: Multiple Issues Combined
; ===============================================
; Low humidity, moderate indoor air, high outdoor air

;(deffacts case-17 "Multiple issues combined"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 28)
;    (carbon-monoxide-alarm idle)
;    (IAQI 68)
;    (AQHI 7)
;    (current-temp 19)
;)

; ===============================================
; CASE 18: Winter Night - Sleeping
; ===============================================
; Cold winter night, person sleeping, low humidity

;(deffacts case-18 "Winter night - sleeping"
;    (occupancy home)
;    (sleep-status sleeping)
;    (humidity 26)
;    (carbon-monoxide-alarm idle)
;    (IAQI 88)
;    (AQHI 2)
;    (current-temp 15)
;)

; ===============================================
; CASE 19: Perfect Conditions
; ===============================================
; Everything is optimal

;(deffacts case-19 "Perfect conditions"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 45)
;    (carbon-monoxide-alarm idle)
;    (IAQI 95)
;    (AQHI 2)
;    (current-temp 20)
;)

; ===============================================
; CASE 20: Worst Case Scenario
; ===============================================
; Multiple critical issues at once

;(deffacts case-20 "Worst case scenario"
;    (occupancy home)
;    (sleep-status awake)
;    (humidity 68)
;    (carbon-monoxide-alarm alert)
;    (IAQI 18)
;    (AQHI 10)
;    (current-temp 16)
;)

; ===============================================
; INSTRUCTIONS:
; ===============================================
; 1. Uncomment ONE case at a time (remove the ; symbols)
; 2. Make sure all other cases are commented out
; 3. Load this file: (load "test-cases.clp")
; 4. Load the main system: (load "smart-home.clp")
; 5. Reset: (reset)
; 6. Run: (run)
; ===============================================
