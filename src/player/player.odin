package player

import rl "vendor:raylib"

BLOCK_SIZE  :: 16
SIZE        :: rl.Vector2{2 * BLOCK_SIZE, 3 * BLOCK_SIZE}
TANK_SIZE   :: SIZE

SPEED: f32 = 100
FRICTION: f32 = 0.98

pos, vel: rl.Vector2
fullness: f32
facing_left: bool

Action :: enum u8 {
    Left, Right,
}

get_input :: proc() -> bit_set[Action] {
    input: bit_set[Action]

    if      rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)  do input += {.Left}
    else if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) do input += {.Right}

    return input
}

update :: proc(dt: f32) {
    input := get_input()
    if .Left  in input {
        vel.x -= SPEED * dt
        facing_left = true
    } else if .Right in input {
        vel.x += SPEED * dt
        facing_left = false
    }

    vel *= FRICTION
    pos += vel * dt
}

draw2D :: proc() {
    // Player
    rect := rl.Rectangle{pos.x, pos.y, SIZE.x, SIZE.y}
    rl.DrawRectangleRec(rect, rl.WHITE)

    // Tank
    rect.x += SIZE.x if facing_left else -SIZE.x
    rect.y -= SIZE.y / 2
    rl.DrawRectangleRec(rect, rl.BLUE)

    // Liquid
    rect.height = (1 - fullness) * SIZE.y
    rl.DrawRectangleRec(rect, rl.BLACK)
}