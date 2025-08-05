package main

import "core:container/small_array"
import math "core:math"
import rl "vendor:raylib"


PHYSIC_HZ :: 500
FONT_SIZE :: 12

Player :: struct {
	rect:       rl.Rectangle,
	dy:         f32,
	tried_jump: bool,
}

Tile :: struct {
	x: i32,
	y: i32,
}

Game :: struct {
	player:                   Player,
	camera:                   rl.Camera2D,
	zoom_factor:              f32,
	tiles:                    small_array.Small_Array(1024, Tile),
	editing:                  bool,
	physics_time_accumulator: f32,
	show_debug_ui:            bool,
}

main :: proc() {
	INIT_WIDTH :: 600
	INIT_HEIGHT :: 600

	rl.SetConfigFlags(rl.ConfigFlags{rl.ConfigFlag.WINDOW_RESIZABLE, rl.ConfigFlag.WINDOW_HIGHDPI})
	rl.InitWindow(INIT_WIDTH, INIT_HEIGHT, "platformer")
	dpi := rl.GetWindowScaleDPI()

	dpi_font_load := cast(i32)dpi.x * FONT_SIZE
	mono_font := rl.LoadFontEx("resources/IBMPlexMono.ttf", dpi_font_load, {}, 250)
	sans_font := rl.LoadFontEx("resources/IBMPlexSans.ttf", dpi_font_load, {}, 250)

	game := Game {
		player = {rect = {0, 0, .8, 1.2}},
		camera = {offset = {INIT_WIDTH / 2, INIT_HEIGHT / 2}, zoom = 1},
		zoom_factor = 1,
	}

	last_frame_time := rl.GetTime()
	for !rl.WindowShouldClose() {
		mouse_in_screen := rl.GetMousePosition()
		current_frame_time := rl.GetTime()
		delta_time := current_frame_time - last_frame_time
		f32_delta_time := cast(f32)delta_time
		last_frame_time = current_frame_time
		mouse_in_world := rl.GetScreenToWorld2D(mouse_in_screen, game.camera)
		mouse_tile_pos := [2]int {
			int(math.round(mouse_in_world.x)),
			int(math.round(mouse_in_world.y)),
		}

		if game.editing {
			speed :: 10
			if (rl.IsKeyDown(rl.KeyboardKey.LEFT) || rl.IsKeyDown(rl.KeyboardKey.A)) {
				game.player.rect.x -= f32_delta_time * speed
			}
			if (rl.IsKeyDown(rl.KeyboardKey.RIGHT) || rl.IsKeyDown(rl.KeyboardKey.D)) {
				game.player.rect.x += f32_delta_time * speed
			}
			if (rl.IsKeyDown(rl.KeyboardKey.UP) || rl.IsKeyDown(rl.KeyboardKey.W)) {
				game.player.rect.y -= f32_delta_time * speed
			}
			if (rl.IsKeyDown(rl.KeyboardKey.DOWN) || rl.IsKeyDown(rl.KeyboardKey.S)) {
				game.player.rect.y += f32_delta_time * speed
			}

			if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
				tile_exists := false
				for i in 0 ..< game.tiles.len {
					tile := small_array.get(game.tiles, i)
					if tile.x == cast(i32)mouse_tile_pos[0] &&
					   tile.y == cast(i32)mouse_tile_pos[1] {
						tile_exists = true
						break
					}
				}
				if !tile_exists {
					small_array.push_back(
						&game.tiles,
						Tile{x = cast(i32)mouse_tile_pos[0], y = cast(i32)mouse_tile_pos[1]},
					)
				}
			} else if rl.IsMouseButtonDown(rl.MouseButton.RIGHT) {
				for i in 0 ..< game.tiles.len {
					tile := small_array.get(game.tiles, i)
					if tile.x == cast(i32)mouse_tile_pos[0] &&
					   tile.y == cast(i32)mouse_tile_pos[1] {
						small_array.unordered_remove(&game.tiles, i)
					}
				}
			}

		} else {
			if (rl.IsKeyPressed(rl.KeyboardKey.SPACE) ||
				   rl.IsMouseButtonPressed(rl.MouseButton.LEFT) ||
				   rl.IsMouseButtonPressed(rl.MouseButton.RIGHT)) {
				game.player.tried_jump = true
			}

			game.physics_time_accumulator += f32_delta_time
			physic_tick := cast(f32)1 / PHYSIC_HZ
			for game.physics_time_accumulator >= 1 / PHYSIC_HZ {
				game.physics_time_accumulator -= physic_tick

				extra_repel :: 0.0001 // small value to avoid collision issues
				// handle movement and collisions in X axis
				{
					player_dx: f32 = 0
					player_speed :: 5.0
					if (rl.IsKeyDown(rl.KeyboardKey.LEFT) || rl.IsKeyDown(rl.KeyboardKey.A)) {
						player_dx = -player_speed * physic_tick // move left
						game.player.rect.x += player_dx
					}
					if (rl.IsKeyDown(rl.KeyboardKey.RIGHT) || rl.IsKeyDown(rl.KeyboardKey.D)) {
						player_dx = player_speed * physic_tick // move right
						game.player.rect.x += player_dx
					}

					for i in 0 ..< game.tiles.len {
						tile := small_array.get(game.tiles, i)
						tile_rect := rl.Rectangle{cast(f32)tile.x, cast(f32)tile.y, 1.0, 1.0}
						if is_colliding(game.player.rect, tile_rect) {
							if player_dx > 0 {
								game.player.rect.x =
									tile_rect.x -
									(tile_rect.width / 2.0) -
									(game.player.rect.width / 2.0) -
									extra_repel
							} else {
								game.player.rect.x =
									tile_rect.x +
									tile_rect.width / 2.0 +
									game.player.rect.width / 2.0 +
									extra_repel
							}
						}
					}
				}
				// handle movement and collisions in Y axis
				{
					// apply gravity
					game.player.dy += physic_tick * 18
					if game.player.tried_jump {
						game.player.dy = -10.0 // jump speed
						game.player.tried_jump = false
					}
					player_dy := game.player.dy * physic_tick
					game.player.rect.y += player_dy
					for i in 0 ..< game.tiles.len {
						tile := small_array.get(game.tiles, i)
						tile_rect := rl.Rectangle{cast(f32)tile.x, cast(f32)tile.y, 1.0, 1.0}
						if is_colliding(game.player.rect, tile_rect) {
							if player_dy > 0 {
								game.player.rect.y =
									tile_rect.y -
									(tile_rect.height / 2.0) -
									(game.player.rect.height / 2.0) -
									extra_repel
								game.player.dy = 0 // stop falling
							} else {
								game.player.rect.y =
									tile_rect.y +
									tile_rect.height / 2.0 +
									game.player.rect.height / 2.0 +
									extra_repel
								game.player.dy = 0 // stop jumping
							}
						}
					}
				}
			}
		}

		if rl.IsKeyPressed(rl.KeyboardKey.E) {
			game.editing = !game.editing
		}
		zoom_speed: f32 = .5
		if rl.IsKeyDown(rl.KeyboardKey.EQUAL) {
			game.zoom_factor += zoom_speed * f32_delta_time
		} else if rl.IsKeyDown(rl.KeyboardKey.MINUS) {
			game.zoom_factor -= zoom_speed * f32_delta_time
		}

		{
			default_game_width :: 20
			screen_width := cast(f32)rl.GetScreenWidth()
			screen_height := cast(f32)rl.GetScreenHeight()

			game.camera.offset = {screen_width / 2, screen_height / 2}
			game.camera.zoom = screen_width / default_game_width * game.zoom_factor
			game.camera.target = {game.player.rect.x, game.player.rect.y}
		}
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.BeginMode2D(game.camera)

		{
			// draw tiles
			for i in 0 ..< game.tiles.len {
				tile := small_array.get(game.tiles, i)
				rl.DrawRectanglePro(
					{cast(f32)tile.x, cast(f32)tile.y, 1, 1},
					{0.5, 0.5},
					0,
					rl.GREEN,
				)
			}

			rl.DrawRectanglePro(
				game.player.rect,
				{game.player.rect.width, game.player.rect.height} / 2,
				0,
				rl.BLUE,
			)

			if game.editing {
				rl.DrawRectangleLinesEx(
					{cast(f32)mouse_tile_pos.x - .5, cast(f32)mouse_tile_pos.y - .5, 1, 1},
					.1,
					rl.RED,
				)
			}
		}
		rl.EndMode2D()

		rl.DrawText(
			rl.TextFormat("x, y: %f, %f", game.player.rect.x, game.player.rect.y),
			10,
			10,
			FONT_SIZE * 2,
			rl.DARKGRAY,
		)
		rl.EndDrawing()
	}

	rl.CloseWindow()
}

is_colliding :: proc(a: rl.Rectangle, b: rl.Rectangle) -> bool {
	x_dist := abs(a.x - b.x)
	y_dist := abs(a.y - b.y)
	return x_dist < (a.width + b.width) / 2 && y_dist < (a.height + b.height) / 2
}
