package game

import "core:math"
import rl "vendor:raylib"

PLAYER_SPEED :: 7.5
COYOTE_JUMP_TIME :: 0.1 // time in seconds to allow coyote jump
JUMP_BUFFER_TIME :: .1 // time in seconds to allow jump buffer
ANGLE_AMOUNT :: 8

Player :: struct {
	rect:                rl.Rectangle,
	dx:                  f32,
	dy:                  f32,
	grounded:            bool,
	time_since_grounded: f32,
	jump_buffer:         f32,
	can_coyote_jump:     bool,
	can_shorten_jump:    bool,
	angle:               f32, // angle for rotation
}

player_update :: proc(delta_time: f32) {
	g.player.jump_buffer -= delta_time
	g.player.jump_buffer = math.max(g.player.jump_buffer, 0)

	if rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		g.player.jump_buffer = JUMP_BUFFER_TIME
	}

	g.physics_time_accumulator += delta_time
	// clamp physics time to some reasonable value
	g.physics_time_accumulator = math.min(g.physics_time_accumulator, .1)
	physic_tick := f32(1) / PHYSIC_HZ

	for g.physics_time_accumulator >= physic_tick {
		g.physics_time_accumulator -= physic_tick

		extra_repel :: 0.00001 // small value to avoid collision issues
		// handle movement and collisions in X axis
		{
			g.player.dx = 0 // reset dx for this tick
			if (rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A)) {
				g.player.dx += -PLAYER_SPEED * physic_tick // move left
			}
			if (rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D)) {
				g.player.dx += PLAYER_SPEED * physic_tick // move right
			}
			g.player.rect.x += g.player.dx

			for tile in g.tiles {
				if tile.type != .SolidTile do continue
				tile_rect := rl.Rectangle{f32(tile.x), f32(tile.y), 1.0, 1.0}
				if is_colliding(g.player.rect, tile_rect) {
					if g.player.dx > 0 {
						g.player.rect.x =
							tile_rect.x -
							(tile_rect.width / 2.0) -
							(g.player.rect.width / 2.0) -
							extra_repel
					} else {
						g.player.rect.x =
							tile_rect.x +
							tile_rect.width / 2.0 +
							g.player.rect.width / 2.0 +
							extra_repel
					}
				}
			}
		}
		previously_grounded := g.player.grounded
		g.player.grounded = false
		// handle movement and collisions in Y axis
		{
			// apply gravity
			g.player.dy += physic_tick * 18
			MAX_FALL_SPEED :: 20.0
			g.player.dy = math.min(g.player.dy, MAX_FALL_SPEED)
			if g.player.jump_buffer > 0 {
				if (previously_grounded || g.player.time_since_grounded < COYOTE_JUMP_TIME) &&
				   g.player.can_coyote_jump {
					g.player.dy = -10.0 // jump speed
					g.player.can_shorten_jump = true
					g.player.can_coyote_jump = false
					g.player.jump_buffer = 0
					rl.PlaySound(g.jump_sound)
				}
			}
			jump_keys_are_up := !rl.IsKeyDown(.SPACE) && !rl.IsKeyDown(.UP) && !rl.IsKeyDown(.W)
			if g.player.can_shorten_jump && jump_keys_are_up && g.player.dy < 0 {
				g.player.dy *= 0.5 // shorten jump
				g.player.can_shorten_jump = false
			}
			player_dy := g.player.dy * physic_tick
			g.player.rect.y += player_dy
			for tile in g.tiles {
				tile_rect := rl.Rectangle{f32(tile.x), f32(tile.y), 1.0, 1.0}
				if tile.type == .SolidTile {
					if is_colliding(g.player.rect, tile_rect) {
						if player_dy > 0 {
							g.player.rect.y =
								tile_rect.y -
								(tile_rect.height / 2.0) -
								(g.player.rect.height / 2.0) -
								extra_repel
							g.player.dy = 0 // stop falling
							g.player.grounded = true
							g.player.can_coyote_jump = true
						} else {
							g.player.rect.y =
								tile_rect.y +
								tile_rect.height / 2.0 +
								g.player.rect.height / 2.0 +
								extra_repel
							g.player.dy = 0 // stop jumping
						}
					}
				} else if tile.type == .PlatformTile {
					if is_colliding(g.player.rect, tile_rect) {
						prev_y := g.player.rect.y - player_dy
						was_above_previously :=
							prev_y + g.player.rect.height / 2.0 <
							tile_rect.y - tile_rect.height / 2.0
						if was_above_previously && !(rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S)) {
							g.player.rect.y =
								tile_rect.y -
								(tile_rect.height / 2.0) -
								(g.player.rect.height / 2.0) -
								extra_repel
							g.player.dy = 0 // stop falling
							g.player.grounded = true
						}
					}
				}
			}
		}

		if g.player.grounded {
			g.player.time_since_grounded = 0
		} else {
			g.player.time_since_grounded += physic_tick
		}

		grace_margin :: 0.1 // shrink lava to favor player
		// handle lava
		for tile in g.tiles {
			if tile.type != .LavaTile do continue
			tile_rect := rl.Rectangle {
				f32(tile.x) + grace_margin,
				f32(tile.y) + grace_margin,
				1.0 - 2 * grace_margin,
				1.0 - 2 * grace_margin,
			}
			if is_colliding(g.player.rect, tile_rect) {
				kill_player()
				break
			}
		}

		for cannon_ball in g.cannon_balls {
			if cannon_ball.remaining_life > 0 {
				if circ_vs_rect_collide(
					{cannon_ball.x, cannon_ball.y},
					CANNON_CIRCLE_RADIUS - grace_margin,
					g.player.rect,
				) {
					kill_player()
					break
				}
			}
		}

		// animate player angle
		{
			target_angle: f32 = ANGLE_AMOUNT * math.sign(g.player.dx)
			g.player.angle = math.lerp(
				g.player.angle,
				target_angle,
				physic_tick * 20, // smoothing factor
			)
		}
	}
}

kill_player :: proc() {
	rl.PlaySound(g.death_sound)
	g.player.rect.x = g.spawn.x
	g.player.rect.y = g.spawn.y
	g.player.dy = 0
	g.player.grounded = false
}


circ_vs_rect_collide :: proc(circle: rl.Vector2, radius: f32, rect: rl.Rectangle) -> bool {
	closest_x := math.clamp(circle.x, rect.x - rect.width / 2, rect.x + rect.width / 2)
	closest_y := math.clamp(circle.y, rect.y - rect.height / 2, rect.y + rect.height / 2)
	distance_x := circle.x - closest_x
	distance_y := circle.y - closest_y
	distance_squared := distance_x * distance_x + distance_y * distance_y
	return distance_squared < radius * radius
}

draw_player :: proc() {
	player_color := g.editing ? rl.Fade(rl.BLUE, 0.5) : rl.BLUE

	osc_strength := math.abs(g.player.angle) / ANGLE_AMOUNT * 4
	rot_osc := math.sin(f32(rl.GetTime()) * 14) * osc_strength

	hop_strength := math.abs(g.player.angle) / ANGLE_AMOUNT * .05
	hop_osc := g.player.grounded ? math.abs(math.sin(f32(rl.GetTime()) * 13) * hop_strength) : 0

	rl.DrawRectanglePro(
		{g.player.rect.x, g.player.rect.y - hop_osc, g.player.rect.width, g.player.rect.height},
		{g.player.rect.width, g.player.rect.height} / 2,
		g.player.angle + rot_osc,
		player_color,
	)
}
