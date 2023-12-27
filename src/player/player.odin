package player

import "core:math/linalg"

import rl "vendor:raylib"

import "../world"
import "../world/grid"
import "../ngui"

SIZE        :: rl.Vector2{2 * grid.CELL_SIZE, 3 * grid.CELL_SIZE}

SPEED     :: 8 * grid.CELL_SIZE
MAX_SPEED :: 10 * grid.CELL_SIZE
FRICTION  :: 0.95
TURN_FRICTION :: 0.75
GRAVITY :: 8 * grid.CELL_SIZE
FIXED_DT :: 1.0 / 120.0

pos, vel: rl.Vector2
fullness: f32
dt_acc: f32

is_colliding: bool

facing: FacingDirection
FacingDirection :: enum u8 { Left, Right, Turning }

Action :: enum u8 { Left, Right }

get_input :: proc() -> bit_set[Action] {
    if ngui.want_keyboard() do return {} // User is typing in GUI

    input: bit_set[Action]
    if      rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)  do input += {.Left}
    else if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) do input += {.Right}
    return input
}

@(require_results)
get_rect :: #force_inline proc() -> rl.Rectangle {
    return {pos.x, pos.y, SIZE.x, SIZE.y}
}

@(require_results)
get_tank_rect :: #force_inline proc(player_rect: rl.Rectangle) -> rl.Rectangle {
    tank := player_rect
    if facing != .Turning {
        tank.x += SIZE.x if facing == .Left else -SIZE.x
    }
    tank.y -= SIZE.y / 2

    return tank
}

update :: proc(dt: f32) {
    dt_acc += dt
    for dt_acc >= FIXED_DT {
        dt_acc -= FIXED_DT
        fixed_update(FIXED_DT)
    }
}

fixed_update :: proc(dt: f32) {
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
        vel.x *= FRICTION // Only apply friction when not moving.
    }

    vel.y += GRAVITY * dt
    vel = linalg.clamp(vel, -MAX_SPEED, MAX_SPEED)

    if vel != 0 && abs(vel.x) < linalg.F32_EPSILON && abs(vel.y) < linalg.F32_EPSILON {
        vel = 0
    }

    player_rect := get_rect()
    if vel != 0 {
        vel = world.check_collision(dt, player_rect, vel)
    }
    pos += vel * dt

    {
        // Check liquid tank collision.
        tank_rect := get_tank_rect(player_rect)
        for &particle, i in world.liquid {
            if rl.CheckCollisionCircleRec(particle.center, world.LIQUID_RADIUS, tank_rect) {
                if fullness >= 1 {
                    fullness = 1
                    particle.vel *= -1
                    // particle.vel.y *= -1
                    // particle.vel.x += (rand.float32() - 0.5) * 100 * grid.CELL_SIZE * dt
                    // particle.vel.x += (rand.float32() - 0.5) * MAX_SPEED / 2
                    continue
                }

                // @HACK: last element will be skipped because of swap.
                unordered_remove(&world.liquid, i)
                fullness += 0.1
            }
        }
    }

}

draw2D :: proc() {
    rect := get_rect()
    rl.DrawRectangleRec(rect, rl.BEIGE if !is_colliding else rl.RED)
}