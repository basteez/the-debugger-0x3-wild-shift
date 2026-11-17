extends GutTest
## Story 8.2 (E2-E5, E7, F2, F3; AC 2, 9, 10, 12, 15): the tutorial screen's pure helpers (device
## tracking, key names, prompts, the hold), the checklist view's rows and layout inside the play area,
## the dummy's boss-view cue, the screen reading the real arena, and the title's [T] tutorial option.

const GameScript := preload("res://src/autoloads/game.gd")
const S := GameScript.FlowState
const SCREEN: TextScreenText = preload("res://data/text/screen_text.tres")
const KB := TutorialScreen.Device.KEYBOARD
const PAD := TutorialScreen.Device.GAMEPAD
const PROMPT_MAX := 64

var _saved_game: Dictionary = {}
var _saved_done: bool
var _saved_unlocked: bool
var _arena: Arena


func before_each() -> void:
	_saved_game = {}
	for key: String in ["flow_state", "run", "stats", "first_input_frame", "intro_start_frame", "tutorial_replay"]:
		_saved_game[key] = Game.get(key)
	_saved_done = SaveService.tutorial_done
	_saved_unlocked = AudioManager.is_unlocked()


func after_each() -> void:
	for key: String in _saved_game:
		Game.set(key, _saved_game[key])
	SaveService.tutorial_done = _saved_done
	if not _saved_unlocked:
		AudioManager.set("_unlocked", false)
	if is_instance_valid(_arena):
		_arena.free()


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


# --- E4: device and key names ----------------------------------------------------------------


func test_device_follows_the_last_input() -> void:
	assert_eq(TutorialScreen.device_for(_key(KEY_J), PAD), KB)
	var click := InputEventMouseButton.new()
	assert_eq(TutorialScreen.device_for(click, PAD), KB, "the mouse is the keyboard")
	var button := InputEventJoypadButton.new()
	assert_eq(TutorialScreen.device_for(button, KB), PAD)
	var stick := InputEventJoypadMotion.new()
	stick.axis_value = 0.1
	assert_eq(TutorialScreen.device_for(stick, KB), KB, "stick noise keeps the device")
	stick.axis_value = -0.9
	assert_eq(TutorialScreen.device_for(stick, KB), PAD)
	assert_eq(TutorialScreen.initial_device([]), KB, "no pad connected: the keyboard")
	assert_eq(TutorialScreen.initial_device([0]), PAD, "Story 9.1 (618c): a connected pad starts as the pad")
	var screen: TutorialScreen = autofree(TutorialScreen.new())
	if Input.get_connected_joypads().is_empty(): # headless CI: no pad
		screen._ready()
		assert_eq(screen.device, KB, "the default without a pad is the keyboard")


## Story 9.1 (AC 10, D-S91-7): a trigger at rest (0 or -1 on some pads) never flips the device; a
## positive press of 0.5 or more does. Sticks keep the absolute rule.
func test_trigger_rest_values_keep_the_device() -> void:
	for axis: JoyAxis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		var trigger := InputEventJoypadMotion.new()
		trigger.axis = axis
		for rest: float in [-1.0, -0.6, 0.0, 0.4]:
			trigger.axis_value = rest
			assert_eq(TutorialScreen.device_for(trigger, KB), KB, "trigger %d at %.1f keeps the device" % [axis, rest])
		trigger.axis_value = 0.6
		assert_eq(TutorialScreen.device_for(trigger, KB), PAD, "trigger %d pressed flips it" % axis)
		trigger.axis_value = 0.5
		assert_eq(TutorialScreen.device_for(trigger, KB), PAD)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -0.6
	assert_eq(TutorialScreen.device_for(stick, KB), PAD, "a stick pushed up still counts")


