;; ===========================================================================
;; rooms.s - the flat, the school and the way home, in C64 geometry.
;;
;; First written by tools/convrooms.py from the CPC's tables (x * 5/3,
;; y * 3/4 about the floor), and edited by hand from there on. Every
;; number is a multicolour pixel across (0-159) or a raster line down
;; (0-199, the HUD is 0-15). See config.s for the grid.
;;
;; A box is dx, dy, width, height, pen. Pens are the CPC's sixteen, mapped
;; to C64 colours by pen_colour in video.s; pen 0 is the room's light,
;; which takes no colour slot in the cell.
;; ===========================================================================

PROP_SOFA          = 0
PROP_TV            = 1
PROP_WINDOW        = 2
PROP_COOKER        = 3
PROP_WORKTOP       = 4
PROP_FRIDGE        = 5
PROP_FRIDGEOPEN    = 6
PROP_VENT          = 7
PROP_VENTOPEN      = 8
PROP_DOOR          = 9
PROP_DOOROPEN      = 10
PROP_WARDROBE      = 11
PROP_WARDROBEOPEN  = 12
PROP_RACK          = 13
PROP_CRATES        = 14
PROP_BOILER        = 15
PROP_CAR           = 16
PROP_TYRES         = 17
PROP_TOOLBOARD     = 18
PROP_TREE          = 19
PROP_FENCE         = 20
PROP_BUSH          = 21
PROP_STAIRS        = 22
PROP_SHOES         = 23
PROP_COATS         = 24
PROP_BED           = 25
PROP_DRAWERS       = 26
PROP_RAIL          = 27
PROP_CASES         = 28
PROP_SHOEBOX       = 29
PROP_BATH          = 30
PROP_BASIN         = 31
PROP_TOILET        = 32
PROP_DESK          = 33
PROP_BOOKCASE      = 34
PROP_BIN           = 35
PROP_KENNEL        = 36
PROP_STAND         = 37
PROP_LOCKERS       = 38
PROP_BOARD         = 39
PROP_WALLBARS      = 40
PROP_VAULT         = 41
PROP_BLEACHERS     = 42
PROP_BUSSEAT       = 43
PROP_BUS           = 44
PROP_COUNTER       = 45
PROP_CHIMNEY       = 46
PROP_SANDPIT       = 47
PROP_FOUNTAIN      = 48
PROP_BENCH         = 49
PROP_CABINET       = 50
PROP_EXAMTABLE     = 51
PROP_TRUNK         = 52
PROP_TRUNKLOW      = 53
PROP_CRATES_RED    = 54

prop_boxes
        .word box_sofa, box_tv, box_window, box_cooker
        .word box_worktop, box_fridge, box_fridgeopen, box_vent
        .word box_ventopen, box_door, box_dooropen, box_wardrobe
        .word box_wardrobeopen, box_rack, box_crates, box_boiler
        .word box_car, box_tyres, box_toolboard, box_tree
        .word box_fence, box_bush, box_stairs, box_shoes
        .word box_coats, box_bed, box_drawers, box_rail
        .word box_cases, box_shoebox, box_bath, box_basin
        .word box_toilet, box_desk, box_bookcase, box_bin
        .word box_kennel, box_stand, box_lockers, box_board
        .word box_wallbars, box_vault, box_bleachers, box_busseat
        .word box_bus, box_counter, box_chimney, box_sandpit
        .word box_fountain, box_bench, box_cabinet, box_examtable
        .word box_trunk, box_trunklow, box_crates_red

;; 128 x 58 px: a two-seater against the wall.
box_sofa
        .byte   0,   0,  53,  18,  3      ; back
        .byte   3,   2,  47,  14, 12
        .byte   0,  18,  53,  17,  3      ; seat
        .byte   3,  20,  47,  12, 13      ; cushions
        .byte   0,   8,   8,  28,  3      ; arms
        .byte   2,  11,   5,  22, 12
        .byte  45,   8,   8,  28,  3
        .byte  47,  11,   5,  22, 12
        .byte   5,  36,   7,   8,  3      ; feet
        .byte  42,  36,   6,   8,  3
        .byte $ff

;; 56 x 56 px: the telly, switched on.
box_tv
        .byte   8,  33,   7,   8,  3      ; stand
        .byte   3,  39,  17,   3,  3      ; base
        .byte   0,   0,  23,  33,  3      ; case
        .byte   2,   2,  20,  30,  4
        .byte   3,   4,  17,  24, 11      ; picture
        .byte $ff

;; 96 x 96 px: a window on the back wall.
box_window
        .byte   0,   0,  40,  72,  3
        .byte   3,   3,  34,  66,  6
        .byte   5,   5,  13,  28, 15
        .byte  22,   5,  13,  28, 15
        .byte   5,  38,  13,  28, 15
        .byte  22,  38,  13,  28, 15
        .byte $ff

;; 48 x 70 px: a freestanding cooker, hob level with the worktop.
box_cooker
        .byte   0,   0,  20,  53,  3
        .byte   2,   3,  16,  47,  5
        .byte   0,   0,  20,   5,  3      ; hob
        .byte   3,   1,   5,   3, 13      ; rings
        .byte  12,   1,   5,   3, 13
        .byte   3,  11,  14,   2,  3      ; handle
        .byte   2,  17,  16,  31,  3      ; oven door
        .byte   3,  19,  14,  27,  5
        .byte   5,  23,  10,  19,  7      ; the light inside
        .byte $ff

;; 100 x 70 px: worktop with a sink and a tap. Its surface is six scanlines
;; down, so standing it on the floor puts the top exactly one jump above the
;; bin - which is the only way up onto it.
box_worktop
        .byte  27,   0,   1,   5,  3      ; tap
        .byte  25,   0,   7,   2,  3
        .byte   0,   5,  42,   4,  3      ; the worktop
        .byte   5,   5,  17,   3, 11      ; basin
        .byte   0,   9,  42,  44,  3      ; unit
        .byte   2,  11,  38,  39,  6
        .byte   3,  14,  17,  34,  3      ; doors
        .byte   5,  16,  13,  30,  6
        .byte  22,  14,  16,  34,  3
        .byte  23,  16,  14,  30,  6
        .byte $ff

;; 48 x 136 px: the vintage Pitsos, two doors and four digital locks.
box_fridge
        .byte   0,   0,  20, 102,  3
        .byte   2,   2,  16,  98,  5
        .byte   0,  44,  20,   3,  3      ; between the doors
        .byte  15,  15,   3,  12,  3      ; handles
        .byte  15,  57,   3,  12,  3
        .byte   3,  53,   4,   4, 13      ; the four locks
        .byte   3,  62,   4,   4, 13
        .byte   3,  71,   4,   4, 13
        .byte   3,  80,   4,   4, 13
        .byte $ff

box_fridgeopen
        .byte   0,   0,  20, 102,  3
        .byte   2,   2,  16,  98, 15      ; the light is on
        .byte   0,  44,  20,   3,  3
        .byte  15,  15,   3,  12,  3
        .byte  15,  57,   3,  12,  3
        .byte $ff

;; 24 x 24 px. A vent is not furniture; it is cat sized on purpose.
box_vent
        .byte   0,   0,  10,  18,  3
        .byte   2,   2,   6,  15,  4
        .byte   2,   4,   6,   1,  3
        .byte   2,   8,   6,   2,  3
        .byte   2,  13,   6,   1,  3
        .byte $ff

box_ventopen
        .byte   0,   0,  10,  18,  3
        .byte   2,   2,   6,  15, 15      ; light from the next room
        .byte $ff

;; Doors. The same pair serves most of the flat: 80 x 720 px, which is a door
;; a person walks through and four times the height of the cat.
box_door
        .byte   0,   0,  33, 135,  3      ; frame
        .byte   2,   3,  30, 132,  6
        .byte   3,   5,  27, 130,  3      ; the leaf
        .byte   5,   7,  23, 126,  6
        .byte   7,  14,   8,  39,  3      ; upper panels
        .byte   8,  16,   5,  34,  6
        .byte  20,  14,   8,  39,  3
        .byte  22,  16,   5,  34,  6
        .byte   7,  69,   8,  48,  3      ; lower panels
        .byte   8,  71,   5,  44,  6
        .byte  20,  69,   8,  48,  3
        .byte  22,  71,   5,  44,  6
        .byte  25,  63,   3,   5,  2      ; handle
        .byte $ff

box_dooropen
        .byte   0,   0,  33, 135,  3
        .byte   2,   3,  30, 132, 15      ; the next room, lit
        .byte  23,   3,   9, 132,  3      ; the leaf swung back against the jamb
        .byte  25,   6,   5, 126,  6
        .byte $ff

;; 120 x 176 px: the bedroom wardrobe, and the way through to inside it.
box_wardrobe
        .byte   0,   0,  50, 132,  3
        .byte   2,   3,  46, 126,  6
        .byte   2,   0,  46,   5,  3      ; cornice
        .byte   3,   6,  20, 120,  3      ; the two doors
        .byte   5,   8,  17, 116,  6
        .byte  27,   6,  20, 120,  3
        .byte  28,   8,  17, 116,  6
        .byte  22,  59,   3,  12,  2      ; handles
        .byte  27,  59,   3,  12,  2
        .byte   2, 129,  46,   3,  3      ; plinth
        .byte $ff

box_wardrobeopen
        .byte   0,   0,  50, 132,  3
        .byte   2,   3,  46, 126, 15      ; lit inside
        .byte   2,   0,  46,   5,  3
        .byte   3,   5,  44,   2,  3      ; the rail (C64: up a cell row,
        .byte   7,   7,   6,  70, 12      ; out of the clothes' top row, where
        .byte  15,   7,   8,  81, 11      ; white and two garments made four
        .byte  25,   7,   7,  66, 14      ; colours in a cell; the clothes
        .byte  33,   7,   9,  75, 13      ; hang from the next line down)
        .byte   2, 129,  46,   3,  3
        .byte $ff

;; 96 x 160 px: steel shelving. Its shelves are 32 scanlines apart, which is
;; exactly one jump, so the platforms line up with the bars that are drawn.
box_rack
        .byte   0,   0,   3, 120,  5      ; uprights
        .byte  37,   0,   3, 120,  5
        .byte   0,   0,  40,   3,  5      ; five shelves
        .byte   0,  24,  40,   3,  5
        .byte   0,  48,  40,   3,  5
        .byte   0,  72,  40,   3,  5
        .byte   0,  96,  40,   3,  5
        .byte   5,   6,  30,  17,  7      ; tins and jars nobody has touched in years
        .byte   8,  30,  20,  17,  7
        .byte   7,  78,  26,  17,  7
        .byte $ff

