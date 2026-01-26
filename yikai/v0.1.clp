(deffacts init-facts
    (dates 25/1/2026 sunny -10 -20) ;f-1
    (dates 2/5/2026 sunny 11 14)   ;f-2
    (security ringing ringing 26/2/2025 10:25) ;f-3 security-alarm fire-alarm date time
    (curtain 7 summer 6/8/2025) ;f-4
    (curtain 17 winter 31/12/2025) ;f-4
)

(defrule heating-on
    (dates ?date ?weather ?temperature_high ?temperature_low 
    &:(and(<= ?temperature_high 15)(<= ?temperature_low 10)) 
    ) 
    =>
    (printout t ?date ": heating turned on!" crlf)
)

(defrule heating-off
    (dates ?date ?weather ?temperature_high ?temperature_low 
    &:(or(> ?temperature_high 15)(> ?temperature_low 10)) 
    ) 
    =>
    (printout t ?date ": heating turned off!" crlf)
)

(defrule ac-on
    (dates ?date ?weather ?temperature_high ?temperature_low 
    &:(and(>= ?temperature_high 32)(>= ?temperature_low 27)) 
    ) 
    =>
    (printout t ?date ": AC turned on!" crlf)
)

(defrule ac-on
    (dates ?date ?weather ?temperature_high ?temperature_low 
    &:(and(< ?temperature_high 32)(< ?temperature_low 27)) 
    ) 
    =>
    (printout t ?date ": AC turned off!" crlf)
)

(defrule break-in-detected
    (security ringing ? ?date ?time)
    =>
    (printout t "Emergency! Break-in detected at " ?time " on " ?date crlf)
)

(defrule fire-detected
    (security ? ringing ?date ?time)
    =>
    (printout t "Emergency! Fire detected at " ?time " on " ?date crlf)
)

(defrule open-curtain-summer
    (curtain ?time summer ?date
    &:(= ?time 7) 
    )
    => 
    (printout t ?date ": Open curtain at " ?time crlf)
)

(defrule close-curtain-summer
    (curtain ?time summer ?date
    &:(= ?time 19) 
    )
    => 
    (printout t ?date ": Close curtain at " ?time crlf)
)

(defrule close-curtain-summer
    (curtain ?time winter ?date
    &:(= ?time 8) 
    )
    => 
    (printout t ?date ": Open curtain at " ?time crlf)
)

(defrule close-curtain-summer
    (curtain ?time winter ?date
    &:(= ?time 17) 
    )
    => 
    (printout t ?date ": Close curtain at " ?time crlf)
)