func test_glyph_names_follow_the_story_7_5_mapping() -> void:
	assert_eq(TutorialScreen.glyph_name(&"action_1", KB), "J")
	assert_eq(TutorialScreen.glyph_name(&"action_2", KB), "K")
	assert_eq(TutorialScreen.glyph_name(&"shift", KB), "Q / E")
	assert_eq(TutorialScreen.glyph_name(&"skip", KB), "Esc or Bksp")
	assert_eq(TutorialScreen.glyph_name(&"action_1", PAD), "(X)")
	assert_eq(TutorialScreen.glyph_name(&"action_2", PAD), "(A)")
	assert_eq(TutorialScreen.glyph_name(&"shift", PAD), "LB / RB")
	assert_eq(TutorialScreen.glyph_name(&"skip", PAD), "SELECT")
	assert_eq(TutorialScreen.glyph_name(&"nope", KB), "")


func test_prompts_fit_64_columns_and_name_the_keys_per_device() -> void:
	for step: int in TutorialSteps.STEP_COUNT:
		for device: int in [KB, PAD]:
			var rows: PackedStringArray = TutorialScreen.prompt_rows(step, device)
			assert_between(rows.size(), 1, 2, "step %d" % step)
			for row: String in rows:
				assert_lte(row.length(), PROMPT_MAX, "%s fits 64 columns at 1x" % row)
				assert_false(row.contains("{"), "%s: every placeholder filled" % row)
				assert_true(DuckLineDef.is_ascii(row), row)
	assert_eq(TutorialScreen.prompt_rows(TutorialSteps.STEP_COUNT, KB).size(), 0, "no prompt once all passed")
	var actions_kb: String = TutorialScreen.prompt_rows(TutorialSteps.Step.ACTIONS, KB)[0]
	assert_true(actions_kb.begins_with("J ") and actions_kb.contains(" K "), actions_kb)
	assert_true(TutorialScreen.prompt_rows(TutorialSteps.Step.ACTIONS, PAD)[0].begins_with("(X) "))
	assert_true(TutorialScreen.prompt_rows(TutorialSteps.Step.ACTIONS, KB)[1].contains("A = slash, D = dash"), "the bits explained")
	assert_true(TutorialScreen.prompt_rows(TutorialSteps.Step.SHIFT, KB)[0].begins_with("Q / E "))
	assert_true(TutorialScreen.prompt_rows(TutorialSteps.Step.SHIFT, PAD)[0].begins_with("LB / RB "))
	assert_true(TutorialScreen.prompt_rows(TutorialSteps.Step.MOVE, PAD)[0].contains("left stick"))
	assert_eq(TutorialScreen.hint_rows(KB), PackedStringArray(["hold Esc or Bksp: skip", "P: pause"]))
	assert_eq(TutorialScreen.hint_rows(PAD), PackedStringArray(["hold SELECT: skip", "START: pause"]))
	assert_eq(TutorialScreen.glyph_name(&"pause", KB), "P")
	assert_eq(TutorialScreen.glyph_name(&"pause", PAD), "START")


# --- E3: the hold ------------------------------------------------------------------------------


func test_hold_helpers() -> void:
	assert_eq(TutorialScreen.SKIP_HOLD_FRAMES, 60)
	assert_false(TutorialScreen.hold_done(59))
	assert_true(TutorialScreen.hold_done(60))
	assert_false(TutorialScreen.hold_hint_visible(0))
	assert_true(TutorialScreen.hold_hint_visible(1))
	assert_eq(TutorialScreen.next_hold(5, true), 6)
	assert_eq(TutorialScreen.next_hold(5, false), 0)
	assert_eq(TutorialScreen.hold_fraction(30), 0.5)
	assert_eq(TutorialScreen.hold_fraction(90), 1.0)


# --- E2: the checklist view --------------------------------------------------------------------


func test_checklist_lines_turn_to_pass() -> void:
	var steps := TutorialSteps.new()
	var lines: PackedStringArray = TutorialChecklistView.checklist_lines(steps)
	assert_eq(lines, PackedStringArray(["[ ] test_move", "[ ] test_actions", "[ ] test_shift", "[ ] test_combo", "[ ] test_patch", "[ ] test_crit"]))
	steps.observe_move(48.0)
	lines = TutorialChecklistView.checklist_lines(steps)
	assert_eq(lines[0], "[PASS] test_move")
	assert_eq(lines[1], "[ ] test_actions")
	assert_eq(TutorialChecklistView.done_lines(), PackedStringArray(["ALL TESTS PASSED.", "deploying to production..."]))