;; 96 x 64 px: two packing crates, one on the other.
box_crates
        .byte   0,  24,  40,  24,  7
        .byte   2,  26,  36,  20,  6
        .byte   2,  35,  36,   2,  7
        .byte   0,   0,  40,  24,  7
        .byte   2,   2,  36,  20,  6
        .byte   2,  11,  36,   2,  7
        .byte $ff

box_crates_red
        ;; (C64: the car park's crates, painted the car's white and red: they
        ;; stand behind it, and a cell has room for one car or the other)
        .byte   0,  24,  40,  24,  3
        .byte   2,  26,  36,  20,  12
        .byte   2,  35,  36,   2,  3
        .byte   0,   0,  40,  24,  3
        .byte   2,   2,  36,  20,  12
        .byte   2,  11,  36,   2,  3
        .byte $ff

;; 72 x 96 px: the water heater, still lit.
box_boiler
        .byte   0,   0,  30,  72,  3
        .byte   2,   3,  26,  66,  5
        .byte   3,   6,  24,   6, 13      ; the burner
        .byte   5,  18,  20,  30,  3      ; tank face
        .byte   7,  20,  16,  26,  5
        .byte  12,  56,   6,   4, 15      ; dial
        .byte  10,  63,   3,   9,  3      ; pipes
        .byte  20,  63,   3,   9,  3
        .byte $ff

;; 192 x 56 px: the family estate, nose to the left. The bonnet is a step up
;; to the roof, so the car is the climb as well as the scenery.
box_car
        .byte   0,  20,  80,  10,  3      ; body
        .byte   2,  22,  76,   6, 12
        .byte  27,   0,  50,  21,  3      ; cabin, over the back half
        .byte  28,   2,  47,  17, 12
        .byte  30,   5,  18,  12, 11      ; windows
        .byte  52,   5,  21,  12, 11
        .byte     0,  23,  80,   2,  3      ; the trim line down the side (C64: white: the body has red and white only)
        .byte     2,  17,   8,   3,  3      ; headlamp, on the nose of the bonnet (C64: white)
        .byte   8,  30,  17,  11,  4      ; wheels, clear of the body
        .byte   13,  32,   7,   6,  3      ; (C64: white hubs)
        .byte  55,  30,  17,  11,  4
        .byte   60,  32,   7,   6,  3
        .byte $ff

;; 48 x 32 px: three tyres nobody got round to taking to the tip.
box_tyres
        .byte   0,   0,  20,   8,  4
        .byte   5,   2,  10,   4,  5
        .byte   0,   8,  20,   8,  4
        .byte   5,  10,  10,   4,  5
        .byte   0,  17,  20,   7,  4
        .byte   5,  18,  10,   5,  5
        .byte $ff

;; 80 x 44 px: the tool board on the wall.
box_toolboard
        .byte   0,   0,  33,  33,  3
        .byte   2,   2,  30,  29,  6
        .byte   5,   5,   3,  15,  5
        .byte  12,   5,   5,  10,  5
        .byte  20,   5,   3,  18,  5
        .byte  25,   5,   5,  13,  5
        .byte   5,  24,  23,   3,  5
        .byte $ff

;; 112 x 160 px: the lemon tree. Its branches are the platforms.
box_tree
        .byte   20,  51,   7,  69,  6      ; trunk (C64: the trunk starts under the branch shelf)
        .byte    22,  51,   3,  66,  6      ; (C64: one brown)
        .byte  10,   0,  27,  18,  8      ; canopy, three tiers
        .byte  12,   2,  23,  14,  9
        .byte   3,  14,  40,  19,  8
        .byte   5,  16,  37,  15,  9
        .byte  13,  30,  20,  17,  8
        .byte  15,  32,  17,  12,  9
        .byte     7,  48,  13,   2,  6      ; branch stubs (C64: on the shelf line, under the yellow)
        .byte  27,  59,  16,   2,  6
        .byte   3,  72,  17,   2,  6
        .byte $ff

;; 96 x 32 px: the garden fence.
box_fence
        .byte   0,   0,  40,   3,  7      ; rails
        .byte   0,  11,  40,   3,  7
        .byte   2,   0,   3,  24,  7      ; pickets
        .byte  10,   0,   3,  24,  7
        .byte  18,   0,   4,  24,  7
        .byte  27,   0,   3,  24,  7
        .byte  35,   0,   3,  24,  7
        .byte $ff

;; 64 x 36 px: a shrub by the back door.
box_bush
        .byte   3,   0,  20,  12,  8
        .byte   5,   2,  17,   9,  9
        .byte   0,   9,  27,  18,  8
        .byte   2,  11,  23,  14,  9
        .byte  12,  23,   3,   4,  8
        .byte $ff

;; 144 x 64 px: the flight up, top step on the right.
box_stairs
        .byte  50,   0,  10,  48,  3
        .byte  52,   2,   6,  44,  6
        .byte  40,   9,  10,  39,  3
        .byte  42,  11,   6,  35,  6
        .byte  30,  18,  10,  30,  3
        .byte  32,  20,   6,  26,  6
        .byte  20,  27,  10,  21,  3
        .byte  22,  29,   6,  17,  6
        .byte  10,  36,  10,  12,  3
        .byte  12,  38,   6,   8,  6
        .byte   0,  44,  10,   4,  3
        .byte $ff

;; 80 x 32 px: the shoe rack by the front door.
box_shoes
        .byte   0,   0,  33,   3,  3
        .byte   0,  21,  33,   3,  3
        .byte   0,   0,   3,  24,  3
        .byte  30,   0,   3,  24,  3
        .byte   5,   5,   8,   6, 12
        .byte  17,   5,   8,   6, 12
        .byte   5,  14,   8,   6, 13
        .byte  18,  14,   9,   6, 13
        .byte $ff

;; 56 x 88 px: the coat stand, fully loaded as always.
box_coats
        .byte  10,   0,   3,  66,  5      ; pole
        .byte   3,   3,  17,   2,  5      ; hooks
        .byte   0,   6,  23,   2,  5
        .byte   0,   8,   7,  30, 12      ; three coats on it
        .byte   8,   8,   7,  36, 13
        .byte  17,   8,   6,  27, 14
        .byte   7,  59,  10,   7,  5      ; foot
        .byte $ff

;; 144 x 32 px: the bed, headboard to the left.
box_bed
        .byte   0,   3,  60,  18,  3      ; base
        .byte   2,   5,  56,  14,  6
        .byte   0,   0,   8,  24,  3      ; headboard
        .byte   2,   2,   5,  20,  6
        .byte   8,   3,  17,   5,  3      ; pillow
        .byte   8,   8,  50,   6, 11      ; quilt
        .byte   3,  21,   5,   3,  3      ; legs
        .byte  52,  21,   5,   3,  3
        .byte $ff

;; 64 x 60 px: the bedside chest.
box_drawers
        .byte   0,   0,  27,  45,  3
        .byte   2,   2,  23,  41,  6
        .byte   3,   5,  20,  10,  3
        .byte   5,   7,  17,   6,  6
        .byte   3,  18,  20,  11,  3
        .byte   5,  20,  17,   6,  6
        .byte   3,  32,  20,  10,  3
        .byte   5,  34,  17,   6,  6
        .byte  12,   9,   3,   2,  2      ; handles
        .byte  12,  23,   3,   1,  2
        .byte  12,  36,   3,   2,  2
        .byte $ff

;; 128 x 52 px: the hanging rail, seen from inside the wardrobe.
box_rail
        .byte   0,   0,  53,   3,  5
        .byte   3,   3,   9,  30, 12
        .byte  13,   3,  10,  35, 13
        .byte  25,   3,   8,  27, 11
        .byte  35,   3,  10,  36, 14
        .byte  47,   3,   6,  32,  7
        .byte $ff

;; 72 x 40 px: the suitcases that live at the bottom of it.
box_cases
        .byte   0,  17,  30,  13,  3      ; the big one, underneath
        .byte   2,  19,  26,   9, 12
        .byte   2,  23,  26,   1,  3      ; its lid seam
        .byte  13,  14,   4,   3,  3      ; handle
        .byte   5,   0,  20,  13,  3      ; and a smaller one on top
        .byte   7,   2,  16,   9,  7
        .byte   7,   6,  16,   2,  3
        .byte  13,  12,   4,   2,  2
        .byte $ff

;; 80 x 32 px: shoe boxes, stacked.
box_shoebox
        .byte   0,  12,  33,  12,  3
        .byte   2,  14,  30,   8,  7
        .byte   0,  12,  33,   3, 15
        .byte   3,   0,  27,  12,  3
        .byte   5,   2,  23,   8,  7
        .byte   3,   0,  27,   3, 15
        .byte $ff

;; 128 x 40 px: the bath, still half full.
box_bath
        .byte   0,   0,  53,  23,  3
        .byte   5,   4,  43,  16,  3
        .byte   5,  13,  43,   7, 11      ; still half full
        .byte   0,   0,  53,   4,  3      ; the rim
        .byte   0,  20,  53,   3,  3      ; and the skirt
        .byte   3,  23,   9,   7,  3      ; feet
        .byte  42,  23,   8,   7,  3
        .byte  48,   1,   4,   3,  2      ; tap
        .byte $ff

;; 72 x 64 px: pedestal basin.
box_basin
        .byte   0,   0,  30,   9,  3
        .byte   2,   2,  26,   5,  3
        .byte  10,   9,  10,  33,  3      ; pedestal
        .byte  12,  11,   6,  29,  3
        .byte   3,  42,  24,   6,  3      ; foot
        .byte  13,   0,   4,   3,  2      ; tap
        .byte $ff

;; 48 x 32 px.
box_toilet
        .byte   0,   0,  20,   5,  3      ; lid
        .byte   2,   5,  16,   9,  3
        .byte   3,   7,  14,   4,  3
        .byte   5,  14,  10,   7,  3
        .byte   2,  21,  16,   3,  3
        .byte $ff

;; 120 x 32 px: the desk.
box_desk
        .byte   0,   0,  50,   4,  3      ; the top
        .byte   2,   4,   5,  20,  3      ; legs
        .byte  43,   4,   5,  20,  3
        .byte  23,   4,  24,  12,  3      ; drawer unit
        .byte  25,   6,  20,   8,  6
        .byte  32,   9,   6,   2,  2
        .byte $ff

