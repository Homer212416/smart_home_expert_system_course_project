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
