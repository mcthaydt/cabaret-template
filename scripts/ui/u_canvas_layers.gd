extends RefCounted
class_name U_CanvasLayers

## Canonical CanvasLayer ordering for root viewport and GameViewport post-process layers.

# Root viewport layers (draw order)
const HUD := 6
const UI_OVERLAY := 10
const UI_COLOR_BLIND := 11
const TRANSITION := 50
const DAMAGE_FLASH := 90
const LOADING := 100
const MOBILE_CONTROLS := 101
const DEBUG_OVERLAY := 128

# GameViewport-internal layers (separate layer space)
const PP_CINEMA_GRADE := 1
const PP_FILM_GRAIN := 2
const PP_DITHER := 3
const PP_CRT := 4
const PP_COLOR_BLIND := 5
