package main

import rl "vendor:raylib"
import "ngui"
import "player"
import "world"
import "world/grid"
import "world/liquid"

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
        return // What a drag, I'm outta here
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
            // gui_drag(cursor)
            if !ngui.want_mouse() {
                // rl.DrawRectangleV(hover, grid.CELL_SIZE, rl.YELLOW - {0, 0, 0, 60})
                // grid.draw(camera)
            }
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
        if ngui.flex_row({0.5, 0.5}) {
            ngui.float(&timescale, 0, 5, label = "Timescale")
            if ngui.button("Play" if timescale == 0 else "Pause") || rl.IsKeyPressed(.SPACE) {
                timescale = 1 if timescale == 0 else 0
            }
        }

        if ngui.flex_row({0.2, 0.3, 0.3, 0.2}) {
            ngui.text("Player")
            ngui.vec2(&player.pos, label = "Position")
            ngui.vec2(&player.vel, label = "Velocity")
            ngui.float(&player.fullness, min = 0, max = 1, step = 0.01, label = "Fullness")
        }

        if ngui.flex_row({0.25, 0.25}) {
            ngui.text("Particles: %d", len(liquid.particles))
            if liquid.stats.neighbor_count != 0 {
                ngui.text("Avg Neighbors: %d", liquid.stats.neighbors / liquid.stats.neighbor_count)
            }
        }
        if ngui.flex_row({0.25, 0.25, 0.25, 0.25}) {
            ngui.float(&liquid.collision_damp,   min = 0.1, max = 1, step = 0.01, label = "Collision Damp")
            ngui.float(&liquid.smoothing_radius, min = 0.1, max = 100, label = "Smoothing Radius")
            ngui.float(&liquid.target_density,   min = 1,   max = 200, label = "Target Density")
            ngui.float(&liquid.pressure_mult,    min = 0.1, max = 500, label = "Pressure Mult")
        }
        if ngui.flex_row({0.4, 0.3, 0.3}) {
            if ngui.button("Stop all particles") {
                for &p in liquid.particles {
                    p.vel = 0
                }
            }

            SPAWN_STEP :: 16
            if ngui.button("Less") do liquid.create(len(liquid.particles) - SPAWN_STEP)
            if ngui.button("More") do liquid.create(len(liquid.particles) + SPAWN_STEP)
        }

        if ngui.flex_row({0.25, 0.25}) {
            ngui.arrow(&liquid.GRAVITY, "Gravity",  max_mag = 600)
            ngui.float(&liquid.interaction_strength, min = 100, max = 400, step = 1, label = "Mouse Force")
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