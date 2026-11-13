class_name GhostDecoy
extends RefCounted
## The Ghost Echo decoy (Story 6.1, D-S61-3): sim data only, no node. One object per arena, reused:
## GhostEchoSystem (re)spawns it, ticks it and clears it; CombatResolver clears it when a boss attack
## strikes it (D-S61-8). Live while frames_left > 0. Named GhostDecoy so it is never confused with
## the Null Pointer's decoy arrays (null_pointer_body.gd).

## The register window the Ghost Echo started on (L->N), carried by DECOY_STRUCK.
var window_pair: Vector2i = Vector2i.ZERO
## Arena-local px: the Ghost Echo's start point (D-S61-11).
var position_px: Vector2 = Vector2.ZERO
## Sim frames left; 0 = no decoy.
var frames_left: int = 0


## Places a fresh decoy (replacing a live one, D-S61-4).
func spawn(p_position: Vector2, p_window: Vector2i, frames: int) -> void:
	position_px = p_position
	window_pair = p_window
	frames_left = maxi(frames, 0)


func is_live() -> bool:
	return frames_left > 0


## One sim frame: counts down to 0 and stays there (D-S61-5).
func tick() -> void:
	if frames_left > 0:
		frames_left -= 1


func clear() -> void:
	frames_left = 0
