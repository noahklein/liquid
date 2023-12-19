package player

import rl "vendor:raylib"

BLOCK_SIZE  :: 16
SIZE        :: rl.Vector2{BLOCK_SIZE, 3 * BLOCK_SIZE}
TANK_SIZE   :: SIZE

SPEED: f32 = 100
FRICTION: f32 = 0.98

pos, vel: rl.Vector2
fullness: f32

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
    if      .Left  in input do vel.x -= SPEED * dt
    else if .Right in input do vel.x += SPEED * dt

    vel *= FRICTION
    pos += vel * dt
}

draw2D :: proc() {
    rl.DrawRectangleRec({pos.x, pos.y, SIZE.x, SIZE.y}, rl.WHITE)
    rl.DrawRectangleRec({pos.x - SIZE.x, pos.y - SIZE.y / 2, SIZE.x, SIZE.y}, rl.BLUE)
    rl.DrawRectangleRec({pos.x - SIZE.x, pos.y - SIZE.y / 2, SIZE.x, (1 - fullness) * SIZE.y}, rl.BLACK)
}