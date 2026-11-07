extends Node
## Game flow state machine (AD-08). Only Game changes flow_state, through _set_flow_state.
## Presentation calls start_run_from_title, finish_intro, advance (and debug_jump in debug).

enum FlowState { TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING }

## Intro cap (D-040): 8 s at 60 Hz, counted in sim frames so it stops with pause (DC5).
const INTRO_MAX_FRAMES := 480
const LAST_BOSS_INDEX := 2

var flow_state: FlowState = FlowState.TITLE
## Sim frame of the first title input: start of the 30-s first-shift clock. -1 before it.
var first_input_frame: int = -1
## Sim frame on which INTRO was entered; -1 outside a run.
var intro_start_frame: int = -1
var run: RunState = RunState.new()


## Title press-to-start (FR47). Valid only from TITLE.
func start_run_from_title(frame: int) -> void:
	if flow_state != FlowState.TITLE:
		Log.warn(&"flow", "start_run_from_title ignored outside TITLE")
		return
	first_input_frame = frame
	intro_start_frame = frame
	run = RunState.new()
	Log.info(&"flow", "title -> intro at f=%d" % frame)
	_set_flow_state(FlowState.INTRO)


## The title input never counts as an Intro skip (D-040, D-048).
func can_skip_intro(frame: int) -> bool:
	return first_input_frame >= 0 and frame > first_input_frame


func intro_timed_out(frame: int) -> bool:
	return intro_start_frame >= 0 and frame - intro_start_frame >= INTRO_MAX_FRAMES


## INTRO -> FIGHT 1 on a skip input (`skip_requested`, accepted only when can_skip_intro) or when
## the 480-frame cap is reached. The Intro screen calls it every physics frame without a skip and
## once per input with one, so it never logs when nothing happens. True if it moved.
func finish_intro(frame: int, skip_requested: bool = false) -> bool:
	if flow_state != FlowState.INTRO:
		return false
	if not ((skip_requested and can_skip_intro(frame)) or intro_timed_out(frame)):
		return false
	run.boss_index = 0
	Log.info(&"flow", "intro -> fight 1 at f=%d" % frame)
	_set_flow_state(FlowState.FIGHT)
	return true


## Placeholder advance gesture (Story 1.6): the next state in the run sequence.
func advance() -> void:
	match flow_state:
		FlowState.TITLE:
			pass # the title's own input starts the run (start_run_from_title)
		FlowState.INTRO:
			run.boss_index = 0
			_set_flow_state(FlowState.FIGHT)
		FlowState.FIGHT:
			_set_flow_state(FlowState.ENDING if run.boss_index >= LAST_BOSS_INDEX else FlowState.HARVEST)
		FlowState.HARVEST:
			run.boss_index += 1
			_set_flow_state(FlowState.FIGHT)
		FlowState.ENDING:
			run = RunState.new()
			first_input_frame = -1
			intro_start_frame = -1
			_set_flow_state(FlowState.TITLE)
		FlowState.DEAD:
			Log.warn(&"flow", "advance ignored in DEAD")


## Debug jump (F1-F5, DC6): TITLE, FIGHT boss 0-2 or ENDING, only while Debug.enabled.
func debug_jump(target: FlowState, boss_index: int) -> void:
	if not Debug.enabled:
		return
	var valid: bool = target == FlowState.TITLE or target == FlowState.ENDING \
			or (target == FlowState.FIGHT and boss_index >= 0 and boss_index <= LAST_BOSS_INDEX)
	if not valid:
		Log.warn(&"debug", "jump rejected: %s boss=%d" % [FlowState.keys()[target], boss_index])
		return
	if target == FlowState.TITLE:
		run = RunState.new()
		first_input_frame = -1
		intro_start_frame = -1
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
	EventBus.flow_state_changed.emit(from, to)
