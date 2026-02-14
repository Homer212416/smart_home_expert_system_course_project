; ===============================================
; Crawled Weather Data from Environment Canada
; Generated: 2026-02-14 17:53:15
; ===============================================

(deffacts crawled-weather-data "Real data from Environment Canada"
    (current-temp -9.6)
    (humidity 78)
    (AQHI 3)
    ; Static defaults for sensor-only data:
    (occupancy home)
    (sleep-status awake)
    (carbon-monoxide-alarm idle)
    (IAQI 85)
)
