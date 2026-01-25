(deffacts init-facts
    (dates 25/1/2026 sunny -10 -20) ;f-1
    (dates 2/5/2026 sunny 11 14)   ;f-2
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

