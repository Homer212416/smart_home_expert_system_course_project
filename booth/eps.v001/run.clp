; =========================
; run.clp
; Smart Home Expert System
; Entry point
; =========================
; use (batch "c:\\Users\\Booth\\Desktop\\eps\\run.clp") to run 
(clear)

(load "c:\\Users\\Booth\\Desktop\\eps\\fact.clp")
(load "c:\\Users\\Booth\\Desktop\\eps\\rule.clp")

; do not have code yet
(load "C:\Users\Booth\Desktop\eps\load-day-from-txt.clp")

(reset)

; for test
(load-day-txt "days/2026-02-06.txt")