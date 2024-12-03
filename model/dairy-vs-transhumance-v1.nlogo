;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GNU GENERAL PUBLIC LICENSE ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;  Dairy versus Transhumance model
;;  Copyright (C) 2024 Andreas ANGOURAKIS (andros.spica@gmail.com), Francesco Carrer, Marc Vander Linden
;;  Based on the 'Basic' template by Andreas Angourakis (andros.spica@gmail.com)
;;  last update Feb 2019
;;  available at https://www.github.com/Andros-Spica/abm-templates
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.
;;
;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;;;;;;;;;;;;;;;;
;;;;; BREEDS ;;;;
;;;;;;;;;;;;;;;;;

breed [ dairy-herds dairy-herd ]

breed [ transhumance-herds transhumance-herd ]

breed [ huts hut ]

;;;;;;;;;;;;;;;;;
;;; VARIABLES ;;;
;;;;;;;;;;;;;;;;;

globals
[
  ;;; constants

  ;;;; visualisation
  pixel-size

  ;;;; simulation control
  record_initial-lag
  record_sample-frequency
  record_equilibrium-threshold

  ;;;; true model constants
  length-of-grazing-season
  grazing-potential-max-recovery-rate

  grazing-rate-dairy
  grazing-rate-transhumance
  overgrazing-threshold

  dairy-hut-radius
  transhumance-max-speed

  ;;; parameters
  area-width
  area-height

  conflict-avoidance

  grazing-potential_max

  herd-size-dairy
  herd-size-transhumance
  number-herds-dairy
  number-herds-transhumance

  ;;; variables
  ;;;; auxiliar

  ; Calculated directly from parameters and kept constant:
  patch-count

  population-size-dairy
  population-size-transhumance

  dairy-pressure-coef
  transhumance-pressure-coef

  ; time tracking:

  day
  season

  ; used to calculate final measurements:

  total-grazing-potential_localMax

  record_total-grazing-potential
  record_grazing-land-use

  ;;;; Observers: counters and final measures

  total-grazing-potential

  grazing-land-use
  grazing-land-use_dairy
  grazing-land-use_transhumance

  unsustainable-state
  unsustainable-dairy-herds
  unsustainable-transhumance-herds

  dairy-hut-count
  total-occupation-layers
]

;;; agents variables

dairy-herds-own
[
  ;;; Input: given properties
  head-count
  grazing-requirement_day
  ;;; Output: state
  current-hut
  unsustainable
]

transhumance-herds-own
[
  ;;; Input: given properties
  head-count
  grazing-requirement_day
  ;;; Output: state
  unsustainable
]

huts-own
[
  ;;; Input: given properties
  owner
  ;;; Output: state
  occupation-layers
]

