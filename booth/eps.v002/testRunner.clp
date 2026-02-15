; ; =========================
; ; test_runner.clp
; ; Run all scenarios automatically
; ; =========================

; ; 打印当前设备状态（heater/ac/humidifier/dehumidifier/window）
; (deffunction print-device-states ()
;   (printout t "---- Device States ----" crlf)
;   (do-for-all-facts ((?d device)) TRUE
;     (printout t "device=" (?d:get-slot name)
;                 " power=" (?d:get-slot power)
;                 " position=" (?d:get-slot position) crlf))
;   (printout t "-----------------------" crlf crlf)
; )

; ; 跑一个 scenario：reset + assert inputs + run + print states
; (deffunction run-one-scenario (?label ?temp ?hum ?outdoor ?tod ?IAQI ?AQHI ?occ ?coLevel)
;   (printout t crlf "===============================" crlf)
;   (printout t "SCENARIO: " ?label crlf)
;   (printout t "===============================" crlf)

;   ; 1) 清空工作记忆并加载 startup-facts
;   (reset)

;   ; 2) assert 本场景输入（env + occupancy + CO）
;   (assert (env (temp ?temp) (humidity ?hum) (outdoor ?outdoor) (tod ?tod) (IAQI ?IAQI) (AQHI ?AQHI)))
;   (assert (occupancy (status ?occ)))
;   (assert (carbon-monoxide-alarm (power on) (level ?coLevel)))

;   ; 3) 执行规则（你的 print-msg 会自动打印 msg）
;   (run)

;   ; 4) 打印最终设备状态
;   (print-device-states)
; )

; ; 一次跑完你 dataFact 里的 5 个 scenario
; (deffunction run-all-scenarios ()
;   (run-one-scenario "hot-humid"
;                     30 75 mild night 120 7 home-awake low)

;   (run-one-scenario "cold-dry"
;                     18 30 cold morning 40 2 home-awake low)

;   (run-one-scenario "air-bad-close-window"
;                     24 50 mild afternoon 200 8 home-awake low)

;   (run-one-scenario "co-high"
;                     22 45 mild evening 60 3 home-awake high)

;   (run-one-scenario "outside"
;                     28 55 mild afternoon 80 4 outside low)

;   (printout t "All scenarios done." crlf)
; )

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
  (run-one-scenario "air-bad-close-window" 24 50 mild afternoon 200 8 home-awake low)
  (run-one-scenario "co-high" 22 45 mild evening 60 3 home-awake high)
  (run-one-scenario "outside" 28 55 mild afternoon 80 4 outside low)

  (printout t "All scenarios done." crlf)
)
