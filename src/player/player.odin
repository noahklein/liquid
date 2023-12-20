package player

import rl "vendor:raylib"
import "core:math/linalg"
import "../world"
import "../world/grid"

SIZE        :: rl.Vector2{2 * grid.CELL_SIZE, 3 * grid.CELL_SIZE}

SPEED     :: 8 * grid.CELL_SIZE
MAX_SPEED :: 10 * grid.CELL_SIZE
FRICTION  :: 0.95
TURN_FRICTION :: 0.75

pos, vel: rl.Vector2
fullness: f32

facing: FacingDirection
FacingDirection :: enum u8 { Left, Right, Turning }

Action :: enum u8 { Left, Right }

get_input :: proc() -> bit_set[Action] {
    input: bit_set[Action]

    if      rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)  do input += {.Left}
    else if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) do input += {.Right}

    return input
}

@(require_results)
get_rect :: #force_inline proc() -> rl.Rectangle {
    return {pos.x, pos.y, SIZE.x, SIZE.y}
}

update :: proc(dt: f32) {
    if world.check_collision(get_rect()) {
        return
    }

    input := get_input()
    if .Left  in input {
        facing = .Left
        if vel.x > 0 {
            // We're sliding the wrong way, slow down.
            vel.x *= TURN_FRICTION
            facing = .Turning
        }

        vel.x -= SPEED * dt
    } else if .Right in input {
        facing = .Right
        if vel.x < 0 {
            // We're sliding the wrong way, slow down.
            vel.x *= TURN_FRICTION
            facing = .Turning
        }

        vel.x += SPEED * dt
    } else {
        vel *= FRICTION // Only apply friction when not moving.
    }

    vel = linalg.clamp(vel, -MAX_SPEED, MAX_SPEED)
    pos += vel * dt
}

draw2D :: proc() {
    // Player
    rect := get_rect()
    rl.DrawRectangleRec(rect, rl.BEIGE)

    // Tank
    if facing != .Turning {
        rect.x += SIZE.x if facing == .Left else -SIZE.x
    }
    rect.y -= SIZE.y / 2
    rl.DrawRectangleRec(rect, rl.BLUE)

    // Liquid
    rect.height = (1 - fullness) * SIZE.y
    rl.DrawRectangleRec(rect, rl.BLACK)
}