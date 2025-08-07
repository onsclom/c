package main

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

PHYSIC_HZ :: 500
FONT_SIZE :: 20
INIT_WIDTH :: 600
INIT_HEIGHT :: 600
MAX_TILES :: 1024

Player :: struct {
	rect:       rl.Rectangle,
	dy:         f32,
	tried_jump: bool,
}

SolidTileVariant :: struct {}
LavaTileVariant :: struct {}
CannonTileVariant :: struct {
	angle: f32,
}
TrampolineTileVariant :: struct {}
Tile :: struct {
	x:       i32,
	y:       i32,
	variant: union {
		SolidTileVariant,
		LavaTileVariant,
		CannonTileVariant,
		TrampolineTileVariant,
	},
}

Level :: struct {
	staticTiles: [MAX_TILES]Tile,
}


Editor :: struct {
	placing_variant: union {
		SolidTileVariant,
		LavaTileVariant,
		CannonTileVariant,
		TrampolineTileVariant,
	},
}

Game :: struct {
	player:                   Player,
	camera:                   rl.Camera2D,
	zoom_factor:              f32,
	tiles:                    [MAX_TILES]Tile,
	editing:                  bool,
	editor:                   Editor,
	physics_time_accumulator: f32,
	show_debug_ui:            bool, // TODO
	mouse_in_screen:          rl.Vector2,
	mouse_in_world:           rl.Vector2,
	mouse_tile_pos:           [2]i32,
}

game := Game {
	player = {rect = {0, 0, .8, 1.2}},
	camera = {offset = {INIT_WIDTH / 2, INIT_HEIGHT / 2}, zoom = 1},
	zoom_factor = 1,
	editor = {placing_variant = SolidTileVariant{}},
	editing = true,
}
mono_font := rl.Font{}
sans_font := rl.Font{}

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
	mono_font = rl.LoadFontEx("resources/IBMPlexMono.ttf", dpi_font_load, {}, 250)
	defer rl.UnloadFont(mono_font)
	sans_font = rl.LoadFontEx("resources/IBMPlexSans.ttf", dpi_font_load, {}, 250)
	defer rl.UnloadFont(sans_font)
	{
		FONT_SIZE_ENUM :: 16 // checked raygui.h for this
		rl.GuiSetFont(sans_font)
		rl.GuiSetStyle(.DEFAULT, FONT_SIZE_ENUM, FONT_SIZE)
	}

	for !rl.WindowShouldClose() {
		delta_time := rl.GetFrameTime()

		game.mouse_in_screen = rl.GetMousePosition()
		game.mouse_in_world = rl.GetScreenToWorld2D(game.mouse_in_screen, game.camera)
		game.mouse_tile_pos = [2]i32 {
			i32(math.round(game.mouse_in_world.x)),
			i32(math.round(game.mouse_in_world.y)),
		}

		if game.editing {
			editor_update(delta_time)
		} else {
			playing_update(delta_time)
		}

		{ 	// happens both in and out of editor!
			if rl.IsKeyPressed(.E) {
				game.editing = !game.editing
			}
			zoom_speed: f32 = .5
			if rl.IsKeyDown(.EQUAL) {
				game.zoom_factor += zoom_speed * delta_time
			} else if rl.IsKeyDown(.MINUS) {
				game.zoom_factor -= zoom_speed * delta_time
			}
			{
				default_game_width :: 20
				screen_width := f32(rl.GetScreenWidth())
				screen_height := f32(rl.GetScreenHeight())
				game.camera.offset = {screen_width / 2, screen_height / 2}
				game.camera.zoom = screen_width / default_game_width * game.zoom_factor
				game.camera.target = {game.player.rect.x, game.player.rect.y}
			}
		}

		game_draw()

		free_all(context.temp_allocator)
	}
}

playing_update :: proc(delta_time: f32) {
	if rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		game.player.tried_jump = true
	}

	game.physics_time_accumulator += delta_time
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
				if tile.variant == nil do continue
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
				if tile.variant == nil do continue
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

selectedNum: i32 = 0
game_draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.RAYWHITE)
	rl.BeginMode2D(game.camera)
	{
		// draw tiles
		for tile in game.tiles {
			switch v in tile.variant {
			case SolidTileVariant:
				rl.DrawRectanglePro({f32(tile.x), f32(tile.y), 1, 1}, {0.5, 0.5}, 0, rl.GREEN)
			case LavaTileVariant:
				rl.DrawRectanglePro({f32(tile.x), f32(tile.y), 1, 1}, {0.5, 0.5}, 0, rl.RED)
			case CannonTileVariant:
				rl.DrawCircleV({f32(tile.x), f32(tile.y)}, 0.5, rl.DARKGRAY)
			case TrampolineTileVariant:
				rl.DrawRectanglePro({f32(tile.x), f32(tile.y), 1, 1}, {0.5, 0.5}, 0, rl.BLACK)
			}
		}

		rl.DrawRectanglePro(
			game.player.rect,
			{game.player.rect.width, game.player.rect.height} / 2,
			0,
			rl.BLUE,
		)

		if game.editing {
			rl.DrawRectangleLinesEx(
				{f32(game.mouse_tile_pos.x) - .5, f32(game.mouse_tile_pos.y) - .5, 1, 1},
				.1,
				rl.RED,
			)

		}
	}
	rl.EndMode2D()

	// draw editing text:
	if (game.editing) {
		rl.DrawTextEx(sans_font, "EDITING", {10, 10}, FONT_SIZE, 0, rl.RED)
		selected := ""
		switch _ in game.editor.placing_variant {
		case SolidTileVariant:
			selected = "Solid"
		case LavaTileVariant:
			selected = "Lava"
		case CannonTileVariant:
			selected = "Cannon"
		case TrampolineTileVariant:
			selected = "Trampoline"
		}
		rl.DrawTextEx(
			sans_font,
			strings.clone_to_cstring(selected, context.temp_allocator),
			{10, 10 + FONT_SIZE},
			FONT_SIZE,
			0,
			rl.BLACK,
		)
	}
	rl.EndDrawing()
}

editor_update :: proc(delta_time: f32) {
	speed :: 10
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		game.player.rect.x -= delta_time * speed
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		game.player.rect.x += delta_time * speed
	}
	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		game.player.rect.y -= delta_time * speed
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		game.player.rect.y += delta_time * speed
	}

	if rl.IsKeyPressed(.ONE) {
		game.editor.placing_variant = SolidTileVariant{}
	} else if rl.IsKeyPressed(.TWO) {
		game.editor.placing_variant = LavaTileVariant{}
	} else if rl.IsKeyPressed(.THREE) {
		game.editor.placing_variant = CannonTileVariant{}
	} else if rl.IsKeyPressed(.FOUR) {
		game.editor.placing_variant = TrampolineTileVariant{}
	}

	if rl.IsMouseButtonDown(.LEFT) {
		for &tile in game.tiles {
			if tile.x == game.mouse_tile_pos[0] && tile.y == game.mouse_tile_pos[1] {
				tile = {}
				break
			}
		}
		add_tile(&game.tiles, game.mouse_tile_pos[0], game.mouse_tile_pos[1])
	} else if rl.IsMouseButtonDown(.RIGHT) {
		for tile, i in game.tiles {
			if tile.x == i32(game.mouse_tile_pos[0]) && tile.y == i32(game.mouse_tile_pos[1]) {
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
		if tiles[i].variant == nil {
			tiles[i] = Tile {
				x       = x,
				y       = y,
				variant = game.editor.placing_variant,
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
