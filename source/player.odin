package game

import "core:math"
import rl "vendor:raylib"

PLAYER_SPEED :: 7.5
COYOTE_JUMP_TIME :: 0.1 // time in seconds to allow coyote jump
JUMP_BUFFER_TIME :: .1 // time in seconds to allow jump buffer
ANGLE_AMOUNT :: 8
DEATH_ANIMATION_TIME :: 0.5 // time in seconds for death animation

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
	squish_y:            f32, // used for squish effect
	squish_x:            f32, // used for squish effect
	dead:                bool,
	time_dead:           f32,
}

player_update :: proc(delta_time: f32) {
	g.player.jump_buffer -= delta_time
	g.player.jump_buffer = math.max(g.player.jump_buffer, 0)

	if IsKeyPressed(.SPACE) || IsKeyPressed(.UP) || IsKeyPressed(.W) {
		g.player.jump_buffer = JUMP_BUFFER_TIME
	}

	g.physics_time_accumulator += delta_time
	// clamp physics time to some reasonable value
	g.physics_time_accumulator = math.min(g.physics_time_accumulator, .1)
	physic_tick := f32(1) / PHYSIC_HZ

	for g.physics_time_accumulator >= physic_tick {
		g.physics_time_accumulator -= physic_tick
		if !g.player.dead {
			extra_repel :: 0.00001 // small value to avoid collision issues
			// handle movement and collisions in X axis
			{
				g.player.dx = 0 // reset dx for this tick
				if (IsKeyDown(.LEFT) || IsKeyDown(.A)) {
					g.player.dx += -PLAYER_SPEED * physic_tick // move left
				}
				if (IsKeyDown(.RIGHT) || IsKeyDown(.D)) {
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
				g.player.dy += physic_tick * 50
				MAX_FALL_SPEED :: 20.0
				g.player.dy = math.min(g.player.dy, MAX_FALL_SPEED)
				if g.player.jump_buffer > 0 {
					if (previously_grounded || g.player.time_since_grounded < COYOTE_JUMP_TIME) &&
					   g.player.can_coyote_jump {
						g.player.dy = -20.0 // jump speed
						g.player.can_shorten_jump = true
						g.player.can_coyote_jump = false
						g.player.jump_buffer = 0
						g.player.squish_x = 1
						g.player.squish_y = -1
						rl.PlaySound(g.jump_sound)
					}
				}
				jump_keys_are_up := !IsKeyDown(.SPACE) && !IsKeyDown(.UP) && !IsKeyDown(.W)
				if g.player.can_shorten_jump && jump_keys_are_up && g.player.dy < 0 {
					g.player.dy *= 0.5 // shorten jump
					g.player.can_shorten_jump = false
				}
				player_dy := g.player.dy * physic_tick
				g.player.rect.y += player_dy

				handle_landing :: proc(tile_rect: rl.Rectangle) {
					g.player.rect.y =
						tile_rect.y -
						(tile_rect.height / 2.0) -
						(g.player.rect.height / 2.0) -
						extra_repel
					landing_threshold :: 1
					if (g.player.dy > landing_threshold) {
						rl.PlaySound(g.land_sound)
						g.player.squish_x = -1
						g.player.squish_y = 1
					}
					g.player.dy = 0 // stop falling
					g.player.grounded = true
					g.player.can_coyote_jump = true
				}

				for tile in g.tiles {
					tile_rect := rl.Rectangle{f32(tile.x), f32(tile.y), 1.0, 1.0}
					if tile.type == .SolidTile {
						if is_colliding(g.player.rect, tile_rect) {
							if player_dy > 0 {
								handle_landing(tile_rect)
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
							if was_above_previously && !(IsKeyDown(.DOWN) || IsKeyDown(.S)) {
								handle_landing(tile_rect)
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
					kill_player(physic_tick)
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
						kill_player(physic_tick)
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

			// make squish approach 0
			g.player.squish_x = math.lerp(
				g.player.squish_x,
				0,
				physic_tick * 10, // smoothing factor
			)
			g.player.squish_y = math.lerp(
				g.player.squish_y,
				0,
				physic_tick * 10, // smoothing factor
			)
		} else {
			g.player.time_dead += physic_tick
			if g.player.time_dead >= DEATH_ANIMATION_TIME {
				g.player.rect.x = g.spawn.x
				g.player.rect.y = g.spawn.y
				g.player.dy = 0
				g.player.grounded = false
				g.player.dead = false
				g.player.time_dead = 0
			}
		}

	}
}

kill_player :: proc(dt: f32) {
	if !g.player.dead {
		g.player.dead = true
		rl.PlaySound(g.death_sound)
	}
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
	if g.player.dead {
		player_color = rl.GRAY
	}

	osc_strength := math.abs(g.player.angle) / ANGLE_AMOUNT * 4
	rot_osc := math.sin(f32(rl.GetTime()) * 14) * osc_strength

	hop_strength := math.abs(g.player.angle) / ANGLE_AMOUNT * .05
	hop_osc := g.player.grounded ? math.abs(math.sin(f32(rl.GetTime()) * 13) * hop_strength) : 0

	squish_strength :: .3
	rect_after_squish := rl.Rectangle {
		g.player.rect.x,
		g.player.rect.y,
		g.player.rect.width - squish_strength * g.player.squish_x,
		g.player.rect.height - squish_strength * g.player.squish_y,
	}

	rl.DrawRectanglePro(
		{
			rect_after_squish.x,
			rect_after_squish.y - hop_osc,
			rect_after_squish.width,
			rect_after_squish.height,
		},
		{rect_after_squish.width, rect_after_squish.height} / 2,
		g.player.angle + rot_osc,
		player_color,
	)
}
