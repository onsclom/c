/*
This file is the starting point of your g.

Some important procedures are:
- game_init_window: Opens the window
- game_init: Sets up the game state
- game_update: Run once per frame
- game_should_close: For stopping your game when close button is pressed
- game_shutdown: Shuts down game and frees memory
- game_shutdown_window: Closes window

The procs above are used regardless if you compile using the `build_release`
script or the `build_hot_reload` script. However, in the hot reload case, the
contents of this file is compiled as part of `build/hot_reload/g.dll` (or
.dylib/.so on mac/linux). In the hot reload cases some other procedures are
also used in order to facilitate the hot reload functionality:

- game_memory: Run just before a hot reload. That way game_hot_reload.exe has a
	pointer to the game's memory that it can hand to the new game DLL.
- game_hot_reloaded: Run after a hot reload so that the `g` global
	variable can be set to whatever pointer it was in the old DLL.

NOTE: When compiled as part of `build_release`, `build_debug` or `build_web`
then this whole package is just treated as a normal Odin package. No DLL is
created.
*/

package game

// import "core:encoding/cbor"
// import "core:fmt"
// import "core:mem"
// import "core:os"
import "core:math"
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

Game_Memory :: struct {
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
	mono_font:                rl.Font,
	sans_font:                rl.Font,
}

g: ^Game_Memory

@(export)
game_update :: proc() {
	delta_time := rl.GetFrameTime()

	g.mouse_in_screen = rl.GetMousePosition()
	g.mouse_in_world = rl.GetScreenToWorld2D(g.mouse_in_screen, g.camera)
	g.mouse_tile_pos = [2]i32 {
		i32(math.round(g.mouse_in_world.x)),
		i32(math.round(g.mouse_in_world.y)),
	}

	if g.editing {
		editor_update(delta_time)
	} else {
		playing_update(delta_time)
	}

	{ 	// happens both in and out of editor!
		if rl.IsKeyPressed(.E) {
			g.editing = !g.editing
		}
		zoom_speed: f32 = .5
		if rl.IsKeyDown(.EQUAL) {
			g.zoom_factor += zoom_speed * delta_time
		} else if rl.IsKeyDown(.MINUS) {
  		g.zoom_factor -= zoom_speed
		}

		{
			default_game_width :: 20
			screen_width := f32(rl.GetScreenWidth())
			screen_height := f32(rl.GetScreenHeight())
			g.camera.offset = {screen_width / 2, screen_height / 2}
			g.camera.zoom = screen_width / default_game_width * g.zoom_factor
			g.camera.target = {g.player.rect.x, g.player.rect.y}
		}
	}

	game_draw()

	// Everything on tracking allocator is valid until end-of-frame.
	free_all(context.temp_allocator)
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .WINDOW_HIGHDPI})
	rl.InitWindow(INIT_WIDTH, INIT_HEIGHT, "platformer")
	rl.SetTargetFPS(500)
}

@(export)
game_init :: proc() {
	g = new(Game_Memory)

	g^ = Game_Memory {
		player = {rect = {0, 0, .8, 1.2}},
		camera = {offset = {INIT_WIDTH / 2, INIT_HEIGHT / 2}, zoom = 1},
		zoom_factor = 1,
		editor = {placing_variant = SolidTileVariant{}},
		editing = true,
		mono_font = rl.LoadFont("assets/mono_font.ttf"),
		sans_font = rl.LoadFont("assets/sans_font.ttf"),
	}

	game_hot_reloaded(g)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}
	return true
}

@(export)
game_shutdown :: proc() {
	free(g)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside `g`.
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable g.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}

// MY GAME STUFF BELOW
///////////////////////////////

