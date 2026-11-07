extends Node
## Game flow state machine (AD-08). Only Game changes flow_state, through _set_flow_state.
## Presentation calls start_run_from_title, finish_intro, advance (and debug_jump in debug).
## Game is also the only writer of SimClock.paused (Story 1.7 DC2): Esc and focus loss.

enum FlowState { TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING }

## Intro cap (D-040): 8 s at 60 Hz, counted in sim frames so it stops with pause (DC5).
const INTRO_MAX_FRAMES := 480
const LAST_BOSS_INDEX := 2
## States where Esc and focus loss pause (Story 1.7 DC1): the 60 Hz clock drives the Intro cap and the fight.
const PAUSABLE_STATES: Array[FlowState] = [FlowState.INTRO, FlowState.FIGHT]

var flow_state: FlowState = FlowState.TITLE
## Sim frame of the first title input: start of the 30-s first-shift clock. -1 before it.
var first_input_frame: int = -1
## Sim frame on which INTRO was entered; -1 outside a run.
var intro_start_frame: int = -1
var run: RunState = RunState.new()
## Web only: the JS focus callback, kept alive for the session (a freed callback is never called).
var _web_focus_cb: JavaScriptObject = null


func _ready() -> void:
	if OS.has_feature("web"):
		_listen_web_focus()


func _input(event: InputEvent) -> void:
	if handle_pause_input(event):
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if is_focus_lost_notification(what):
		on_focus_lost()


## Pause on or off. The only writer of SimClock.paused outside tests (DC2). Refused outside
## PAUSABLE_STATES (false, no log). True when the call is accepted; it emits and logs only on change.
func set_paused(on: bool, reason: StringName) -> bool:
	if flow_state not in PAUSABLE_STATES:
		return false
	if SimClock.paused == on:
		return true
	SimClock.paused = on
	Log.info(&"flow", "pause on (%s)" % reason if on else "pause off")
	EventBus.pause_toggled.emit(on)
	return true


## Esc toggles the pause in a pausable state (DC2, DC3). True when the event was a fresh `pause`
## press that toggled it; the caller then consumes it. Esc elsewhere is left to the screens.
func handle_pause_input(event: InputEvent) -> bool:
	if not is_pause_press(event):
		return false
	return set_paused(not SimClock.paused, &"esc")


## Pure: a fresh, non-echo press of the `pause` action.
static func is_pause_press(event: InputEvent) -> bool:
	return InputMap.has_action(&"pause") and event.is_action_pressed(&"pause")


## Pure: the engine notifications that mean "the player looked away" (DC9). Desktop sends
## APPLICATION_FOCUS_OUT; the web build sends only WM_WINDOW_FOCUS_OUT (canvas blur).
static func is_focus_lost_notification(what: int) -> bool:
	return what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT


## Focus loss pauses; focus return never resumes (AC4, DC3). A no-op when already paused.
func on_focus_lost() -> void:
	set_paused(true, &"focus")


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
	if SimClock.paused: # DC4: nothing moves while paused
		return false
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
	if SimClock.paused: # DC4: a key press during pause never skips the fight
		return
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
	if SimClock.paused: # DC5: a flow change never leaves the game paused
		SimClock.paused = false
		Log.info(&"flow", "pause off")
		EventBus.pause_toggled.emit(false)
	EventBus.flow_state_changed.emit(from, to)


## Web fallback for DC9: document `visibilitychange` (tab hidden) and window `blur` pause the game.
## The engine's WM_WINDOW_FOCUS_OUT comes from canvas blur only, which a page that never focused
## the canvas does not get; these listeners cover that case. Web builds only.
func _listen_web_focus() -> void:
	_web_focus_cb = JavaScriptBridge.create_callback(_on_web_focus_event)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	var document: JavaScriptObject = JavaScriptBridge.get_interface("document")
	if window == null or document == null:
		Log.warn(&"flow", "web focus listeners not installed")
		return
	document.addEventListener("visibilitychange", _web_focus_cb)
	window.addEventListener("blur", _web_focus_cb)


func _on_web_focus_event(args: Array) -> void:
	var js_event := args[0] as JavaScriptObject if not args.is_empty() else null
	if js_event == null:
		return
	var document: JavaScriptObject = JavaScriptBridge.get_interface("document")
	var hidden: bool = document != null and bool(document.hidden)
	if is_web_focus_loss(str(js_event.type), hidden):
		on_focus_lost()


## Pure: a `blur`, or a `visibilitychange` to hidden, is a focus loss; becoming visible is not.
static func is_web_focus_loss(event_type: String, document_hidden: bool) -> bool:
	return event_type == "blur" or (event_type == "visibilitychange" and document_hidden)
