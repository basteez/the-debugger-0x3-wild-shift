extends Node
## Game flow state machine (AD-08). Only Game changes flow_state, through _set_flow_state.
## Presentation calls start_run_from_title, finish_intro, advance (and debug_jump in debug).
## Story 3.8: finish_defeat (FIGHT -> HARVEST / ENDING after the defeat animation), finish_harvest
## (HARVEST -> next FIGHT) and debug_grant_bit (F8), all called from presentation after the tick.
## Game is also the only writer of SimClock.paused (Story 1.7 DC2): Esc / P, focus loss and the
## resume click (D-FIX-FS-1).

enum FlowState { TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING }

## Intro cap (D-040): 8 s at 60 Hz, counted in sim frames so it stops with pause (DC5).
const INTRO_MAX_FRAMES := 480
const LAST_BOSS_INDEX := 2
## Story 2.9 (D-049 c, D-S29-3): the DEAD screen accepts a new press only this many sim frames
## after the death frame.
const RETRY_DELAY_FRAMES := 20
## Story 3.8 (D-S38-10): the HARVEST screen lasts at most HARVEST_MAX_FRAMES sim frames and accepts
## a skip press from HARVEST_SKIP_FRAMES after its entry.
const HARVEST_MAX_FRAMES := 480
const HARVEST_SKIP_FRAMES := 120
## Boss ids by boss_index (I-5): the `player_died` payload and the boss signatures.
const BOSS_IDS: Array[StringName] = [&"infinite_loop", &"null_pointer", &"segfault"]
## Story 6.8 (AC 4-6, D-S68-1, D-S68-7): the Ending's timeline holds at ENDING_HOLD_FRAMES (30 s, the
## cap of the whole ending) and waits for the player; a press leaves it only after
## ENDING_LEAVE_GATE_FRAMES sim frames, so the input that ended the last fight never counts.
const ENDING_HOLD_FRAMES := 900
const ENDING_LEAVE_GATE_FRAMES := 60
## States where Esc and focus loss pause (Story 1.7 DC1): the 60 Hz clock drives the Intro cap and the fight.
## Story 6.8 (D-S68-6): the Ending too, so its timeline freezes on Esc.
const PAUSABLE_STATES: Array[FlowState] = [FlowState.INTRO, FlowState.FIGHT, FlowState.ENDING]
## [design call] D-FIX-FS-1 (fullscreen Esc lock): in browser fullscreen Esc exits fullscreen and never
## reaches the canvas, and the blur pauses the game. So the `pause` action is Esc or P, and while
## paused a left click / tap resumes, unless it comes less than CLICK_RESUME_GUARD_MSEC (wall clock,
## sim frames stop while paused) after the pause began: the click that took focus away (or came with
## the blur) never also resumes. Every left click re-focuses the game on web (D-FIX-FS-2).
const CLICK_RESUME_GUARD_MSEC := 300
## Focus loss only: focuses the canvas inside its own document, never takes focus from the parent page.
const _FOCUS_CANVAS_JS := "var c=document.querySelector('canvas'); if (c) { c.focus(); }"
## [design call] D-FIX-FS-2 (frozen after a fullscreen resume): after itch.io's fullscreen exits, the
## focus sits in the parent page while the canvas stays its iframe's activeElement. canvas.focus()
## on the already active element is then a no-op (Godot's own mousedown focus too, and the engine
## preventDefaults mousedown, so the click never focuses the iframe natively): the game resumes
## but every key goes to the parent page. window.focus() first moves the focus back into the
## iframe. It runs on a left click only: Godot flushes input inside the DOM mousedown callback, so
## the click's user activation allows it, and a blur never steals the focus back.
## Story 7.6 [design call] (D-S76-4 changed): the practice loadout key. R (the story's pick) is the
## `watch` action, so the keyboard uses L ("loadout"); the pad uses Select (button 4, `mute` only on
## the pause screen, where the cycle is off).
const PRACTICE_CYCLE_KEY := KEY_L
const PRACTICE_CYCLE_BUTTON := JOY_BUTTON_BACK
## Story 7.6 [design call] D-S76-6: L3 leaves a practice fight on the pad (Esc on the keyboard).
const PRACTICE_LEAVE_BUTTON := JOY_BUTTON_LEFT_STICK
const REFOCUS_ON_CLICK_JS := "window.focus(); var c=document.querySelector('canvas'); if (c) { c.focus(); }"