func test_every_row_fits_the_play_area_and_clears_the_dummy() -> void:
	var dummy := Rect2(Arena.TUTORIAL_DUMMY_PX - Vector2(24, 8), Vector2(48, 16))
	for i: int in TutorialSteps.STEP_COUNT:
		var text: String = "[PASS] " + SCREEN.tutorial_tests[i]
		var at: Vector2 = TutorialChecklistView.row_top_left(i)
		assert_true(TutorialChecklistView.fits_play_area(at, text, TutorialChecklistView.TEST_SCALE), text)
		var r := Rect2(at, Vector2(GlyphFont.text_width(text, 2), 16))
		assert_false(r.intersects(dummy), "%s never covers the dummy" % text)
	for step: int in TutorialSteps.STEP_COUNT:
		var rows: PackedStringArray = TutorialScreen.prompt_rows(step, PAD)
		for i: int in rows.size():
			assert_true(TutorialChecklistView.fits_play_area(TutorialChecklistView.prompt_top_left(rows[i], i, rows.size()), rows[i], 1), rows[i])
	for device: int in [KB, PAD]:
		var hints: PackedStringArray = TutorialScreen.hint_rows(device)
		for i: int in hints.size():
			assert_true(TutorialChecklistView.fits_play_area(TutorialChecklistView.hint_row_top_left(hints, i), hints[i], 1), hints[i])
	var done: PackedStringArray = TutorialChecklistView.done_lines()
	for i: int in done.size():
		var at: Vector2 = TutorialChecklistView.done_top_left(done[i], i)
		assert_true(TutorialChecklistView.fits_play_area(at, done[i], 2), done[i])
		assert_false(Rect2(at, Vector2(GlyphFont.text_width(done[i], 2), 16)).intersects(dummy))


## A row's drawn rect with its BG backing (what _text paints).
static func _backed(top_left: Vector2, text: String, scale: int) -> Rect2:
	var b: float = TutorialChecklistView.BACKING
	return Rect2(top_left - Vector2.ONE * b, Vector2(GlyphFont.text_width(text, scale), GlyphFont.CELL * scale) + Vector2.ONE * b * 2.0)


## Story 9.1 (AC 7, 618a, D-S91-4): the skip / pause hint rows and the hold bar never touch a
## checklist row ([ ] or [PASS], backing included), for either device.
func test_hint_rows_and_hold_bar_clear_the_checklist() -> void:
	var rows: Array[Rect2] = []
	for i: int in TutorialSteps.STEP_COUNT:
		for mark: String in [TutorialChecklistView.TODO_MARK, TutorialChecklistView.PASS_MARK]:
			var text: String = "%s %s" % [mark, SCREEN.tutorial_tests[i]]
			rows.append(_backed(TutorialChecklistView.row_top_left(i), text, TutorialChecklistView.TEST_SCALE))
			rows.append(_backed(Vector2(TutorialChecklistView.CURSOR_LEFT, TutorialChecklistView.row_top_left(i).y), TutorialChecklistView.CURSOR, TutorialChecklistView.TEST_SCALE))
	for device: int in [KB, PAD]:
		var hints: PackedStringArray = TutorialScreen.hint_rows(device)
		assert_eq(hints.size(), 2, "skip row and pause row")
		var drawn: Array[Rect2] = [TutorialChecklistView.hold_bar_rect(hints[0])]
		for i: int in hints.size():
			assert_lte(hints[i].length(), PROMPT_MAX)
			assert_true(DuckLineDef.is_ascii(hints[i]), hints[i])
			drawn.append(_backed(TutorialChecklistView.hint_row_top_left(hints, i), hints[i], TutorialChecklistView.PROMPT_SCALE))
		for d: Rect2 in drawn:
			for r: Rect2 in rows:
				assert_false(d.intersects(r), "hint %s overlaps checklist %s" % [d, r])
		assert_false(_backed(TutorialChecklistView.hint_row_top_left(hints, 1), hints[1], 1).intersects(drawn[0]), "the pause row clears the hold bar")


