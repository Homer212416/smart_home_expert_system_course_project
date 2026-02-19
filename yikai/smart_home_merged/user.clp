; -----------------------------------------------
; User Input Functions - Per-Day Occupancy
; Requires: templates.clp loaded first
; -----------------------------------------------
; Occupancy is loaded per-day from facts.clp.
; Use these functions after (reset) to view or
; change any day's occupancy before (run).
;
; Quick reference:
;   (show-occupancy)
;   (set-occupancy-for-date "2026-02-15" sleep)
;   (set-all-occupancy gone)
;   (ask-all-occupancy)
; -----------------------------------------------


(deffunction set-occupancy-for-date (?date ?status)
    "Set occupancy for a specific date (sleep | awake | gone).
     Retracts the existing occupancy fact for that date before asserting the new one."
    (if (or (eq ?status sleep) (eq ?status awake) (eq ?status gone))
        then
            (do-for-all-facts ((?f occupancy))
                              (eq (fact-slot-value ?f date) ?date)
                (retract ?f))
            (assert (occupancy (date ?date) (status ?status)))
            (printout t "  " ?date " -> " ?status crlf)
        else
            (printout t "Invalid status '" ?status "'. Choose: sleep | awake | gone" crlf)
    )
)


(deffunction set-all-occupancy (?status)
    "Set every date to the same occupancy status."
    (if (or (eq ?status sleep) (eq ?status awake) (eq ?status gone))
        then
            (printout t "Setting all days to: " ?status crlf)
            (do-for-all-facts ((?e env)) TRUE
                (set-occupancy-for-date (fact-slot-value ?e date) ?status))
        else
            (printout t "Invalid status '" ?status "'. Choose: sleep | awake | gone" crlf)
    )
)


(deffunction show-occupancy ()
    "Print the current occupancy status for every date."
    (printout t "--- Occupancy by Date ---" crlf)
    (do-for-all-facts ((?e env)) TRUE
        (bind ?date (fact-slot-value ?e date))
        (bind ?status "(not set)")
        (do-for-fact ((?o occupancy)) (eq (fact-slot-value ?o date) ?date)
            (bind ?status (fact-slot-value ?o status)))
        (printout t "  " ?date ": " ?status crlf)
    )
    (printout t "-------------------------" crlf)
)


(deffunction ask-all-occupancy ()
    "Interactively set occupancy for every date.
     Prompts for each day in order; accepts: sleep | awake | gone."
    (printout t "=== Set Per-Day Occupancy ===" crlf)
    (show-occupancy)
    (printout t "Enter status for each day (sleep / awake / gone):" crlf)
    (do-for-all-facts ((?e env)) TRUE
        (bind ?date (fact-slot-value ?e date))
        (printout t "  " ?date ": ")
        (bind ?input (read stdin))
        (set-occupancy-for-date ?date ?input)
    )
    (printout t crlf)
    (show-occupancy)
)