;; 128 x 160 px: the bookcase. Like the basement rack its shelves are one
;; jump apart, so what is drawn is what the cat can stand on.
box_bookcase
        .byte   0,   0,  53, 120,  3
        .byte   3,   3,  47, 114,  6
        .byte     3,  24,  47,   3,  2      ; shelves (C64: yellow: they are the platforms)
        .byte     3,  48,  47,   3,  2
        .byte     3,  72,  47,   3,  2
        .byte     3,  96,  47,   3,  2
        .byte     7,   6,   5,  18, 12      ; books (C64: a row of books, one colour)
        .byte   13,   6,   4,  18, 12
        .byte   18,   6,   5,  18, 12
        .byte     7,  30,   3,  18,  9
        .byte   12,  30,   5,  18,  9
        .byte   33,  30,   7,  18,  9
        .byte     8,  78,   5,  18, 13
        .byte   17,  78,   3,  18, 13
        .byte   37,  78,   6,  18, 13
        .byte    10, 102,   5,  13, 15      ; (C64: short of the floor's cell row)
        .byte $ff

;; 48 x 32 px: the pedal bin, and the way up onto the worktop.
box_bin
        .byte   0,   0,  20,   4,  3      ; lid
        .byte   2,   4,  16,  20,  3
        .byte   3,   6,  14,  16,  5
        .byte   8,   0,   4,   2, 13      ; pedal linkage
        .byte $ff

;; 64 x 32 px: next door's kennel, and the first step up the garden wall.
box_kennel
        .byte  10,   0,   7,   3, 12      ; the roof, stepped down to the eaves
        .byte   7,   3,  13,   3, 12
        .byte   3,   6,  20,   3, 12
        .byte   0,   9,  27,   3, 12
        .byte   2,  12,  23,  12,  7      ; the box itself
        .byte     3,  14,  20,  10,  7      ; (C64: orange like the outside: roof, walls, door)
        .byte   8,  15,  10,   9,  4      ; and the hole in the front of it
        .byte $ff

;; 80 x 64 px: the lemonade stand, unattended since about half past seven.
box_stand
        .byte   0,   0,  33,   9, 13      ; the sign
        .byte   2,   2,  30,   5, 15
        .byte   2,   9,   3,  12,  6      ; the posts holding it up
        .byte  28,   9,   4,  12,  6
        .byte  13,  15,   7,   6, 11      ; the jug
        .byte     0,  21,  33,   4,  6      ; the counter (C64: brown like the posts)
        .byte   2,  25,  30,  23, 15      ; and the cloth over the trestle
        .byte   5,  25,   3,  23, 13      ; with a stripe down it
        .byte  15,  25,   3,  23, 13
        .byte  25,  25,   3,  23, 13
        .byte $ff

;; 96 x 64 px: the bank of lockers down one side of the corridor.
box_lockers
        .byte   0,   0,  40,  48,  6
        .byte   0,   0,  40,   2,  5      ; the top, which is what you climb onto
        .byte   2,   3,   5,  42, 10      ; six doors
        .byte   8,   3,   5,  42, 10
        .byte  15,   3,   5,  42, 10
        .byte  22,   3,   5,  42, 10
        .byte  28,   3,   5,  42, 10
        .byte  35,   3,   5,  42, 10
        .byte   5,  21,   2,   4,  2      ; and six handles
        .byte  12,  21,   1,   4,  2
        .byte  18,  21,   2,   4,  2
        .byte  25,  21,   2,   4,  2
        .byte  32,  21,   1,   4,  2
        .byte  38,  21,   2,   4,  2
        .byte $ff

;; 112 x 64 px: the blackboard, with yesterday's lesson still on it.
box_board
        .byte   0,   0,  47,  48,  6      ; the frame
        .byte   2,   2,  43,  42,  8      ; the slate
        .byte   5,   6,  17,   2,  3      ; chalk
        .byte   5,  11,  27,   1,  3
        .byte   5,  15,  12,   2,  3
        .byte   5,  24,  23,   2,  3
        .byte   5,  29,  15,   1,  3
        .byte     0,  44,  47,   4,  6      ; the tray (C64: the frame's brown)
        .byte       3,  44,   7,   2,  6      ; and a stick of it in the tray (C64: white chalk) (C64: no chalk: the ledge shares a cell row with the floor)
        .byte $ff

;; 64 x 160 px: the gym's wall bars. The rungs are on the same 32-scanline
;; grid the cat jumps on, which is why they are a staircase and not a ladder.
box_wallbars
        .byte   0,   0,   3, 120,  7
        .byte  23,   0,   4, 120,  7
        .byte   0,   0,  27,   3,  7
        .byte   0,  24,  27,   3,  7
        .byte   0,  48,  27,   3,  7
        .byte   0,  72,  27,   3,  7
        .byte   0,  96,  27,   3,  7
        .byte   0, 117,  27,   3,  7
        .byte $ff

;; 72 x 32 px: the vaulting horse.
box_vault
        .byte   0,   0,  30,   5,  7      ; the padded top
        .byte   2,   2,  26,   1, 15      ; the seam along it
        .byte   0,   5,  30,   7,  6
        .byte   3,  12,   5,  12,  5      ; the legs
        .byte  22,  12,   5,  12,  5
        .byte $ff

;; 112 x 64 px: four rows of terracing beside the pitch.
box_bleachers
        .byte   0,  36,  47,  12,  5
        .byte   0,  36,  47,   2, 12
        .byte   7,  24,  40,  12,  5
        .byte   7,  24,  40,   2, 12
        .byte  13,  12,  34,  12,  5
        .byte  13,  12,  34,   2, 12
        .byte  20,   0,  27,  12,  5
        .byte  20,   0,  27,   2, 12
        .byte $ff

;; 72 x 32 px: a pair of seats on the school bus.
box_busseat
        .byte   0,   0,  13,  17, 13
        .byte   2,   2,  10,  12, 12
        .byte  17,   0,  13,  17, 13
        .byte  18,   2,  10,  12, 12
        .byte   0,  17,  30,   4, 12      ; the squabs
        .byte   3,  21,   4,   3,  5      ; and the frame under them
        .byte  23,  21,   4,   3,  5
        .byte $ff

;; 128 x 88 px: the school bus, side on, with the engine running.
box_bus
        .byte   0,   0,  53,  54,  2
        .byte   0,   0,  53,   3, 15      ; the roof
        .byte   3,   6,   9,  15, 11      ; four windows
        .byte  15,   6,   8,  15, 11
        .byte  27,   6,   8,  15, 11
        .byte  38,   6,   9,  15, 11
        .byte   0,  33,  53,   4,  4      ; the stripe along the side
        .byte   43,  38,   9,  16,  4      ; the door (C64: a black door, the stripe's colour)
        .byte  45,  40,   5,  12, 11
        .byte  50,  26,   3,   3, 13      ; a lamp
        .byte   7,  54,  10,  12,  4      ; wheels
        .byte       8,  57,   7,   6,  4      ; (C64: solid wheels)
        .byte  37,  54,  10,  12,  4
        .byte    38,  57,   7,   6,  4
        .byte $ff

;; 96 x 64 px: the counter at the vet's, with the bell nobody rings.
box_counter
        .byte   0,   0,  40,   5,  3
        .byte  32,   0,   5,   3, 13      ; the bell
        .byte   2,   5,  36,  43, 11
        .byte   3,   8,  34,  34, 10
        .byte   7,  11,  11,  28,  3      ; two inlays
        .byte  22,  11,  11,  28,  3
        .byte $ff

;; 40 x 64 px: a chimney stack, with the pots that are the way down it.
box_chimney
        .byte   2,   0,   5,   8,  7
        .byte  10,   0,   5,   8,  7
        .byte   0,   8,  17,  40, 12
        .byte   0,  11,  17,   1,  7      ; courses of brick
        .byte   0,  17,  17,   1,  7
        .byte   0,  23,  17,   1,  7
        .byte   0,  29,  17,   1,  7
        .byte   0,  35,  17,   1,  7
        .byte   0,  41,  17,   1,  7
        .byte $ff

;; 96 x 24 px: the sandpit, with a bucket and a spade left in it.
box_sandpit
        .byte   0,   0,  40,   4,  6
        .byte   2,   4,  36,  14, 15
        .byte   7,   2,   5,   3, 13
        .byte   27,   2,   3,   3, 13      ; (C64: red like the bucket)
        .byte $ff

;; 80 x 64 px: the fountain in the middle of the park.
box_fountain
        .byte  15,   0,   3,  11, 11      ; the jet
        .byte   7,   9,  20,   5,  5      ; the upper bowl
        .byte   8,  11,  17,   2, 11
        .byte  13,  14,   7,  19,  5      ; the column
        .byte   0,  33,  33,  15,  5      ; the basin
        .byte   2,  35,  30,   8, 11
        .byte $ff

;; 80 x 32 px: a park bench, which is also the waiting room's bench.
box_bench
        .byte   0,   0,  33,   3,  7      ; the back slats
        .byte   0,   5,  33,   3,  7
        .byte   0,   8,   3,   6,  6      ; the arms
        .byte  30,   8,   3,   6,  6
        .byte   0,  11,  33,   3,  7      ; the seat
        .byte   2,  14,   5,  10,  6      ; the legs
        .byte  27,  14,   5,  10,  6
        .byte $ff

;; 48 x 80 px: a filing cabinet, four drawers.
box_cabinet
        .byte     0,   0,  20,  48,  5      ; (C64: 48 tall, standing on the counter, not through it)
        .byte   2,   2,  16,  13,  6
        .byte   8,   8,   5,   2,  3
        .byte   2,  17,  16,  12,  6
        .byte   8,  22,   5,   2,  3
        .byte     2,  31,  16,  14,  6
        .byte   8,  36,   5,   2,  3
        .byte $ff

;; 88 x 32 px: the vet's examination table, and he is not getting on it.
box_examtable
        .byte   0,   0,  37,   4,  3
        .byte   2,   2,  33,   2, 11      ; the padding
        .byte   3,   4,   5,  20,  5      ; the legs
        .byte  28,   4,   5,  20,  5
        .byte   3,  15,  30,   2,  5      ; the brace between them
        .byte  12,   6,  13,   5,  6      ; a drawer under the top
        .byte $ff

;; 16 x 160 px: a trunk, to put under a canopy. The decal is the leaves and
;; nothing else, so without one of these a tree is a hedge in mid-air.
box_trunk
        .byte   0,   0,   7, 120,  6
        .byte     2,   0,   3, 120,  6      ; lit down one side (C64: one brown: leaves sit on it)
        .byte   0,  26,   7,   3,  6      ; two branch stubs
        .byte   0,  59,   7,   3,  6
        .byte $ff

;; 16 x 120 px: the same again for a tree whose lowest branch is a jump lower.
box_trunklow
        .byte   0,   0,   7,  90,  6
        .byte     2,   0,   3,  90,  6      ; (C64: one brown)
        .byte   0,  23,   7,   3,  6
        .byte $ff


rooms
        ;; --- 1 ------------------------------------------------------------
        .byte MSG_ROOM1
        .word r1_plat, r1_saus
        .byte 5
        .word r1_enem
        .byte 3
        .word r1_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 3

        ;; --- 2 ------------------------------------------------------------
        .byte MSG_ROOM2
        .word r2_plat, r2_saus
        .byte 5
        .word r2_enem
        .byte 3
        .word r2_props
        .byte 0, 46
        .byte 3, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 147, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 5

        ;; --- 3 ------------------------------------------------------------
        .byte MSG_ROOM3
        .word r3_plat, r3_saus
        .byte 5
        .word r3_enem
        .byte 3
        .word r3_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte 89, SHELF_2-PICK_H
        .byte LIGHT_INDOOR, 8

        ;; --- 4 ------------------------------------------------------------
        .byte MSG_ROOM4
        .word r4_plat, r4_saus
        .byte 5
        .word r4_enem
        .byte 3
        .word r4_props
        .byte 0, 46
        .byte 3, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 147, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 3

        ;; --- 5 ------------------------------------------------------------
        .byte MSG_ROOM5
        .word r5_plat, r5_saus
        .byte 5
        .word r5_enem
        .byte 3
        .word r5_props
        .byte 110, 49
        .byte 113, 136, 44, 45, PROP_WARDROBE, PROP_WARDROBEOPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 3

        ;; --- 6 ------------------------------------------------------------
        .byte MSG_ROOM6
        .word r6_plat, r6_saus
        .byte 5
        .word r6_enem
        .byte 3
        .word r6_props
        .byte 133, 67
        .byte 133, 67, 10, 18, PROP_VENT, PROP_VENTOPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte 116, SHELF_4-PICK_H
        .byte LIGHT_INDOOR, 3

        ;; --- 7 ------------------------------------------------------------
        .byte MSG_ROOM7
        .word r7_plat, r7_saus
        .byte 5
        .word r7_enem
        .byte 3
        .word r7_props
        .byte 0, 46
        .byte 3, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 147, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 3

        ;; --- 8 ------------------------------------------------------------
        .byte MSG_ROOM8
        .word r8_plat, r8_saus
        .byte 5
        .word r8_enem
        .byte 3
        .word r8_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 3

        ;; --- 9 ------------------------------------------------------------
        .byte MSG_ROOM9
        .word r9_plat, r9_saus
        .byte 5
        .word r9_enem
        .byte 3
        .word r9_props
        .byte 143, 67
        .byte 143, 67, 10, 18, PROP_VENT, PROP_VENTOPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte 99, SHELF_2-PICK_H
        .byte LIGHT_INDOOR, 3

        ;; --- 10 ------------------------------------------------------------
        .byte MSG_ROOM10
        .word r10_plat, r10_saus
        .byte 5
        .word r10_enem
        .byte 3
        .word r10_props
        .byte 130, 79
        .byte 130, 131, 20, 50, PROP_FRIDGE, PROP_FRIDGEOPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 3

        ;; --- 11 ------------------------------------------------------------
        .byte MSG_ROOM11
        .word r11_plat, r11_saus
        .byte 5
        .word r11_enem
        .byte 3
        .word r11_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_DAY, 9

        ;; --- 12 ------------------------------------------------------------
        .byte MSG_ROOM12
        .word r12_plat, r12_saus
        .byte 5
        .word r12_enem
        .byte 3
        .word r12_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte 116, SHELF_3-PICK_H
        .byte LIGHT_DAY, 5

        ;; --- 13 ------------------------------------------------------------
        .byte MSG_ROOM13
        .word r13_plat, r13_saus
        .byte 5
        .word r13_enem
        .byte 3
        .word r13_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_DAY, 7

        ;; --- 14 ------------------------------------------------------------
        .byte MSG_ROOM14
        .word r14_plat, r14_saus
        .byte 5
        .word r14_enem
        .byte 3
        .word r14_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_DAY, 9

        ;; --- 15 ------------------------------------------------------------
        .byte MSG_ROOM15
        .word r15_plat, r15_saus
        .byte 5
        .word r15_enem
        .byte 3
        .word r15_props
        .byte 0, 46
        .byte 3, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 147, FLOOR_Y-CAT_H
        .byte 133, SHELF_3-PICK_H
        .byte LIGHT_DAY, 5

        ;; --- 16 ------------------------------------------------------------
        .byte MSG_ROOM16
        .word r16_plat, r16_saus
        .byte 5
        .word r16_enem
        .byte 3
        .word r16_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 3

        ;; --- 17 ------------------------------------------------------------
        .byte MSG_ROOM17
        .word r17_plat, r17_saus
        .byte 5
        .word r17_enem
        .byte 3
        .word r17_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 6

        ;; --- 18 ------------------------------------------------------------
        .byte MSG_ROOM18
        .word r18_plat, r18_saus
        .byte 5
        .word r18_enem
        .byte 3
        .word r18_props
        .byte 0, 46
        .byte 3, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 147, FLOOR_Y-CAT_H
        .byte 133, SHELF_1-PICK_H
        .byte LIGHT_INDOOR, 6

        ;; --- 19 ------------------------------------------------------------
        .byte MSG_ROOM19
        .word r19_plat, r19_saus
        .byte 5
        .word r19_enem
        .byte 3
        .word r19_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 10

        ;; --- 20 ------------------------------------------------------------
        .byte MSG_ROOM20
        .word r20_plat, r20_saus
        .byte 5
        .word r20_enem
        .byte 3
        .word r20_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 7

        ;; --- 21 ------------------------------------------------------------
        .byte MSG_ROOM21
        .word r21_plat, r21_saus
        .byte 5
        .word r21_enem
        .byte 3
        .word r21_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte 93, SHELF_2-PICK_H
        .byte LIGHT_DAY, 9

        ;; --- 22 ------------------------------------------------------------
        .byte MSG_ROOM22
        .word r22_plat, r22_saus
        .byte 5
        .word r22_enem
        .byte 3
        .word r22_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_DAY, 5

        ;; --- 23 ------------------------------------------------------------
        .byte MSG_ROOM23
        .word r23_plat, r23_saus
        .byte 5
        .word r23_enem
        .byte 3
        .word r23_props
        .byte 0, 46
        .byte 3, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 147, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 6

        ;; --- 24 ------------------------------------------------------------
        .byte MSG_ROOM24
        .word r24_plat, r24_saus
        .byte 5
        .word r24_enem
        .byte 3
        .word r24_props
        .byte 0, 46
        .byte 3, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 147, FLOOR_Y-CAT_H
        .byte 139, SHELF_1-PICK_H
        .byte LIGHT_DAY, 5

        ;; --- 25 ------------------------------------------------------------
        .byte MSG_ROOM25
        .word r25_plat, r25_saus
        .byte 5
        .word r25_enem
        .byte 3
        .word r25_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 10

        ;; --- 26 ------------------------------------------------------------
        .byte MSG_ROOM26
        .word r26_plat, r26_saus
        .byte 5
        .word r26_enem
        .byte 3
        .word r26_props
        .byte 0, 46
        .byte 3, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 147, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_INDOOR, 10

        ;; --- 27 ------------------------------------------------------------
        .byte MSG_ROOM27
        .word r27_plat, r27_saus
        .byte 5
        .word r27_enem
        .byte 3
        .word r27_props
        .byte 127, 46
        .byte 130, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 7, FLOOR_Y-CAT_H
        .byte 89, SHELF_2-PICK_H
        .byte LIGHT_INDOOR, 6

        ;; --- 28 ------------------------------------------------------------
        .byte MSG_ROOM28
        .word r28_plat, r28_saus
        .byte 5
        .word r28_enem
        .byte 3
        .word r28_props
        .byte 13, 139
        .byte 13, 139, 10, 18, PROP_VENT, PROP_VENTOPEN
        .byte 143, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_NIGHT, 5

        ;; --- 29 ------------------------------------------------------------
        .byte MSG_ROOM29
        .word r29_plat, r29_saus
        .byte 5
        .word r29_enem
        .byte 3
        .word r29_props
        .byte 0, 46
        .byte 3, 136, 27, 45, PROP_DOOR, PROP_DOOROPEN
        .byte 147, FLOOR_Y-CAT_H
        .byte NO_MILK, 0
        .byte LIGHT_NIGHT, 12
rooms_end
        .cerror rooms_end-rooms != ROOM_COUNT*R_SIZE, "a room record is the wrong size"

;; ---------------------------------------------------------------------------
;; 1 - the basement. Steel shelving on the left, packing crates in the middle,
;; the water heater on the right, and the stairs are a door you have to climb
;; back down to. Everything the flat has stopped using lives here.
;; ---------------------------------------------------------------------------
r1_plat
        .byte   0, 159, FLOOR_Y 
        .byte   3,  44, SHELF_1       ; the rack's lower shelf
        .byte  47,  87, SHELF_2       ; on top of the crates
        .byte   3,  44, SHELF_3       ; the rack's upper shelf
        .byte  93, 124, SHELF_3       ; and the top of the heater
        .byte $ff

r1_saus
        .byte  76, FLOOR_Y-PICK_H
        .byte  13, SHELF_1-PICK_H
        .byte  59, SHELF_2-PICK_H
        .byte  16, SHELF_3-PICK_H
        .byte  99, SHELF_3-PICK_H

r1_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_ROBOT  ,  73, FLOOR_Y-SPR_ROBOT_H,      1,   0, 160-SPR_ROBOT_W , 0
        .byte ET_ROBOT  , 100, SHELF_3-SPR_ROBOT_H, -1&255,  93, 125-SPR_ROBOT_W , 0
        .byte ET_CANARY ,  33, 37                ,      2,   7, 160-SPR_CANARY_W, 37

r1_props
        .byte PROP_RACK             ,   3,  61
        .byte PROP_CRATES           ,  47, 133
        .byte PROP_BOILER           ,  93, 109
        .byte $ff

;; ---------------------------------------------------------------------------
;; 2 - the garage. The car is the staircase: bonnet, then roof, then the shelf
;; under the tool board. You go back into the house by the side door, so this
;; room runs right to left.
;; ---------------------------------------------------------------------------
r2_plat
        .byte   0, 159, FLOOR_Y 
        .byte  40,  61, SHELF_1       ; the tyre stack
        .byte  67,  94, 160     
        .byte  93, 147, 141     
        .byte  43,  91, 117     
        .byte  93, 147, 93      
        .byte $ff

r2_saus
        .byte 109, FLOOR_Y-PICK_H
        .byte  46, SHELF_1-PICK_H
        .byte 116, 141-PICK_H    
        .byte  56, 117-PICK_H    
        .byte 116, 93-PICK_H     

r2_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_ROBOT  ,  83, FLOOR_Y-SPR_ROBOT_H, -1&255,   0, 160-SPR_ROBOT_W , 0
        .byte ET_ROBOT  ,  50, 117-SPR_ROBOT_H   ,      1,  43, 92-SPR_ROBOT_W  , 0
        .byte ET_CANARY , 100, 37                , -2&255,   7, 160-SPR_CANARY_W, 37

r2_props
        .byte PROP_DOOR             ,   0,  46
        .byte PROP_TYRES            ,  40, 157
        .byte PROP_CAR              ,  67, 140
        .byte PROP_TOOLBOARD        ,  47,  82
        .byte $ff

;; ---------------------------------------------------------------------------
;; 3 - the garden. Over the fence and up the lemon tree; the back door is on
;; the right, past the shrub.
;; ---------------------------------------------------------------------------
r3_plat
        .byte   0, 159, FLOOR_Y 
        .byte   7,  47, SHELF_1       ; the top of the fence
        .byte  50, 107, SHELF_2       ; the low branch
        .byte  23,  74, SHELF_3 
        .byte  77, 126, SHELF_4 
        .byte $ff

r3_saus
        .byte  86, FLOOR_Y-PICK_H
        .byte  16, SHELF_1-PICK_H
        .byte  59, SHELF_2-PICK_H
        .byte  33, SHELF_3-PICK_H
        .byte  99, SHELF_4-PICK_H

r3_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_ROBOT  ,  67, FLOOR_Y-SPR_ROBOT_H,      1,   0, 160-SPR_ROBOT_W , 0
        .byte ET_ROBOT  ,  83, SHELF_2-SPR_ROBOT_H, -1&255,  50, 108-SPR_ROBOT_W , 0
        .byte ET_CANARY ,  50, 49                ,      2,   7, 160-SPR_CANARY_W, 49

r3_props
        .byte PROP_FENCE            ,   7, 157
        .byte PROP_TREE             ,  50,  61
        .byte PROP_BUSH             ,  96, 154      ; (C64: clear of the door frame)
        .byte PROP_DOOR             , 127,  46
        .byte $ff

;; ---------------------------------------------------------------------------
;; 4 - the entrance hall. In off the street: shoe rack, the stairs, the coat
;; stand, and the door into the flat proper on the left.
;; ---------------------------------------------------------------------------
r4_plat
        .byte   0, 159, FLOOR_Y 
        .byte 110, 144, SHELF_1       ; the shoe rack
        .byte  77, 137, SHELF_2       ; the half landing
        .byte  37,  81, SHELF_3 
        .byte  83, 127, SHELF_4 
        .byte $ff

r4_saus
        .byte  66, FLOOR_Y-PICK_H
        .byte 119, SHELF_1-PICK_H
        .byte  99, SHELF_2-PICK_H
        .byte  46, SHELF_3-PICK_H
        .byte  96, SHELF_4-PICK_H

r4_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_ROBOT  ,  67, FLOOR_Y-SPR_ROBOT_H,      1,   0, 160-SPR_ROBOT_W , 0
        .byte ET_ROBOT  , 100, SHELF_2-SPR_ROBOT_H, -1&255,  77, 138-SPR_ROBOT_W , 0
        .byte ET_CANARY , 117, 41                , -2&255,   7, 160-SPR_CANARY_W, 41

r4_props
        .byte PROP_DOOR             ,   0,  46
        .byte PROP_SHOES            , 110, 157
        .byte PROP_STAIRS           ,  77, 133
        .byte PROP_COATS            ,  40, 115
        .byte $ff

;; ---------------------------------------------------------------------------
;; 5 - the bedroom. Up the bed to the window ledge, and out through the
;; wardrobe rather than the door: the cat knows a short cut.
;; ---------------------------------------------------------------------------
r5_plat
        .byte   0, 159, FLOOR_Y 
        .byte  13,  74, SHELF_1       ; the bed
        .byte  23,  71, SHELF_2       ; the window ledge
        .byte  73, 107, SHELF_3 
        .byte  33,  77, SHELF_4 
        .byte $ff

r5_saus
        .byte  73, FLOOR_Y-PICK_H
        .byte  33, SHELF_1-PICK_H
        .byte  43, SHELF_2-PICK_H
        .byte  83, SHELF_3-PICK_H
        .byte  49, SHELF_4-PICK_H

r5_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_ROBOT  ,  83, FLOOR_Y-SPR_ROBOT_H, -1&255,   0, 160-SPR_ROBOT_W , 0
        .byte ET_ROBOT  ,  33, SHELF_1-SPR_ROBOT_H,      1,  13, 75-SPR_ROBOT_W  , 0
        .byte ET_CANARY , 100, 40                , -2&255,   7, 160-SPR_CANARY_W, 40

r5_props
        .byte PROP_BED              ,  13, 157
        .byte PROP_WINDOW           ,  23,  61
        .byte PROP_DRAWERS          ,  80, 136
        .byte $ff

;; ---------------------------------------------------------------------------
;; 6 - inside the wardrobe. Shoe boxes, the hanging rail, the shelf above it,
;; and a vent in the back panel that nobody has noticed in twenty years.
;; ---------------------------------------------------------------------------
r6_plat
        .byte   0, 159, FLOOR_Y 
        .byte  13,  47, SHELF_1       ; the shoe boxes
        .byte  50, 104, SHELF_2       ; the hanging rail
        .byte  17,  67, SHELF_3 
        .byte  70, 134, SHELF_4 
        .byte $ff

r6_saus
        .byte 146, FLOOR_Y-PICK_H
        .byte  23, SHELF_1-PICK_H
        .byte  73, SHELF_2-PICK_H
        .byte  33, SHELF_3-PICK_H
        .byte  99, SHELF_4-PICK_H

r6_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_ROBOT  ,  67, FLOOR_Y-SPR_ROBOT_H,      1,   0, 160-SPR_ROBOT_W , 0
        .byte ET_ROBOT  ,  83, SHELF_4-SPR_ROBOT_H, -1&255,  70, 135-SPR_ROBOT_W , 0
        .byte ET_CANARY ,  33, 46                ,      2,   7, 160-SPR_CANARY_W, 46

r6_props
        .byte PROP_SHOEBOX          ,  13, 157
        .byte PROP_RAIL             ,  50, 133
        .byte PROP_CASES            , 107, 151
        .byte $ff

;; ---------------------------------------------------------------------------
;; 7 - the bathroom. The floor is too far from the bath to jump, so the route
;; is the toilet lid first, then the rim, then the basin.
;; ---------------------------------------------------------------------------
r7_plat
        .byte   0, 159, FLOOR_Y 
        .byte  40,  61, SHELF_1       ; the toilet lid
        .byte  67, 121, 151           ; the rim of the bath
        .byte 123, 154, SHELF_2 
        .byte 110, 154, SHELF_3 
        .byte  63, 111, SHELF_4 
        .byte $ff

r7_saus
        .byte  33, FLOOR_Y-PICK_H
        .byte  46, SHELF_1-PICK_H
        .byte  86, 151-PICK_H    
        .byte 129, SHELF_2-PICK_H
        .byte  76, SHELF_4-PICK_H

r7_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_ROBOT  ,  83, FLOOR_Y-SPR_ROBOT_H,      1,   0, 160-SPR_ROBOT_W , 0
        .byte ET_ROBOT  , 133, SHELF_2-SPR_ROBOT_H, -1&255, 123, 155-SPR_ROBOT_W , 0
        .byte ET_CANARY ,  67, 43                ,      2,   7, 160-SPR_CANARY_W, 43

r7_props
        .byte PROP_DOOR             ,   0,  46
        .byte PROP_TOILET           ,  40, 157
        .byte PROP_BATH             ,  67, 151
        .byte PROP_BASIN            , 123, 133
        .byte $ff

;; ---------------------------------------------------------------------------
;; 8 - the study. Desk, the shelf over it, then the bookcase.
;; ---------------------------------------------------------------------------
r8_plat
        .byte   0, 159, FLOOR_Y 
        .byte  20,  71, SHELF_1       ; the desk
        .byte  27,  74, SHELF_2       ; the shelf above it
        .byte  77, 124, SHELF_3       ; bookcase, third shelf down
        .byte  77, 124, SHELF_4 
        .byte $ff

r8_saus
        .byte  93, FLOOR_Y-PICK_H
        .byte  33, SHELF_1-PICK_H
        .byte  39, SHELF_2-PICK_H
        .byte  86, SHELF_3-PICK_H
        .byte 106, SHELF_4-PICK_H

r8_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_ROBOT  ,  83, FLOOR_Y-SPR_ROBOT_H,      1,   0, 160-SPR_ROBOT_W , 0
        .byte ET_ROBOT  , 100, SHELF_3-SPR_ROBOT_H, -1&255,  77, 125-SPR_ROBOT_W , 0
        .byte ET_CANARY ,  50, 40                ,      2,   7, 160-SPR_CANARY_W, 40

r8_props
        .byte PROP_DESK             ,  20, 157
        .byte PROP_BOOKCASE         ,  73,  61
        .byte PROP_DOOR             , 127,  46
        .byte $ff

;; ---------------------------------------------------------------------------
;; 9 - the living room. A wall of bookshelves, the sofa tucked under them and
;; the telly in the gap between.
;;
;; Its collision geometry is frozen: the scripted run in make check depends on
;; every shelf, sausage and patrol being exactly where it is. Furniture is
;; decoration and can move freely.
;; ---------------------------------------------------------------------------
r9_plat
        .byte   0, 159, FLOOR_Y 
        .byte   7,  57, SHELF_1 
        .byte  90, 144, SHELF_2 
        .byte  23,  74, SHELF_3 
        .byte 100, 151, SHELF_4 
        .byte $ff

r9_saus
        .byte  76, FLOOR_Y-PICK_H
        .byte  16, SHELF_1-PICK_H
        .byte 129, SHELF_2-PICK_H
        .byte  33, SHELF_3-PICK_H
        .byte 139, SHELF_4-PICK_H

r9_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_ROBOT  ,  67, FLOOR_Y-SPR_ROBOT_H,      1,   0, 160-SPR_ROBOT_W , 0
        .byte ET_ROBOT  , 117, SHELF_2-SPR_ROBOT_H, -1&255, 107, 145-SPR_ROBOT_W , 0
        .byte ET_CANARY ,  33, 37                ,      2,   7, 160-SPR_CANARY_W, 37

r9_props
        .byte PROP_WINDOW           ,  30,  22
        .byte PROP_SOFA             ,  90, 137
        .byte PROP_TV               ,  63, 139
        .byte $ff

;; ---------------------------------------------------------------------------
;; 10 - the kitchen, and the fridge. A worktop is 90 cm off the floor, which
;; is two jumps, so the bin is not decoration: it is the only way up. The hob
;; sits level with the worktop, the way a freestanding cooker does.
;; ---------------------------------------------------------------------------
r10_plat
        .byte   0, 159, FLOOR_Y 
        .byte  47,  67, SHELF_1 
        .byte   0,  42, SHELF_2       ; the run of units
        .byte  73,  94, SHELF_2       ; and the hob, level with it
        .byte   7,  51, SHELF_3       ; the wall cupboard
        .byte  77, 124, SHELF_3       ; and the shelf beside it
        .byte $ff

r10_saus
        .byte  99, FLOOR_Y-PICK_H
        .byte  53, SHELF_1-PICK_H
        .byte  26, SHELF_2-PICK_H
        .byte  19, SHELF_3-PICK_H
        .byte  96, SHELF_3-PICK_H

r10_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_ROBOT  , 100, FLOOR_Y-SPR_ROBOT_H, -1&255,   0, 160-SPR_ROBOT_W , 0
        .byte ET_ROBOT  ,  83, SHELF_3-SPR_ROBOT_H,      1,  77, 125-SPR_ROBOT_W , 0
        .byte ET_CANARY ,  67, 37                , -2&255,   7, 160-SPR_CANARY_W, 37

r10_props
        .byte PROP_WINDOW           ,  87,  22
        .byte PROP_BIN              ,  47, 157
        .byte PROP_WORKTOP          ,   0, 128
        .byte PROP_COOKER           ,  73, 133
        .byte $ff

;; ---------------------------------------------------------------------------
;; 11 - the back yard. Out through the cat flap at dawn, and the school bus is
;; already at the top of the road. Up the kennel, along the garden wall,
;; over the crates and into the lemon tree.
;; ---------------------------------------------------------------------------
r11_plat
        .byte   0, 159, FLOOR_Y 
        .byte  13,  41, SHELF_1       ; the kennel roof
        .byte  47,  87, SHELF_2       ; the top of the garden wall
        .byte  93, 126, SHELF_3       ; the stack of crates by the shed
        .byte  50,  91, SHELF_4       ; the low branch
        .byte $ff

r11_saus
        .byte  79, FLOOR_Y-PICK_H
        .byte  19, SHELF_1-PICK_H
        .byte  59, SHELF_2-PICK_H
        .byte 103, SHELF_3-PICK_H
        .byte  66, SHELF_4-PICK_H

r11_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_DOG    ,  67, FLOOR_Y-SPR_DOG_H ,      1,   0, 160-SPR_DOG_W   , 0
        .byte ET_BALL   ,  57, SHELF_2-SPR_BALL_H,      1,  47, 88-SPR_BALL_W   , 0
        .byte ET_WASP   , 100, 49                , -2&255,   7, 160-SPR_WASP_W  , 49

r11_props
        .byte DECAL+DECAL_CLOUD     ,   3,  22
        .byte DECAL+DECAL_CLOUD2    , 110,  26
        .byte DECAL+DECAL_SUN       , 137,  22
        .byte PROP_TRUNK            ,  60,  82
        .byte PROP_KENNEL           ,  13, 157
        .byte PROP_FENCE            ,  47, 133
        .byte PROP_CRATES           ,  93, 109
        .byte DECAL+DECAL_TREETOP   ,  50,  67
        .byte DECAL+DECAL_TREETOP   ,  70,  70
        .byte DECAL+DECAL_GRASS     , 117, 176
        .byte $ff

;; ---------------------------------------------------------------------------
;; 12 - the pavement, and a lemonade stand nobody is minding. The first
;; saucer of milk of the journey is on the wall, past the dog.
;; ---------------------------------------------------------------------------
r12_plat
        .byte   0, 159, FLOOR_Y 
        .byte  17,  51, SHELF_1       ; the counter of the stand
        .byte  60,  94, SHELF_2       ; the bench
        .byte 103, 126, SHELF_3       ; the garden wall
        .byte  50,  91, SHELF_4       ; the balcony railing
        .byte $ff

r12_saus
        .byte  83, FLOOR_Y-PICK_H
        .byte  23, SHELF_1-PICK_H
        .byte  66, SHELF_2-PICK_H
        .byte 106, SHELF_3-PICK_H
        .byte  59, SHELF_4-PICK_H

r12_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_DOG    ,  83, FLOOR_Y-SPR_DOG_H , -1&255,   0, 160-SPR_DOG_W   , 0
        .byte ET_STRAY  ,  63, SHELF_2-SPR_STRAY_H,      1,  60, 95-SPR_STRAY_W  , 0
        .byte ET_PIGEON ,  33, 41                ,      2,   7, 160-SPR_PIGEON_W, 41

r12_props
        .byte DECAL+DECAL_CLOUD     ,   7,  22
        .byte DECAL+DECAL_CLOUD2    , 117,  23
        .byte PROP_STAND            ,  17, 157
        .byte PROP_BENCH            ,  60, 133
        .byte PROP_FENCE            , 103, 109
        .byte DECAL+DECAL_LAMP      , 107,  89
        .byte PROP_FENCE            ,  50,  85
        .byte DECAL+DECAL_SIGN      , 148, 167
        .byte $ff

;; ---------------------------------------------------------------------------
;; 13 - the playground. The slide is the way up and the sandpit is the way
;; down, and the football has opinions about both.
;; ---------------------------------------------------------------------------
r13_plat
        .byte   0, 159, FLOOR_Y 
        .byte  10,  44, SHELF_1       ; the swing seat
        .byte  73, 107, SHELF_2       ; the top of the slide
        .byte  33,  61, SHELF_3       ; the climbing frame
        .byte  33,  61, SHELF_4       ; and the top of it
        .byte $ff

r13_saus
        .byte  79, FLOOR_Y-PICK_H
        .byte  16, SHELF_1-PICK_H
        .byte  83, SHELF_2-PICK_H
        .byte  43, SHELF_3-PICK_H
        .byte  43, SHELF_4-PICK_H

r13_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_BALL   ,  67, FLOOR_Y-SPR_BALL_H,      1,   0, 160-SPR_BALL_W  , 0
        .byte ET_WASP   ,  50, 47                ,      2,   7, 160-SPR_WASP_W  , 47
        .byte ET_PIGEON , 117, 40                , -2&255,   7, 160-SPR_PIGEON_W, 40

r13_props
        .byte DECAL+DECAL_CLOUD     , 100,  22
        .byte DECAL+DECAL_SUN       , 140,  23
        .byte DECAL+DECAL_SWING     ,  10, 140
        .byte PROP_WALLBARS         ,  33,  61
        .byte DECAL+DECAL_SLIDE     ,  80, 115
        .byte PROP_SANDPIT          ,   0, 163
        .byte DECAL+DECAL_GRASS     , 110, 176
        .byte $ff

;; ---------------------------------------------------------------------------
;; 14 - the park. Two trees, a fountain and more pigeons than anyone needs.
;; ---------------------------------------------------------------------------
r14_plat
        .byte   0, 159, FLOOR_Y 
        .byte  10,  44, SHELF_1       ; the park bench
        .byte  53,  87, SHELF_2       ; the rim of the fountain
        .byte  97, 126, SHELF_3       ; the low branch
        .byte  43,  84, SHELF_4       ; the high one
        .byte $ff

r14_saus
        .byte  76, FLOOR_Y-PICK_H
        .byte  16, SHELF_1-PICK_H
        .byte  63, SHELF_2-PICK_H
        .byte 106, SHELF_3-PICK_H
        .byte  53, SHELF_4-PICK_H

r14_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_PIGEON ,  33, 43                ,      2,   7, 160-SPR_PIGEON_W, 43
        .byte ET_WASP   , 100, 56                , -2&255,   7, 160-SPR_WASP_W  , 56
        .byte ET_DOG    , 100, FLOOR_Y-SPR_DOG_H , -1&255,   0, 160-SPR_DOG_W   , 0

r14_props
        .byte DECAL+DECAL_CLOUD     ,   3,  22
        .byte DECAL+DECAL_SUN       , 140,  22
        .byte PROP_TRUNKLOW         , 107, 106
        .byte PROP_TRUNK            ,  50,  82
        .byte PROP_BENCH            ,  10, 157
        .byte PROP_FOUNTAIN         ,  53, 133
        .byte DECAL+DECAL_TREETOP   ,  97,  91
        .byte DECAL+DECAL_TREETOP   , 117,  94
        .byte DECAL+DECAL_TREETOP   ,  43,  67
        .byte DECAL+DECAL_FLOWERS   , 127, 173
        .byte DECAL+DECAL_BUSHY     , 143, 172
        .byte $ff

;; ---------------------------------------------------------------------------
;; 15 - the school gate. In over the wall rather than through it, because the
;; gate is shut and there is a terrier on the pavement.
;; ---------------------------------------------------------------------------
r15_plat
        .byte   0, 159, FLOOR_Y 
        .byte  33,  74, SHELF_1       ; the low wall
        .byte  57,  97, SHELF_2       ; the railings
        .byte 100, 147, SHELF_3       ; the steps up to the door
        .byte  50,  91, SHELF_4       ; the canopy over them
        .byte $ff

r15_saus
        .byte  83, FLOOR_Y-PICK_H
        .byte  43, SHELF_1-PICK_H
        .byte  66, SHELF_2-PICK_H
        .byte 116, SHELF_3-PICK_H
        .byte  59, SHELF_4-PICK_H

r15_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_DOG    ,  83, FLOOR_Y-SPR_DOG_H ,      1,   0, 160-SPR_DOG_W   , 0
        .byte ET_BALL   ,  40, SHELF_1-SPR_BALL_H,      1,  33, 75-SPR_BALL_W   , 0
        .byte ET_PIGEON , 100, 38                , -2&255,   7, 160-SPR_PIGEON_W, 38

r15_props
        .byte DECAL+DECAL_CLOUD     ,   3,  22
        .byte DECAL+DECAL_SUN       , 130,  22
        .byte PROP_FENCE            ,  33, 157
        .byte PROP_LOCKERS          ,  57, 133
        .byte PROP_STAIRS           , 100, 109
        .byte PROP_FENCE            ,  50,  85
        .byte DECAL+DECAL_SIGN      , 150, 167
        .byte $ff

;; ---------------------------------------------------------------------------
;; 16 - the corridor, and a floor the caretaker has just done. The lockers are
;; the only way up, and there is a bucket at each end of the run.
;; ---------------------------------------------------------------------------
r16_plat
        .byte   0, 159, FLOOR_Y 
        .byte  50,  71, SHELF_1       ; the bin
        .byte   0,  41, SHELF_2       ; the top of the lockers
        .byte  50,  94, SHELF_3       ; the window ledge
        .byte 100, 126, SHELF_4       ; the noticeboard
        .byte $ff

r16_saus
        .byte  86, FLOOR_Y-PICK_H
        .byte  53, SHELF_1-PICK_H
        .byte  13, SHELF_2-PICK_H
        .byte  59, SHELF_3-PICK_H
        .byte 109, SHELF_4-PICK_H

r16_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_MOP    ,  67, FLOOR_Y-SPR_MOP_H ,      1,   0, 160-SPR_MOP_W   , 0
        .byte ET_MOP    ,   7, SHELF_2-SPR_MOP_H ,      1,   0, 42-SPR_MOP_W    , 0
        .byte ET_PLANE  , 100, 37                , -2&255,   7, 160-SPR_PLANE_W , 37

r16_props
        .byte PROP_BIN              ,  50, 157
        .byte PROP_LOCKERS          ,   0, 133
        .byte PROP_WINDOW           ,  50,  37
        .byte PROP_BOARD            , 100,  85
        .byte $ff

;; ---------------------------------------------------------------------------
;; 17 - the classroom. Desk, blackboard, window ledge, and a paper plane that
;; has been going round the room since Tuesday.
;; ---------------------------------------------------------------------------
r17_plat
        .byte   0, 159, FLOOR_Y 
        .byte  13,  64, SHELF_1       ; the desk
        .byte  83, 126, SHELF_2       ; the top of the blackboard
        .byte  23,  64, SHELF_3       ; the window ledge
        .byte  80, 124, SHELF_4       ; the shelf above the map
        .byte $ff

r17_saus
        .byte  83, FLOOR_Y-PICK_H
        .byte  23, SHELF_1-PICK_H
        .byte  93, SHELF_2-PICK_H
        .byte  33, SHELF_3-PICK_H
        .byte  89, SHELF_4-PICK_H

r17_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_BALL   ,  67, FLOOR_Y-SPR_BALL_H,      1,   0, 160-SPR_BALL_W  , 0
        .byte ET_PLANE  ,  33, 38                ,      2,   7, 160-SPR_PLANE_W , 38
        .byte ET_PLANE  , 117, 50                , -2&255,   7, 160-SPR_PLANE_W , 50

r17_props
        .byte PROP_DESK             ,  13, 157
        .byte PROP_BOARD            ,  79, 133      ; (C64: clear of the door frame)
        .byte PROP_WINDOW           ,  23,  37
        .byte PROP_TOOLBOARD        ,  87,  52
        .byte DECAL+DECAL_GLOBE     ,  50, 143
        .byte $ff

;; ---------------------------------------------------------------------------
;; 18 - the staff room, which is where the confiscated things end up. Milk on
;; the desk, and nobody in until half past eight.
;; ---------------------------------------------------------------------------
r18_plat
        .byte   0, 159, FLOOR_Y 
        .byte  97, 147, SHELF_1       ; the desk
        .byte  50,  77, SHELF_2       ; the chest of drawers
        .byte  40,  91, SHELF_3       ; the bookcase
        .byte 100, 154, SHELF_4       ; the coat rail
        .byte $ff

r18_saus
        .byte  76, FLOOR_Y-PICK_H
        .byte 106, SHELF_1-PICK_H
        .byte  56, SHELF_2-PICK_H
        .byte  49, SHELF_3-PICK_H
        .byte 109, SHELF_4-PICK_H

r18_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_MOP    ,  67, FLOOR_Y-SPR_MOP_H , -1&255,   0, 160-SPR_MOP_W   , 0
        .byte ET_PLANE  ,  33, 40                ,      2,   7, 160-SPR_PLANE_W , 40
        .byte ET_WASP   , 117, 47                , -2&255,   7, 160-SPR_WASP_W  , 47

r18_props
        .byte PROP_DOOR             ,   0,  46
        .byte PROP_BOOKCASE         ,  40,  61
        .byte PROP_DESK             ,  97, 157
        .byte PROP_DRAWERS          ,  50, 133
        .byte PROP_RAIL             , 100,  85
        .byte DECAL+DECAL_PLANT     , 147, 161      ; (C64: standing on the floor)
        .byte $ff

;; ---------------------------------------------------------------------------
;; 19 - the chemistry lab. Whatever was in the beaker is out of the beaker,
;; and it has learned to get about.
;; ---------------------------------------------------------------------------
r19_plat
        .byte   0, 159, FLOOR_Y 
        .byte   3,  44, SHELF_1       ; the first bench
        .byte  53,  94, SHELF_2       ; the second
        .byte  17,  57, SHELF_3       ; the shelf of the rack
        .byte  67, 121, SHELF_4       ; the top shelf
        .byte $ff

r19_saus
        .byte  93, FLOOR_Y-PICK_H
        .byte   9, SHELF_1-PICK_H
        .byte  63, SHELF_2-PICK_H
        .byte  26, SHELF_3-PICK_H
        .byte  76, SHELF_4-PICK_H

r19_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_BLOB   ,  67, FLOOR_Y-SPR_BLOB_H,      1,   0, 160-SPR_BLOB_W  , 0
        .byte ET_BLOB   ,  60, SHELF_2-SPR_BLOB_H,      1,  53, 95-SPR_BLOB_W   , 0
        .byte ET_PLANE  , 117, 38                , -2&255,   7, 160-SPR_PLANE_W , 38

r19_props
        .byte PROP_RACK             ,  17,  61
        .byte PROP_WORKTOP          ,   3, 152
        .byte PROP_WORKTOP          ,  53, 128
        .byte PROP_TOOLBOARD        ,  73,  52
        .byte DECAL+DECAL_FLASK     ,  13, 145
        .byte DECAL+DECAL_FLASK     ,  63, 121
        .byte $ff

;; ---------------------------------------------------------------------------
;; 20 - the gymnasium. Wall bars up the left, the vaulting horse on the right,
;; and a football nobody put away.
;; ---------------------------------------------------------------------------
r20_plat
        .byte   0, 159, FLOOR_Y 
        .byte 100, 126, SHELF_1       ; the vaulting horse
        .byte  50,  91, SHELF_2       ; the stacked mats
        .byte   7,  34, SHELF_3       ; a rung of the wall bars
        .byte  60, 114, SHELF_4       ; the beam
        .byte $ff

r20_saus
        .byte  83, FLOOR_Y-PICK_H
        .byte 106, SHELF_1-PICK_H
        .byte  56, SHELF_2-PICK_H
        .byte  13, SHELF_3-PICK_H
        .byte  73, SHELF_4-PICK_H

r20_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_BALL   ,  67, FLOOR_Y-SPR_BALL_H, -1&255,   0, 160-SPR_BALL_W  , 0
        .byte ET_MOP    ,  67, SHELF_4-SPR_MOP_H ,      1,  60, 115-SPR_MOP_W   , 0
        .byte ET_PLANE  ,  33, 41                ,      2,   7, 160-SPR_PLANE_W , 41

r20_props
        .byte PROP_WALLBARS         ,   7,  61
        .byte PROP_CRATES           ,  50, 133
        .byte PROP_VAULT            , 100, 157
        .byte DECAL+DECAL_HOOP      , 117,  74
        .byte DECAL+DECAL_HOOP      , 120,  34
        .byte $ff

;; ---------------------------------------------------------------------------
;; 21 - the school pitch. Up the terraces, over the steps and past the goal.
;; ---------------------------------------------------------------------------
r21_plat
        .byte   0, 159, FLOOR_Y 
        .byte  10,  51, SHELF_1       ; the bottom terrace
        .byte  57, 117, SHELF_2       ; the steps
        .byte  13,  54, SHELF_3       ; the top terrace
        .byte  67, 107, SHELF_4       ; the floodlight gantry
        .byte $ff

r21_saus
        .byte  83, FLOOR_Y-PICK_H
        .byte  16, SHELF_1-PICK_H
        .byte  66, SHELF_2-PICK_H
        .byte  23, SHELF_3-PICK_H
        .byte  76, SHELF_4-PICK_H

r21_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_BALL   ,  67, FLOOR_Y-SPR_BALL_H,      1,   0, 160-SPR_BALL_W  , 0
        .byte ET_PIGEON ,  33, 41                ,      2,   7, 160-SPR_PIGEON_W, 41
        .byte ET_DOG    , 117, FLOOR_Y-SPR_DOG_H , -1&255,   0, 160-SPR_DOG_W   , 0

r21_props
        .byte DECAL+DECAL_CLOUD     ,   3,  22
        .byte DECAL+DECAL_SUN       , 140,  23
        .byte PROP_BLEACHERS        ,  10, 109
        .byte PROP_STAIRS           ,  57, 133
        .byte DECAL+DECAL_LAMP      ,  77,  65
        .byte DECAL+DECAL_GOAL      , 120, 169      ; (C64: clear of the stairs)
        .byte DECAL+DECAL_GRASS     , 130, 176
        .byte $ff

;; ---------------------------------------------------------------------------
;; 22 - the car park, and the bus is in it with the engine running. Up the
;; teacher's car, over the crates and onto the roof of the bus.
;; ---------------------------------------------------------------------------
r22_plat
        .byte   0, 159, FLOOR_Y 
        .byte  17,  97, SHELF_1       ; the roof of the car
        .byte  28,  69, SHELF_2       ; the crates (C64: 12 to the left,
        .byte  68, 121, SHELF_3       ; the roof of the bus  and the bus 5, so
                                      ;  that neither shares a cell with the door)
        .byte  23,  74, SHELF_4       ; the lamp gantry
        .byte $ff

r22_saus
        .byte 109, FLOOR_Y-PICK_H
        .byte  23, SHELF_1-PICK_H
        .byte  34, SHELF_2-PICK_H
        .byte  94, SHELF_3-PICK_H
        .byte  33, SHELF_4-PICK_H

r22_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_STRAY  ,  67, FLOOR_Y-SPR_STRAY_H,      1,   0, 160-SPR_STRAY_W , 0
        .byte ET_DOG    ,  33, SHELF_1-SPR_DOG_H ,      1,  17, 98-SPR_DOG_W    , 0
        .byte ET_PIGEON , 117, 40                , -2&255,   7, 160-SPR_PIGEON_W, 40

r22_props
        .byte DECAL+DECAL_CLOUD     ,   3,  22
        .byte DECAL+DECAL_SUN       , 140,  23
        .byte PROP_CRATES_RED       ,  28, 133
        .byte PROP_CAR              ,  17, 157
        .byte PROP_BUS              ,  68, 109
        .byte PROP_TYRES            , 133, 157
        .byte DECAL+DECAL_LAMP      ,  27,  65
        .byte $ff

;; ---------------------------------------------------------------------------
;; 23 - inside the school bus. Three rows of seats, the luggage rack, and the
;; lunchbox is not in any of them.
;; ---------------------------------------------------------------------------
r23_plat
        .byte   0, 159, FLOOR_Y 
        .byte  37,  67, SHELF_1       ; the first seat
        .byte  50,  81, SHELF_2       ; the second
        .byte  90, 121, SHELF_3       ; the third
        .byte  40,  81, SHELF_4       ; the luggage rack
        .byte $ff

r23_saus
        .byte 103, FLOOR_Y-PICK_H
        .byte  43, SHELF_1-PICK_H
        .byte  56, SHELF_2-PICK_H
        .byte  96, SHELF_3-PICK_H
        .byte  49, SHELF_4-PICK_H

r23_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_BALL   ,  67, FLOOR_Y-SPR_BALL_H,      1,   0, 160-SPR_BALL_W  , 0
        .byte ET_PLANE  ,  33, 37                ,      2,   7, 160-SPR_PLANE_W , 37
        .byte ET_PLANE  , 117, 46                , -2&255,   7, 160-SPR_PLANE_W , 46

r23_props
        .byte PROP_WINDOW           , 120,  37
        .byte PROP_BUSSEAT          ,  37, 157
        .byte PROP_BUSSEAT          ,  50, 133
        .byte PROP_BUSSEAT          ,  90, 109
        .byte PROP_CASES            ,  40,  85
        .byte $ff

;; ---------------------------------------------------------------------------
;; 24 - the pavement outside the school, and the bus pulling away from it.
;; Onto the roof of the bus, up to the balcony, and across the awnings.
;; ---------------------------------------------------------------------------
r24_plat
        .byte   0, 159, FLOOR_Y 
        .byte 113, 154, SHELF_1       ; the low wall
        .byte  67, 121, SHELF_2       ; the roof of the bus
        .byte  33,  74, SHELF_3       ; the balcony
        .byte  73, 114, SHELF_4       ; the awning
        .byte $ff

r24_saus
        .byte  49, FLOOR_Y-PICK_H
        .byte 119, SHELF_1-PICK_H
        .byte  76, SHELF_2-PICK_H
        .byte  43, SHELF_3-PICK_H
        .byte  83, SHELF_4-PICK_H

r24_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_DOG    ,  67, FLOOR_Y-SPR_DOG_H ,      1,   0, 160-SPR_DOG_W   , 0
        .byte ET_STRAY  ,  73, SHELF_2-SPR_STRAY_H,      1,  67, 120-SPR_STRAY_W , 0
        .byte ET_PIGEON ,  33, 38                ,      2,   7, 160-SPR_PIGEON_W, 38

r24_props
        .byte DECAL+DECAL_CLOUD     ,   3,  20
        .byte DECAL+DECAL_CLOUD2    , 100,  23
        .byte PROP_FENCE            , 113, 157
        .byte PROP_BUS              ,  67, 133
        .byte PROP_FENCE            ,  33, 109
        .byte PROP_FENCE            ,  73,  85
        .byte DECAL+DECAL_LAMP      ,   3, 161
        .byte DECAL+DECAL_SIGN      , 148, 167
        .byte $ff

;; ---------------------------------------------------------------------------
;; 25 - the vet's waiting room. Caught on the pavement by somebody who thought
;; he was a stray, and the lunchbox went into the office with him.
;; ---------------------------------------------------------------------------
r25_plat
        .byte   0, 159, FLOOR_Y 
        .byte  13,  47, SHELF_1       ; the bench
        .byte  57,  97, SHELF_2       ; the counter
        .byte  17,  57, SHELF_3       ; a shelf of the rack
        .byte  67,  87, SHELF_4       ; the top of the cabinet
        .byte $ff

r25_saus
        .byte  83, FLOOR_Y-PICK_H
        .byte  19, SHELF_1-PICK_H
        .byte  66, SHELF_2-PICK_H
        .byte  26, SHELF_3-PICK_H
        .byte  73, SHELF_4-PICK_H

r25_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_DOG    ,  67, FLOOR_Y-SPR_DOG_H ,      1,   0, 160-SPR_DOG_W   , 0
        .byte ET_SYRINGE,  33, 38                ,      2,   7, 160-SPR_SYRINGE_W, 38
        .byte ET_SYRINGE, 117, 49                , -2&255,   7, 160-SPR_SYRINGE_W, 49

r25_props
        .byte PROP_RACK             ,  17,  61
        .byte PROP_BENCH            ,  13, 157
        .byte PROP_COUNTER          ,  57, 133
        .byte PROP_CABINET          ,  67,  85
        .byte DECAL+DECAL_PLANT     , 100, 161      ; (C64: standing on the floor)
        .byte $ff

;; ---------------------------------------------------------------------------
;; 26 - the examination room, and the table he is not getting onto. The
;; syringes float about on their own in here, which is not reassuring.
;; ---------------------------------------------------------------------------
r26_plat
        .byte   0, 159, FLOOR_Y 
        .byte 100, 137, SHELF_1       ; the examination table
        .byte  50,  77, SHELF_2       ; the trolley
        .byte  33,  74, SHELF_3       ; a shelf of the rack
        .byte  60,  81, SHELF_4       ; the top of the cabinet
        .byte $ff

r26_saus
        .byte  76, FLOOR_Y-PICK_H
        .byte 109, SHELF_1-PICK_H
        .byte  56, SHELF_2-PICK_H
        .byte  43, SHELF_3-PICK_H
        .byte  66, SHELF_4-PICK_H

r26_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_DOG    ,  67, FLOOR_Y-SPR_DOG_H , -1&255,   0, 160-SPR_DOG_W   , 0
        .byte ET_SYRINGE,  33, 40                ,      2,   7, 160-SPR_SYRINGE_W, 40
        .byte ET_SYRINGE, 117, 50                , -2&255,   7, 160-SPR_SYRINGE_W, 50

r26_props
        .byte PROP_RACK             ,  33,  61
        .byte PROP_BASIN            , 127, 133
        .byte PROP_EXAMTABLE        , 100, 157
        .byte PROP_DRAWERS          ,  50, 133
        .byte PROP_CABINET          ,  60,  85
        .byte $ff

;; ---------------------------------------------------------------------------
;; 27 - the store room, where the confiscated lunchbox is. Milk on the crates,
;; which is either a kindness or a trap.
;; ---------------------------------------------------------------------------
r27_plat
        .byte   0, 159, FLOOR_Y 
        .byte  10,  44, SHELF_1       ; the boxes
        .byte  60, 101, SHELF_2       ; the crates
        .byte  13,  54, SHELF_3       ; a shelf of the near rack
        .byte  67, 107, SHELF_4       ; the far one
        .byte $ff

r27_saus
        .byte  83, FLOOR_Y-PICK_H
        .byte  16, SHELF_1-PICK_H
        .byte  69, SHELF_2-PICK_H
        .byte  23, SHELF_3-PICK_H
        .byte  76, SHELF_4-PICK_H

r27_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_MOP    ,  67, FLOOR_Y-SPR_MOP_H ,      1,   0, 160-SPR_MOP_W   , 0
        .byte ET_BLOB   ,  17, SHELF_1-SPR_BLOB_H,      1,  10, 43-SPR_BLOB_W   , 0
        .byte ET_SYRINGE, 117, 37                , -2&255,   7, 160-SPR_SYRINGE_W, 37

r27_props
        .byte PROP_RACK             ,  13,  61
        .byte PROP_RACK             ,  67,  85
        .byte PROP_SHOEBOX          ,  10, 157
        .byte PROP_CRATES           ,  60, 133
        .byte DECAL+DECAL_FLASK     , 110, 145
        .byte $ff

;; ---------------------------------------------------------------------------
;; 28 - the rooftops, and it is dark again. Home is four streets that way, over
;; the slates, and the tom who lives up here was here first.
;; ---------------------------------------------------------------------------
r28_plat
        .byte   0, 159, FLOOR_Y 
        .byte  13,  31, SHELF_1       ; the chimney stack
        .byte  50, 111, SHELF_2       ; the pitch of the first roof
        .byte 100, 154, SHELF_3       ; the next one up
        .byte  40,  81, SHELF_4       ; the water tank
        .byte $ff

r28_saus
        .byte  83, FLOOR_Y-PICK_H
        .byte  16, SHELF_1-PICK_H
        .byte  63, SHELF_2-PICK_H
        .byte 109, SHELF_3-PICK_H
        .byte  49, SHELF_4-PICK_H

r28_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_BAT    ,  33, 37                ,      2,   7, 160-SPR_BAT_W   , 37
        .byte ET_BAT    , 117, 49                , -2&255,   7, 160-SPR_BAT_W   , 49
        .byte ET_STRAY  ,  67, FLOOR_Y-SPR_STRAY_H,      1,   0, 160-SPR_STRAY_W , 0

r28_props
        .byte DECAL+DECAL_MOON      , 137,  22
        .byte PROP_CHIMNEY          ,  13, 157
        .byte PROP_STAIRS           ,  50, 133
        .byte PROP_STAIRS           , 100, 109
        .byte PROP_CRATES           ,  40,  85
        .byte DECAL+DECAL_AERIAL    , 117,  98
        .byte DECAL+DECAL_AERIAL    ,  31, 170      ; (C64: clear of the chimney)
        .byte $ff

;; ---------------------------------------------------------------------------
;; 29 - down the chimney, and out into his own fireplace. Two floors of soot,
;; a colony of bats, and the smell of the flat at the bottom of it.
;; ---------------------------------------------------------------------------
r29_plat
        .byte   0, 159, FLOOR_Y 
        .byte 100, 141, SHELF_1       ; a ledge of soot boxes
        .byte  50,  91, SHELF_2       ; the next one
        .byte  97, 154, SHELF_3       ; the brickwork steps
        .byte  40,  81, SHELF_4       ; the flue above them
        .byte $ff

r29_saus
        .byte  76, FLOOR_Y-PICK_H
        .byte 109, SHELF_1-PICK_H
        .byte  59, SHELF_2-PICK_H
        .byte 106, SHELF_3-PICK_H
        .byte  49, SHELF_4-PICK_H

r29_enem
        ;; type, x, y, dx, first x, last x, top of a flyer's arc
        .byte ET_BAT    ,  33, 40                ,      2,   7, 160-SPR_BAT_W   , 40
        .byte ET_BAT    , 117, 52                , -2&255,   7, 160-SPR_BAT_W   , 52
        .byte ET_STRAY  ,  67, FLOOR_Y-SPR_STRAY_H, -1&255,   0, 160-SPR_STRAY_W , 0

r29_props
        .byte PROP_CRATES           , 100, 157
        .byte PROP_CRATES           ,  50, 133
        .byte PROP_STAIRS           ,  97, 109
        .byte PROP_CRATES           ,  40,  85
        .byte DECAL+DECAL_AERIAL    ,   7, 170
        .byte $ff