## Hotfix: the 2x checklist rows' backings reach into the next row (BACKING px), so _draw paints every
## backing before any glyph; text_rows() hands _draw all rows, the cursor included, in one list.
func test_checklist_backings_overlap_neighbours_so_draw_is_two_pass() -> void:
	var view := TutorialChecklistView.new()
	add_child_autofree(view)
	var texts := PackedStringArray()
	for i: int in TutorialSteps.STEP_COUNT:
		texts.append("[ ] test_row_%d" % i)
	view.show_state(texts, 1, PackedStringArray(), PackedStringArray(), 0.0, false)
	var all: Array[Dictionary] = view.text_rows()
	assert_eq(all.size(), TutorialSteps.STEP_COUNT + 1, "six rows and the cursor")
	var first: Dictionary = all[0]
	var second: Dictionary = all[1]
	var glyphs := Rect2(first["at"], Vector2(GlyphFont.text_width(first["text"], first["scale"]), GlyphFont.CELL * first["scale"]))
	var next_back: Rect2 = TutorialChecklistView.backing_rect(second["at"], second["text"], second["scale"])
	assert_true(next_back.intersects(glyphs), "row 2's backing covers the underscore row of row 1 (hence two passes)")


## Hotfix: the hint rows and the hold bar (backing included) sit inside the tree ring, so they never
## cover the frame row and its `stack frame 0x03` label, for either device.
func test_hint_rows_clear_the_frame_title() -> void:
	var cell: float = Arena.TILE_PX
	var label := Rect2(Vector2(Arena.LABEL_COL * cell, 0), Vector2(Arena.LABEL.length() * cell, cell))
	var frame_top := Rect2(Arena.play_area().position, Vector2(Arena.play_area().size.x, cell))
	var interior: Rect2 = Arena.play_area().grow(-cell)
	assert_eq(TutorialChecklistView.hint_area(), interior)
	for device: int in [KB, PAD]:
		var hints: PackedStringArray = TutorialScreen.hint_rows(device)
		var drawn: Array[Rect2] = [TutorialChecklistView.hold_bar_rect(hints[0])]
		for i: int in hints.size():
			drawn.append(_backed(TutorialChecklistView.hint_row_top_left(hints, i), hints[i], TutorialChecklistView.PROMPT_SCALE))
		for d: Rect2 in drawn:
			assert_false(d.intersects(label), "hint %s overlaps the frame title %s" % [d, label])
			assert_false(d.intersects(frame_top), "hint %s sits on the frame row" % d)
			assert_true(interior.encloses(d), "hint %s inside the tree ring" % d)


## Story 9.1 (AC 8, 618b, D-S91-5): the completion rows sit in the bottom band, inside the play
## area, and their backing never touches the `@` at spawn or the dummy (its `{;}`, cue and the
## largest damage number under it).
func test_completion_rows_clear_the_spawn_and_the_dummy() -> void:
	var at_size := Vector2(GlyphFont.text_width(PlayerView.PLAYER_GLYPH, PlayerView.GLYPH_SCALE), Const.TILE_PX)
	var player := Rect2(PlayerView.player_top_left(Arena.SPAWN_PX), at_size)
	var cell: float = GlyphFont.CELL * BossView.GLYPH_SCALE
	var dummy_body := Rect2(BossView.line_top_left(Arena.TUTORIAL_DUMMY_PX, Vector2(cell * 3, cell)), Vector2(cell * 3, cell))
	# The cue reaches CUE_REF_RADIUS under the `;`; the PATCHED (2x) damage number sits under the
	# body + cue band (BossView._draw_number): a generous box over both.
	var number_h: float = GlyphFont.CELL * 2.0
	var below: float = BossView.CUE_MARKER_BASE + cell + BossView.STACK_GAP + number_h
	var dummy_zone := Rect2(dummy_body.position - Vector2(cell * 2, cell * 2), Vector2(cell * 7, maxf(below, BossView.CUE_REF_RADIUS) + cell * 3))
	var done: PackedStringArray = TutorialChecklistView.done_lines()
	var area: Rect2 = Arena.play_area()
	for i: int in done.size():
		var at: Vector2 = TutorialChecklistView.done_top_left(done[i], i)
		var r: Rect2 = _backed(at, done[i], TutorialChecklistView.TEST_SCALE)
		assert_true(TutorialChecklistView.fits_play_area(at, done[i], TutorialChecklistView.TEST_SCALE), done[i])
		assert_true(area.encloses(r), "%s backing inside the play area" % done[i])
		assert_false(r.intersects(player), "%s never covers the @" % done[i])
		assert_false(r.intersects(dummy_zone), "%s never covers the dummy or its number" % done[i])
		assert_gt(at.y, Arena.SPAWN_PX.y + Const.TILE_PX, "%s is in the bottom band" % done[i])
	assert_eq(TutorialChecklistView.done_top_left(done[0], 0).y, 240.0)
	assert_eq(TutorialChecklistView.done_top_left(done[1], 1).y, 264.0)


