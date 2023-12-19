package ngui

import rl "vendor:raylib"
import "core:math"
import "core:math/linalg"

FONT :: 11
TEXT_COLOR :: rl.WHITE
// DARK_TEXT_COLOR :: rl.BLACK
DARK_TEXT_COLOR :: DEFAULT_BUTTON_COLOR
PANEL_COLOR ::  rl.Color{ 200, 200, 200, 190 }

TITLE_FONT :: 11
TITLE_HEIGHT :: 26
TITLE_COLOR :: rl.MAROON

LABEL_HEIGHT :: FONT + 2

DEFAULT_BUTTON_COLOR :: rl.DARKBLUE
HOVER_BUTTON_COLOR   :: rl.BLUE
ACTIVE_BUTTON_COLOR  :: rl.SKYBLUE

INPUT_PAD :: 2
INPUT_CURSOR_WIDTH  :: 5

SLIDER_WIDTH :: 16

button_color :: proc(hover, active: bool, press := false) -> rl.Color {
    mod: rl.Color = {10, 10, 0, 0} if press else 0
    if active {
        return ACTIVE_BUTTON_COLOR + mod
    } else if hover {
        return HOVER_BUTTON_COLOR + mod
    }
    return DEFAULT_BUTTON_COLOR + mod
}

dark_color :: proc(hover, active: bool) -> rl.Color {
    if active {
        return {80, 80, 80, 255}
    } else if hover {
        return {40, 40, 40, 255}
    }
    return rl.BLACK
}

title_color :: proc(active: bool) -> rl.Color {
    return rl.RED if active else rl.MAROON
}

input_color :: proc(hover, active: bool) -> rl.Color {
    color := dark_color(hover, active)
    if hover && rl.IsMouseButtonDown(.LEFT) {
        color += {20, 20, 20, 0}
    }
    return color
}

// Blinks between white and non_white.
cursor_color :: proc(non_white := rl.SKYBLUE) -> rl.Color {
    now := rl.GetTime()
    t := math.cos(2 * (now - state.last_keypress_time))
    t *= t

    return lerp_color(rl.WHITE, non_white, f32(t))
}

lerp_color :: proc(ac, bc: rl.Color, t: f32) -> rl.Color {
    a := linalg.array_cast(ac, f32)
    b := linalg.array_cast(bc, f32)

    v := linalg.lerp(a, b, t)

    return rl.Color(linalg.array_cast(v, u8))
}