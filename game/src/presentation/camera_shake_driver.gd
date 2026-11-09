class_name CameraShakeDriver
extends Node
## Owns the arena Camera2D and plays the combo-hit shake on its offset (Story 2.8 AC4, AD-07).
## Presentation only (AD-05): it listens to EventBus.hit_landed and starts the shake when
## `is_combo` is true; solo hits do not shake. Story 2.9: EventBus.player_damaged starts the
## player-hit schedule (3 px, 4 frames). It counts engine physics frames, not SimClock, so
## the shake plays during the hit-stop it accompanies (D-S28-5). The camera is anchored top-left at
## the canvas origin, so offset zero is exactly the framing without a camera. HUD, Pause and
## ScreenFX are CanvasLayers and do not move. Main adds `camera` under the Arena (arena/ may not
## reference presentation/).

var camera: Camera2D = Camera2D.new()

## Physics frame the current shake started on; NO_START when idle.
var _start: int = ShiftJuice.NO_START
## Schedule of the current shake (amplitude in px, length in frames).
var _px: int = CameraShake.SHAKE_PX
var _frames: int = CameraShake.SHAKE_FRAMES


func _init() -> void:
	camera.name = &"ArenaCamera"
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.position_smoothing_enabled = false
	set_process(false)


func _notification(what: int) -> void:
	# A camera never handed to the arena (tests) is freed with its driver.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(camera) and not camera.is_inside_tree() and camera.get_parent() == null:
		camera.free()


func _enter_tree() -> void:
	if not EventBus.hit_landed.is_connected(_on_hit_landed):
		EventBus.hit_landed.connect(_on_hit_landed)
	if not EventBus.player_damaged.is_connected(_on_player_damaged):
		EventBus.player_damaged.connect(_on_player_damaged)


func _exit_tree() -> void:
	if EventBus.hit_landed.is_connected(_on_hit_landed):
		EventBus.hit_landed.disconnect(_on_hit_landed)
	if EventBus.player_damaged.is_connected(_on_player_damaged):
		EventBus.player_damaged.disconnect(_on_player_damaged)


func _process(_delta: float) -> void:
	apply(now())


## Presentation frame: the engine's 60 Hz physics counter (D-S24-1, D-S28-5).
func now() -> int:
	return Engine.get_physics_frames()


## Starts (or restarts) a shake at frame `at`: the combo schedule by default (2 px, 6 frames).
func start(at: int, px: int = CameraShake.SHAKE_PX, frames: int = CameraShake.SHAKE_FRAMES) -> void:
	_start = at
	_px = px
	_frames = frames
	set_process(true)
	apply(at)


## Frames of shake still to show at frame `t` (the schedule length on the start frame, 0 when idle).
func frames_left(t: int) -> int:
	if _start == ShiftJuice.NO_START:
		return 0
	return maxi(_frames - (t - _start), 0)


## Writes the camera offset for frame `t`; stops processing when the shake is over.
func apply(t: int) -> void:
	var left: int = frames_left(t)
	camera.offset = CameraShake.offset_for(left, _px, _frames)
	if left == 0:
		_start = ShiftJuice.NO_START
		set_process(false)


func reset() -> void:
	_start = ShiftJuice.NO_START
	camera.offset = Vector2.ZERO
	set_process(false)


func _on_hit_landed(_target: StringName, _damage: int, _state: int, is_combo: bool, _pos: Vector2) -> void:
	if is_combo:
		start(now())


func _on_player_damaged(_hp: int) -> void:
	start(now(), CameraShake.PLAYER_HIT_PX, CameraShake.PLAYER_HIT_FRAMES)
