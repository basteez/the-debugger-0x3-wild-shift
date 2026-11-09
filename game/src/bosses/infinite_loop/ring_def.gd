class_name RingDef
extends Def
## The Infinite Loop's ring numbers (Story 3.3, D-S33-15, GDD "Boss 1 — Infinite Loop", D-018):
## segment count, spin speed and its ramp, drift speed, how long the `;` stays open per lap and the
## contact / hurt circle radii. Read-only at runtime; InfiniteLoopBody runs it. The GDD's fixed
## facts (24 segments, 8 -> 12 tiles/s at +5% per lap, 2 tiles/s drift) are checked here.

## Segments in the closed ring, 1 tile each (the circumference in tiles).
@export var segments: int = 24
## Spin speed at fight start and after every phase change, in tiles/s.
@export var base_speed_tps: int = 8
## Spin speed cap, in tiles/s (>= base).
@export var speed_cap_tps: int = 12
## Speed added at each lap start, in percent of the current speed (integer floor, D-S33-2).
@export var ramp_percent: int = 5
## Speed at which the ring centre drifts toward the player, in tiles/s (D-S33-7).
@export var drift_tps: int = 2
## Frames the `;` stays open from each lap start.
@export var open_frames: int = 90
## Radius of each segment's contact circle, in tiles (D-S33-3).
@export var contact_radius_tiles: float = 0.5
## Radius of the `;` hurt circle, in tiles (D-S33-4).
@export var hurt_radius_tiles: float = 0.5


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if segments != 24:
		out.append("segments must be 24 (got %d)" % segments)
	if base_speed_tps != 8:
		out.append("base_speed_tps must be 8 (got %d)" % base_speed_tps)
	if speed_cap_tps != 12 or speed_cap_tps < base_speed_tps:
		out.append("speed_cap_tps must be 12 and >= base_speed_tps (got %d)" % speed_cap_tps)
	if ramp_percent != 5:
		out.append("ramp_percent must be 5 (got %d)" % ramp_percent)
	if drift_tps != 2:
		out.append("drift_tps must be 2 (got %d)" % drift_tps)
	if open_frames < 1:
		out.append("open_frames must be >= 1 (got %d)" % open_frames)
	if not is_finite(contact_radius_tiles) or contact_radius_tiles <= 0.0:
		out.append("contact_radius_tiles must be > 0 (got %s)" % contact_radius_tiles)
	if not is_finite(hurt_radius_tiles) or hurt_radius_tiles <= 0.0:
		out.append("hurt_radius_tiles must be > 0 (got %s)" % hurt_radius_tiles)
	return out


## Ring radius in tiles: the circumference (one tile per segment) over 2π (D-S33-3).
func radius_tiles() -> float:
	return float(segments) / TAU
