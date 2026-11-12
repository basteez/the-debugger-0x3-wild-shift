class_name InputSource
extends RefCounted
## Where the simulation reads input from (AC7): LiveInput for play, ReplayInput for playback.
## Simulation code never touches the Input singleton directly.


## Fresh presses of buffered actions this physics frame. Called once per polled frame by SimClock.
func presses_for_frame() -> Array[StringName]:
	return []


## Held movement direction this physics frame (Story 2.2, D-S22-3): one value per polled frame,
## each component in {-1, 0, 1}. Called once per polled frame by SimClock, after presses_for_frame.
func move_for_frame() -> Vector2i:
	return Vector2i.ZERO


## Story 5.4 (D-S54-2): Watch held this physics frame (a held state, not a press). Called once per
## polled frame by SimClock, after move_for_frame. Default: never held.
func watch_held_for_frame() -> bool:
	return false
