extensions [
  csv
  matrix
]


globals [

]

breed [Governments Government]
breed [PoRs PoR] ; Port of Rotterdam
breed [Industries Industry]
breed [Storages Storage] ; Storage points
undirected-link-breed [Pipelines Pipeline]

Governments-own [
  subsidy ; int [eur] - Total available subsidy
  co2-price ; int [eur / ton of co2] - Price of CO2 emissions
  oil-price ; int [eur / ton of oil] - Price of oil consumption
  electricity-price ; int [eur / MWh] - Price of electricity
]

PoRs-own [
  connection-price ; int [eur] - Cost to connect to pipeline (1000000 euros)
  pipeline-availability ; double [ton of CO2 / yr] - Unused pipeline capacity
  opex-extensible ; int [eur / ton of CO2] - Price that industries pay to use the extensible pipelines of the PoR
  opex-fixed ; int [eur / ton of CO2] - Price that industries pay to use the fixed pipelines of the PoR
  budget ; int [eur] - Port of Rotterdams budget

]

Industries-own [
  oil-demand ; int [ton of oil / yr] - Oil demanded by industry
  co2-emissions-oil ; double [ton of CO2 / ton of oil] - CO2 emitted per ton of oil by industry
  co2-emissions ; double [ton of CO2] - CO2 emitted by industry (oil-demand*co2-emissions-oil)
  opex-oil ; int [eur] - Operating expenditure for industry using oil in a given year
           ; (oil-demand*oil-price + co2-emissions*co2-price)
  capture-electricity ; int [MWh / ton of CO2] - Operating expenditure for industry to run capture with electricity
  opex-capture-extensible ; int [eur] - Operating expenditure for industry using capture (extensible) in a given year
               ; (opex-oil + electricity-price*CO2-emmissions*capture-electricity + CO2-emissions*opex-extensible)
  opex-capture-fixed ; int [eur] - Operating expenditure for industry using capture (fixed) in a given year
               ; (opex-oil + electricity-price*CO2-emmissions*capture-electricity + CO2-emissions*opex-fixed)
  capex-capture ; int [eur / ton of CO2] - Capital expenditure for industry in a given year (200 eur / ton of CO2)
  intent ; bool - Industries intent to build CCS (True=intend to build, False=no intent)
  built ; bool - True if an industry has built CCS
  payback-period ; int [yr] - How many years the industry wants to take to payback their investment
  extensible-connection ; bool - True if industry is connected to extensible pipeline
  fixed-connection ; bool - True if industry is connected to fixed pipeline
]

Storages-own [
  location ; location as mentioned in assignment data
  pipeline-capacity ; int [Mt co2 / yr] - the maximum capacity of the pipeline
  onshore-km ; int [km] - required onshore distance
  offshore-km ; int [km] - required offshore distance
  capex-onshore ; int [eur / km] - capital expenditure required to lay onshore pipeline per km
  capex-offshore ; int [eur / km] - capital expenditure required to lay off shore pipeline per km
]

Pipelines-own [

]


to setup
  clear-all
  file-close-all

  ask patches [ set pcolor blue - 0.25 - random-float 0.25 ] ; colour variation looks nice
  import-pcolors "PoR_map.png" ; import an image of the PoR landmass
  ask patches with [ not shade-of? blue pcolor ] [
    ; if you're not part of the ocean, you are part of the continent
    set pcolor green ; set landmass to be green
  ]

  ; Set PoR
  set-default-shape PoRs "house"
  create-PoRs 1 [
    set color yellow
    set size 6
    setxy -26 10

    set connection-price 1000000 ; [eur]
    set pipeline-availability 0 ; double [ton of CO2 / yr]
    set opex-extensible 0.3 ; int [eur / ton of CO2]
    set opex-fixed 0.21 ; int [eur / ton of CO2] (0.7*opex-extensible)
    set budget 10000000 ; int [eur]
  ]

  ; Set Government
  create-Governments 1 [
    set subsidy 15000000 ; int [eur]
    file-open "co2-oil-price.csv"
    if file-at-end? [ stop ]
    let p csv:from-row file-read-line
    set co2-price item 1 p ; int [eur / ton of co2]
    set oil-price item 2 p ; int [eur / ton of oil]
    set electricity-price 75 ; int [eur / MWh]
  ]

  ; Set Industries
  set-default-shape industries "house"
  ask n-of 25 patches with [ (pxcor > -40 and pxcor < 20) and (pycor > -15 and pycor < 20) ]
    [ sprout-industries 1 [
      set color black
      set size 3

      set oil-demand random 9000 + 1000; int [ton of oil / yr]
      set co2-emissions-oil 3.2 ; double [ton of CO2 / ton of oil]
      set co2-emissions 0 ; double [ton of CO2]
      set opex-oil 0 ; int [eur]
      set capture-electricity 1.3 ; int [MWh / ton of CO2]
      set opex-capture-extensible 0 ; int [eur]
      set opex-capture-fixed 0 ; int [eur]
      set capex-capture 200 ; int [eur / ton of CO2]
      set intent False ; bool
      set built False ; bool
      set payback-period random 19 + 1; int [yr]
      set extensible-connection False
      set fixed-connection False
  ]]

  ; Set globals

  reset-ticks
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; GOVERNMENT PROCEDURES ;;;;;;;

