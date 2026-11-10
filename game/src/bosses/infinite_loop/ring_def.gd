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
## Story 3.4 (D-S34-8): how far Head Rush's head charges in its ACTIVE window, in tiles.
@export var head_charge_tiles: int = 10
## Story 3.4 (D-S34-7): speed at which Constrict re-centres on its aim, in tiles/s. Must beat the
## player's walk (a test checks it against PlayerDef.speed_tiles_s, D-S34-16).
@export var constrict_chase_tps: int = 8
## Story 3.4 (D-S34-7): Constrict's radius at the end of its ACTIVE window, in tiles (< the ring radius).
@export var constrict_radius_tiles: int = 2
## Story 3.5 (D-S35-4, D-S35-13): the phase-3 split. Segments of the outer ring after the split.
@export var split_outer_segments: int = 16
## Segments of the inner ring after the split (concentric, 1 tile each).
@export var split_inner_segments: int = 8
## Inner ring speed in percent of the outer ring's (derived each tick, capped, D-S35-5).
@export var split_inner_speed_percent: int = 150
## Ticks between two timed `;` openings after the split (D-S35-6). Longer than any opening.
@export var opening_period_frames: int = 180
## The `;` Spit cycle in ticks (D-S35-9): one shot per cycle in phase 3.
@export var spit_period_frames: int = 360
## The Spit tell: the origin `;` glows for the last this-many ticks of the cycle (>= 1, < period).
@export var spit_tell_frames: int = 20
## Spit projectile speed in tiles/s (D-S35-10): 6 tiles/s = 100 milli-tiles per tick.
@export var spit_tps: int = 6
## Preallocated Spit projectile slots (D-S35-10).
@export var spit_slots: int = 16


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
	if head_charge_tiles <= 0:
		out.append("head_charge_tiles must be > 0 (got %d)" % head_charge_tiles)
	if constrict_chase_tps <= 0:
		out.append("constrict_chase_tps must be > 0 (got %d)" % constrict_chase_tps)
	# Story 3.5 (D-S35-12): Constrict also shrinks from the split outer ring, so the smaller radius bounds it.
	var smallest: float = minf(radius_tiles(), split_radius_tiles(split_outer_segments))
	if constrict_radius_tiles <= 0 or float(constrict_radius_tiles) >= smallest:
		out.append("constrict_radius_tiles must be > 0 and < the ring radius %.2f (got %d)" % [smallest, constrict_radius_tiles])
	if split_outer_segments != 16:
		out.append("split_outer_segments must be 16 (got %d)" % split_outer_segments)
	if split_inner_segments != 8:
		out.append("split_inner_segments must be 8 (got %d)" % split_inner_segments)
	if split_inner_speed_percent != 150:
		out.append("split_inner_speed_percent must be 150 (got %d)" % split_inner_speed_percent)
	if opening_period_frames <= open_frames:
		out.append("opening_period_frames must be > open_frames %d (got %d)" % [open_frames, opening_period_frames])
	if spit_period_frames < 2:
		out.append("spit_period_frames must be >= 2 (got %d)" % spit_period_frames)
	if spit_tell_frames < 1 or spit_tell_frames >= spit_period_frames:
		out.append("spit_tell_frames must be >= 1 and < spit_period_frames (got %d)" % spit_tell_frames)
	if spit_tps <= 0:
		out.append("spit_tps must be > 0 (got %d)" % spit_tps)
	if spit_slots < 1:
		out.append("spit_slots must be >= 1 (got %d)" % spit_slots)
	return out


## Radius in tiles of a ring of `count` 1-tile segments (D-S35-4). Pure.
static func split_radius_tiles(count: int) -> float:
	return float(count) / TAU


## Ring radius in tiles: the circumference (one tile per segment) over 2π (D-S33-3).
func radius_tiles() -> float:
	return float(segments) / TAU