func test_view_draws_only_while_fed() -> void:
	var view: TutorialChecklistView = autofree(TutorialChecklistView.new())
	assert_false(view.active)
	view.show_state(TutorialChecklistView.checklist_lines(TutorialSteps.new()), 0, PackedStringArray(["x"]), PackedStringArray(["hint"]), 0.0, false)
	assert_true(view.active)
	assert_eq(view.current, 0)
	view.clear()
	assert_false(view.active)


# --- E1: the screen reads the real arena ---------------------------------------------------------


func test_screen_feeds_the_steps_from_the_arena() -> void:
	_arena = Arena.new()
	_arena.enter_fight(Register.fight_start_for_boss(0), false, Arena.TUTORIAL_DEF_PATH)
	Game.flow_state = S.TUTORIAL
	var screen: TutorialScreen = autofree(TutorialScreen.new())
	screen.arena = _arena
	add_child(screen) # connects the hit and patch signals
	screen.set_physics_process(false) # polled by hand below
	screen.poll(1, false) # baseline only
	assert_eq(screen.steps.current_step(), TutorialSteps.Step.MOVE)
	_arena.player.position_px += Vector2(48, 0)
	screen.poll(2, false)
	assert_eq(screen.steps.current_step(), TutorialSteps.Step.ACTIONS, "3 tiles moved")
	_arena.actions.action_serial += 1
	_arena.actions.action_slot = 0
	screen.poll(3, false)
	_arena.actions.action_serial += 1
	_arena.actions.action_slot = 1
	screen.poll(4, false)
	assert_eq(screen.steps.current_step(), TutorialSteps.Step.SHIFT, "J and K used")
	_arena.register.shift(Register.RIGHT) # a 2-bit ring: one shift either way gives [A, D]
	assert_eq(_arena.register.active_window(), Vector2i(Register.Bit.ATTACK, Register.Bit.DASH))
	screen.poll(5, false)
	assert_eq(screen.steps.current_step(), TutorialSteps.Step.COMBO, "the register reads [A, D]")
	EventBus.hit_landed.emit(&"boss", 10, DamageState.Kind.UNPATCHED, true, Vector2.ZERO)
	assert_eq(screen.steps.current_step(), TutorialSteps.Step.PATCH)
	EventBus.patched_applied.emit(&"tutorial_dummy", 180)
	EventBus.hit_landed.emit(&"boss", 30, DamageState.Kind.PATCHED, true, Vector2.ZERO)
	assert_eq(screen.steps.current_step(), TutorialSteps.Step.CRIT, "the patching hit is not the crit")
	var frame: int = SimClock.sim_frame
	SimClock.sim_frame = frame + 1 # a later tick: this hit did not apply Patched
	EventBus.hit_landed.emit(&"boss", 15, DamageState.Kind.PATCHED, false, Vector2.ZERO)
	SimClock.sim_frame = frame
	assert_true(screen.steps.all_passed())


func test_screen_ignores_hits_outside_tutorial() -> void:
	Game.flow_state = S.FIGHT
	var screen: TutorialScreen = autofree(TutorialScreen.new())
	add_child(screen) # connects the signals
	screen.steps.step = TutorialSteps.Step.COMBO
	EventBus.hit_landed.emit(&"boss", 10, DamageState.Kind.UNPATCHED, true, Vector2.ZERO)
	assert_eq(screen.steps.current_step(), TutorialSteps.Step.COMBO)


