package game

import "core:math"
import "core:strings"
import rl "vendor:raylib"

PHYSIC_HZ :: 500
FONT_SIZE :: 20
INIT_WIDTH :: 600
INIT_HEIGHT :: 600
MAX_TILES :: 1024
CANNON_FIRE_RATE :: 1

Game_State :: enum {
	Level_Select,
	Playing,
}

Level_Select :: struct {
	level_index: i32,
}

Game_Memory :: struct {
	game_state:                  Game_State,
	player:                      Player,
	camera:                      rl.Camera2D,
	zoom_factor:                 f32,
	tiles:                       [MAX_TILES]Tile,
	cannon_balls:                [MAX_CANNON_BALLS]Cannon_Ball,
	time_since_last_cannon_fire: f32,
	spawn:                       rl.Vector2,
	editing:                     bool,
	editor:                      Editor,
	physics_time_accumulator:    f32,
	mouse_in_screen:             rl.Vector2,
	mouse_in_world:              rl.Vector2,
	mouse_tile_pos:              [2]i32,
	// fonts
	mono_font:                   rl.Font,
	sans_font:                   rl.Font,
	// sounds
	jump_sound:                  rl.Sound,
	death_sound:                 rl.Sound,
	land_sound:                  rl.Sound,
}

g: ^Game_Memory

@(export)
game_update :: proc() {
	delta_time := rl.GetFrameTime()
	g.game_state = Game_State.Playing

	switch g.game_state {
	case .Level_Select:
		// Handle level selection logic here
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		level_names :: []string {
			"Level 1",
			"Level 2",
			"Level 3",
			// Add more levels as needed
		}


		rl.EndDrawing()


	case .Playing:
		g.mouse_in_screen = rl.GetMousePosition()
		g.mouse_in_world = rl.GetScreenToWorld2D(g.mouse_in_screen, g.camera)
		g.mouse_tile_pos = [2]i32 {
			i32(math.round(g.mouse_in_world.x)),
			i32(math.round(g.mouse_in_world.y)),
		}

		g.time_since_last_cannon_fire += delta_time
		if g.time_since_last_cannon_fire > CANNON_FIRE_RATE {
			g.time_since_last_cannon_fire -= CANNON_FIRE_RATE
			for tile in g.tiles {
				if tile.type == .CannonTile {
					cannon_ball_add(tile.x, tile.y, tile.angle)
				}
			}
		}
		cannon_balls_update(delta_time)

		if g.editing {
			editor_update(delta_time)
		} else {
			playing_update(delta_time)
		}

		if IsKeyPressed(.E) {
			g.player.dy = 0
			g.editing = !g.editing
		}
		zoom_speed: f32 = .5
		if IsKeyDownRespectingEditor(.EQUAL) {
			g.zoom_factor += zoom_speed * delta_time
		} else if IsKeyDownRespectingEditor(.MINUS) {
			g.zoom_factor -= zoom_speed * delta_time
		}

		{
			default_game_height :: 20
			screen_width := f32(rl.GetScreenWidth())
			screen_height := f32(rl.GetScreenHeight())
			g.camera.offset = {screen_width / 2, screen_height / 2}
			g.camera.zoom = screen_height / default_game_height * g.zoom_factor
			g.camera.target = {g.player.rect.x, g.player.rect.y}
		}

		game_draw()

	}


	free_all(context.temp_allocator)
}

IsKeyPressed :: proc(key: rl.KeyboardKey) -> bool {
	// respect editor ui using keyboard
	if g.editing && g.editor.keyboard_input {
		return false
	}
	return rl.IsKeyPressed(key)
}

IsKeyDownRespectingEditor :: proc(key: rl.KeyboardKey) -> bool {
	// respect editor ui using keyboard
	if g.editing && g.editor.keyboard_input {
		return false
	}
	return rl.IsKeyDown(key)
}

IsMouseButtonDownRespectingEditor :: proc(button: rl.MouseButton) -> bool {
	// respect editor ui using mouse
	if g.editing && g.editor.mouse_input {
		return false
	}
	return rl.IsMouseButtonDown(button)
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_HIGHDPI, .MSAA_4X_HINT})
	rl.InitWindow(INIT_WIDTH, INIT_HEIGHT, "platformer")
	rl.InitAudioDevice()
	rl.SetTargetFPS(500)
}

@(export)
game_init :: proc() {
	g = new(Game_Memory)

	g^ = Game_Memory {
		spawn = {0, 0},
		player = {rect = {0, 0, .8, 1.2}},
		camera = {offset = {INIT_WIDTH / 2, INIT_HEIGHT / 2}, zoom = 1},
		zoom_factor = 1,
		editor = {placing_type = .SolidTile},
		editing = true,
		mono_font = rl.LoadFontEx(
			"assets/mono_font.ttf",
			i32(FONT_SIZE * rl.GetWindowScaleDPI().x),
			nil,
			0,
		),
		sans_font = rl.LoadFontEx(
			"assets/sans_font.ttf",
			i32(FONT_SIZE * rl.GetWindowScaleDPI().x),
			nil,
			0,
		),
		jump_sound = rl.LoadSound("assets/sounds/jump.wav"),
		death_sound = rl.LoadSound("assets/sounds/death.wav"),
		land_sound = rl.LoadSound("assets/sounds/land.wav"),
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
	return IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable g.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}

playing_update :: proc(delta_time: f32) {
	player_update(delta_time)
}

game_draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.WHITE)
	rl.BeginMode2D(g.camera)
	{
		// draw spawn
		rl.DrawCircleV(g.spawn, 0.2, rl.GREEN)
		cannon_balls_draw()
		draw_tiles()
		draw_player()

		if g.editing {
			rl.DrawRectangleLinesEx(
				{f32(g.mouse_tile_pos.x) - .5, f32(g.mouse_tile_pos.y) - .5, 1, 1},
				.1,
				rl.RED,
			)
		}
	}
	rl.EndMode2D()

	rl.DrawFPS(10, 10 + FONT_SIZE * 2)
	// draw editing text:
	if (g.editing) {
		tileTypeToName := TileTypeToName
		rl.DrawTextEx(g.sans_font, "EDITING", {10, 10}, FONT_SIZE, 0, rl.RED)
		rl.DrawTextEx(
			g.sans_font,
			strings.clone_to_cstring(
				tileTypeToName[g.editor.placing_type],
				context.temp_allocator,
			),
			{10, 10 + FONT_SIZE},
			FONT_SIZE,
			0,
			rl.BLACK,
		)
		editor_ui()
	}

	if (rl.GuiButton({f32(rl.GetScreenWidth() - 100), 10, 90, 30}, g.editing ? "Play" : "Edit")) {
		g.player.dy = 0
		g.editing = !g.editing
	}

	rl.EndDrawing()
}

is_colliding :: proc(a: rl.Rectangle, b: rl.Rectangle) -> bool {
	x_dist := abs(a.x - b.x)
	y_dist := abs(a.y - b.y)
	return x_dist < (a.width + b.width) / 2 && y_dist < (a.height + b.height) / 2
}
