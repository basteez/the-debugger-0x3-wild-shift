class_name JuiceDirector
extends Node
## Presentation listener for shift juice (Story 2.4, FR28; architecture "JuiceDirector", hit
## feedback joins in 2.8). On EventBus.register_shifted it starts the register slide, inverts the
## player glyph and plays the key click. Presentation only (AD-05): it reads the signal arguments
## and writes only the injected presentation nodes. It runs on the engine physics counter, never on
## the simulation clock, so hit-stop and Breakpoint do not freeze it (D-S24-1).

const CLICK_LEFT: AudioStream = preload(ShiftJuice.CLICK_LEFT)
const CLICK_RIGHT: AudioStream = preload(ShiftJuice.CLICK_RIGHT)

## Injected by Main. Either may be null (nothing is applied to a missing node).
var register_panel: RegisterPanel
var player_view: PlayerView
var juice: ShiftJuice = ShiftJuice.new()

## True while a slide or inversion still has frames to show; _process does nothing otherwise.
var _live: bool = false


func _enter_tree() -> void:
	if not EventBus.register_shifted.is_connected(_on_register_shifted):
		EventBus.register_shifted.connect(_on_register_shifted)


func _exit_tree() -> void:
	if EventBus.register_shifted.is_connected(_on_register_shifted):
		EventBus.register_shifted.disconnect(_on_register_shifted)


func _process(_delta: float) -> void:
	if not _live:
		return
	_apply()
	_live = juice.is_live(now())


## Presentation frame: the engine's 60 Hz physics counter (D-S24-1).
func now() -> int:
	return Engine.get_physics_frames()


func reset() -> void:
	juice.reset()
	_live = false
	_apply()


func _on_register_shifted(direction: int, _window: Vector2i, _ring: PackedInt32Array, _source: StringName) -> void:
	juice.on_shift(direction, now())
	_live = true
	AudioManager.play_sfx(click_stream(direction))
	Log.debug(&"juice", "shift %d" % direction)
	_apply()


## The preloaded click for a direction, matching ShiftJuice.click_path (AC2). No load() per shift.
static func click_stream(direction: int) -> AudioStream:
	return CLICK_LEFT if ShiftJuice.click_path(direction) == ShiftJuice.CLICK_LEFT else CLICK_RIGHT


func _apply() -> void:
	var t: int = now()
	if is_instance_valid(register_panel):
		register_panel.slide_px = juice.slide_offset_px(t)
	if is_instance_valid(player_view):
		player_view.inverted = juice.is_inverted(t)
		player_view.queue_redraw()
