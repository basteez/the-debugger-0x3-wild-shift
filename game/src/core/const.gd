class_name Const
extends RefCounted
## Foundation constants shared by every system. Units: tiles, pixels, frames.

const TILE_PX := 16
const SIM_HZ := 60
const BASE_RES := Vector2i(640, 360)
const ARENA_TILES := Vector2i(32, 18)


## Converts a speed in tiles per second to pixels per simulation frame.
static func tiles_per_s_to_px_per_frame(tiles_s: float) -> float:
	return tiles_s * TILE_PX / SIM_HZ
