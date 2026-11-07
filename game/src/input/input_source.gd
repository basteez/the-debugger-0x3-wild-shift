class_name InputSource
extends RefCounted
## Where the simulation reads input from (AC7): LiveInput for play, ReplayInput for playback.
## Simulation code never touches the Input singleton directly.


## Fresh presses of buffered actions this physics frame. Called once per polled frame by SimClock.
func presses_for_frame() -> Array[StringName]:
	return []
