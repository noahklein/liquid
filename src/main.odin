package main

import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

import "player"
import "ngui"
import "world"
import "world/grid"

timescale : f32 = 1.0
camera: rl.Camera2D

main :: proc() {
      when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }
    defer free_all(context.temp_allocator)

    rl.SetTraceLogLevel(.ALL if ODIN_DEBUG else .WARNING)
    rl.InitWindow(1600, 900, "Terminalia")
    defer rl.CloseWindow()

    camera = rl.Camera2D{ zoom = 1, offset = screen_size() / 2 }
    world.init()
    defer world.deinit()

    defer delete(player.broad_hits)

    when ODIN_DEBUG {
        ngui.init()
        defer ngui.deinit()
    }

    rl.SetTargetFPS(120)
    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)

        dt := rl.GetFrameTime() * timescale
        player.update(dt)

        camera.target += (player.pos - camera.target) * dt

        rl.BeginDrawing()
        defer rl.EndDrawing()
        rl.ClearBackground(rl.PURPLE)

        rl.BeginMode2D(camera)
            player.draw2D()
            world.draw2D()
        rl.EndMode2D()

        when ODIN_DEBUG {
            draw_gui()
        }
    }
}

draw_gui :: proc() {
    cursor := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
    if hover, ok := grid.hovered_cell(cursor); ok {
        rl.BeginMode2D(camera)
            gui_drag(cursor)
            rl.DrawRectangleV(hover, grid.CELL_SIZE, rl.YELLOW - {0, 0, 0, 60})
            grid.draw(camera)
        rl.EndMode2D()
    }

    ngui.update()

    if ngui.begin_panel("Game", {0, 0, 500, 0}) {
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

screen_size :: #force_inline proc() -> rl.Vector2 {
    return { f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()) }
}