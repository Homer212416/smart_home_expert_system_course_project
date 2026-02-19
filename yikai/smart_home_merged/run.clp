; ================================================
; Smart Home Expert System - Run Script
;
; Prerequisites: generate data files first:
;   python3 crawler.py       -> crawled_data.json  (outdoor weather)
;   python3 gen_env_facts.py -> env_data.json       (indoor sensors)
;   edit user_data.json      -> set per-day occupancy (sleep/awake/gone)
;   python3 gen_facts.py     -> facts.clp            (combined 10-day facts)
;
; Execute from the CLIPS prompt:
;   (batch "run.clp")
;
; Occupancy is loaded from user_data.json via facts.clp.
; To change it, edit user_data.json and re-run gen_facts.py, then batch again.
; To override interactively at the CLIPS prompt (not inside batch):
;   (set-occupancy-for-date "2026-02-15" sleep)
;   (set-all-occupancy gone)
;   (ask-all-occupancy)   <- then call (run) manually
; ================================================

(printout t "================================================" crlf)
(printout t "  Smart Home Expert System" crlf)
(printout t "================================================" crlf)
(printout t crlf)

; --- Load constructs ---
(load "templates.clp")
(load "user.clp")
(load "rules.clp")
(load "facts.clp")

; Initialize working memory (asserts all deffacts including occupancy)
(reset)

; Show occupancy loaded from facts.clp
(show-occupancy)

; Run the inference engine
(run)

; --- Summary: print all active device states ---
(printout t crlf)
(printout t "=== Device Status ===" crlf)
(do-for-all-facts ((?d device)) TRUE
    (printout t "  " (fact-slot-value ?d name) ": " (fact-slot-value ?d status) crlf)
)
(printout t "================================================" crlf)
