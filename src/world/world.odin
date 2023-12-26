package world

import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"

import rl "vendor:raylib"

import "grid"
// import liquid_sim "liquid"
import "../ngui"

FIXED_DT :: 1.0 / 120.0

LIQUID_COLOR  :: rl.BLUE
LIQUID_RADIUS :: grid.CELL_SIZE / 8
// LIQUID_RADIUS :: grid.CELL_SIZE / 4
LIQUID_GRAVITY  :: 5 * grid.CELL_SIZE
MAX_PARTICLE_SPEED :: 10 * grid.CELL_SIZE
EMITTER_FIRE_SECONDS :: 0.1

TANK_GRAVITY :: 5 * grid.CELL_SIZE

walls:  [dynamic]Wall
liquid: [dynamic]LiquidParticle
tanks:  [dynamic]Tank
emitters: [dynamic]LiquidEmitter
dt_acc: f32

init :: proc() {
    // reserve(&walls, 128)
    reserve(&liquid, 128)
    reserve(&emitters, 16)
    reserve(&walls, 1024)
    reserve(&tanks, 1)

    for x in 0..<cap(walls) {
        WIDTH :: 3 * grid.CELL_SIZE
        append(&walls, Wall{
            rec = {f32(x) * WIDTH, 10 * grid.CELL_SIZE, WIDTH, grid.CELL_SIZE * 5},
            color = rand_color(),
        })
    }
}

deinit :: proc() {
    delete(walls)
    delete(liquid)
    delete(emitters)
    delete(tanks)
    delete(broad_hits)
}

Wall :: struct{
    rec: rl.Rectangle,
    color: rl.Color,
}

LiquidEmitter :: struct {
    pos: rl.Vector2,
    dt_acc: f32, // Fire rate in seconds.
}

LiquidParticle :: struct {
    center, vel: rl.Vector2,
    color: rl.Color,
}

Tank :: struct {
    pos, size, vel: rl.Vector2,
}

liquid_update :: proc(dt: f32) {
    dt_acc += dt
    for dt_acc >= FIXED_DT {
        dt_acc -= FIXED_DT
        liquid_fixed_update(FIXED_DT)
    }
}

liquid_fixed_update :: proc(dt: f32) {
    for &emitter in emitters {
        emitter.dt_acc += dt
        if emitter.dt_acc >= EMITTER_FIRE_SECONDS {
            emitter.dt_acc -= EMITTER_FIRE_SECONDS
            append(&liquid, LiquidParticle{
                center = emitter.pos,
                vel = {(rand.float32() - 0.5) * grid.CELL_SIZE, LIQUID_GRAVITY},
                color = {0, 0, u8(rand.float32() * 100) + 155, 255},
            })
        }
    }

    outer: for &particle, i in liquid {
        particle.vel.y += LIQUID_GRAVITY * dt // @TODO: clamp velocity
        particle.vel = linalg.clamp(particle.vel, -MAX_PARTICLE_SPEED, MAX_PARTICLE_SPEED)
        particle.center += particle.vel * dt

        for &wall in walls {
            if rl.CheckCollisionCircleRec(particle.center, LIQUID_RADIUS, wall.rec) {
                wall.color = ngui.lerp_color(wall.color, LIQUID_COLOR, 0.25)
                // @HACK: last element will be skipped because of swap.
                unordered_remove(&liquid, i)
                continue outer
            }
        }

        // Particle vs particle.
        for &particle_b in liquid[i+1:] {
            if rl.CheckCollisionCircles(particle.center, LIQUID_RADIUS, particle_b.center, LIQUID_RADIUS) {
                // ab := particle_b.center - particle.center
                // dir := linalg.normalize(ab)

                // Particles bounce away from each other.
                // particle.vel = linalg.length(particle.vel) * -dir
                // particle_b.vel = linalg.length(particle_b.vel) * dir

                // Vecter perpendicular to {x, y} is {-y, x}.
                normal := linalg.normalize(rl.Vector2{
                      particle_b.center.y - particle.center.y,
                    -(particle_b.center.x - particle.center.x),
                })

                rel_vel := particle_b.vel - particle.vel
                length := linalg.dot(rel_vel, normal)

                delta_vel := rel_vel - length * normal
                particle.vel   -= delta_vel
                particle_b.vel += delta_vel

            }
        }
    }

    for &tank in tanks {
        tank.vel.y += TANK_GRAVITY * dt // TODO: mass
        tank.pos += tank.vel * dt
    }
}

