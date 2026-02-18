; ================================================
; Smart Home Expert System - Run Script
;
; Prerequisites: generate data files first:
;   python3 crawler.py       -> crawled_facts.clp  (outdoor)
;   python3 gen_env_facts.py -> env_facts.clp      (indoor sensors + alarm signals)
;
; Execute from the CLIPS prompt:
;   (batch "run.clp")
; ================================================

(printout t "================================================" crlf)
(printout t "  Smart Home Expert System" crlf)
(printout t "================================================" crlf)
(printout t crlf)

; --- Load constructs ---
(load "templates.clp")
(load "user.clp")
(load "rules.clp")
(load "crawled_facts.clp")
(load "env_facts.clp")

; Initialize working memory (asserts all deffacts)
(reset)

; Prompt user for occupancy status
(ask-occupancy)
(printout t crlf)

; Run the inference engine
(run)

; --- Summary: print all active device states ---
(printout t crlf)
(printout t "=== Device Status ===" crlf)
(do-for-all-facts ((?d device)) TRUE
    (printout t "  " (fact-slot-value ?d name) ": " (fact-slot-value ?d status) crlf)
)
(printout t "================================================" crlf)
