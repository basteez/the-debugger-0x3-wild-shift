class_name Fullscreen
extends RefCounted
## Story 7.7 (FR55, AC 1-7): the fullscreen toggle shared by the title and the pause screen.
## Presentation only. `toggle` must be called from inside an input-event handler: the browser only
## grants fullscreen to a user gesture (project-context rule). It never touches SimClock, the save or
## the flow state.
## A refused request (the browser said no, or the window mode did not change) is silent for the
## player: the game stays windowed and one `Log.warn(&"display", ...)` is written per session (AC 5).
## The web request is asynchronous (document.fullscreenElement is set after the call returns), so
## the result is read REFUSAL_CHECK_SEC later on a SceneTreeTimer (UI side, never the sim).

const REFUSAL_CHECK_SEC := 0.75

## Seams for tests: the window mode reader and writer (DisplayServer by default).
static var get_mode_fn: Callable = func() -> DisplayServer.WindowMode: return DisplayServer.window_get_mode()
static var set_mode_fn: Callable = func(mode: DisplayServer.WindowMode) -> void: DisplayServer.window_set_mode(mode)
## True once the refusal warning was written (one per session).
static var warned: bool = false
## Id of the latest toggle: a pending refusal check of an older toggle is dropped (double press, Esc).
static var request_id: int = 0


## Pure: true for the fullscreen modes (exclusive included).
static func is_fullscreen(mode: DisplayServer.WindowMode) -> bool:
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## Pure: the mode a toggle asks for from `current` (fullscreen -> windowed, anything else -> fullscreen).
static func toggle_mode(current: DisplayServer.WindowMode) -> DisplayServer.WindowMode:
	return DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen(current) else DisplayServer.WINDOW_MODE_FULLSCREEN


## True while the window is fullscreen (the labels follow it, so a browser Esc exit shows too).
static func is_on() -> bool:
	return is_fullscreen(get_mode_fn.call())


## Pure: true when a request for `wanted` was not honoured (the mode read back differs in kind).
static func is_refused(wanted: DisplayServer.WindowMode, actual: DisplayServer.WindowMode) -> bool:
	return is_fullscreen(wanted) != is_fullscreen(actual)


## Flips the window mode. Call ONLY from an input-event handler. Returns the requested mode.
## A refusal is checked after REFUSAL_CHECK_SEC (when a SceneTree runs) and warned once.
static func toggle() -> DisplayServer.WindowMode:
	var wanted: DisplayServer.WindowMode = toggle_mode(get_mode_fn.call())
	set_mode_fn.call(wanted)
	request_id += 1
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.create_timer(REFUSAL_CHECK_SEC).timeout.connect(_check_if_latest.bind(wanted, request_id))
	return wanted


static func _check_if_latest(wanted: DisplayServer.WindowMode, id: int) -> void:
	if id == request_id:
		check_request(wanted)


## Reads the mode back after a request for `wanted`; warns once per session on a refusal.
## True when the request was refused.
static func check_request(wanted: DisplayServer.WindowMode) -> bool:
	if not is_refused(wanted, get_mode_fn.call()):
		return false
	if not warned:
		warned = true
		Log.warn(&"display", "fullscreen request refused or ignored; staying windowed")
	return true
