class_name RunStats
extends RefCounted
## Story 6.8 (AC 14-16, D-S68-4, D-S68-5): the run's clear-time and hits-taken record, owned by Game
## as Game.stats. Never part of a fight-start snapshot, so a retry does not restore it: the summary
## reflects the whole run. Reset with the run (title start, ENDING -> TITLE, debug jump to TITLE).
## Integer sim state only; the Ending's summary card reads a snapshot of it (Game.ending_summary).

## Sim frame of the run's first FIGHT entry (Fight 1); -1 before it. The Intro is not counted.
var fight_start_frame: int = -1
## Every landed hit on the player in this run, retries and the lethal hit included.
var hits: int = 0
## True once a debug jump (F1-F5) or a debug bit grant (F8) touched this run: not a clear.
var debug_jumped: bool = false


## Pure: the clear time in sim frames from the first FIGHT entry to `end_frame`; 0 before a fight.
## Pause is excluded because sim frames stop while paused (DC4).
static func clear_frames(start_frame: int, end_frame: int) -> int:
	if start_frame < 0:
		return 0
	return maxi(end_frame - start_frame, 0)


## The ENDING snapshot (AC 15): {clear_frames, hits, debug_jumped} as of `end_frame`.
func snapshot(end_frame: int) -> Dictionary:
	return {
		&"clear_frames": clear_frames(fight_start_frame, end_frame),
		&"hits": hits,
		&"debug_jumped": debug_jumped,
	}
