class_name JuiceDirector
extends Node
## Presentation listener for shift juice (Story 2.4, FR28; architecture "JuiceDirector", hit
## feedback joins in 2.8). On EventBus.register_shifted it starts the register slide, inverts the
## player glyph and plays the key click. Presentation only (AD-05): it reads the signal arguments
## and writes only the injected presentation nodes. It runs on the engine physics counter, never on
## the simulation clock, so hit-stop and Breakpoint do not freeze it (D-S24-1).
## Story 2.8: the only writer of the ScreenFX uniforms (AD-07): request_invert (full-screen
## inversion for N physics frames) and set_dither. Gameplay in 2.8 requests neither (crit inversion
## is Epic 3, Breakpoint dither Epic 4). Presentation never requests hit-stop (D-S28-12).
## Story 3.2 (AC 4, D-S32-18): a Patched (crit) hit inverts the screen for 1 frame.
## Story 4.3 (AC 9, D-S43-14): breakpoint_started dithers the screen at BREAKPOINT_DITHER,
## breakpoint_ended clears it.

const CLICK_LEFT: AudioStream = preload(ShiftJuice.CLICK_LEFT)
const CLICK_RIGHT: AudioStream = preload(ShiftJuice.CLICK_RIGHT)
## Full-screen inversion frames of a crit (FR27, D-S32-18).
const CRIT_INVERT_FRAMES := 1
## Screen dither while Breakpoint runs (GDD "50% ink", D-S43-14).
const BREAKPOINT_DITHER := 0.5

## Injected by Main. Either may be null (nothing is applied to a missing node).
var register_panel: RegisterPanel
var player_view: PlayerView
## Injected by Main (Story 2.8). Null = invert and dither requests are kept but not shown.
var screen_fx: ScreenFX
var juice: ShiftJuice = ShiftJuice.new()

## True while a slide or inversion still has frames to show; _process does nothing otherwise.
var _live: bool = false
## Physics frame the full-screen inversion ends on (exclusive); NO_START when none.
var _invert_until: int = ShiftJuice.NO_START
## Current dither level 0..1.
var _dither: float = 0.0


func _enter_tree() -> void:
	if not EventBus.register_shifted.is_connected(_on_register_shifted):
		EventBus.register_shifted.connect(_on_register_shifted)
	if not EventBus.hit_landed.is_connected(_on_hit_landed):
		EventBus.hit_landed.connect(_on_hit_landed)
	if not EventBus.breakpoint_started.is_connected(_on_breakpoint_started):
		EventBus.breakpoint_started.connect(_on_breakpoint_started)
	if not EventBus.breakpoint_ended.is_connected(_on_breakpoint_ended):
		EventBus.breakpoint_ended.connect(_on_breakpoint_ended)


func _exit_tree() -> void:
	if EventBus.register_shifted.is_connected(_on_register_shifted):
		EventBus.register_shifted.disconnect(_on_register_shifted)
	if EventBus.hit_landed.is_connected(_on_hit_landed):
		EventBus.hit_landed.disconnect(_on_hit_landed)
	if EventBus.breakpoint_started.is_connected(_on_breakpoint_started):
		EventBus.breakpoint_started.disconnect(_on_breakpoint_started)
	if EventBus.breakpoint_ended.is_connected(_on_breakpoint_ended):
		EventBus.breakpoint_ended.disconnect(_on_breakpoint_ended)


func _process(_delta: float) -> void:
	if not _live:
		return
	_apply()
	var t: int = now()
	_live = juice.is_live(t) or is_screen_inverted(t)


## Presentation frame: the engine's 60 Hz physics counter (D-S24-1).
func now() -> int:
	return Engine.get_physics_frames()


func reset() -> void:
	juice.reset()
	_invert_until = ShiftJuice.NO_START
	_dither = 0.0
	_live = false
	_apply()


## Inverts the full screen for `frames` physics frames from now (Story 2.8 AC5; crit is Epic 3).
## A new request restarts the count.
func request_invert(frames: int = 1) -> void:
	if frames <= 0:
		return
	_invert_until = now() + frames
	_live = true
	_apply()


## Sets the full-screen dither level, clamped to 0..1 (Story 2.8 AC5; Breakpoint is Epic 4).
func set_dither(level: float) -> void:
	_dither = clampf(level, 0.0, 1.0)
	_apply()


func dither_level() -> float:
	return _dither


## True while a requested full-screen inversion covers frame `t`.
func is_screen_inverted(t: int) -> bool:
	return _invert_until != ShiftJuice.NO_START and t < _invert_until


func _on_register_shifted(direction: int, _window: Vector2i, _ring: PackedInt32Array, _source: StringName) -> void:
	juice.on_shift(direction, now())
	_live = true
	AudioManager.play_sfx(click_stream(direction))
	Log.debug(&"juice", "shift %d" % direction)
	_apply()


## Story 3.2 (AC 4): a Patched hit inverts the full screen for CRIT_INVERT_FRAMES.
func _on_hit_landed(_target: StringName, _damage: int, state: int, _is_combo: bool, _pos: Vector2) -> void:
	if state == DamageState.Kind.PATCHED:
		request_invert(CRIT_INVERT_FRAMES)


func _on_breakpoint_started() -> void:
	set_dither(BREAKPOINT_DITHER)


func _on_breakpoint_ended() -> void:
	set_dither(0.0)


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
	if is_instance_valid(screen_fx):
		screen_fx.set_invert(is_screen_inverted(t))
		screen_fx.set_dither(_dither)
