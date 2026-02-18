; =========================
; testRunner.clp
; Run all scenarios automatically (CLIPSDOS-safe)
; =========================

(deffunction print-device-states ()
  (printout t "---- Device States ----" crlf)
  (bind ?ds (find-all-facts ((?d device)) TRUE))
  (bind ?n (length$ ?ds))
  (bind ?i 1)
  (while (<= ?i ?n) do
    (bind ?d (nth$ ?i ?ds))
    (printout t "device=" (fact-slot-value ?d name)
                " power=" (fact-slot-value ?d power)
                " position=" (fact-slot-value ?d position) crlf)
    (bind ?i (+ ?i 1))
  )
  (printout t "-----------------------" crlf crlf)
)

(deffunction run-one-scenario (?label ?temp ?hum ?outdoor ?tod ?IAQI ?AQHI ?occ ?coLevel)
  (printout t crlf "===============================" crlf)
  (printout t "SCENARIO: " ?label crlf)
  (printout t "===============================" crlf)

  (reset)

  (assert (env (temp ?temp) (humidity ?hum) (outdoor ?outdoor) (tod ?tod) (IAQI ?IAQI) (AQHI ?AQHI)))
  (assert (occupancy (status ?occ)))
  (assert (carbon-monoxide-alarm (power on) (level ?coLevel)))

  (run)

  (print-device-states)
)

(deffunction run-all-scenarios ()
  (run-one-scenario "hot-humid" 30 75 mild night 120 7 home-awake low)
  (run-one-scenario "cold-dry" 18 30 cold morning 40 2 home-awake low)
  (run-one-scenario "air-bad-close-window" 24 50 mild afternoon 200 8 home-awake low) ; not showing message fixed
  (run-one-scenario "co-high" 22 45 mild evening 60 3 home-awake high)
  (run-one-scenario "outside" 28 55 mild afternoon 80 4 outside low)  ; not showing message
  ; testing
  ; (run-one-scenario "freezing-night-home" -5 40 cold night 35 2 home-asleep low)
  ; (run-one-scenario "hot-clean-air" 32 45 hot afternoon 30 1 home-awake low)
  ; (run-one-scenario "humid-only" 23 90 mild evening 50 3 home-awake low)
  ; (run-one-scenario "toxic-air" 24 50 mild afternoon 350 9 home-awake low)
  ; (run-one-scenario "empty-house-energy-save" 31 80 hot afternoon 100 5 outside low)

  (printout t "All scenarios done." crlf)
)
