package game

import cbor "core:encoding/cbor"
import "core:math"
import os "core:os"
import strings "core:strings"
import rl "vendor:raylib"

LEVEL_NAME_MAX :: 40
Editor :: struct {
	placing_type:      TileType,
	level_name_buffer: [40]byte,
	keyboard_input:    bool,
	mouse_input:       bool,
}

editor_update :: proc(delta_time: f32) {
	speed :: 10
	if IsKeyDown(.LEFT) || IsKeyDown(.A) {
		g.player.rect.x -= delta_time * speed
	}
	if IsKeyDown(.RIGHT) || IsKeyDown(.D) {
		g.player.rect.x += delta_time * speed
	}
	if IsKeyDown(.UP) || IsKeyDown(.W) {
		g.player.rect.y -= delta_time * speed
	}
	if IsKeyDown(.DOWN) || IsKeyDown(.S) {
		g.player.rect.y += delta_time * speed
	}

	if IsKeyPressed(.ONE) do g.editor.placing_type = .SolidTile
	else if IsKeyPressed(.ZERO) do g.editor.placing_type = .PlatformTile
	else if IsKeyPressed(.TWO) do g.editor.placing_type = .LavaTile
	else if IsKeyPressed(.THREE) do g.editor.placing_type = .CannonTile
	else if IsKeyPressed(.FOUR) do g.editor.placing_type = .TrampolineTile
	else if IsKeyPressed(.FIVE) do g.editor.placing_type = .PlatformTile

	float_mouse_tile := rl.Vector2{f32(g.mouse_tile_pos[0]), f32(g.mouse_tile_pos[1])}

	if rl.IsMouseButtonDown(.LEFT) {
		shouldAddTile := true
		for &tile in g.tiles {
			if tile.type != .None &&
			   tile.x == float_mouse_tile[0] &&
			   tile.y == float_mouse_tile[1] {
				if tile.type == .CannonTile && g.editor.placing_type == .CannonTile {
					if rl.IsMouseButtonPressed(.LEFT) {
						tile.angle += math.PI / 2
						// round to closest 90 degrees
						tile.angle = math.round(tile.angle / (math.PI / 2)) * (math.PI / f32(2))

					}
					shouldAddTile = false
				} else {
					tile = {}
				}
				break
			}
		}
		if shouldAddTile {add_tile(&g.tiles, g.mouse_tile_pos[0], g.mouse_tile_pos[1])}
	} else if rl.IsMouseButtonDown(.RIGHT) {
		for tile, i in g.tiles {
			if tile.type != .None &&
			   tile.x == f32(g.mouse_tile_pos[0]) &&
			   tile.y == f32(g.mouse_tile_pos[1]) {
				g.tiles[i] = {}
			}
		}
	}

	LEVEL_FILE := "assets/level.cbor"

	if IsKeyPressed(.L) {
		// load game state from file
		data, success := os.read_entire_file(LEVEL_FILE, context.temp_allocator)
		if !success {
			rl.TraceLog(.ERROR, "Failed to load game state")
			return
		}

		{
			err := cbor.unmarshal(data, &g.tiles, {}, context.temp_allocator)
			if err != nil {
				rl.TraceLog(.ERROR, "Failed to unmarshal game state: %v", err)
				return
			}
		}
	}

	if IsKeyPressed(.P) {
		// save game state to file
		data, err := cbor.marshal(g.tiles, cbor.ENCODE_SMALL, context.temp_allocator)
		if err != nil {
			rl.TraceLog(.ERROR, "Failed to save game state: %v", err)
			return
		}
		os.write_entire_file(LEVEL_FILE, data)
	}
}

editor_ui :: proc() {
	g.editor.keyboard_input = false
	g.editor.mouse_input = false

	rl.GuiSetFont(g.sans_font)
	rl.GuiSetStyle(.DEFAULT, 16, FONT_SIZE)
	x: f32 = 10
	y: f32 = 10
	rl.GuiPanel({x, 10, 200, 400}, "Editor")
	y += 25
	x += 10
	rl.GuiLabel({x, y, 180, 20}, "Level name:")
	y += 20
	@(static) textbox_active: bool = false
	if (rl.GuiTextBox(
			   {x, y, 180, 20},
			   cstring(&g.editor.level_name_buffer[0]),
			   30,
			   textbox_active,
		   )) {
		textbox_active = !textbox_active
	}
	if (textbox_active) {
		g.editor.keyboard_input = true
	}
	y += 25
	rl.GuiLabel({x, y, 180, 20}, "Place tile:")
	y += 20

	// tileTypeToName := TileTypeToName
	// for name, i in tileTypeToName {
	// 	if i == .None do continue
	// 	if rl.GuiButton({x, y, 180, 20}, strings.clone_to_cstring(name, context.temp_allocator)) {
	// 		g.editor.placing_type = i
	// 	}
	// 	y += 20
	// }

	// build strings from tile enum names
	b := strings.builder_make(context.temp_allocator)
	for name, i in TileTypeToName {
		if i != .None {
			strings.write_string(&b, "\n")
		}
		strings.write_string(&b, name)
	}
	tile_strings := strings.to_string(b)
	@(static) dropdown_open: bool = false
	if rl.GuiDropdownBox(
		{x, y, 180, 20},
		strings.clone_to_cstring(tile_strings, context.temp_allocator),
		cast(^i32)&g.editor.placing_type,
		dropdown_open,
	) {
		dropdown_open = !dropdown_open
	}
}
