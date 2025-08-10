package game

import cbor "core:encoding/cbor"
import "core:math"
import os "core:os"
import rl "vendor:raylib"

Editor :: struct {
	placing_type: TileType,
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

	if rl.IsKeyPressed(.ONE) do g.editor.placing_type = .SolidTile
	else if rl.IsKeyPressed(.ZERO) do g.editor.placing_type = .PlatformTile
	else if rl.IsKeyPressed(.TWO) do g.editor.placing_type = .LavaTile
	else if rl.IsKeyPressed(.THREE) do g.editor.placing_type = .CannonTile
	else if rl.IsKeyPressed(.FOUR) do g.editor.placing_type = .TrampolineTile
	else if rl.IsKeyPressed(.FIVE) do g.editor.placing_type = .PlatformTile

	float_mouse_tile := rl.Vector2{f32(g.mouse_tile_pos[0]), f32(g.mouse_tile_pos[1])}

	if rl.IsMouseButtonDown(.LEFT) {
		shouldAddTile := true
		for &tile in g.tiles {
			if tile.type != .None &&
			   tile.x == float_mouse_tile[0] &&
			   tile.y == float_mouse_tile[1] {
				if tile.type == .CannonTile {
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

	LEVEL_FILE := "level.cbor"

	if rl.IsKeyPressed(.L) {
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

	if rl.IsKeyPressed(.P) {
		// save game state to file
		data, err := cbor.marshal(g.tiles, cbor.ENCODE_SMALL, context.temp_allocator)
		if err != nil {
			rl.TraceLog(.ERROR, "Failed to save game state: %v", err)
			return
		}
		os.write_entire_file(LEVEL_FILE, data)
	}
}