; PURPOSE: update electricity price with equation and read price data for oil and CO2 emission from file
to update-govt-prices
  ask Government 1 [
    set electricity-price electricity-price * 0.95

    file-open "co2-oil-price.csv"
    if file-at-end? [ stop ]
    let p csv:from-row file-read-line
    set co2-price item 1 p
    set oil-price item 2 p
  ]
end

;;;;; END GOVERNMENT PROCEDURES;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; PORT OF ROTTERDAM PROCEDURES ;;;;;;;

; PURPOSE:
to build-pipeline
  let total-emissions sum [ co2-emissions ] of Industries with [intent and not built]
  write "EMISSIONS"
  show total-emissions
  ask PoR 0 [
    if pipeline-availability < total-emissions and total-emissions > 0 [
      expand-storage
    ]
  ]
end

;;;;; END PORT OF ROTTERDAM PROCEDURES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; INDUSTRY PROCEDURES ;;;;;;;

; PURPOSE: update the costs for the industries so that they can decide on intent to build
to update-expenditures
  let curr-oil-price [ oil-price ] of Government 1
  let curr-co2-price [ co2-price ] of Government 1
  let curr-elec-price [ electricity-price ] of Government 1
  let curr-opex-extensible [ opex-extensible ] of PoR 0
  let curr-opex-fixed [ opex-fixed ] of PoR 0
  ask Industries [
    set co2-emissions co2-emissions-oil * oil-demand
    set opex-oil oil-demand * curr-oil-price + co2-emissions * curr-co2-price
    set opex-capture-extensible oil-demand * curr-oil-price + curr-elec-price * co2-emissions * capture-electricity + co2-emissions * curr-opex-extensible
    set opex-capture-fixed opex-oil + curr-elec-price * co2-emissions * capture-electricity + co2-emissions * curr-opex-fixed
    set capex-capture capex-capture * 0.9
  ]
end

; PURPOSE: allow industries to decide on their intent to build CCS infrastructure so they can connect to the pipelines of PoR
to intent-to-build
  let curr-connection-price [ connection-price ] of PoR 0
  ask Industries with [not intent] [
    if opex-oil > opex-capture-extensible + curr-connection-price + capex-capture * co2-emissions / payback-period [
      set intent True
    ]
  ]
end

; PURPOSE: Companies decide on whether to build the CCS depending on the available pipeline capacity
to build
  let curr-connection-price [ connection-price ] of PoR 0
  ask Industries with [intent and not built] [
    let curr-pipeline-availability [ pipeline-availability ] of PoR 0
    if co2-emissions < curr-pipeline-availability [
      set built True
      set extensible-connection True ; NOTE: Add in if statement for fixed or extensible
      let temp-co2-emissions co2-emissions
      ask PoR 0 [
        set budget budget + curr-connection-price
        set pipeline-availability pipeline-availability - temp-co2-emissions
      ]
      create-Pipeline-with PoR 0
    ]
  ]
end

to pay-subscription-to-PoR
  ask Industries with [ built and extensible-connection ] [
    ask PoR 0 [
      set budget budget + opex-extensible * co2-emissions
    ]
  ]
  ask Industries with [ built and fixed-connection ] [
    set budget budget + opex-fixed * co2-emissions
  ]
end

;;;;; END INDUSTRY PROCEDURES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; STORAGE PROCEDURES ;;;;;;;

; PURPOSE:
to expand-storage
  file-open "storagepoints.csv"
  if file-at-end? [ stop ]
  let x csv:from-row file-read-line
  ask n-of 1 patches with [ pycor > pxcor + 60 ] [
    sprout-Storages 1 [
      set location item 0 x
      set pipeline-capacity item 3 x
      show pipeline-capacity
      set onshore-km item 1 x
      set offshore-km item 2 x
      set capex-onshore item 4 x
      set capex-offshore item 5 x

      let temp-pipeline-capacity pipeline-capacity
      let temp-onshore-km onshore-km
      let temp-offshore-km offshore-km
      let temp-capex-onshore capex-onshore
      let temp-capex-offshore capex-offshore

      create-Pipeline-with PoR 0

      ask PoR 0 [
        set pipeline-availability pipeline-availability + temp-pipeline-capacity
        let subtract-from-budget temp-onshore-km * temp-capex-onshore + temp-offshore-km * temp-capex-offshore
        set budget budget - subtract-from-budget
      ]
    ]
  ]
end

;;;;; END STORAGE PROCEDURES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to go
  build
  update-expenditures
  intent-to-build
  build-pipeline
  update-govt-prices
  if ticks = 31 [ stop ]
  tick
end
@#$#@#$#@
GRAPHICS-WINDOW
0
0
1815
1374
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-69
69
-52
52
0
0
1
0
1
ticks
30.0

BUTTON
40
41
104
74
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
40
86
103
119
GO!
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
136
172
213
205
Go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

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
NetLogo 3D 6.1.0
@#$#@#$#@
need-to-manually-make-preview-for-this-model
@#$#@#$#@
@#$#@#$#@
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
