package player

import "core:fmt"
import "core:math/linalg"
import "core:slice"

import rl "vendor:raylib"

import "../world"
import "../world/grid"

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

    EPSILON :: 1e-7
    if vel != 0 && abs(vel.x) < EPSILON && abs(vel.y) < EPSILON {
        vel = 0
    }

    check_collision(dt)
    pos += vel * dt
}

draw2D :: proc() {
    // Player
    rect := get_rect()
    rl.DrawRectangleRec(rect, rl.BEIGE if !is_colliding else rl.RED)

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

broad_hits : [dynamic]BroadHit

BroadHit :: struct {
    time: f32,
    wall_index: int,
}

check_collision :: proc(dt: f32)  {
    player_rect := get_rect()

    // Broad-phase, get a list of all collision objects.
    clear(&broad_hits)
    for wall, i in world.walls {
        contact := world.dyn_rect_vs_rect(player_rect, wall.rec, vel, dt) or_continue
        append(&broad_hits, BroadHit{
            time = contact.time,
            wall_index = i,
        })
    }

    if len(broad_hits) == 0 {
        return
    }

    // Sort the colliding rects by collision time: nearest first.
    slice.sort_by_key(broad_hits[:], proc(bh: BroadHit) -> f32 {
        return bh.time
    })

    // Narrow-phase: check sorted collisions and resolve them in order.
    for hit in broad_hits {
        wall := world.walls[hit.wall_index]
        contact := world.dyn_rect_vs_rect(player_rect, wall.rec, vel, dt) or_continue
        vel += contact.normal * linalg.abs(vel) * (1 - contact.time)
    }
}