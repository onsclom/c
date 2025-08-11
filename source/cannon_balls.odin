package game

import "core:math"
import rl "vendor:raylib"

MAX_CANNON_BALLS :: 1024
LIFE_SPAN :: 60

Cannon_Ball :: struct {
	remaining_life: f32,
	x:              f32,
	y:              f32,
	angle:          f32,
}

cannon_ball_add :: proc(x, y, angle: f32) {
	for i in 0 ..< MAX_CANNON_BALLS {
		if g.cannon_balls[i].remaining_life <= 0 {
			g.cannon_balls[i] = Cannon_Ball{LIFE_SPAN, x, y, angle}
			return
		}
	}
	rl.TraceLog(.WARNING, "Reached max cannon balls (%d)", MAX_CANNON_BALLS)
}

cannon_balls_update :: proc(delta_time: f32) {
	for i in 0 ..< MAX_CANNON_BALLS {
		if g.cannon_balls[i].remaining_life > 0 {
			g.cannon_balls[i].remaining_life -= delta_time
			if g.cannon_balls[i].remaining_life <= 0 {
				g.cannon_balls[i] = Cannon_Ball{}
			} else {
				g.cannon_balls[i].x +=
					math.cos(g.cannon_balls[i].angle) * delta_time * PLAYER_SPEED
				g.cannon_balls[i].y +=
					math.sin(g.cannon_balls[i].angle) * delta_time * PLAYER_SPEED

				// TODO: check if cannon ball hit solid tile
				for tile in g.tiles {
					if tile.type != .SolidTile do continue
					tile_rect := rl.Rectangle{f32(tile.x), f32(tile.y), 1.0, 1.0}
					ball_rect := rl.Rectangle {
						g.cannon_balls[i].x,
						g.cannon_balls[i].y,
						CANNON_CIRCLE_RADIUS * 2,
						CANNON_CIRCLE_RADIUS * 2,
					}
					if rl.CheckCollisionRecs(ball_rect, tile_rect) {
						g.cannon_balls[i] = Cannon_Ball{} // remove the ball
						break // no need to check other tiles
					}
				}
			}
		}
	}
}

cannon_balls_draw :: proc() {
	for ball in g.cannon_balls {
		if ball.remaining_life > 0 {
			rl.DrawCircleV({ball.x, ball.y}, CANNON_CIRCLE_RADIUS, rl.RED)
		}
	}
}
