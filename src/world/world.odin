package world

import rl "vendor:raylib"

walls: [dynamic]Wall

Wall :: struct{
    rec: rl.Rectangle,
}

check_collision :: proc(rec: rl.Rectangle) -> bool {
    for wall in walls {
        if rl.CheckCollisionRecs(rec, wall.rec) do return true
    }

    return false
}