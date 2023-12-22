package main

import rl "vendor:raylib"
import "ngui"
import "player"
import "world"
import "world/grid"

Gui :: struct {
    dragging: bool,
    drag_mouse_start: rl.Vector2,
}

gui : Gui

gui_drag :: proc(cursor: rl.Vector2) {
    if !ngui.want_mouse() && rl.IsMouseButtonPressed(.LEFT) {
        gui.dragging = true
        gui.drag_mouse_start = cursor
        return
    }

    if !gui.dragging do return
    // Here be draggin'

    if rl.IsMouseButtonPressed(.RIGHT) {
        gui.dragging = false
        return
    }

    // The grid square the mouse hovered when dragging started. Pick the corner based on drag direction.
    d_mouse := gui.drag_mouse_start
    start_x := grid.snap_up(i32(d_mouse.x)) if cursor.x < d_mouse.x else grid.snap_down(i32(d_mouse.x))
    start_y := grid.snap_up(i32(d_mouse.y)) if cursor.y < d_mouse.y else grid.snap_down(i32(d_mouse.y))
    start := rl.Vector2{f32(start_x), f32(start_y)}

    // The grid square the mouse is currently hovering. Again, the corner is based on drag direction.
    end_x := grid.snap_up(i32(cursor.x)) if cursor.x > d_mouse.x else grid.snap_down(i32(cursor.x))
    end_y := grid.snap_up(i32(cursor.y)) if cursor.y > d_mouse.y else grid.snap_down(i32(cursor.y))
    end := rl.Vector2{f32(end_x), f32(end_y)}

    drag_rect := normalize_rect(start, end)
    rl.DrawRectangleRec(drag_rect, rl.GREEN - {0, 0, 0, 100})

    if rl.IsMouseButtonReleased(.LEFT) {
        gui.dragging = false
        append(&world.walls, world.Wall{ drag_rect, world.rand_color() })
    }
}

gui_draw :: proc() {
    cursor := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
    if hover, ok := grid.hovered_cell(cursor); ok {
        // Delete walls on right click.
        if rl.IsMouseButtonPressed(.RIGHT) do for wall, i in world.walls {
            if rl.CheckCollisionPointRec(cursor, wall.rec) {
                unordered_remove(&world.walls, i)
            }
        }

        rl.BeginMode2D(camera)
            gui_drag(cursor)
            rl.DrawRectangleV(hover, grid.CELL_SIZE, rl.YELLOW - {0, 0, 0, 60})
            grid.draw(camera)
        rl.EndMode2D()
    }

    ngui.update()

    if ngui.begin_panel("Game", {0, 0, 400, 0}) {
        if ngui.flex_row({0.2, 0.4, 0.2, 0.2}) {
            ngui.text("Camera")
            ngui.vec2(&camera.target, label = "Target")
            ngui.float(&camera.zoom, min = 0.1, max = 10, label = "Zoom")
            ngui.float(&camera.rotation, min = -360, max = 360, label = "Angle")
        }
        if ngui.flex_row({1}) {
            ngui.float(&timescale, 0, 10, label = "Timescale")
        }

        if ngui.flex_row({0.2, 0.3, 0.3, 0.2}) {
            ngui.text("Player")
            ngui.vec2(&player.pos, label = "Position")
            ngui.vec2(&player.vel, label = "Velocity")
            ngui.float(&player.fullness, min = 0, max = 1, step = 0.01, label = "Fullness")
        }
    }

    rl.DrawFPS(rl.GetScreenWidth() - 80, 0)
}

normalize_rect :: proc(start, end: rl.Vector2) -> rl.Rectangle {
    return {
        min(start.x, end.x),
        min(start.y, end.y),
        abs(end.x - start.x),
        abs(end.y - start.y),
    }
}