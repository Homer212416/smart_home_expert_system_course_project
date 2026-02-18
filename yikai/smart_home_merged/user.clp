; -----------------------------------------------
; User Input Functions
; Requires: templates.clp loaded first
; -----------------------------------------------

(deffunction set-occupancy (?status)
    "Set occupancy to sleep, awake, or gone.
     Retracts any existing occupancy fact before asserting the new one."
    (if (or (eq ?status sleep) (eq ?status awake) (eq ?status gone))
        then
            (do-for-all-facts ((?f occupancy)) TRUE
                (retract ?f))
            (assert (occupancy (status ?status)))
            (printout t "Occupancy set to: " ?status crlf)
        else
            (printout t "Invalid status '" ?status "'. Choose: sleep | awake | gone" crlf)
    )
)

(deffunction ask-occupancy ()
    "Prompt the user to enter their status interactively."
    (printout t "Enter your status (sleep / awake / gone): ")
    (bind ?input (read))
    (set-occupancy ?input)
)