playing_update :: proc(delta_time: f32) {
	if rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		g.player.tried_jump = true
	}

	g.physics_time_accumulator += delta_time
	physic_tick := f32(1) / PHYSIC_HZ
	for g.physics_time_accumulator >= physic_tick {
		g.physics_time_accumulator -= physic_tick

		extra_repel :: 0.0001 // small value to avoid collision issues
		// handle movement and collisions in X axis
		{
			player_dx: f32 = 0
			player_speed :: 5.0
			if (rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A)) {
				player_dx = -player_speed * physic_tick // move left
				g.player.rect.x += player_dx
			}
			if (rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D)) {
				player_dx = player_speed * physic_tick // move right
				g.player.rect.x += player_dx
			}

			for tile in g.tiles {
				if tile.variant == nil do continue
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
		// handle movement and collisions in Y axis
		{
			// apply gravity
			g.player.dy += physic_tick * 18
			if g.player.tried_jump {
				g.player.dy = -10.0 // jump speed
				g.player.tried_jump = false
			}
			player_dy := g.player.dy * physic_tick
			g.player.rect.y += player_dy
			for tile in g.tiles {
				if tile.variant == nil do continue
				tile_rect := rl.Rectangle{f32(tile.x), f32(tile.y), 1.0, 1.0}
				if is_colliding(g.player.rect, tile_rect) {
					if player_dy > 0 {
						g.player.rect.y =
							tile_rect.y -
							(tile_rect.height / 2.0) -
							(g.player.rect.height / 2.0) -
							extra_repel
						g.player.dy = 0 // stop falling
					} else {
						g.player.rect.y =
							tile_rect.y +
							tile_rect.height / 2.0 +
							g.player.rect.height / 2.0 +
							extra_repel
						g.player.dy = 0 // stop jumping
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
	rl.BeginMode2D(g.camera)
	{
		// draw tiles
		for tile in g.tiles {
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
			g.player.rect,
			{g.player.rect.width, g.player.rect.height} / 2,
			0,
			rl.BLUE,
		)

		if g.editing {
			rl.DrawRectangleLinesEx(
				{f32(g.mouse_tile_pos.x) - .5, f32(g.mouse_tile_pos.y) - .5, 1, 1},
				.1,
				rl.RED,
			)

		}
	}
	rl.EndMode2D()

	// draw editing text:
	if (g.editing) {
		rl.DrawTextEx(g.sans_font, "EDITING", {10, 10}, FONT_SIZE, 0, rl.RED)
		selected := ""
		switch _ in g.editor.placing_variant {
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
			g.sans_font,
			strings.clone_to_cstring(selected, context.temp_allocator),
			{10, 10 + FONT_SIZE},
			FONT_SIZE,
			0,
			rl.BLACK,
		)
		rl.DrawFPS(10, 10 + FONT_SIZE * 2)
	}

	if (rl.GuiButton({f32(rl.GetScreenWidth() - 100), 10, 90, 30}, g.editing ? "Play" : "Edit")) {
		g.editing = !g.editing
	}

	rl.EndDrawing()
}

editor_update :: proc(delta_time: f32) {
	speed :: 10
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		g.player.rect.x -= delta_time * speed
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		g.player.rect.x += delta_time * speed
	}
	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		g.player.rect.y -= delta_time * speed
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		g.player.rect.y += delta_time * speed
	}

	if rl.IsKeyPressed(.ONE) {
		g.editor.placing_variant = SolidTileVariant{}
	} else if rl.IsKeyPressed(.TWO) {
		g.editor.placing_variant = LavaTileVariant{}
	} else if rl.IsKeyPressed(.THREE) {
		g.editor.placing_variant = CannonTileVariant{}
	} else if rl.IsKeyPressed(.FOUR) {
		g.editor.placing_variant = TrampolineTileVariant{}
	}

	if rl.IsMouseButtonDown(.LEFT) {
		for &tile in g.tiles {
			if tile.x == g.mouse_tile_pos[0] && tile.y == g.mouse_tile_pos[1] {
				tile = {}
				break
			}
		}
		add_tile(&g.tiles, g.mouse_tile_pos[0], g.mouse_tile_pos[1])
	} else if rl.IsMouseButtonDown(.RIGHT) {
		for tile, i in g.tiles {
			if tile.x == i32(g.mouse_tile_pos[0]) && tile.y == i32(g.mouse_tile_pos[1]) {
				g.tiles[i] = {}
			}
		}
	}

	// if rl.IsKeyPressed(.L) {
	// 	// load game state from file
	// 	data, success := os.read_entire_file("game_state.cbor", context.temp_allocator)
	// 	if !success {
	// 		rl.TraceLog(.ERROR, "Failed to load game state")
	// 		return
	// 	}
	// 	{
	// 		err := cbor.unmarshal(data, &game, {}, context.temp_allocator)
	// 		if err != nil {
	// 			rl.TraceLog(.ERROR, "Failed to unmarshal game state: %v", err)
	// 			return
	// 		}
	// 	}
	// }

	// if rl.IsKeyPressed(.P) {
	// 	// save game state to file
	// 	data, err := cbor.marshal(game, cbor.ENCODE_SMALL, context.temp_allocator)
	// 	if err != nil {
	// 		rl.TraceLog(.ERROR, "Failed to save game state: %v", err)
	// 		return
	// 	}
	// 	os.write_entire_file("game_state.cbor", data)
	// }
}

// slow way to add tiles, but works for now
add_tile :: proc(tiles: ^[MAX_TILES]Tile, x: i32, y: i32) {
	for i in 0 ..< MAX_TILES {
		if tiles[i].variant == nil {
			tiles[i] = Tile {
				x       = x,
				y       = y,
				variant = g.editor.placing_variant,
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
