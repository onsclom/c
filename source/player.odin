package game

import "core:math"
import rl "vendor:raylib"

PLAYER_SPEED :: 7.5

Player :: struct {
	rect:             rl.Rectangle,
	dy:               f32,
	grounded:         bool,
	tried_jump:       bool,
	can_shorten_jump: bool,
}

player_update :: proc(delta_time: f32) {
	if rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		g.player.tried_jump = true
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
			player_dx: f32 = 0
			if (rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A)) {
				player_dx = -PLAYER_SPEED * physic_tick // move left
				g.player.rect.x += player_dx
			}
			if (rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D)) {
				player_dx = PLAYER_SPEED * physic_tick // move right
				g.player.rect.x += player_dx
			}

			for tile in g.tiles {
				if tile.type != .SolidTile do continue
				tile_rect := rl.Rectangle{f32(tile.x), f32(tile.y), 1.0, 1.0}
				if is_colliding(g.player.rect, tile_rect) {
					if player_dx > 0 {
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
			if g.player.tried_jump {
				if (previously_grounded) {
					g.player.dy = -10.0 // jump speed
					g.player.can_shorten_jump = true
					rl.PlaySound(g.jump_sound)
				}
				g.player.tried_jump = false
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
	}

	// handle lava
	for tile in g.tiles {
		if tile.type != .LavaTile do continue
		grace_margin :: 0.1 // shrink lava to favor player
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
				CANNON_CIRCLE_RADIUS,
				g.player.rect,
			) {
				kill_player()
				break
			}
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
	rl.DrawRectanglePro(
		g.player.rect,
		{g.player.rect.width, g.player.rect.height} / 2,
		0,
		player_color,
	)
}
