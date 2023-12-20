package main

import rl "vendor:raylib"
import "world"
import "world/grid"

Gui :: struct {
    dragging: bool,
    drag_mouse_start: rl.Vector2,
}

gui : Gui

gui_drag :: proc(cursor: rl.Vector2) {
    if rl.IsMouseButtonPressed(.LEFT) {
        gui.dragging = true
        gui.drag_mouse_start = cursor
        return
    }

    if !gui.dragging do return

    if rl.IsMouseButtonPressed(.RIGHT) {
        gui.dragging = false
        return
    }

    d_mouse := gui.drag_mouse_start
    start_x := grid.snap_up(i32(d_mouse.x)) if cursor.x < d_mouse.x else grid.snap_down(i32(d_mouse.x))
    start_y := grid.snap_up(i32(d_mouse.y)) if cursor.y < d_mouse.y else grid.snap_down(i32(d_mouse.y))
    start := rl.Vector2{f32(start_x), f32(start_y)}

    end_x := grid.snap_up(i32(cursor.x)) if cursor.x > d_mouse.x else grid.snap_down(i32(cursor.x))
    end_y := grid.snap_up(i32(cursor.y)) if cursor.y > d_mouse.y else grid.snap_down(i32(cursor.y))
    end := rl.Vector2{f32(end_x), f32(end_y)}

    drag_rect := normalize_rect(start, end)
    rl.DrawRectangleRec(drag_rect, rl.GREEN - {0, 0, 0, 100})

    if rl.IsMouseButtonReleased(.LEFT) {
        gui.dragging = false
        append(&world.walls, world.Wall{ drag_rect })
    }
}

normalize_rect :: proc(start, end: rl.Vector2) -> rl.Rectangle {
    return {
        min(start.x, end.x),
        min(start.y, end.y),
        abs(end.x - start.x),
        abs(end.y - start.y),
    }
}