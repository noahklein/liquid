package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:math/rand"

import rl "vendor:raylib"

import "player"
import "ngui"
import "world"
import "world/grid"
import "world/liquid"

timescale : f32 = 1.0
camera: rl.Camera2D
liquid_box_target: rl.Vector2

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


    // Spawn liquid emitter for testing.
    // append(&world.emitters, world.LiquidEmitter{
    //     pos = {10 * grid.CELL_SIZE, -8 * grid.CELL_SIZE},
    // })


    liquid.init(128)
    defer liquid.deinit()
    liquid.create(128)

    defer delete(player.broad_hits)

    when ODIN_DEBUG {
        ngui.init()
        defer ngui.deinit()
    }

    rl.SetTargetFPS(120)
    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)

        dt := rl.GetFrameTime() * timescale
        world.liquid_update(dt)
        liquid.update(dt)
        player.update(dt)

        if linalg.distance(camera.target, player.pos) > 3 * grid.CELL_SIZE {
            camera.target += (player.pos - camera.target) * rl.GetFrameTime() // Unaffected by timescale
        }

        if !ngui.want_mouse() && rl.IsMouseButtonPressed(.LEFT) {
            liquid_box_target = rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

        }
        liquid.BOX.x = linalg.lerp(liquid.BOX.x, liquid_box_target.x, dt)
        liquid.BOX.y = linalg.lerp(liquid.BOX.y, liquid_box_target.y, dt)

        rl.BeginDrawing()
        defer rl.EndDrawing()
        rl.ClearBackground(rl.LIGHTGRAY - 5 * {10, 0, 10, 0})

        rl.BeginMode2D(camera)
            player.draw2D()
            world.draw2D()
            liquid.draw2D()
        rl.EndMode2D()

        when ODIN_DEBUG {
            gui_draw()
        }
    }
}

screen_size :: #force_inline proc() -> rl.Vector2 {
    return { f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()) }
}