broad_hits : [dynamic]BroadHit

BroadHit :: struct {
    time: f32,
    wall_index: int,
}

// Player collision detection and resolution. Called for player and tank.
check_collision :: proc(dt: f32, rect: rl.Rectangle, velocity: rl.Vector2) -> rl.Vector2 {
    // Broad-phase, get a list of all collision objects.
    clear(&broad_hits)
    for wall, i in walls {
        contact := dyn_rect_vs_rect(rect, wall.rec, velocity, dt) or_continue
        append(&broad_hits, BroadHit{
            time = contact.time,
            wall_index = i,
        })
    }

    if len(broad_hits) == 0 {
        return velocity
    }

    // Sort the colliding rects by collision time: nearest first.
    slice.sort_by_key(broad_hits[:], proc(bh: BroadHit) -> f32 {
        return bh.time
    })

    // Narrow-phase: check sorted collisions and resolve them in order.
    new_vel := velocity
    for hit in broad_hits {
        wall := walls[hit.wall_index]
        contact := dyn_rect_vs_rect(rect, wall.rec, new_vel, dt) or_continue
        new_vel += contact.normal * linalg.abs(new_vel) * (1 - contact.time)
    }
    return new_vel
}

draw2D :: proc() {
    for wall in walls {
        rl.DrawRectangleRec(wall.rec, wall.color)
    }

    for particle in liquid {
        rl.DrawCircleV(particle.center, LIQUID_RADIUS, particle.color)
    }

    when ODIN_DEBUG do for emitter in emitters {
        EMITTER_SIZE :: rl.Vector2{10, 10}
        rl.DrawRectangleV(emitter.pos - EMITTER_SIZE, EMITTER_SIZE, {0, 200, 0, 150})
    }
}

Contact :: struct {
    time: f32,
    normal: rl.Vector2,
    point: rl.Vector2,
}

ray_vs_rect :: proc(origin, dir: rl.Vector2, rect: rl.Rectangle) -> (Contact, bool) {
    rpos, rsize: rl.Vector2 = {rect.x, rect.y}, {rect.width, rect.height}

    near := (rpos - origin) / dir
    far  := (rpos + rsize - origin) / dir

    if math.is_nan(near.x) || math.is_nan(near.y) do return {}, false
    if math.is_nan(far.x)  || math.is_nan(far.y)  do return {}, false

    if near.x > far.x do near.x, far.x = far.x, near.x
    if near.y > far.y do near.y, far.y = far.y, near.y

    if near.x > far.y || near.y > far.x do return {}, false

    t_near := max(near.x, near.y)
    t_far  := min(far.x, far.y)
    if t_far < 0 {
        return {}, false // Ray pointing away from rect.
    }

    contact_normal : rl.Vector2
     if near.x > near.y {
        contact_normal = {1, 0} if dir.x < 0 else {-1, 0}
    } else if near.x < near.y {
        contact_normal = {0, 1} if dir.y < 0 else {0, -1}
    } // else contact_normal is {0, 0}

    return {
        time = t_near,
        normal = contact_normal,
        point = origin + t_near * dir,
    }, true
}

dyn_rect_vs_rect :: proc(dyn, static: rl.Rectangle, vel: rl.Vector2, dt: f32) -> (contact: Contact, ok: bool) {
    // Add dynamic's area as padding to the static rect, so we can detect collision before penetration.
    expanded_target := rl.Rectangle{
        static.x - dyn.width  / 2,
        static.y - dyn.height / 2,
        static.width + dyn.width,
        static.height + dyn.height,
    }

    origin := rl.RecPos(dyn) + rl.RecSize(dyn) / 2 // Cast ray from center of dynamic rect.
    contact = ray_vs_rect(origin, vel * dt, expanded_target) or_return
    if contact.time > 1 {
        return {}, false
    }

    return contact, true
}

rand_color :: proc() -> rl.Color {
    return {
        u8(rand.int_max(256)),
        u8(rand.int_max(256)),
        u8(rand.int_max(256)),
        255,
    }
}
