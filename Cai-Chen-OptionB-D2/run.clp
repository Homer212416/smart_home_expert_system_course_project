; ================================================
; Smart Home Expert System - Run Script  (D2 FuzzyCLIPS)
;
; Prerequisites: generate data files first:
;   python3 data_scripts/crawler.py              -> outdoor_data.json
;   python3 data_scripts/generate_indoor_facts.py -> generated_indoor_data.json
;   python3 data_scripts/combine_facts.py        -> facts.clp
;
; Execute with FuzzyCLIPS (NOT standard clips):
;   fzclips -f run.clp
;
; Or from the FuzzyCLIPS prompt:
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

(exit)