class_name PlayerDef
extends Def
## Player movement and survivability data (GDD Movement table, GFR1-GFR3). Balance lives in
## data/player/player_def.tres; hurtbox, HP and invulnerability are stored now and used from 2.7/2.9.

## Top speed in tiles per second (converted once via Const.tiles_per_s_to_px_per_frame).
@export var speed_tiles_s: float = 7.0
## Frames to ramp from rest to top speed.
@export var accel_frames: int = 4
## Frames to stop from top speed.
@export var decel_frames: int = 3
@export var max_hp: int = 5
## Post-hit invulnerability (Story 2.9).
@export var invuln_frames: int = 60
## Hurtbox diameter in tiles (Story 2.7).
@export var hurtbox_tiles: float = 0.6


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if not is_finite(speed_tiles_s) or speed_tiles_s <= 0.0:
		out.append("speed_tiles_s must be > 0 (got %s)" % speed_tiles_s)
	if accel_frames < 1:
		out.append("accel_frames must be >= 1 (got %d)" % accel_frames)
	if decel_frames < 1:
		out.append("decel_frames must be >= 1 (got %d)" % decel_frames)
	if max_hp < 1:
		out.append("max_hp must be >= 1 (got %d)" % max_hp)
	if invuln_frames < 0:
		out.append("invuln_frames must be >= 0 (got %d)" % invuln_frames)
	if not is_finite(hurtbox_tiles) or hurtbox_tiles <= 0.0 or hurtbox_tiles > 1.0:
		out.append("hurtbox_tiles must be in (0, 1] (got %s)" % hurtbox_tiles)
	return out
