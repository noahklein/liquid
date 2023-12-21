package world

import "core:fmt"
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

Contact :: struct {
    time: f32,
    normal: rl.Vector2,
    point: rl.Vector2,
}

ray_vs_rect :: proc(origin, dir: rl.Vector2, rect: rl.Rectangle) -> (Contact, bool) {
    rpos, rsize: rl.Vector2 = {rect.x, rect.y}, {rect.width, rect.height}

    near := (rpos - origin) / dir
    far  := (rpos + rsize - origin) / dir

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