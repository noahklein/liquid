package main

import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

import "ngui"

timescale : f32

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

    ngui.init()
    defer ngui.deinit()

    rl.SetTargetFPS(120)
    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)

        // dt := rl.GetFrameTime() * timescale

        rl.BeginDrawing()
        defer rl.EndDrawing()
        rl.ClearBackground(rl.PURPLE)

        when ODIN_DEBUG {
            draw_gui()
        }
    }
}

draw_gui :: proc() {
    ngui.update()

    if ngui.begin_panel("hello", {0, 0, 300, 0}) {
        if ngui.flex_row({1}) {
            if ngui.button("hello") do fmt.println("hello")
        }
    }

    rl.DrawFPS(rl.GetScreenWidth() - 80, 0)
}