; ===============================================
; Crawled Weather Data from Environment Canada
; Generated: 2026-02-10 19:35:37
; ===============================================

(deffacts crawled-weather-data "Real data from Environment Canada"
    (current-temp -12.5)
    (humidity 60)
    (AQHI 2)
    ; Static defaults for sensor-only data:
    (occupancy home)
    (sleep-status awake)
    (carbon-monoxide-alarm idle)
    (IAQI 85)
)
