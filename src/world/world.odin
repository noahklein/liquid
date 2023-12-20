package world

import rl "vendor:raylib"

walls: [dynamic]Wall

init :: proc() {
    reserve(&walls, 128)

}
deinit :: proc() {
    delete(walls)
}

Wall :: struct{
    rec: rl.Rectangle,
}

check_collision :: proc(rec: rl.Rectangle) -> bool {
    for wall in walls {
        if rl.CheckCollisionRecs(rec, wall.rec) do return true
    }

    return false
}

draw2D :: proc() {
    for wall in walls {
        rl.DrawRectangleRec(wall.rec, rl.LIME)
    }
}