; =========================
; dataFact.clp
; Test scenarios (only inputs: env + occupancy + optional alarm overrides)
; =========================

(deffacts scenario-hot-humid
  (env (temp 30) (humidity 75) (outdoor mild) (tod night) (IAQI 120) (AQHI 7))
  (occupancy (status home-awake))
  (carbon-monoxide-alarm (power on) (level low))
)

(deffacts scenario-cold-dry
  (env (temp 18) (humidity 30) (outdoor cold) (tod morning) (IAQI 40) (AQHI 2))
  (occupancy (status home-awake))
  (carbon-monoxide-alarm (power on) (level low))
)

(deffacts scenario-air-bad-close-window
  (env (temp 24) (humidity 50) (outdoor mild) (tod afternoon) (IAQI 200) (AQHI 8))
  (occupancy (status home-awake))
  (carbon-monoxide-alarm (power on) (level low))
)

; temp = 22, which satisfies <= 24, so it will close the window that was just opened.
; Then once the window closes, safety-co-high-open-window will open the window again
; fix
; When CO levels are high, disable the “close windows after comfort” rule.

(deffacts scenario-co-high
  (env (temp 22) (humidity 45) (outdoor mild) (tod evening) (IAQI 60) (AQHI 3))
  (occupancy (status home-awake))
  (carbon-monoxide-alarm (power on) (level high))
)

(deffacts scenario-outside
  (env (temp 28) (humidity 55) (outdoor mild) (tod afternoon) (IAQI 80) (AQHI 4))
  (occupancy (status outside))
  (carbon-monoxide-alarm (power on) (level low))
)
