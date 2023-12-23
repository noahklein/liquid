package liquid

import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"
import "../grid"

BOUND_SIZE :: 20 * grid.CELL_SIZE
BOUNDING_BOX :: rl.Rectangle{
    -BOUND_SIZE / 2, -BOUND_SIZE / 2,
    BOUND_SIZE, BOUND_SIZE,
}

particles: [dynamic]Particle

smoothing_radius: f32 = grid.CELL_SIZE
collision_damp  : f32 = 0.95
target_density  : f32 = 2.75
pressure_mult   : f32 = 10

// GRAVITY :: 10 * grid.CELL_SIZE
GRAVITY :: 0
RADIUS  :: grid.CELL_SIZE / 8
COLOR   :: rl.BLUE

Particle :: struct {
    pos, vel: rl.Vector2,
    density, property: f32,
}

init :: proc(size: int) {
    reserve(&particles, size)
}

deinit :: proc() {
    delete(particles)
 }

draw2D :: proc() {
    for particle in particles {
        rl.DrawCircleV(particle.pos, RADIUS, COLOR)
    }

    rl.DrawRectangleLinesEx(BOUNDING_BOX, 2, rl.BLACK)
}

update :: proc(dt: f32) {
    for &p in particles {
        // p.vel.y += GRAVITY * dt
        p.density = calc_density(p.pos)
    }

    for &p, i in particles {
        accel := calc_pressure_force(i) / p.density
        p.vel += accel * dt
    }

    for &p in particles {
        p.pos += p.vel * dt

        {
            // Keep in bounding-box.
            if p.pos.x < BOUNDING_BOX.x || p.pos.x > BOUNDING_BOX.x + BOUNDING_BOX.width {
                p.vel.x *= -collision_damp
            }
            if p.pos.y < BOUNDING_BOX.y || p.pos.y > BOUNDING_BOX.y + BOUNDING_BOX.height {
                p.vel.y *= -collision_damp
            }
        }

    }
}

create :: proc(quantity: int) {
    clear(&particles)
    reserve(&particles, quantity)
    for _ in 0..<quantity {
        pos := rl.Vector2{
            BOUNDING_BOX.x + rand.float32() * (BOUNDING_BOX.width),
            BOUNDING_BOX.y + rand.float32() * (BOUNDING_BOX.height),
        }
        append(&particles, Particle{
            pos = pos,
            property = example_function(pos),
        })
    }
}

calc_density :: proc(sample_point: rl.Vector2) -> (density: f32) {
    for particle in particles {
        dist := linalg.length(particle.pos - sample_point)
        influence := smoothing_kernel(smoothing_radius, dist)
        density += influence
    }
    return
}

calc_property :: proc(sample_point: rl.Vector2) -> (property: f32) {
    for p in particles {
        dist := linalg.length(p.pos - sample_point)
        influence := smoothing_kernel(smoothing_radius, dist)
        property += p.property * influence / p.density
    }
    return
}

calc_property_gradient :: proc(sample_point: rl.Vector2) -> (gradient: rl.Vector2) {
    for p in particles {
        dist := linalg.length(p.pos - sample_point)
        dir := (p.pos - sample_point) / dist
        slope := smoothing_kernel_derivative(smoothing_radius, dist)
        gradient += -p.property * dir * slope / p.density
    }
    return
}

calc_pressure_force :: proc(particle_index: int) -> (force: rl.Vector2) {
    other_p := particles[particle_index]
    for p, i in particles do if i != particle_index {
        dist := linalg.length(p.pos - other_p.pos)
        dir := (p.pos - other_p.pos) / dist if dist != 0 else {1, 0}
        slope := smoothing_kernel_derivative(smoothing_radius, dist)

        avg_pressure := (density_to_presure(p.density) + density_to_presure(other_p.density)) / 2
        force += -avg_pressure * dir * slope / p.density
    }

    return
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

example_function :: proc(pos: rl.Vector2) -> f32 {
    return linalg.cos(pos.y - 3 + linalg.sin(pos.x))
}

density_to_presure :: proc(density: f32) -> f32 {
    error := density - target_density
    return error * pressure_mult
}

draw_arrow :: proc(start, end: rl.Vector2, color: rl.Color) {
    ARROW_HEIGHT :: 30
    ARROW_WIDTH  :: ARROW_HEIGHT / 1.73205 // approx sqrt(3), ratio in an equilateral triangle.
    LINE_THICKNESS :: ARROW_HEIGHT / 3

    slope := linalg.normalize(end - start)
    v1 := end + slope * ARROW_HEIGHT  // Pointy-tip, continue along the line.

    // Other 2 arrow-head vertices are perpendicular to the end point.
    // Perpendicular line has negative reciprical slope: -(x2 - x1) / (y2 - y1)
    slope.x, slope.y = slope.y, -slope.x

    v2 := end + slope * ARROW_WIDTH
    v3 := end - slope * ARROW_WIDTH

    rl.DrawLineEx(start, end, LINE_THICKNESS, color)
    rl.DrawTriangle(v1, v2, v3, color)
}