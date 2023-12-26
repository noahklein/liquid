package main

import "core:fmt"
import "core:math/linalg"
import "core:mem"

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

    // liquid.BOX = player.get_tank_rect(player.get_rect())
    player.pos = {5, 5} * grid.CELL_SIZE

    {
        // Init tank position.
        rect := player.get_tank_rect(player.get_rect())
        liquid.BOX.x = rect.x
        liquid.BOX.y = rect.y
        liquid.BOX = rect
    }

    liquid.create(100)
    defer liquid.deinit()

    when ODIN_DEBUG {
        ngui.init()
        defer ngui.deinit()
    }

    rl.SetTargetFPS(120)
    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)

        dt := min(rl.GetFrameTime() * timescale, 0.3)
        cursor := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

        world.liquid_update(dt)
        liquid.update(dt, liquid_box_target, cursor)
        player.update(dt)

        camera_follow :: proc(target: rl.Vector2) {
            if linalg.distance(camera.target, target) > 3 * grid.CELL_SIZE {
                camera.target += (target - camera.target) * rl.GetFrameTime() // Unaffected by timescale
            }
        }
        camera_follow({
            liquid.BOX.x + liquid.BOX.width  / 2,
            liquid.BOX.y + liquid.BOX.height / 2,
        })
        tank := player.get_tank_rect(player.get_rect())
        liquid_box_target = {tank.x, tank.y}
        // if !ngui.want_mouse() && rl.IsMouseButtonPressed(.LEFT) {
            // liquid.interaction_force(cursor)
            // liquid_box_target = rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
        // }

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