patches-own
[
  ;;; Input: given properties
  grazing-potential_localmax
  ;;; Output: state
  grazing-potential
  grazed
  land-use
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup

  clear-all

  set-constants

  set-parameters

  initialise-time-counters

  setup-patches

  setup-herds

  initialise-observers

  update-observers

  refresh-view

  reset-ticks

end

to set-constants

  ; "constants" are variables that will not be explored as parameters
  ; and may be used during a simulation.

  set pixel-size 1 ; hectare
  set-patch-size 12

  set record_initial-lag 20 ;;; initial seasons not added to the record
  set record_sample-frequency 20 ;;; sample a record every X seasons
  set record_equilibrium-threshold 5 ;;; standard deviation units

  set length-of-grazing-season 90 ; days
  set grazing-potential-max-recovery-rate 0.5

  set grazing-rate-dairy 1
  set grazing-rate-transhumance 0.25
  set overgrazing-threshold 10

  set dairy-hut-radius 5
  set transhumance-max-speed 10

end

to set-parameters

  ; set random seed
  random-seed seed

  ; check parameters values
  parameters-check

  set area-width gui_area-width ; 50
  set area-height gui_area-height ;25
  resize-world 0 (area-width - 1) 0 (area-height - 1)

  ;;; setup parameters depending on the type of experiment
  if (type-of-experiment = "user-defined")
  [
    ;;; load parameters from user interface
    set conflict-avoidance gui_conflict-avoidance

    set grazing-potential_max gui_grazing-potential_max

    set herd-size-dairy gui_herd-size-dairy
    set herd-size-transhumance gui_herd-size-transhumance
    set number-herds-dairy gui_number-herds-dairy
    set number-herds-transhumance gui_number-herds-transhumance
  ]
  if (type-of-experiment = "random")
  [
    ;;; use values from user interface as a maximum for random uniform distributions
    set conflict-avoidance gui_conflict-avoidance

    set grazing-potential_max 1 + random-float gui_grazing-potential_max

    set herd-size-dairy 1 + random gui_herd-size-dairy
    set herd-size-transhumance 1 + random gui_herd-size-transhumance
    set number-herds-dairy random gui_number-herds-dairy
    set number-herds-transhumance random gui_number-herds-transhumance
  ]

end

to parameters-check

  ;;; check if values were reset to 0 (NetLogo does that from time to time...!)
  ;;; and set default values (assuming they are not 0)
  if (gui_grazing-potential_max = 0)    [ set gui_grazing-potential_max     250 ]

  ;;; initial parameter check (e.g., avoiding division per zero error)
  check-par-is-positive "gui_area-width" gui_area-width
  check-par-is-positive "gui_area-height" gui_area-height
  check-par-is-positive "gui_herd-size-dairy" gui_herd-size-dairy
  check-par-is-positive "gui_herd-size-transhumancey" gui_herd-size-transhumance
  check-par-is-positive "gui_number-herds-dairy" gui_number-herds-dairy
  check-par-is-positive "gui_number-herds-transhumance" gui_number-herds-transhumance

end

to check-par-is-positive [ parName parValue ]

  if (parValue <= 0)
  [
    print (word "ERROR: " parName " must be greater than zero")
    stop
  ]

end

to initialise-observers

  set patch-count count patches

  set population-size-dairy sum [head-count] of dairy-herds
  set population-size-transhumance sum [head-count] of transhumance-herds

  set dairy-hut-count 0
  set total-occupation-layers 0

  set total-grazing-potential 100
  set grazing-land-use 0
  set grazing-land-use_dairy 0
  set grazing-land-use_transhumance 0

  set record_total-grazing-potential []
  set record_grazing-land-use []

  set unsustainable-state false

  set unsustainable-dairy-herds 0
  set unsustainable-transhumance-herds 0

  set total-grazing-potential_localMax (sum [grazing-potential_localmax] of patches)

  set dairy-pressure-coef length-of-grazing-season * grazing-rate-dairy * population-size-dairy / total-grazing-potential_localMax
  set transhumance-pressure-coef length-of-grazing-season * grazing-rate-transhumance * population-size-transhumance / total-grazing-potential_localMax

end

to initialise-time-counters

  set day 0
  set season 1

end

to setup-patches

  ;;; set patches variables
  ask patches
  [
    set grazed false

    ;set grazing-potential_localmax (random-float ((pxcor - min-pxcor) / world-width)) * (random-float ((pycor - min-pycor) / world-height)) * grazing-potential_max
    ;set grazing-potential_localmax random-float 1 * random-float 1 * grazing-potential_max
    set grazing-potential_localmax random-float grazing-potential_max
  ]

  diffuse grazing-potential_localmax 0.2

  ask patches
  [
    set grazing-potential grazing-potential_localmax
  ]

end

to setup-herds

  ;;; create dairy herds
  create-dairy-herds number-herds-dairy
  [
    set head-count herd-size-dairy

    set grazing-requirement_day grazing-rate-dairy * head-count

    set current-hut nobody

    set unsustainable false

    set shape "cow"
  ]

  ;;; create transhumant herds
  create-transhumance-herds number-herds-transhumance
  [
    set head-count herd-size-transhumance

    set grazing-requirement_day grazing-rate-transhumance * head-count

    set unsustainable false

    set shape "sheep"
  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GO ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go

  update-time-counters

  if (day = 1)
  [ recover-grazing-potentials ]

  update-herds

  update-observers

  refresh-view

  if (day = 1 and (unsustainable-state or is-equilibrium-reached))
  [ stop ]

  tick

end

;;; GLOBAL ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-time-counters

  set day day + 1

  if (day > length-of-grazing-season)
  [
    set season season + 1

    set day 1
  ]

end

to recover-grazing-potentials

  ask patches
  [
    recover-grazing-potential
  ]

end

to reset-land-use

  ask patches
  [
    set grazed false
  ]

end

to update-herds

  ask (turtle-set dairy-herds transhumance-herds) ;;; complete scheduling shuffle
  [
    ifelse (breed = dairy-herds)
    [
      ;;; dairy herd behaviour
      if (day = 1)
      [
        ;;; return to hut or get a new one
        dairy-herd_set-hut
      ]

      dairy-herd_graze
    ]
    [
      ;;; transhumance herd behaviour
      if (day = 1)
      [
        ;;; return to a random patch at the edge
        transhumance-herd_enter
      ]

      transhumance-herd_graze
    ]
  ]

end

to-report get-grazing-potential-at-distance [ radius ]

  ;;; grazing potential returned already accounts for the overgrazing-threshold
  report sum [max (list 0 (grazing-potential - overgrazing-threshold))] of patches in-radius radius

end

to-report get-mean-grazing-potential-at-distance [ radius ]

  ;;; grazing potential returned already accounts for the overgrazing-threshold
  report mean [max (list 0 (grazing-potential - overgrazing-threshold))] of patches in-radius radius

end

;;; PATCHES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to recover-grazing-potential

  ;;; logistic/densitiy-dependent
  set grazing-potential grazing-potential + grazing-potential-max-recovery-rate * grazing-potential * (1 - (grazing-potential / grazing-potential_localmax))
  ;;; linear
  ;set grazing-potential min (list grazing-potential_localmax (grazing-potential + grazing-potential-max-recovery-rate * grazing-potential_localmax))

end

;;; AGENTS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to dairy-herd_set-hut

  let me self

  ;;; return to current hut (no action needed)
  ;;; check if it not sufficiently recovered
  if (current-hut != nobody)
  [
    ;;; evaluate the sustainability of the herd around the current hut
    ;;; and abandon it if unsustainble
    let currentHutPotential [get-mean-grazing-potential-at-distance dairy-hut-radius] of current-hut
    if (currentHutPotential < grazing-requirement_day * length-of-grazing-season)
    [
      ;;; abandon hut
      ask current-hut [ set shape "flag" ]
      set current-hut nobody
    ]
  ]

  ;;; if hutless, choose new hut location
  if (current-hut = nobody)
  [
    ;;; consider re-using old huts?

    let bestHutLocation max-one-of patches [grazing-potential]
    ask bestHutLocation
    [
      ifelse (any? huts-here)
      [
        ask one-of huts-here
        [
          set owner me

          set occupation-layers occupation-layers + 1

          set shape "house"
        ]
      ]
      [
        sprout-huts 1
        [
          set owner me

          set occupation-layers 1

          set shape "house"

          hut-shift-display
        ]
      ]
    ]
    move-to bestHutLocation
    dairy-herd-shift-display

    set current-hut one-of huts-here
  ]

end

to dairy-herd_graze

  ;;; choose new grazing location
  ;;; 1. within transhumance-max-speed from the current position
  ;;; 2. best grazing potential
  ;;; 3. flag unsustainable state if no location found

  ;;; choose grazing location(s) around current hut (within dairy-hut-radius)
  let validPatches patches in-radius dairy-hut-radius

  ifelse (count validPatches > 0)
  [
    let bestGrazingLocation max-one-of validPatches [grazing-potential]

    graze bestGrazingLocation "dairy"
  ]
  [
    if (print-messages)
    [
      print (word self " unsustainble! No valid patches to graze")
    ]
    set unsustainable true
  ]

end

to transhumance-herd_enter

  let bestLocation max-one-of patches with [count neighbors < 8 and count (turtle-set dairy-herds-here transhumance-herds-here) = 0] [grazing-potential]

  move-to bestLocation

end

to transhumance-herd_graze

  ;;; choose new grazing location
  ;;; 1. among the conflict-free patches and
  ;;; 2. within transhumance-max-speed from the current position
  ;;; 3. best grazing potential
  ;;; 3. flag unsustainable state if no location found

  let validPatches patches
  if (conflict-avoidance)
  [
    set validPatches patches with [ min [distance myself] of dairy-herds > dairy-hut-radius ]
  ]

  set validPatches validPatches in-radius transhumance-max-speed

  ifelse (count validPatches > 0)
  [
    let bestGrazingLocation max-one-of validPatches [grazing-potential]

    move-to bestGrazingLocation

    graze bestGrazingLocation "transhumance"
  ]
  [
    if (print-messages)
    [
      print (word self " unsustainble! No valid patches to graze")
    ]
    set unsustainable true
  ]

end

to graze [ aPatch landUse ]

  let me self

  ;;; graze until satisfaction or flag as unsustainable
  ask aPatch
  [
    if (print-messages)
    [
      print (word me ": " grazing-potential " vs " ([grazing-requirement_day] of me))
    ]

    set grazing-potential grazing-potential - [grazing-requirement_day] of me

    set grazed true
    set land-use landUse

    if (grazing-potential < overgrazing-threshold)
    [
      if (print-messages)
      [
        print (word me " unsustainble! " grazing-potential " less than " overgrazing-threshold)
      ]
      ask me [ set unsustainable true ]
    ]
  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; OBSERVERS: COUNTERS AND MEASURES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-observers

  set dairy-hut-count count huts
  set total-occupation-layers sum [occupation-layers] of huts

  set total-grazing-potential 100 * (sum [grazing-potential] of patches) / total-grazing-potential_localMax
  set grazing-land-use 100 * (count patches with [grazed]) / (count patches)
  set grazing-land-use_dairy 100 * (count patches with [land-use = "dairy"]) / (count patches)
  set grazing-land-use_transhumance 100 * (count patches with [land-use = "transhumance"]) / (count patches)

  if (season > record_initial-lag and day = 1 and remainder season record_sample-frequency = 1)
  [
    set record_total-grazing-potential lput total-grazing-potential record_total-grazing-potential
    set record_grazing-land-use lput grazing-land-use record_grazing-land-use
  ]

  let unsustaibleSituation any? (turtle-set dairy-herds transhumance-herds) with [unsustainable]
  if (unsustaibleSituation)
  [ set unsustainable-state true ]

  set unsustainable-dairy-herds 100 * (count dairy-herds with [unsustainable]) / number-herds-dairy
  set unsustainable-transhumance-herds 100 * (count transhumance-herds with [unsustainable]) / number-herds-transhumance

end

to-report is-equilibrium-reached

  let value false

  if (length record_total-grazing-potential > 3) ;;; minimum 3 measurements sampled
  [
    ;;; check if the variation in the record is less than a certain percentage of the maximum value
    let condition1 standard-deviation record_total-grazing-potential < record_equilibrium-threshold
    let condition2 standard-deviation record_grazing-land-use < record_equilibrium-threshold

    set value condition1 and condition2
  ]

  report value

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DISPLAY ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to refresh-view

  if (display-mode = "grazing-potential")
  [
    ask patches
    [
      set pcolor 68 - 6 * (grazing-potential / grazing-potential_max)
    ]
  ]

  if (display-mode = "grazed")
  [
    ask patches
    [
      ifelse (grazed)
      [
        ifelse (land-use = "dairy")
        [ set pcolor cyan ]
        [ set pcolor pink ]
      ]
      [
        set pcolor grey
      ]
    ]
  ]

  ask huts
  [
    set size 1 + patch-size * 3 * occupation-layers / (1E-6 + total-occupation-layers)
  ]

end

to hut-shift-display

  set heading 45
  fd 0.5

end

to dairy-herd-shift-display

  set heading -135
  fd 0.5

end

to plot-season-start

  if (day = 1)
  [ plotxy ticks plot-y-max ]

end

to plot-mean-and-range [ aListOfValues ]

  if (length aListOfValues > 1)
  [
    create-temporary-plot-pen "mean"
    set-plot-pen-color black
    plot-pen-down
    plotxy ticks mean aListOfValues
    plot-pen-up

    create-temporary-plot-pen "min"
    set-plot-pen-color grey
    plot-pen-down
    plotxy ticks min aListOfValues
    plot-pen-up

    create-temporary-plot-pen "max"
    set-plot-pen-color grey
    plot-pen-down
    plotxy ticks max aListOfValues
    plot-pen-up
  ]

end

to plot-hut-occupation-layers

  let hutWhosColorsAndOccupationLayers []

  ask huts
  [
    set hutWhosColorsAndOccupationLayers lput (list who color occupation-layers) hutWhosColorsAndOccupationLayers
  ]

  plot-variable-per-pen hutWhosColorsAndOccupationLayers

end

to plot-variable-per-pen [ whosColorsAndValues ]

  foreach whosColorsAndValues
  [
    i ->
    create-temporary-plot-pen (word (item 0 i) "")
    set-plot-pen-color (item 1 i)
    set-plot-pen-mode 0 ;;; line
    plot-pen-down
    plotxy ticks (item 2 i)
    plot-pen-up
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
293
22
889
319
-1
-1
12.0
1
10
1
1
1
0
0
0
1
0
48
0
23
0
0
1
ticks
30.0

BUTTON
9
10
64
43
NIL
setup
NIL
1
T
OBSERVER
NIL
1
NIL
NIL
1

BUTTON
138
10
193
43
NIL
go
T
1
T
OBSERVER
NIL
3
NIL
NIL
1

INPUTBOX
182
139
282
199
seed
0.0
1
0
Number

CHOOSER
34
90
172
135
type-of-experiment
type-of-experiment
"user-defined" "random"
0

SLIDER
10
579
287
612
gui_grazing-potential_max
gui_grazing-potential_max
0
500
250.0
1
1
(default: 250)
HORIZONTAL

PLOT
923
104
1210
336
Grazing potential local maxima
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"set-histogram-num-bars 20\nset-plot-x-range -0.01 (0.01 + ceiling max [grazing-potential_localmax] of patches)" "set-histogram-num-bars 20\nset-plot-x-range -0.01 (0.01 + ceiling max [grazing-potential_localmax] of patches)"
PENS
"default" 1.0 1 -16777216 true "" "histogram [grazing-potential_localmax] of patches"

MONITOR
202
10
284
55
NIL
day
0
1
11

MONITOR
78
615
221
660
NIL
grazing-potential_max
5
1
11

BUTTON
82
10
137
43
NIL
go
NIL
1
T
OBSERVER
NIL
2
NIL
NIL
1

MONITOR
148
687
264
732
NIL
population-size-dairy
3
1
11

MONITOR
76
273
255
318
NIL
population-size-transhumance
17
1
11

SLIDER
6
240
286
273
gui_herd-size-dairy
gui_herd-size-dairy
0
100
10.0
1
1
(default: 20)
HORIZONTAL

MONITOR
76
273
255
318
NIL
herd-size-dairy
17
1
11

SLIDER
5
317
285
350
gui_herd-size-transhumance
gui_herd-size-transhumance
0
200
25.0
1
1
(default: 50)
HORIZONTAL

MONITOR
75
350
254
395
NIL
herd-size-transhumance
17
1
11

SLIDER
6
406
286
439
gui_number-herds-dairy
gui_number-herds-dairy
0
10
5.0
1
1
(default: 5)
HORIZONTAL

MONITOR
76
439
255
484
NIL
number-herds-dairy
17
1
11

SLIDER
7
484
287
517
gui_number-herds-transhumance
gui_number-herds-transhumance
0
20
5.0
1
1
(default: 10)
HORIZONTAL

MONITOR
77
517
256
562
NIL
number-herds-transhumance
17
1
11

MONITOR
203
58
260
103
NIL
season
17
1
11

PLOT
293
349
1217
529
Grazing
days (in grazing season) 
percentage
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"dairy (% patches)" 1.0 1 -11221820 true "" "plot grazing-land-use_dairy + grazing-land-use_transhumance"
"transhumance (% patches)" 1.0 1 -2064490 true "" "plot grazing-land-use_transhumance"
"Potential (% local max)" 1.0 0 -12087248 true "" "plot total-grazing-potential"
"season start" 1.0 1 -7500403 true "" "plot-season-start"

MONITOR
418
688
529
733
NIL
count dairy-herds
17
1
11

MONITOR
601
688
763
733
NIL
count transhumance-herds
17
1
11

MONITOR
151
740
290
785
NIL
length-of-grazing-season
17
1
11

MONITOR
291
740
480
785
NIL
grazing-potential-max-recovery-rate
17
1
11

MONITOR
479
739
601
784
NIL
overgrazing-threshold
17
1
11

MONITOR
601
740
689
785
NIL
dairy-hut-radius
17
1
11

CHOOSER
928
23
1070
68
display-mode
display-mode
"grazing-potential" "grazed"
1

BUTTON
1089
28
1191
61
NIL
refresh-view
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
529
688
601
733
NIL
count huts
17
1
11

PLOT
293
532
1091
690
Hut occupation layers (mean, min, max)
days (in season)
count per hut
0.0
10.0
0.0
10.0
true
false
"" "plot-mean-and-range ([occupation-layers] of huts)\n;plot-hut-occupation-layers"
PENS

MONITOR
764
689
905
734
NIL
total-occupation-layers
17
1
11

MONITOR
1092
440
1217
485
total-grazing-potential
precision total-grazing-potential 2
17
1
11

MONITOR
1094
487
1218
532
grazing-land-use
precision grazing-land-use 2
17
1
11

MONITOR
1096
546
1219
591
NIL
unsustainable-state
17
1
11

MONITOR
689
740
826
785
NIL
transhumance-max-speed
17
1
11

MONITOR
826
740
939
785
NIL
grazing-rate-dairy
17
1
11

MONITOR
937
740
1103
785
NIL
grazing-rate-transhumance
17
1
11

TEXTBOX
30
748
137
773
Constants:
20
0.0
1

MONITOR
264
687
419
732
NIL
population-size-transhumance
17
1
11

TEXTBOX
32
689
182
714
Observers:
20
0.0
1

SWITCH
54
204
233
237
gui_conflict-avoidance
gui_conflict-avoidance
0
1
-1000

BUTTON
37
50
103
83
go season
repeat (length-of-grazing-season - day + 1) [ go ]
NIL
1
T
OBSERVER
NIL
4
NIL
NIL
1

BUTTON
102
50
171
83
go season
repeat (length-of-grazing-season - day + 1) [ go ]
T
1
T
OBSERVER
NIL
5
NIL
NIL
1

MONITOR
905
689
1026
734
dairy-pressure-coef
precision dairy-pressure-coef 4
17
1
11

MONITOR
1029
689
1186
734
transhumance-pressure-coef
precision transhumance-pressure-coef 4
17
1
11

INPUTBOX
8
140
91
200
gui_area-width
49.0
1
0
Number

INPUTBOX
90
140
177
200
gui_area-height
24.0
1
0
Number

MONITOR
1096
591
1277
636
NIL
unsustainable-dairy-herds
17
1
11

MONITOR
1096
637
1278
682
NIL
unsustainable-transhumance-herds
17
1
11

SWITCH
175
102
292
135
print-messages
print-messages
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="random-params-exploration" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>;;; params (sampled)</metric>
    <metric>conflict-avoidance</metric>
    <metric>grazing-potential_max</metric>
    <metric>herd-size-dairy</metric>
    <metric>herd-size-transhumance</metric>
    <metric>number-herds-dairy</metric>
    <metric>number-herds-transhumance</metric>
    <metric>;;; variables</metric>
    <metric>;;;; auxiliar</metric>
    <metric>day</metric>
    <metric>season</metric>
    <metric>;;;; Observers: counters and final measures</metric>
    <metric>population-size-dairy</metric>
    <metric>population-size-transhumance</metric>
    <metric>dairy-hut-count</metric>
    <metric>total-occupation-layers</metric>
    <metric>total-grazing-potential</metric>
    <metric>grazing-land-use</metric>
    <metric>grazing-intensity_mean</metric>
    <metric>grazing-intensity_sd</metric>
    <metric>record_total-grazing-potential</metric>
    <metric>record_grazing-land-use</metric>
    <metric>unsustainable-state</metric>
    <steppedValueSet variable="seed" first="0" step="1" last="99"/>
    <enumeratedValueSet variable="type-of-experiment">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gui_conflict-avoidance">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gui_grazing-potential_max">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gui_herd-size-dairy">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gui_number-herds-dairy">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gui_herd-size-transhumance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gui_number-herds-transhumance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-mode">
      <value value="&quot;grazing-potential&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