var flow_state: FlowState = FlowState.TITLE
## Sim frame of the first title input: start of the 30-s first-shift clock. -1 before it.
var first_input_frame: int = -1
## Sim frame on which INTRO was entered; -1 outside a run.
var intro_start_frame: int = -1
var run: RunState = RunState.new()
## Sim frame of the last death (Story 2.9); -1 when not dead.
var death_frame: int = -1
## Sim frame on which HARVEST was entered (Story 3.8, B3); -1 outside HARVEST.
var harvest_start_frame: int = -1
## Sim frame on which ENDING was entered (Story 6.8, AC 1); -1 outside ENDING.
var ending_start_frame: int = -1
## Story 6.8 (AC 14-16): the run's clear-time and hits record. Not restored by a retry.
var stats: RunStats = RunStats.new()
## Story 6.8 (AC 15): the stats snapshot taken on ENDING entry ({clear_frames, hits, debug_jumped});
## empty outside ENDING. The Ending's stretch summary card reads it.
var ending_summary: Dictionary = {}
## True only while retry() re-enters FIGHT: the snapshot is restored, not re-captured (D-S29-4).
var _retrying: bool = false
## Web only: the JS focus callback, kept alive for the session (a freed callback is never called).
var _web_focus_cb: JavaScriptObject = null
## True from a focus loss until focus returns or the player presses Esc: a blur seen in a
## non-pausable state (TITLE, DEAD, HARVEST) pauses on entering INTRO or FIGHT (review fix).
var _focus_lost: bool = false
## Wall-clock msec (Time.get_ticks_msec) when the current pause began; -1 when not paused (D-FIX-FS-1).
var _paused_at_msec: int = -1
## Runs a JS snippet on web (JavaScriptBridge.eval); a no-op elsewhere. Tests swap in a recorder.
var _web_eval: Callable = _eval_on_web
## Story 5.6 (D-S56-3): cut ladder #4. Off: the Segfault fight is cut, the Null Pointer's defeat goes
## straight to ENDING and NULL is never dropped. Read once (AD-12); tests may override it before
## the fight, the same pattern as Arena.watch_enabled.
var segfault_enabled: bool = Defs.FEATURE_FLAGS.segfault
## Story 7.6 (FR59, AC 1, 6): true from the title's practice start until the practice leaves to the
## title. Not persisted. In practice the fight has the `/* test */` dummy and no boss, and the FIGHT
## entry never writes the save (SaveService.note_fight_start is skipped).
var practice_run: bool = false
## Story 7.6 (AC 9-12): the offered loadouts (boss indices whose fight-start set the register starts
## from, practice_loadout_bosses) and the current one. Never saved: every practice start recomputes them.
var practice_loadouts_offered: Array[int] = []
var practice_loadout_index: int = 0
## Story 7.6 (AC 5, D-S76-2): sim frame of the current practice FIGHT entry (each loadout change and
## retry restarts it); the practice frame counter reads it. -1 outside practice.
var practice_start_frame: int = -1


func _ready() -> void:
	if OS.has_feature("web"):
		_listen_web_focus()
	EventBus.player_damaged.connect(on_player_damaged)


func _input(event: InputEvent) -> void:
	handle_click_refocus(event) # never consumes: the click still reaches the resume rule and the screens
	if handle_pause_input(event) or handle_resume_click(event, Time.get_ticks_msec()):
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_unlisten_web_focus()
	if EventBus.player_damaged.is_connected(on_player_damaged):
		EventBus.player_damaged.disconnect(on_player_damaged)


func _notification(what: int) -> void:
	if is_focus_lost_notification(what):
		on_focus_lost()
	elif is_focus_gained_notification(what):
		_focus_lost = false


## Pause on or off. The only writer of SimClock.paused outside tests (DC2). Refused outside
## PAUSABLE_STATES (false, no log). True when the call is accepted; it emits and logs only on change.
func set_paused(on: bool, reason: StringName) -> bool:
	if flow_state not in PAUSABLE_STATES:
		return false
	if SimClock.paused == on:
		return true
	SimClock.paused = on
	_paused_at_msec = Time.get_ticks_msec() if on else -1
	Log.info(&"flow", ("pause on (%s)" % reason) if on else "pause off")
	EventBus.pause_toggled.emit(on)
	return true


## Esc or P toggles the pause in a pausable state (DC2, DC3, D-FIX-FS-1). True when the event was a
## fresh `pause` press that toggled it; the caller then consumes it. Esc / P elsewhere is left to the
## screens (P is the title's Practice option, D-FIX-FS-1: never consumed in TITLE).
## Story 7.6 (AC 11, 13, D-S76-4, D-S76-5): in a practice FIGHT that is not paused, Esc leaves to the
## title in one press (P and Start still pause), and L / pad Select change the loadout.
func handle_pause_input(event: InputEvent) -> bool:
	if handle_practice_input(event):
		return true
	if not is_pause_press(event):
		return false
	_focus_lost = false # a key press proves the window has focus
	return set_paused(not SimClock.paused, &"esc")


