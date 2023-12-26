package liquid

import "core:slice"
import "core:math/linalg"
import rl "vendor:raylib"

grid_lookup: [dynamic]CellParticle

// CellParticle is used for grouping particles into grid cells. Particles only
// influence particles in their own grid cell and the 8 cells surrounding them.
CellParticle :: struct {
    particle_index, cell_key: int,
}

// Maps from cell key to the index of the cell's first particle in grid_lookup.
start_index: [dynamic]int

@(private)
_particles_in_range: [dynamic]int // Cleared every time particles_near_point() is called.
                                  // For internal use only.

UNKNOWN :: 0xFFFF_FFFF

// Builds the fast grid lookup tables. O(N*log(N)) sorting.
update_grid_lookup :: proc(points: []rl.Vector2, radius: f32) {
    clear(&grid_lookup)
    clear(&start_index)

    for pos, i in points {
        cell := pos_to_cell(pos, radius)
        key := hash_to_key(hash_cell(cell))

        append(&grid_lookup, CellParticle{ particle_index = i, cell_key = key})
        append(&start_index, UNKNOWN)
    }

    // Group all of the particles in a cell together.
    slice.sort_by(grid_lookup[:], proc(a, b: CellParticle) -> bool {
        return a.cell_key < b.cell_key
    })

    // Store the index of the first particle in each cell.
    for cp, i in grid_lookup {
        key := cp.cell_key
        key_prev := grid_lookup[i - 1].cell_key if i != 0 else UNKNOWN
        if key != key_prev {
            start_index[key] = i
        }
    }
}

// Returns a list of particles in the 9 grid cells surrounding a point. Used to calculate
// density and pressure. This is a massive optimization over the naive O(N^2) approach.
// In practice this means reducing the list to <10 neighbors per particle.
particles_near_point :: proc(sample_point: rl.Vector2, radius: f32) -> []int {
    center := pos_to_cell(sample_point, radius)

    sqr_radius := radius * radius

    clear(&_particles_in_range)

    for offset_x in -1..=1 do for offset_y in -1..=1 {
        key := hash_to_key(hash_cell(center + {offset_x, offset_y}))
        cell_start_index := start_index[key]
        if cell_start_index == UNKNOWN {
            continue
        }

        for cp in grid_lookup[cell_start_index:] {
            if cp.cell_key != key {
                break // We've visited all particles in this grid cell.
            }

            particle := particles[cp.particle_index]
            diff := particle.pos - sample_point
            sqr_dist := linalg.dot(diff, diff)
            if sqr_dist < sqr_radius {
                // pidx := ParticleIndex{ particle, cp.particle_index }
                append(&_particles_in_range, cp.particle_index)
            }
        }
    }

    return _particles_in_range[:]
}

pos_to_cell :: proc(pos: rl.Vector2, radius: f32) -> [2]int {
    return linalg.array_cast(pos / radius, int)
}

hash_cell :: proc(cell: [2]int) -> int {
    // Multiply by prime numbers.
    a := cell.x * 15823
    b := cell.y * 9737333
    return a + b
}

hash_to_key :: proc(hash: int) -> int {
    return abs(hash) % len(particles)
}
