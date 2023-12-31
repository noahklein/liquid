package grid

import rl "vendor:raylib"

CELL_SIZE :: 16
COLOR :: rl.Color{255, 255, 255, 150}

draw :: proc(camera: rl.Camera2D) {
    start := snap_down(camera.target - camera.offset)
    end   := snap_up  (camera.target + camera.offset)

    if int(start.x) % (2 * CELL_SIZE) != 0 do start.x -= CELL_SIZE
    if int(start.y) % (2 * CELL_SIZE) != 0 do start.y -= CELL_SIZE

    for x := start.x; x <= end.x; x += 2 * CELL_SIZE {
        rl.DrawLineV({x, start.y}, {x, end.y}, COLOR)
    }

    for y := start.y; y <= end.y; y += 2 * CELL_SIZE {
        rl.DrawLineV({start.x, y}, {end.x, y}, COLOR)
    }
}

hovered_cell :: proc(mouse: rl.Vector2) -> (rl.Vector2, bool) {
    return snap_down(mouse), rl.IsCursorOnScreen()
}

snap_down :: proc{
    snap_down_i32,
    snap_down_vec,
}

@(require_results)
snap_down_i32 :: #force_inline proc(i: i32) -> i32 {
    if i < 0 {
        return ((i - CELL_SIZE + 1) / CELL_SIZE) * CELL_SIZE
    }

    return (i / CELL_SIZE) * CELL_SIZE
}

@(require_results)
snap_down_vec :: #force_inline proc(m: rl.Vector2) -> rl.Vector2 {
    return { f32(snap_down(i32(m.x))), f32(snap_down(i32(m.y))) }
}

snap_up :: proc{
    snap_up_i32,
    snap_up_vec,
}

@(require_results)
snap_up_i32 :: #force_inline proc(i: i32) -> i32 {
    return snap_down(i) + CELL_SIZE
}

@(require_results)
snap_up_vec :: #force_inline proc(m: rl.Vector2) -> rl.Vector2 {
    return { f32(snap_up(i32(m.x))), f32(snap_up(i32(m.y))) }
}