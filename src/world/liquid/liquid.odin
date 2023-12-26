package liquid

import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"
import "../grid"
import "../../ngui"

// TODO: clean this up and make it gui editable.
BOUND_SIZE :: 60 * grid.CELL_SIZE
BOX := rl.Rectangle{
    -BOUND_SIZE / 2, -BOUND_SIZE / 2,
    BOUND_SIZE, BOUND_SIZE,
}

particles    : [dynamic]Particle
predicted_pos: [dynamic]rl.Vector2 // Parallel with particles, the naive projected position
                                   // of a particle. Greatly improves simulation stability.

stats : struct{ neighbors, neighbor_count: int }

// Gui properties.
smoothing_radius: f32 = grid.CELL_SIZE / 2
collision_damp  : f32 = 0.3
target_density  : f32 = 12
pressure_mult   : f32 = grid.CELL_SIZE

interaction_strength: f32 = 250

FIXED_DT :: 1.0 / 120.0
dt_acc: f32

GRAVITY := rl.Vector2{0, grid.CELL_SIZE}
// GRAVITY :: 0
RADIUS  ::  grid.CELL_SIZE / 8
MAX_SPEED :: 25 * grid.CELL_SIZE

Particle :: struct {
    pos, vel: rl.Vector2,
    density: f32,
}

init :: proc(size: int) {
    reserve(&particles, size)
    reserve(&grid_lookup, size)
    reserve(&start_index, size)
    reserve(&_particles_in_range, size)
    resize(&predicted_pos, size)
}

deinit :: proc() {
    delete(particles)
    delete(grid_lookup)
    delete(start_index)
    delete(_particles_in_range)
    delete(predicted_pos)
 }

create :: proc(quantity: int) {
    init(quantity)
    clear(&particles)

    for _ in 0..<quantity {
        pos := rl.Vector2{
            BOX.x + rand.float32() * (BOX.width),
            BOX.y + rand.float32() * (BOX.height),
        }
        append(&particles, Particle{ pos = pos })
    }
}

draw2D :: proc() {
    rl.DrawRectangleRec(BOX, rl.BLACK)

    for particle in particles {
        // color := rl.BLUE
        speed := linalg.length(particle.vel)
        // color := rl.ColorFromHSV(182, speed / MAX_SPEED, 1)
        color := ngui.lerp_color(rl.BLUE, rl.WHITE, speed / MAX_SPEED)
        rl.DrawCircleV(particle.pos, RADIUS, color)
    }
}

update :: proc(dt: f32, box_target, cursor: rl.Vector2) {
    dt_acc += dt
    for dt_acc >= FIXED_DT {
        dt_acc -= FIXED_DT
        fixed_update(FIXED_DT, box_target, cursor)
    }
}

fixed_update :: proc(dt: f32, box_target, cursor: rl.Vector2) {
    // Update box position.
    if box_target != 0 && linalg.distance(box_target, rl.Vector2{BOX.x, BOX.y}) > grid.CELL_SIZE {
        BOX.x = linalg.lerp(BOX.x, box_target.x, dt)
        BOX.y = linalg.lerp(BOX.y, box_target.y, dt)
    }

    for &p, i in particles {
        p.vel += GRAVITY * dt
        predicted_pos[i] = p.pos + p.vel * dt
    }

    update_grid_lookup(predicted_pos[:], smoothing_radius)

    for &p in particles {
        p.density = calc_density(p.pos)
    }

    for &p, i in particles {
        accel := calc_pressure_force(i) / p.density
        if rl.IsMouseButtonDown(.LEFT) {
            accel += calc_interaction_force(cursor, i, interaction_strength)
        } else if rl.IsMouseButtonDown(.RIGHT) {
            accel += calc_interaction_force(cursor, i, -interaction_strength)
        }

        p.vel += accel * dt
    }


    // @TODO: precalculate these
    bmin := rl.Vector2{BOX.x + RADIUS, BOX.y + RADIUS}
    bmax := rl.Vector2{BOX.x + BOX.width - RADIUS, BOX.y + BOX.height - RADIUS}
    for &p in particles {
        p.vel = linalg.clamp(p.vel, -MAX_SPEED, MAX_SPEED)
        p.pos += p.vel * dt
        {
            // Keep in bounding-box.
            if p.pos.x < bmin.x && p.vel.x < 0 {
                p.vel.x *= -collision_damp
            } else if p.pos.x > bmax.x && p.vel.x > 0 {
                p.vel.x *= -collision_damp
            }
            if p.pos.y < bmin.y && p.vel.y < 0 {
                p.vel.y *= -collision_damp
            } else if p.pos.y > bmax.y && p.vel.y > 0 {
                p.vel.y *= -collision_damp
            }
            p.pos = linalg.clamp(p.pos, bmin, bmax)
        }
    }
}

calc_density :: proc(sample_point: rl.Vector2) -> (density: f32) {
    neighbors := particles_near_point(sample_point, smoothing_radius)
    for pidx in neighbors {
        dist := linalg.length(predicted_pos[pidx] - sample_point)
        influence := smoothing_kernel(smoothing_radius, dist)
        density += influence
    }

    return max(density, 1e-7) // Avoid zero density, leads to NaN nonsense.
}

calc_pressure_force :: proc(particle_index: int) -> (force: rl.Vector2) {
    other_p := particles[particle_index]
    neighbors := particles_near_point(other_p.pos, smoothing_radius)

    stats.neighbors += len(neighbors)
    stats.neighbor_count += 1

    for pidx in neighbors do if pidx != particle_index {
        diff := predicted_pos[pidx] - predicted_pos[particle_index]
        dist := linalg.length(diff)
        dir := (diff) / dist if dist != 0 else rand_direction()
        slope := smoothing_kernel_derivative(smoothing_radius, dist)

        density := particles[pidx].density
        avg_pressure := (density_to_presure(density) + density_to_presure(other_p.density)) / 2
        force += -avg_pressure * dir * slope / density
    }

    return
}

calc_interaction_force :: proc(point: rl.Vector2, particle_index: int, strength: f32) -> rl.Vector2 {
    INTERACTION_RADIUS :: 6 * grid.CELL_SIZE

    offset := point - particles[particle_index].pos
    sqr_dist := linalg.dot(offset, offset)
    if sqr_dist >= INTERACTION_RADIUS * INTERACTION_RADIUS {
        return 0 // Too far, no impact.
    }

    dist := linalg.sqrt(sqr_dist)
    dir := offset / dist if dist > linalg.F32_EPSILON else 0
    center_t := 1 - dist / INTERACTION_RADIUS // 1 at point, 0 at radius edge.
    return (dir * strength * grid.CELL_SIZE - particles[particle_index].vel) * center_t
}

smoothing_kernel :: proc(radius, dist: f32) -> f32 {
    if dist >= radius do return 0
    volume := linalg.PI * linalg.pow(radius, 4) / 6
    return (radius - dist) * (radius - dist) / volume
}

smoothing_kernel_derivative :: proc(radius, dist: f32) -> f32 {
    if dist >= radius do return 0
    scale := 12 / linalg.pow(radius, 4) * linalg.PI
    return (dist - radius) * scale
}

density_to_presure :: proc(density: f32) -> f32 {
    error := density - target_density
    return error * pressure_mult
}

rand_direction :: proc() -> rl.Vector2 {
    r := rand.float32() * linalg.TAU
    return {linalg.cos(r), linalg.sin(r)}
}