# --- E7: the dummy in the boss view ----------------------------------------------------------------


func test_dummy_cue_only_while_open() -> void:
	_arena = Arena.new()
	_arena.enter_fight(Register.fight_start_for_boss(0), false, Arena.TUTORIAL_DEF_PATH)
	var dummy := _arena.boss as TutorialDummyBody
	assert_not_null(dummy)
	assert_eq(dummy.body_center_px, Arena.TUTORIAL_DUMMY_PX)
	assert_false(BossView.dummy_cue_on(dummy), "closed: plain `;`, no cue")
	dummy.open_left = TutorialDummyBody.OPEN_FRAMES
	assert_true(BossView.dummy_cue_on(dummy))
	assert_false(BossView.dummy_cue_on(null))
	var semicolon: Vector2 = dummy.body_center_px
	var centre: Vector2 = BossView.dummy_cue_centre(semicolon)
	var marker: PackedVector2Array = BossView.open_cue_marker(centre, semicolon)
	assert_gt(marker[0].y, semicolon.y, "the pointer sits under the `;`")
	assert_lt(marker[0].y, marker[1].y, "pointing up at it")
	assert_eq(BossView.dummy_cell_centre(semicolon, 1), semicolon, "the `;` is the middle cell")
	assert_eq(BossView.dummy_cell_centre(semicolon, 0), semicolon - Vector2(16, 0))
	var view: BossView = autofree(BossView.new())
	view.boss = dummy
	add_child(view)
	view.queue_redraw()
	await wait_physics_frames(1)
	assert_true(is_instance_valid(view), "drawing the dummy does not crash")


# --- F2, F3: the title option ------------------------------------------------------------------------


func test_t_is_an_option_and_the_labels_share_the_practice_row() -> void:
	assert_true(InputMap.has_action(&"title_option_tutorial"))
	assert_eq(TitleScreen.classify(_key(KEY_T)), TitleScreen.Action.OPTION)
	assert_eq(TitleScreen.option_of(_key(KEY_T)), &"tutorial")
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	for b: int in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		pad.button_index = b as JoyButton
		assert_ne(TitleScreen.option_of(pad), &"tutorial", "no pad button replays the tutorial (D-S82-13)")
	var practice: Rect2 = TitleScreen.practice_label_rect()
	var tutorial: Rect2 = TitleScreen.tutorial_label_rect()
	assert_eq(practice.position.y, tutorial.position.y, "one row")
	assert_lt(practice.end.x, tutorial.position.x + 1.0, "practice left, tutorial right, apart")
	assert_true(Rect2(0, 0, Const.BASE_RES.x, Const.BASE_RES.y).encloses(tutorial), "fits the 640-px base")
	assert_eq(TitleScreen.TUTORIAL_TEXT, "[T] tutorial")
	var x: Vector2i = TitleScreen.shared_row_x()
	assert_eq(x.x % GlyphFont.CELL, 0)
	assert_eq(x.y - x.x, GlyphFont.text_width(TitleScreen.PRACTICE_TEXT, 2) + 2 * 16, "two glyph cells apart")


func test_t_and_a_click_replay_the_tutorial_whatever_the_save() -> void:
	SaveService.tutorial_done = true
	Game.flow_state = S.TITLE
	var title: TitleScreen = autofree(TitleScreen.new())
	assert_eq(title.handle_input(_key(KEY_T)), TitleScreen.Action.OPTION)
	assert_eq(Game.flow_state, S.TUTORIAL)
	assert_true(Game.tutorial_replay)
	Game.flow_state = S.TITLE
	Game.tutorial_replay = false
	var other: TitleScreen = autofree(TitleScreen.new())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = TitleScreen.tutorial_label_rect().get_center()
	assert_eq(other.handle_input(click), TitleScreen.Action.OPTION)
	assert_eq(Game.flow_state, S.TUTORIAL)
	click.position = TitleScreen.practice_label_rect().get_center()
	assert_eq(TitleScreen.option_of(click, other.label_rects), &"practice", "the practice label still clicks")
