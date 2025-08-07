package main

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

PHYSIC_HZ :: 500
FONT_SIZE :: 14
INIT_WIDTH :: 600
INIT_HEIGHT :: 600
MAX_TILES :: 1024

Player :: struct {
	rect:       rl.Rectangle,
	dy:         f32,
	tried_jump: bool,
}

Tile :: struct {
	active: bool,
	x:      i32,
	y:      i32,
}

Game :: struct {
	player:                   Player,
	camera:                   rl.Camera2D,
	zoom_factor:              f32,
	tiles:                    [MAX_TILES]Tile,
	editing:                  bool,
	physics_time_accumulator: f32,
	show_debug_ui:            bool, // TODO
}

game := Game {
	player = {rect = {0, 0, .8, 1.2}},
	camera = {offset = {INIT_WIDTH / 2, INIT_HEIGHT / 2}, zoom = 1},
	zoom_factor = 1,
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_HIGHDPI})
	rl.InitWindow(INIT_WIDTH, INIT_HEIGHT, "platformer")
	defer rl.CloseWindow()
	dpi := rl.GetWindowScaleDPI()

	dpi_font_load := i32(dpi.x) * FONT_SIZE
	mono_font := rl.LoadFontEx("resources/IBMPlexMono.ttf", dpi_font_load, {}, 250)
	defer rl.UnloadFont(mono_font)
	sans_font := rl.LoadFontEx("resources/IBMPlexSans.ttf", dpi_font_load, {}, 250)
	defer rl.UnloadFont(sans_font)

	{
		FONT_SIZE_ENUM :: 16 // checked raygui.h for this
		rl.GuiSetFont(sans_font)
		rl.GuiSetStyle(.DEFAULT, FONT_SIZE_ENUM, FONT_SIZE)
	}

	last_frame_time := rl.GetTime()
	for !rl.WindowShouldClose() {
		mouse_in_screen := rl.GetMousePosition()
		current_frame_time := rl.GetTime()
		delta_time := current_frame_time - last_frame_time
		f32_delta_time := f32(delta_time)
		last_frame_time = current_frame_time
		mouse_in_world := rl.GetScreenToWorld2D(mouse_in_screen, game.camera)
		mouse_tile_pos := [2]i32 {
			i32(math.round(mouse_in_world.x)),
			i32(math.round(mouse_in_world.y)),
		}

		if game.editing {
			editor_update(f32_delta_time, mouse_tile_pos)
		} else {
			if rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
				game.player.tried_jump = true
			}

			game.physics_time_accumulator += f32_delta_time
			physic_tick := f32(1) / PHYSIC_HZ
			for game.physics_time_accumulator >= 1 / PHYSIC_HZ {
				game.physics_time_accumulator -= physic_tick

				extra_repel :: 0.0001 // small value to avoid collision issues
				// handle movement and collisions in X axis
				{
					player_dx: f32 = 0
					player_speed :: 5.0
					if (rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A)) {
						player_dx = -player_speed * physic_tick // move left
						game.player.rect.x += player_dx
					}
					if (rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D)) {
						player_dx = player_speed * physic_tick // move right
						game.player.rect.x += player_dx
					}

					for tile in game.tiles {
						if !tile.active do continue
						tile_rect := rl.Rectangle{f32(tile.x), f32(tile.y), 1.0, 1.0}
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
					for tile in game.tiles {
						if !tile.active do continue
						tile_rect := rl.Rectangle{f32(tile.x), f32(tile.y), 1.0, 1.0}
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

		if rl.IsKeyPressed(.E) {
			game.editing = !game.editing
		}
		zoom_speed: f32 = .5
		if rl.IsKeyDown(.EQUAL) {
			game.zoom_factor += zoom_speed * f32_delta_time
		} else if rl.IsKeyDown(.MINUS) {
			game.zoom_factor -= zoom_speed * f32_delta_time
		}

		{
			default_game_width :: 20
			screen_width := f32(rl.GetScreenWidth())
			screen_height := f32(rl.GetScreenHeight())

			game.camera.offset = {screen_width / 2, screen_height / 2}
			game.camera.zoom = screen_width / default_game_width * game.zoom_factor
			game.camera.target = {game.player.rect.x, game.player.rect.y}
		}
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.BeginMode2D(game.camera)

		{
			// draw tiles
			for tile in game.tiles {
				if !tile.active do continue
				rl.DrawRectanglePro({f32(tile.x), f32(tile.y), 1, 1}, {0.5, 0.5}, 0, rl.GREEN)
			}

			rl.DrawRectanglePro(
				game.player.rect,
				{game.player.rect.width, game.player.rect.height} / 2,
				0,
				rl.BLUE,
			)

			if game.editing {
				rl.DrawRectangleLinesEx(
					{f32(mouse_tile_pos.x) - .5, f32(mouse_tile_pos.y) - .5, 1, 1},
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

		rl.GuiButton({10, 50, 200, 40}, "Toggle Editing Mode")

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
}

editor_update :: proc(f32_delta_time: f32, mouse_tile_pos: [2]i32) {
	speed :: 10
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		game.player.rect.x -= f32_delta_time * speed
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		game.player.rect.x += f32_delta_time * speed
	}
	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		game.player.rect.y -= f32_delta_time * speed
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		game.player.rect.y += f32_delta_time * speed
	}

	if rl.IsMouseButtonDown(.LEFT) {
		tile_exists := false
		for tile in game.tiles {
			if tile.active && tile.x == mouse_tile_pos[0] && tile.y == mouse_tile_pos[1] {
				tile_exists = true
				break
			}
		}
		if !tile_exists {
			add_tile(&game.tiles, mouse_tile_pos[0], mouse_tile_pos[1])
		}
	} else if rl.IsMouseButtonDown(.RIGHT) {
		for tile, i in game.tiles {
			if tile.x == i32(mouse_tile_pos[0]) && tile.y == i32(mouse_tile_pos[1]) {
				game.tiles[i] = {}
			}
		}
	}

	if rl.IsKeyPressed(.L) {
		// load game state from file
		data, success := os.read_entire_file("game_state.sjson", context.temp_allocator)
		if !success {
			rl.TraceLog(.ERROR, "Failed to load game state")
			return
		}
		{
			err := json.unmarshal(data, &game, .SJSON, context.temp_allocator)
			if err != nil {
				rl.TraceLog(.ERROR, "Failed to unmarshal game state: %v", err)
				return
			}
		}
	}

	if rl.IsKeyPressed(.P) {
		// save game state to file
		data, err := json.marshal(game, {spec = .SJSON, pretty = true}, context.temp_allocator)
		if err != nil {
			rl.TraceLog(.ERROR, "Failed to save game state: %v", err)
			return
		}
		os.write_entire_file("game_state.sjson", data)
	}
}

// slow way to add tiles, but works for now
add_tile :: proc(tiles: ^[MAX_TILES]Tile, x: i32, y: i32) {
	for i in 0 ..< MAX_TILES {
		if !tiles[i].active {
			tiles[i] = Tile {
				active = true,
				x      = x,
				y      = y,
			}
			return
		}
	}
	// todo: think of better way to handle this?
	rl.TraceLog(.WARNING, "Maximum number of tiles reached (%d)", MAX_TILES)
}

is_colliding :: proc(a: rl.Rectangle, b: rl.Rectangle) -> bool {
	x_dist := abs(a.x - b.x)
	y_dist := abs(a.y - b.y)
	return x_dist < (a.width + b.width) / 2 && y_dist < (a.height + b.height) / 2
}