## Story 7.6: the practice-only keys, live only in a practice FIGHT that is not paused. True when the
## event was consumed (Esc left to the title, or the loadout changed).
func handle_practice_input(event: InputEvent) -> bool:
	if not practice_run or flow_state != FlowState.FIGHT or SimClock.paused:
		return false
	if is_practice_leave_press(event):
		_focus_lost = false
		return leave_practice_to_title(SimClock.sim_frame)
	if is_practice_cycle_press(event):
		return cycle_practice_loadout(SimClock.sim_frame)
	return false


## Pure (Story 7.6, D-S76-5): a fresh, non-echo Esc key press (P is the same `pause` action but
## pauses), or [design call] D-S76-6 a pad PRACTICE_LEAVE_BUTTON (L3, the button that entered practice
## from the title): a pad has no Esc and Start pauses.
static func is_practice_leave_press(event: InputEvent) -> bool:
	var pad := event as InputEventJoypadButton
	if pad != null:
		return pad.pressed and pad.button_index == PRACTICE_LEAVE_BUTTON
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	return code == KEY_ESCAPE


## Pure (Story 7.6, D-S76-4 changed): a fresh, non-echo PRACTICE_CYCLE_KEY press (no modifiers) or a
## pad PRACTICE_CYCLE_BUTTON (Select) press. Matched by code, not through the InputMap, so it can
## never reach the sim; R is the `watch` action, so the keyboard key is L ("loadout").
static func is_practice_cycle_press(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo or key.shift_pressed or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
			return false
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return code == PRACTICE_CYCLE_KEY
	var pad := event as InputEventJoypadButton
	return pad != null and pad.pressed and pad.button_index == PRACTICE_CYCLE_BUTTON


## D-FIX-FS-2: every left click / tap, in any state, paused or not, moves the keyboard focus back to
## the game (REFOCUS_ON_CLICK_JS). True when it was a left click. Never consumes the event.
func handle_click_refocus(event: InputEvent) -> bool:
	if not is_left_click(event):
		return false
	_web_eval.call(REFOCUS_ON_CLICK_JS)
	return true


func _eval_on_web(code: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(code)


## D-FIX-FS-1: while paused, a left click / tap resumes once the guard has passed (the keyboard
## focus comes back through handle_click_refocus, D-FIX-FS-2). True when it
## resumed; the caller then consumes the click, so no screen sees it. No mouse button is bound to a
## gameplay action and a paused tick never polls (D-S21-9), so the resume click never attacks.
## A click on the pause screen's mute label is consumed by PauseScreen first (it sits later in the
## tree, and _input runs in reverse tree order), so it toggles mute and never resumes.
func handle_resume_click(event: InputEvent, now_msec: int) -> bool:
	if not SimClock.paused or not is_left_click(event):
		return false
	_focus_lost = false # a click on the game proves it has focus
	if not click_resume_allowed(_paused_at_msec, now_msec):
		return false
	return set_paused(false, &"click")


## Pure: a left mouse button press (a tap arrives as one: emulate_mouse_from_touch).
static func is_left_click(event: InputEvent) -> bool:
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT


## Pure (D-FIX-FS-1): a click may resume only CLICK_RESUME_GUARD_MSEC after the pause began.
## An unknown start (-1) allows it, so the game can never stay locked.
static func click_resume_allowed(paused_at_msec: int, now_msec: int) -> bool:
	return paused_at_msec < 0 or now_msec - paused_at_msec >= CLICK_RESUME_GUARD_MSEC


## Pure: a fresh, non-echo press of the `pause` action (Esc or P).
static func is_pause_press(event: InputEvent) -> bool:
	return InputMap.has_action(&"pause") and event.is_action_pressed(&"pause")


## Pure: the engine notifications that mean "the player looked away" (DC9). Desktop sends
## APPLICATION_FOCUS_OUT; the web build sends only WM_WINDOW_FOCUS_OUT (canvas blur).
static func is_focus_lost_notification(what: int) -> bool:
	return what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT


## Pure: the engine notifications that mean the player is back.
static func is_focus_gained_notification(what: int) -> bool:
	return what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN


## Focus loss pauses; focus return never resumes (AC4, DC3). A no-op when already paused.
## The loss is remembered so a blur in a non-pausable state still pauses on the next INTRO/FIGHT.
## On web the canvas is re-focused so Esc reaches it when the player returns.
func on_focus_lost() -> void:
	_focus_lost = true
	if set_paused(true, &"focus"):
		_web_eval.call(_FOCUS_CANVAS_JS)


## Title press-to-start (FR47). Valid only from TITLE.
func start_run_from_title(frame: int) -> void:
	if flow_state != FlowState.TITLE:
		Log.warn(&"flow", "start_run_from_title ignored outside TITLE")
		return
	first_input_frame = frame
	intro_start_frame = frame
	run = RunState.new()
	stats = RunStats.new() # Story 6.8: a new run, new stats
	Log.info(&"flow", "title -> intro at f=%d" % frame)
	_set_flow_state(FlowState.INTRO)


## Story 7.3 (AC 6, 7, D-S73-2, D-S73-10): title press with a save past Boss 1. Valid only from TITLE.
## Starts the 30-s clock, a fresh RunState and RunStats, skips the Intro and enters the resumed fight
## (resume_index); the FIGHT entry writes the save (no change in value). `highest_boss` -1 reads
## SaveService.highest_boss (tests pass a value).
func resume_run_from_title(frame: int, highest_boss: int = -1) -> void:
	if flow_state != FlowState.TITLE:
		Log.warn(&"flow", "resume_run_from_title ignored outside TITLE")
		return
	first_input_frame = frame
	intro_start_frame = -1
	run = RunState.new()
	var saved: int = SaveService.highest_boss if highest_boss < 0 else highest_boss
	run.start_boss(resume_index(saved, segfault_enabled))
	stats = RunStats.new()
	Log.info(&"flow", "title -> resume fight %d at f=%d" % [run.boss_index + 1, frame])
	_set_flow_state(FlowState.FIGHT)


## Story 7.3 (AC 9): the title's [N] new run. Resets the saved progress, then a normal start (Intro kept).
func start_new_run_from_title(frame: int) -> void:
	if flow_state != FlowState.TITLE:
		Log.warn(&"flow", "start_new_run_from_title ignored outside TITLE")
		return
	SaveService.reset_run_progress()
	start_run_from_title(frame)


## Pure (Story 7.3, AC 7, D-S73-4): the boss index a save resumes at, capped by the Segfault cut.
static func resume_index(highest_boss: int, segfault_on: bool) -> int:
	return clampi(highest_boss - 1, 0, last_fight_index(segfault_on))


## Story 7.6 (FR59, AC 1, 6, 9): the title's practice option. Valid only from TITLE. A fresh RunState
## and RunStats; no Intro; FIGHT with the `/* test */` dummy and no boss; the register starts at the
## highest loadout reached (`highest_boss`, -1 reads SaveService.highest_boss: tests pass a value).
## The 30-s first-shift clock is not started and the save is never written.
func start_practice_from_title(frame: int, highest_boss: int = -1) -> void:
	if flow_state != FlowState.TITLE:
		Log.warn(&"flow", "start_practice_from_title ignored outside TITLE")
		return
	var saved: int = SaveService.highest_boss if highest_boss < 0 else highest_boss
	practice_run = true
	practice_loadouts_offered = practice_loadout_bosses(saved)
	practice_loadout_index = practice_start_index(saved)
	first_input_frame = -1
	intro_start_frame = -1
	run = RunState.new()
	stats = RunStats.new()
	_apply_practice_loadout()
	Log.info(&"flow", "title -> practice at f=%d" % frame)
	_set_flow_state(FlowState.FIGHT)


## Pure (Story 7.6, AC 9, 10, D-S76-3): the boss indices whose GDD fight-start set
## (Register.fight_start_for_boss) the practice chooser offers, in order: every boss reached
## (0 .. highest_boss - 1), then the full set (LAST_BOSS_INDEX: [A, D, L, N]) when not already there.
static func practice_loadout_bosses(highest_boss: int) -> Array[int]:
	var reached: int = clampi(highest_boss, 1, LAST_BOSS_INDEX + 1)
	var out: Array[int] = []
	for i: int in reached:
		out.append(i)
	if not out.has(LAST_BOSS_INDEX):
		out.append(LAST_BOSS_INDEX)
	return out


## Pure (Story 7.6, AC 10): the offered loadouts as register rings, same order.
static func practice_loadouts(highest_boss: int) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	for i: int in practice_loadout_bosses(highest_boss):
		out.append(Register.fight_start_for_boss(i))
	return out


## Pure (Story 7.6, AC 9): the chooser index of the highest loadout reached (never the appended full set
## on a save that has not reached it).
static func practice_start_index(highest_boss: int) -> int:
	return clampi(highest_boss, 1, LAST_BOSS_INDEX + 1) - 1


## The current practice loadout as the run's boss index (Breakpoint / Watch unlocks follow it, AC 7)
## and its fight-start ring (the retry snapshot).
func _apply_practice_loadout() -> void:
	var boss: int = practice_loadouts_offered[practice_loadout_index] if not practice_loadouts_offered.is_empty() else 0
	run.start_boss(boss)
	run.fight_start_ring = Register.fight_start_for_boss(boss)


## Story 7.6 (AC 11, D-S76-4): the next offered loadout, as a retry of the dummy fight (dummy reset,
## HP and cooldowns reset, new ring). Only in a practice FIGHT that is not paused. True if it moved.
func cycle_practice_loadout(frame: int) -> bool:
	if not practice_run or flow_state != FlowState.FIGHT or SimClock.paused or practice_loadouts_offered.is_empty():
		return false
	practice_loadout_index = (practice_loadout_index + 1) % practice_loadouts_offered.size()
	_apply_practice_loadout()
	Log.info(&"flow", "practice loadout %s at f=%d" % [Register.to_text(run.fight_start_ring), frame])
	_retrying = true # the ring is set above; never re-captured
	_set_flow_state(FlowState.FIGHT)
	_retrying = false
	if not SimClock.paused:
		SimClock.swallow_presses_next_poll()
	return true


## Story 7.6 (AC 13-15): practice FIGHT -> TITLE. Resets the run, the stats and the practice state;
## never writes SaveService and never goes through the Intro, Harvest or Ending. True if it moved.
func leave_practice_to_title(frame: int) -> bool:
	if not practice_run or flow_state != FlowState.FIGHT:
		return false
	Log.info(&"flow", "practice -> title at f=%d" % frame)
	_clear_practice()
	run = RunState.new()
	stats = RunStats.new()
	first_input_frame = -1
	intro_start_frame = -1
	_set_flow_state(FlowState.TITLE)
	return true


func _clear_practice() -> void:
	practice_run = false
	practice_loadouts_offered = []
	practice_loadout_index = 0
	practice_start_frame = -1


## The title input never counts as an Intro skip (D-040, D-048).
func can_skip_intro(frame: int) -> bool:
	return first_input_frame >= 0 and frame > first_input_frame


func intro_timed_out(frame: int) -> bool:
	return intro_start_frame >= 0 and frame - intro_start_frame >= INTRO_MAX_FRAMES


## INTRO -> FIGHT 1 on a skip input (`skip_requested`, accepted only when can_skip_intro) or when
## the 480-frame cap is reached. The Intro screen calls it every physics frame without a skip and
## once per input with one, so it never logs when nothing happens. True if it moved.
func finish_intro(frame: int, skip_requested: bool = false) -> bool:
	if SimClock.paused: # DC4: nothing moves while paused
		return false
	if flow_state != FlowState.INTRO:
		return false
	if not ((skip_requested and can_skip_intro(frame)) or intro_timed_out(frame)):
		return false
	run.start_boss(0)
	Log.info(&"flow", "intro -> fight 1 at f=%d" % frame)
	_set_flow_state(FlowState.FIGHT)
	return true


## Placeholder advance gesture (Story 1.6): the next state in the run sequence. In INTRO it is a
## gated skip (Story 6.7), never an unconditional start; in ENDING a gated leave (Story 6.8).
func advance() -> void:
	if SimClock.paused: # DC4: a key press during pause never skips the fight
		return
	match flow_state:
		FlowState.TITLE:
			pass # the title's own input starts the run (start_run_from_title)
		FlowState.INTRO:
			# Story 6.7 (AC 7): the same skip gate as the Intro screen, so no caller skips the
			# Intro on the title input frame.
			if can_skip_intro(SimClock.sim_frame):
				finish_intro(SimClock.sim_frame, true)
		FlowState.FIGHT:
			_set_flow_state(route_after_defeat(run.boss_index, segfault_enabled)) # Story 5.6 (D-S56-3)
		FlowState.HARVEST:
			run.start_boss(run.boss_index + 1)
			_set_flow_state(FlowState.FIGHT)
		FlowState.ENDING:
			# Story 6.8 (AC 7): the same leave gate as the Ending screen; no unconditional reset.
			if can_leave_ending(SimClock.sim_frame):
				finish_ending(SimClock.sim_frame, true)
		FlowState.DEAD:
			Log.warn(&"flow", "advance ignored in DEAD")


## Pure (Story 6.8, AC 6, D-S68-7): true once a press may leave an ending entered at `start_frame`.
static func ending_leave_open_at(start_frame: int, frame: int) -> bool:
	return start_frame >= 0 and frame > start_frame + ENDING_LEAVE_GATE_FRAMES


## Story 6.8 (AC 6): true in ENDING once the leave gate has passed.
func can_leave_ending(frame: int) -> bool:
	return flow_state == FlowState.ENDING and ending_leave_open_at(ending_start_frame, frame)


## Story 6.8 (AC 6, 7, 8): ENDING -> TITLE on a leave press (`skip_requested`, accepted only when
## can_leave_ending). The ending never times out (D-S68-1). Refused (false, no log) while paused
## (DC4), outside ENDING or before the gate. The only place the ENDING -> TITLE run reset runs.
func finish_ending(frame: int, skip_requested: bool = false) -> bool:
	if SimClock.paused or flow_state != FlowState.ENDING:
		return false
	if not (skip_requested and can_leave_ending(frame)):
		return false
	Log.info(&"flow", "ending -> title at f=%d" % frame)
	run = RunState.new()
	stats = RunStats.new()
	ending_summary = {}
	first_input_frame = -1
	intro_start_frame = -1
	_set_flow_state(FlowState.TITLE)
	return true


## Pure (Story 5.6, D-S56-3): the index of the run's last fight. With the Segfault cut (cut ladder #4,
## `segfault_on` false) the Null Pointer (index 1) is the last fight.
static func last_fight_index(segfault_on: bool) -> int:
	return LAST_BOSS_INDEX if segfault_on else LAST_BOSS_INDEX - 1


## Pure (Story 3.8, D-S38-2; Story 5.6, D-S56-3): where a finished defeat of boss `index` goes. A boss
## before the last fight drops a bit (HARVEST); the last fight drops nothing and goes straight to
## ENDING (GDD D-012), which is the Null Pointer when the Segfault is cut (GDD cut ladder #4).
static func route_after_defeat(index: int, segfault_on: bool) -> FlowState:
	return FlowState.ENDING if index >= last_fight_index(segfault_on) else FlowState.HARVEST


## Pure (Story 5.6, D-S56-3): true when the defeat of boss `index` drops its bit (a HARVEST follows).
## False for the last fight, so NULL is never dropped when the Segfault is cut.
static func drops_bit(index: int, segfault_on: bool) -> bool:
	return index >= 0 and route_after_defeat(index, segfault_on) == FlowState.HARVEST


## Story 3.8 (B1, AC 5, AC 6, D-S38-11): FIGHT -> HARVEST / ENDING once `boss` (the arena's boss) has
## finished its defeat animation. Called by presentation after the tick (Main), never from inside
## SimClock.tick(). Refused (false, no log: it is polled) outside FIGHT, while paused, or before
## the animation ends. True if it moved.
func finish_defeat(boss: BossController) -> bool:
	if SimClock.paused or flow_state != FlowState.FIGHT:
		return false
	if boss == null or not boss.defeat_finished():
		return false
	var to: FlowState = route_after_defeat(run.boss_index, segfault_enabled)
	Log.info(&"flow", "boss %d defeated -> %s" % [run.boss_index, FlowState.keys()[to]])
	_set_flow_state(to)
	return true


## Pure (Story 3.8, D-S38-10): true once HARVEST has run for HARVEST_MAX_FRAMES sim frames.
static func harvest_timed_out_at(start_frame: int, frame: int) -> bool:
	return start_frame >= 0 and frame - start_frame >= HARVEST_MAX_FRAMES


## Pure (Story 3.8, D-S38-10): true once a press may end HARVEST early.
static func harvest_skip_open_at(start_frame: int, frame: int) -> bool:
	return start_frame >= 0 and frame - start_frame >= HARVEST_SKIP_FRAMES


func harvest_timed_out(frame: int) -> bool:
	return flow_state == FlowState.HARVEST and harvest_timed_out_at(harvest_start_frame, frame)


func harvest_skip_open(frame: int) -> bool:
	return flow_state == FlowState.HARVEST and harvest_skip_open_at(harvest_start_frame, frame)


## Story 3.8 (B2, AC 3): HARVEST -> FIGHT boss_index + 1. The screen checks the skip gate or the cap
## before calling; this only checks the state. The next fight captures its fight-start snapshot
## (Register.fight_start_for_boss, D-S38-5) and resets HP and cooldowns (D-049 b). True if it moved.
func finish_harvest(frame: int) -> bool:
	if flow_state != FlowState.HARVEST:
		return false
	Log.info(&"flow", "harvest -> fight %d at f=%d" % [run.boss_index + 2, frame])
	run.start_boss(run.boss_index + 1)
	_set_flow_state(FlowState.FIGHT)
	if not SimClock.paused: # the press that skipped HARVEST must not fire in the new fight (D-S29-12)
		SimClock.swallow_presses_next_poll()
	return true


## Story 3.8 (B5, AC 4, D-S38-7): F8 grants the current boss's drop bit without the fight: the same
## route as a finished defeat, without the animation. Debug only. Needs FIGHT, a boss whose drop_bit
## has a BitDef and a bit the run does not own yet; otherwise Log.warn and false.
func debug_grant_bit(boss: BossController) -> bool:
	if not Debug.enabled:
		return false
	if flow_state != FlowState.FIGHT or SimClock.paused:
		Log.warn(&"debug", "F8 ignored outside a running FIGHT")
		return false
	if boss == null or boss.def == null:
		Log.warn(&"debug", "F8 ignored: no boss in this fight")
		return false
	if not drops_bit(run.boss_index, segfault_enabled): # Story 5.6 (D-S56-4): the cut path drops nothing
		Log.warn(&"debug", "F8 ignored: %s drops no bit (Segfault cut, cut ladder #4)" % boss.def.boss_id)
		return false
	var bit: int = boss.def.drop_bit
	if Defs.bit(bit) == null:
		Log.warn(&"debug", "F8 ignored: %s drops no bit with a BitDef" % boss.def.boss_id)
		return false
	if run.fight_start_ring.has(bit):
		Log.warn(&"debug", "F8 ignored: bit %s already owned" % Register.glyph_of(bit))
		return false
	var to: FlowState = route_after_defeat(run.boss_index, segfault_enabled)
	stats.debug_jumped = true # Story 6.8 (D-S68-5): a debug-granted bit makes the run not a clear
	Log.info(&"debug", "F8 grant %s -> %s" % [Register.glyph_of(bit), FlowState.keys()[to]])
	_set_flow_state(to)
	return true


## Debug jump (F1-F5, DC6): TITLE, FIGHT boss 0-2 or ENDING, only while Debug.enabled.
func debug_jump(target: FlowState, boss_index: int) -> void:
	if not Debug.enabled:
		return
	var valid: bool = target == FlowState.TITLE or target == FlowState.ENDING \
			or (target == FlowState.FIGHT and boss_index >= 0 and boss_index <= last_fight_index(segfault_enabled))
	if not valid:
		Log.warn(&"debug", "jump rejected: %s boss=%d" % [FlowState.keys()[target], boss_index])
		return
	_clear_practice() # Story 7.6: a debug jump leaves the title's practice (the save rules apply again)
	if target == FlowState.TITLE:
		run = RunState.new()
		stats = RunStats.new() # Story 6.8: the next run starts clean
		first_input_frame = -1
		intro_start_frame = -1
	else:
		stats.debug_jumped = true # Story 6.8 (AC 16, D-S68-5): a debug-jumped run is not a clear
		if target == FlowState.FIGHT:
			run.start_boss(boss_index) # D-S29-14: a debug jump into a fight is a new boss
		else:
			run.boss_index = boss_index
		intro_start_frame = -1
		if first_input_frame < 0:
			first_input_frame = SimClock.sim_frame # a debug-entered run still starts the clock
	Log.info(&"debug", "jump -> %s boss=%d" % [FlowState.keys()[target], boss_index])
	_set_flow_state(target)


func _set_flow_state(to: FlowState) -> void:
	var from: FlowState = flow_state
	flow_state = to
	Log.info(&"flow", "%s -> %s" % [FlowState.keys()[from], FlowState.keys()[to]])
	if SimClock.paused: # DC5: a flow change never leaves the game paused
		SimClock.paused = false
		_paused_at_msec = -1
		Log.info(&"flow", "pause off")
		EventBus.pause_toggled.emit(false)
	if to != FlowState.DEAD:
		death_frame = -1
	harvest_start_frame = SimClock.sim_frame if to == FlowState.HARVEST else -1
	# Story 6.8 (AC 1, 15): the Ending's timeline origin and the stats snapshot, taken on entry.
	ending_start_frame = SimClock.sim_frame if to == FlowState.ENDING else -1
	ending_summary = stats.snapshot(SimClock.sim_frame) if to == FlowState.ENDING else {}
	if to == FlowState.FIGHT and stats.fight_start_frame < 0:
		stats.fight_start_frame = SimClock.sim_frame # Story 6.8 (D-S68-4): Fight 1 starts the clear time
	if to == FlowState.FIGHT:
		# D-S29-4: every FIGHT entry but a retry captures the snapshot. Story 7.6: practice sets its
		# ring from the chosen loadout (_apply_practice_loadout), never from the boss index.
		if not _retrying and not practice_run:
			run.fight_start_ring = Register.fight_start_for_boss(run.boss_index)
		if practice_run:
			practice_start_frame = SimClock.sim_frame # Story 7.6 (D-S76-2): the frame counter origin
		_begin_fight()
		# Story 7.3 (AC 2, 12, D-S73-3): presentation-side write after the state change; never on a
		# retry (nothing changed), in a debug-jumped run or (Story 7.6, AC 6) in practice.
		if not _retrying and not stats.debug_jumped and not practice_run:
			SaveService.note_fight_start(run.boss_index)
	EventBus.flow_state_changed.emit(from, to)
	if _focus_lost and to in PAUSABLE_STATES:
		set_paused(true, &"focus")


## Story 2.9 (D-S29-2): PlayerHealth reports every landed hit; the lethal one (hp 0) is a death.
## Story 6.8 (AC 14, D-S68-4): every landed hit in FIGHT counts for the run, the lethal one included.
func on_player_damaged(hp: int) -> void:
	if flow_state == FlowState.FIGHT:
		stats.hits += 1
	if hp <= 0:
		record_death(SimClock.sim_frame)


## The player died in FIGHT (AC 3): count it on this boss, enter DEAD, tell the listeners.
## Ignored outside FIGHT. True when the death was recorded.
func record_death(frame: int) -> bool:
	if flow_state != FlowState.FIGHT:
		return false
	run.deaths_on_boss += 1
	Log.info(&"flow", "player died at f=%d (deaths on boss %d)" % [frame, run.deaths_on_boss])
	death_frame = frame # before the state change: listeners of flow_state_changed read it
	_set_flow_state(FlowState.DEAD)
	EventBus.player_died.emit(boss_id(run.boss_index), run.deaths_on_boss)
	return true


## Pure: true once the DEAD screen accepts a retry press (D-049 c, D-S29-3).
static func retry_open(p_death_frame: int, frame: int) -> bool:
	return p_death_frame >= 0 and frame - p_death_frame >= RETRY_DELAY_FRAMES


## DEAD -> FIGHT from the fight-start snapshot (AC 4-6). Refused outside DEAD and before the gate.
## The press that retried never fires an action in the new fight (D-S29-12). True if it moved.
func retry(frame: int) -> bool:
	if flow_state != FlowState.DEAD or not retry_open(death_frame, frame):
		return false
	Log.info(&"flow", "retry at f=%d" % frame)
	_retrying = true
	_set_flow_state(FlowState.FIGHT)
	_retrying = false
	if not SimClock.paused: # a paused tick never polls, so the flag would go stale
		SimClock.swallow_presses_next_poll()
	return true


## Pure: the boss id for a boss index (&"" outside 0..2).
static func boss_id(index: int) -> StringName:
	return BOSS_IDS[index] if index >= 0 and index < BOSS_IDS.size() else &""


## Every route into FIGHT (intro, harvest, retry, debug jump) seeds the fight here (D-S21-6).
## Story 3.4 (D-S34-2): the run's seed comes from the monotonic engine clock (Time.get_ticks_usec) once, on the run's first FIGHT
## entry (presentation side; simulation never reads it); each entry then takes
## fight_seed_for(run_seed, fight_attempt), so retries differ and a recording's seed reproduces.
func _begin_fight() -> void:
	if run.run_seed == 0:
		run.run_seed = maxi(Time.get_ticks_usec(), 1)
	run.fight_attempt += 1
	run.fight_seed = RunState.fight_seed_for(run.run_seed, run.fight_attempt)
	run.assist = SaveService.assist # Story 7.4 (AC 12, D-S74-1): the attempt's copy, presentation side
	SimClock.begin_fight(run.fight_seed)
	Log.info(&"flow", "fight seed %d" % run.fight_seed)


## Web fallback for DC9: document `visibilitychange` (tab hidden) and window `blur` pause the game.
## The engine's WM_WINDOW_FOCUS_OUT comes from canvas blur only, which a page that never focused
## the canvas does not get; these listeners cover that case. Web builds only.
func _listen_web_focus() -> void:
	if _web_focus_cb != null: # never register twice
		return
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	var document: JavaScriptObject = JavaScriptBridge.get_interface("document")
	if window == null or document == null:
		Log.warn(&"flow", "web focus listeners not installed")
		return
	_web_focus_cb = JavaScriptBridge.create_callback(_on_web_focus_event)
	document.addEventListener("visibilitychange", _web_focus_cb)
	window.addEventListener("blur", _web_focus_cb)
	window.addEventListener("focus", _web_focus_cb)


func _unlisten_web_focus() -> void:
	if _web_focus_cb == null:
		return
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	var document: JavaScriptObject = JavaScriptBridge.get_interface("document")
	if window != null and document != null:
		document.removeEventListener("visibilitychange", _web_focus_cb)
		window.removeEventListener("blur", _web_focus_cb)
		window.removeEventListener("focus", _web_focus_cb)
	_web_focus_cb = null


func _on_web_focus_event(args: Array) -> void:
	var js_event := args[0] as JavaScriptObject if not args.is_empty() else null
	if js_event == null:
		return
	var document: JavaScriptObject = JavaScriptBridge.get_interface("document")
	var hidden: bool = document != null and bool(document.hidden)
	if is_web_focus_loss(str(js_event.type), hidden):
		on_focus_lost()
	elif not hidden:
		_focus_lost = false # `focus`, or the tab became visible again


## Pure: a `blur`, or a `visibilitychange` to hidden, is a focus loss; becoming visible is not.
static func is_web_focus_loss(event_type: String, document_hidden: bool) -> bool:
	return event_type == "blur" or (event_type == "visibilitychange" and document_hidden)
