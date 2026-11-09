class_name CameraShakeDriver
extends Node
## Owns the arena Camera2D and plays the combo-hit shake on its offset (Story 2.8 AC4, AD-07).
## Presentation only (AD-05): it listens to EventBus.hit_landed and starts the shake when
## `is_combo` is true; solo hits do not shake. It counts engine physics frames, not SimClock, so
## the shake plays during the hit-stop it accompanies (D-S28-5). The camera is anchored top-left at
## the canvas origin, so offset zero is exactly the framing without a camera. HUD, Pause and
## ScreenFX are CanvasLayers and do not move. Main adds `camera` under the Arena (arena/ may not
## reference presentation/).

var camera: Camera2D = Camera2D.new()

## Physics frame the current shake started on; NO_START when idle.
var _start: int = ShiftJuice.NO_START


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


func _exit_tree() -> void:
	if EventBus.hit_landed.is_connected(_on_hit_landed):
		EventBus.hit_landed.disconnect(_on_hit_landed)


func _process(_delta: float) -> void:
	apply(now())


## Presentation frame: the engine's 60 Hz physics counter (D-S24-1, D-S28-5).
func now() -> int:
	return Engine.get_physics_frames()


## Starts (or restarts) the 6-frame shake at frame `at`.
func start(at: int) -> void:
	_start = at
	set_process(true)
	apply(at)


## Frames of shake still to show at frame `t` (SHAKE_FRAMES on the start frame, 0 when idle).
func frames_left(t: int) -> int:
	if _start == ShiftJuice.NO_START:
		return 0
	return maxi(CameraShake.SHAKE_FRAMES - (t - _start), 0)


## Writes the camera offset for frame `t`; stops processing when the shake is over.
func apply(t: int) -> void:
	var left: int = frames_left(t)
	camera.offset = CameraShake.offset_for(left)
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
