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


# --- Story 7.8 (AC 5-7, 9, 10, D-S78-1): the playtest metric record --------------------------------
# Written by Game (flow side) only, never from the sim tick path; practice writes are blocked in Game.
# Reset with the run like the fields above (every RunStats.new() site). snapshot() is unchanged.

## Sim frame of the run's first player shift in FIGHT; -1 before it.
var first_shift_frame: int = -1
## Boss index -> sim frame of that boss's first non-retry FIGHT entry (retries never restart it).
var boss_start_frames: Dictionary = {}
## Boss index -> clear time in sim frames (FIGHT entry to the finished defeat).
var boss_clear_frames: Dictionary = {}
## Boss index -> deaths on that boss in this run (retries of that boss included).
var boss_deaths: Dictionary = {}


## Records `frame` as `boss_index`'s FIGHT entry, only the first time (AC 6: retries keep the clock).
func note_fight_entry(boss_index: int, frame: int) -> void:
	if boss_index < 0 or boss_start_frames.has(boss_index):
		return
	boss_start_frames[boss_index] = frame


## Records the run's first player shift. True only when this call set it (first shift of the run).
func note_first_shift(frame: int) -> bool:
	if first_shift_frame >= 0:
		return false
	first_shift_frame = frame
	return true


## Counts one death on `boss_index`.
func note_death(boss_index: int) -> void:
	if boss_index < 0:
		return
	boss_deaths[boss_index] = int(boss_deaths.get(boss_index, 0)) + 1


## Records `boss_index`'s clear at `frame` and returns the clear frames (-1 without a recorded start; nothing is recorded).
func note_boss_cleared(boss_index: int, frame: int) -> int:
	if not boss_start_frames.has(boss_index):
		return -1
	var frames: int = maxi(frame - int(boss_start_frames[boss_index]), 0)
	boss_clear_frames[boss_index] = frames
	return frames


## Deaths recorded on `boss_index` (0 when none).
func deaths_on(boss_index: int) -> int:
	return int(boss_deaths.get(boss_index, 0))


## Pure: sim frames as seconds (frames / Const.SIM_HZ); -1.0 for a negative input (not recorded).
static func seconds(frames: int) -> float:
	if frames < 0:
		return -1.0
	return float(frames) / float(Const.SIM_HZ)


## Pure: the ENDING `[metrics]` summary line body (AC 7). `full_run_s` is -1.0 when the run has no
## title input (first_input_frame < 0). `bosses=[index:clear_s/deaths, ...]`, 1-based, cleared bosses
## only, in boss order.
func metrics_summary(first_input_frame: int, end_frame: int, assist: bool, p_debug_jumped: bool) -> String:
	var run_frames: int = maxi(end_frame - first_input_frame, 0) if first_input_frame >= 0 else -1
	var keys: Array = boss_clear_frames.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k: int in keys:
		parts.append("%d:%.1f/%d" % [k + 1, seconds(int(boss_clear_frames[k])), deaths_on(k)])
	return "run full_run_s=%.1f hits=%d assist=%s debug_jumped=%s bosses=[%s]" % [
		seconds(run_frames), hits, str(assist), str(p_debug_jumped), ", ".join(parts)]
