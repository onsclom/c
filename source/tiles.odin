package game

import "core:math"
import rl "vendor:raylib"

CANNON_CIRCLE_RADIUS :: .33

TileType :: enum {
	None,
	SolidTile,
	LavaTile,
	CannonTile,
	TrampolineTile,
	PlatformTile,
}

TileTypeToName :: [TileType]string {
	.None           = "None",
	.SolidTile      = "Solid",
	.LavaTile       = "Lava",
	.CannonTile     = "Cannon",
	.TrampolineTile = "Trampoline",
	.PlatformTile   = "Platform",
}

Tile :: struct {
	type:  TileType,
	x:     f32,
	y:     f32,
	angle: f32,
}

draw_tiles :: proc() {
	for tile in g.tiles {
		switch tile.type {
		case .None:
			continue
		case .SolidTile:
			rl.DrawRectanglePro({tile.x, tile.y, 1, 1}, {0.5, 0.5}, tile.angle, rl.BLACK)
		case .LavaTile:
			rl.DrawRectanglePro({tile.x, tile.y, 1, 1}, {0.5, 0.5}, tile.angle, rl.RED)
		case .CannonTile:
			rl.DrawCircleV({tile.x, tile.y}, CANNON_CIRCLE_RADIUS, rl.DARKGRAY)
			squareCenter := rl.Vector2 {
				math.cos(tile.angle) * CANNON_CIRCLE_RADIUS,
				math.sin(tile.angle) * CANNON_CIRCLE_RADIUS,
			}
			rectSize :: 0.3
			rl.DrawRectanglePro(
				{tile.x + squareCenter.x, tile.y + squareCenter.y, rectSize, rectSize},
				{rectSize / 2, rectSize / 2},
				0,
				rl.DARKGRAY,
			)


		case .TrampolineTile:
			rl.DrawRectanglePro({tile.x, tile.y, 1, 1}, {0.5, 0.5}, tile.angle, rl.DARKGREEN)
		case .PlatformTile:
			// should just draw top bit of rect
			PLATFORM_HEIGHT :: 0.25
			PLATFORM_Y := tile.y - 0.5 + PLATFORM_HEIGHT / 2
			rl.DrawRectanglePro(
				{tile.x, PLATFORM_Y, 1, PLATFORM_HEIGHT},
				{0.5, PLATFORM_HEIGHT / 2},
				tile.angle,
				rl.GRAY,
			)
		}
	}
}

// slow way to add tiles, but works for now
add_tile :: proc(tiles: ^[MAX_TILES]Tile, x: i32, y: i32) {
	for i in 0 ..< MAX_TILES {
		if tiles[i].type == .None {
			tiles[i] = Tile {
				type = g.editor.placing_type,
				x    = f32(x),
				y    = f32(y),
			}
			return
		}
	}
	// todo: think of better way to handle this?
	rl.TraceLog(.WARNING, "Maximum number of tiles reached (%d)", MAX_TILES)
}
