extends GutTest
## Story 2.8 AC4, D-S28-5: the combo-hit shake schedule and its driver.

var _driver: CameraShakeDriver


func before_each() -> void:
	_driver = CameraShakeDriver.new()
	add_child(_driver)


func after_each() -> void:
	_driver.queue_free()
	await get_tree().process_frame


func test_schedule_is_6_frames_of_alternating_2px_on_x() -> void:
	assert_eq(CameraShake.SHAKE_PX, 2)
	assert_eq(CameraShake.SHAKE_FRAMES, 6)
	var expected: Array[Vector2] = [Vector2(2, 0), Vector2(-2, 0), Vector2(2, 0), Vector2(-2, 0), Vector2(2, 0), Vector2(-2, 0)]
	var got: Array[Vector2] = []
	for left: int in range(6, 0, -1):
		got.append(CameraShake.offset_for(left))
	assert_eq(got, expected)
	for left: int in [0, -1, 7, 100]:
		assert_eq(CameraShake.offset_for(left), Vector2.ZERO, "zero outside 1..6 (%d)" % left)


func test_camera_is_top_left_anchored_with_zero_offset() -> void:
	assert_eq(_driver.camera.anchor_mode, Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT)
	assert_eq(_driver.camera.offset, Vector2.ZERO)
	assert_false(_driver.camera.position_smoothing_enabled)


func test_driver_frames_follow_the_schedule() -> void:
	_driver.start(100)
	assert_eq(_driver.frames_left(100), 6)
	assert_eq(_driver.camera.offset, Vector2(2, 0))
	_driver.apply(101)
	assert_eq(_driver.camera.offset, Vector2(-2, 0))
	_driver.apply(105)
	assert_eq(_driver.camera.offset, Vector2(-2, 0))
	_driver.apply(106)
	assert_eq(_driver.camera.offset, Vector2.ZERO, "over after 6 frames")
	assert_eq(_driver.frames_left(107), 0)


func test_combo_hit_shakes_and_solo_hit_does_not() -> void:
	EventBus.hit_landed.emit(&"practice_target", 10, DamageCalc.STATE_BASE, false, Vector2.ZERO)
	assert_eq(_driver.camera.offset, Vector2.ZERO, "a solo hit does not shake")
	assert_eq(_driver.frames_left(_driver.now()), 0)
	EventBus.hit_landed.emit(&"practice_target", 20, DamageCalc.STATE_BASE, true, Vector2.ZERO)
	assert_eq(_driver.frames_left(_driver.now()), 6)
	assert_ne(_driver.camera.offset, Vector2.ZERO)


func test_new_combo_restarts_the_schedule() -> void:
	_driver.start(10)
	_driver.apply(14)
	_driver.start(14)
	assert_eq(_driver.frames_left(14), 6)


func test_shake_settles_on_physics_frames() -> void:
	EventBus.hit_landed.emit(&"practice_target", 20, DamageCalc.STATE_BASE, true, Vector2.ZERO)
	await wait_physics_frames(CameraShake.SHAKE_FRAMES + 2)
	await get_tree().process_frame
	assert_eq(_driver.camera.offset, Vector2.ZERO)


func test_reset_stops_the_shake() -> void:
	_driver.start(_driver.now())
	_driver.reset()
	assert_eq(_driver.camera.offset, Vector2.ZERO)
	assert_eq(_driver.frames_left(_driver.now()), 0)


func test_main_camera_keeps_the_framing_and_the_hud_does_not_move() -> void:
	var main: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	var cam: Camera2D = main.camera_shake.camera
	assert_eq(cam.get_parent(), main.arena)
	assert_eq(cam.global_position, Vector2.ZERO, "offset zero == no camera")
	assert_true(main.get_node(^"Hud") is CanvasLayer, "the HUD is a CanvasLayer: the camera never moves it")
