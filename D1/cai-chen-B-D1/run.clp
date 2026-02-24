; ================================================
; Smart Home Expert System - Run Script
;
; Prerequisites: generate data files first:
;   python3 crawler.py             -> outdoor_data.json        (outdoor weather)
;   python3 generate_indoor_facts.py -> generated_indoor_data.json (indoor sensors + occupancy)
;   python3 combine_facts.py       -> facts.clp                (combined 10-day env facts)
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
(load "rules.clp")
(load "facts.clp")

; Initialize working memory (asserts all deffacts including occupancy)
(reset)

; Run the inference engine
(run)
