extends GutTest
## Story 1.6 AC4/AC5/AC10: F1-F5 jump map, the release gate and input consumption; Story 2.5: F9;
## Story 3.1: Shift+F3 test boss, F6 boss kill, Shift+F6 next phase, Ctrl+F6 player hit (D-S31-2).

const DebugKeysScript := preload("res://src/debug/debug_keys.gd")
const MainScript := preload("res://src/main/main.gd")
const GameScript := preload("res://src/autoloads/game.gd")

var _saved_enabled: bool
var _saved_state: int
var _saved_boss: int
var _saved_first: int


func before_each() -> void:
	_saved_enabled = Debug.enabled
	_saved_state = Game.flow_state
	_saved_boss = Game.run.boss_index
	_saved_first = Game.first_input_frame


func after_each() -> void:
	Debug.enabled = _saved_enabled
	Game.flow_state = _saved_state as GameScript.FlowState
	Game.run.boss_index = _saved_boss
	Game.first_input_frame = _saved_first
	Game.segfault_enabled = Defs.FEATURE_FLAGS.segfault # Story 5.6: tests may flip the cut flag


func _key(code: Key, pressed: bool = true, echo: bool = false, shift: bool = false, ctrl: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	ev.echo = echo
	ev.shift_pressed = shift
	ev.ctrl_pressed = ctrl
	return ev


func test_target_for_f1_to_f5() -> void:
	assert_eq(DebugKeysScript.target_for_key(KEY_F1), {&"state": GameScript.FlowState.TITLE, &"boss_index": 0})
	assert_eq(DebugKeysScript.target_for_key(KEY_F2), {&"state": GameScript.FlowState.FIGHT, &"boss_index": 0})
	assert_eq(DebugKeysScript.target_for_key(KEY_F3), {&"state": GameScript.FlowState.FIGHT, &"boss_index": 1})
	assert_eq(DebugKeysScript.target_for_key(KEY_F4), {&"state": GameScript.FlowState.FIGHT, &"boss_index": 2})
	assert_eq(DebugKeysScript.target_for_key(KEY_F5), {&"state": GameScript.FlowState.ENDING, &"boss_index": 0})


func test_other_keys_have_no_target() -> void:
	for code: Key in [KEY_F6, KEY_F9, KEY_F12, KEY_A, KEY_ENTER, KEY_ESCAPE]:
		assert_true(DebugKeysScript.target_for_key(code).is_empty(), "key %d" % code)


func test_should_add_debug_keys_follows_the_gate() -> void:
	assert_true(MainScript.should_add_debug_keys(true))
	assert_false(MainScript.should_add_debug_keys(false))


func test_handle_key_jumps_and_reports_handled() -> void:
	Debug.enabled = true
	var keys: Node = autofree(DebugKeysScript.new())
	assert_true(keys.handle_key(_key(KEY_F4)))
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
	assert_eq(Game.run.boss_index, 2)


func test_handle_key_ignores_release_echo_and_unmapped() -> void:
	Debug.enabled = true
	var keys: Node = autofree(DebugKeysScript.new())
	assert_false(keys.handle_key(_key(KEY_F2, false)))
	assert_false(keys.handle_key(_key(KEY_F2, true, true)))
	assert_false(keys.handle_key(_key(KEY_A)))
	assert_false(keys.handle_key(_key(KEY_F9, true, false, true)), "Shift+F9 is the HUD grid (D-S25-11)")


## Story 2.5 AC7: F9 toggles the frame overlay (debug-only node).
func test_f9_toggles_frame_overlay() -> void:
	Debug.enabled = true
	var keys: DebugKeys = autofree(DebugKeysScript.new())
	var overlay: FrameOverlay = autofree(FrameOverlay.new())
	keys.frame_overlay = overlay
	assert_true(keys.handle_key(_key(KEY_F9)))
	assert_true(overlay.visible)
	assert_false(keys.handle_key(_key(KEY_F9, true, true)), "echo ignored")
	assert_true(overlay.visible)
	assert_true(keys.handle_key(_key(KEY_F9)))
	assert_false(overlay.visible)
	assert_false(keys.handle_key(_key(KEY_F9, true, false, true)))
	assert_false(overlay.visible, "Shift+F9 does not toggle the overlay")


func test_main_adds_debug_keys_only_when_enabled() -> void:
	Debug.enabled = true
	var main_on: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main_on)
	assert_not_null(main_on.get_node_or_null(^"DebugKeys"))
	Debug.enabled = false
	var main_off: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main_off)
	assert_null(main_off.get_node_or_null(^"DebugKeys"))


## Review 2.5: F9 is not consumed when there is no overlay.
func test_f9_without_overlay_is_not_consumed() -> void:
	var keys: DebugKeys = autofree(DebugKeysScript.new())
	assert_false(keys.handle_key(_key(KEY_F9)))


# --- Story 2.7: Shift+F2 practice target (D-S27-3) ---

func test_shift_f2_maps_to_fight_with_practice() -> void:
	assert_eq(DebugKeysScript.shift_target_for_key(KEY_F2), {&"state": GameScript.FlowState.FIGHT, &"boss_index": 0, &"practice": true})
	for code: Key in [KEY_F1, KEY_F4, KEY_F9, KEY_A]:
		assert_true(DebugKeysScript.shift_target_for_key(code).is_empty(), "key %d" % code)
	assert_false(DebugKeysScript.target_for_key(KEY_F2).has(&"practice"), "plain F2 has no practice")


func test_shift_f2_requests_practice_and_plain_f2_clears_it() -> void:
	Debug.enabled = true
	var keys: DebugKeys = autofree(DebugKeysScript.new())
	assert_true(keys.handle_key(_key(KEY_F2, true, false, true)))
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
	assert_eq(Game.run.boss_index, 0)
	assert_true(keys.practice_requested)
	assert_true(keys.handle_key(_key(KEY_F2)))
	assert_false(keys.practice_requested, "plain F2 is unchanged: no target")
	assert_true(keys.handle_key(_key(KEY_F2, true, false, true)))
	assert_true(keys.handle_key(_key(KEY_F1)))
	assert_false(keys.practice_requested, "any other jump clears it")


func test_main_places_the_practice_target_only_on_shift_f2_and_keeps_it_on_retry() -> void:
	Debug.enabled = true
	var main: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	var keys: DebugKeys = main.get_node(^"DebugKeys")
	var arena: Arena = main.arena
	keys.handle_key(_key(KEY_F2, true, false, true))
	assert_not_null(arena.practice_target)
	assert_eq(arena.practice_target.position_px, Arena.PRACTICE_TARGET_PX)
	assert_eq(arena.combat.targets.size(), 1)
	assert_eq(arena.combat.targets[0], arena.practice_target)
	assert_eq(main.practice_view.target, arena.practice_target)
	assert_eq(main.frame_overlay.practice_target, arena.practice_target)
	arena.practice_target.register_hit(1, 1, &"slash_1", 10)
	main.apply_flow_state(GameScript.FlowState.FIGHT, 0) # a retry re-enters FIGHT
	assert_not_null(arena.practice_target, "a retry keeps the target")
	assert_eq(arena.practice_target.hits, 0, "and resets it")
	keys.handle_key(_key(KEY_F2))
	assert_null(arena.practice_target)
	assert_true(arena.combat.targets.is_empty())
	assert_null(main.practice_view.target)


func test_release_gate_has_no_practice_target_or_key() -> void:
	Debug.enabled = false
	var main: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	assert_null(main.get_node_or_null(^"DebugKeys"))
	assert_null(main.practice_view)
	assert_false(main.wants_practice())
	main.apply_flow_state(GameScript.FlowState.FIGHT, 0)
	assert_null(main.arena.practice_target)
	assert_true(main.arena.combat.targets.is_empty())
	var before: int = Game.flow_state
	var keys: DebugKeys = autofree(DebugKeysScript.new())
	keys.handle_key(_key(KEY_F2, true, false, true))
	assert_eq(Game.flow_state, before, "Game refuses debug jumps when the gate is closed")


# --- Story 2.8: F10 perf overlay (AC6) ---

func test_f10_toggles_the_perf_overlay() -> void:
	assert_eq(DebugKeysScript.PERF_KEY, KEY_F10)
	var keys: DebugKeys = autofree(DebugKeysScript.new())
	var overlay: PerfOverlay = autofree(PerfOverlay.new())
	assert_false(keys.handle_key(_key(KEY_F10)), "not consumed without an overlay")
	keys.perf_overlay = overlay
	assert_true(keys.handle_key(_key(KEY_F10)))
	assert_true(overlay.visible)
	assert_false(keys.handle_key(_key(KEY_F10, true, true)), "echo ignored")
	assert_false(keys.handle_key(_key(KEY_F10, true, false, true)), "Shift+F10 is not the overlay")
	assert_true(overlay.visible)
	assert_true(keys.handle_key(_key(KEY_F10)))
	assert_false(overlay.visible)
	assert_true(DebugKeysScript.target_for_key(KEY_F10).is_empty(), "F10 is not a jump key")


# --- Story 2.9: debug damage key (AC8, D-S29-11), Ctrl+F6 since Story 3.1 (D-S31-2) ---

func test_ctrl_f6_queues_a_hit_only_in_fight() -> void:
	Debug.enabled = true
	var main: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	var keys: DebugKeys = main.get_node(^"DebugKeys")
	var health: PlayerHealth = main.arena.health
	assert_eq(keys.player_health, health, "Main injects the arena's health")
	Game.flow_state = GameScript.FlowState.TITLE
	assert_false(keys.handle_key(_key(KEY_F6, true, false, false, true)), "Ctrl+F6 does nothing outside FIGHT")
	assert_false(health.get(&"_pending"))
	keys.handle_key(_key(KEY_F2, true, false, true)) # Story 6.3: every boss index has a boss; the Shift+F2 sandbox has none
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
	assert_null(main.arena.boss)
	assert_false(keys.handle_key(_key(KEY_F6)), "plain F6 is the boss kill: no boss, not consumed")
	assert_false(keys.handle_key(_key(KEY_F6, true, false, true)), "Shift+F6 is not the damage key")
	assert_false(health.get(&"_pending"), "neither queued a player hit")
	assert_false(keys.handle_key(_key(KEY_F6, true, true, false, true)), "echo ignored")
	assert_false(keys.handle_key(_key(KEY_F6, true, false, true, true)), "Ctrl+Shift+F6 is not mapped")
	assert_true(keys.handle_key(_key(KEY_F6, true, false, false, true)))
	assert_true(health.get(&"_pending"), "one hit queued (a request, not a state write)")
	assert_eq(health.hp, 5, "HP changes only on the sim tick")
	health.set_active(false)


func test_ctrl_f6_without_health_does_nothing() -> void:
	var keys: DebugKeys = autofree(DebugKeysScript.new())
	Game.flow_state = GameScript.FlowState.FIGHT
	assert_false(keys.handle_key(_key(KEY_F6, true, false, false, true)))


func test_release_build_has_no_f6() -> void:
	Debug.enabled = false
	var main: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	assert_null(main.get_node_or_null(^"DebugKeys"), "no DebugKeys, so no F6 in release")


# --- Story 3.1: boss debug keys (AC7, AC8, D-S31-2, D-S31-3) ---

func _main_with_debug() -> Node2D:
	Debug.enabled = true
	var main: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	return main


func test_shift_f3_maps_to_fight_with_the_test_boss() -> void:
	assert_eq(DebugKeysScript.shift_target_for_key(KEY_F3), {&"state": GameScript.FlowState.FIGHT, &"boss_index": 0, &"test_boss": true})
	assert_false(DebugKeysScript.target_for_key(KEY_F3).has(&"test_boss"), "plain F3 is unchanged")


func test_shift_f3_requests_the_test_boss_and_other_jumps_clear_it() -> void:
	Debug.enabled = true
	var keys: DebugKeys = autofree(DebugKeysScript.new())
	assert_true(keys.handle_key(_key(KEY_F3, true, false, true)))
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
	assert_eq(Game.run.boss_index, 0)
	assert_true(keys.test_boss_requested)
	assert_false(keys.practice_requested)
	assert_true(keys.handle_key(_key(KEY_F2, true, false, true)))
	assert_false(keys.test_boss_requested, "Shift+F2 clears it")
	assert_true(keys.practice_requested)
	assert_true(keys.handle_key(_key(KEY_F3, true, false, true)))
	assert_true(keys.handle_key(_key(KEY_F2)))
	assert_false(keys.test_boss_requested, "any other jump clears it")


func test_main_places_the_test_boss_only_on_shift_f3_and_keeps_it_on_retry() -> void:
	var main: Node2D = _main_with_debug()
	Game.segfault_enabled = true # Story 6.3: boss 2 is live (independent of the shipped flag)
	var keys: DebugKeys = main.get_node(^"DebugKeys")
	var arena: Arena = main.arena
	assert_eq(keys.arena, arena, "Main injects the arena")
	keys.handle_key(_key(KEY_F3))
	assert_true(arena.boss is NullPointerBody, "Story 5.1: plain F3 (boss 1) is the Null Pointer")
	assert_eq(main.hud.top_bar_text(), "void nullPointer() // hp 700")
	assert_eq(main.hud.sky_text(), Hud.SKY_NULL_POINTER, "D-S51-4: its sky comment")
	keys.handle_key(_key(KEY_F4))
	assert_eq(arena.boss.def.boss_id, &"segfault", "Story 6.3: plain F4 (boss 2) is the Segfault")
	assert_eq(main.hud.top_bar_text(), "void segfault() // hp 1000")
	assert_eq(main.hud.sky_text(), Hud.SKY_SEGFAULT, "Story 6.3 (AC 3): its sky comment")
	keys.handle_key(_key(KEY_F2))
	assert_true(arena.boss is InfiniteLoopBody, "Story 3.3: plain F2 (boss 0) is the Infinite Loop")
	assert_eq(main.hud.top_bar_text(), "void infiniteLoop() // hp 400")
	assert_eq(main.hud.sky_text(), Hud.SKY, "the sky comment is restored")
	keys.handle_key(_key(KEY_F3, true, false, true))
	assert_false(arena.boss is InfiniteLoopBody, "Shift+F3 wins over boss 0 (AC 9)")
	var boss: BossController = arena.boss
	assert_not_null(boss)
	assert_true(boss.active)
	assert_eq(boss.hp, 20)
	assert_eq(main.boss_view.boss, boss)
	assert_eq(main.hud.top_bar_text(), "void testBoss() // hp 20")
	boss.take_hit(3)
	main.apply_flow_state(GameScript.FlowState.FIGHT, 0) # a retry re-enters FIGHT
	assert_same(arena.boss, boss, "a retry keeps the controller (cached attacks)")
	assert_eq(boss.hp, 20, "and resets it")
	keys.handle_key(_key(KEY_F2, true, false, true)) # the Shift+F2 sandbox: no boss
	assert_null(arena.boss)
	assert_null(main.boss_view.boss)
	assert_eq(main.hud.top_bar_text(), Hud.TOP_BAR)


func test_f6_kills_the_boss_and_shift_f6_skips_a_phase() -> void:
	var main: Node2D = _main_with_debug()
	var keys: DebugKeys = main.get_node(^"DebugKeys")
	keys.handle_key(_key(KEY_F3, true, false, true))
	var boss: BossController = main.arena.boss
	watch_signals(EventBus)
	assert_true(keys.handle_key(_key(KEY_F6, true, false, true)), "Shift+F6 skips to phase 2")
	assert_eq(boss.phase_index, 1)
	assert_eq(boss.state, BossController.BossState.ROAR)
	assert_signal_emit_count(EventBus, "boss_roar_started", 1)
	assert_false(keys.handle_key(_key(KEY_F6, true, false, true)), "no phase after the last")
	assert_false(main.arena.health.get(&"_pending"), "boss keys never hit the player")
	assert_true(keys.handle_key(_key(KEY_F6)), "F6 kills the boss")
	assert_eq(boss.hp, 0)
	assert_eq(boss.state, BossController.BossState.DEFEATED)
	assert_signal_emitted_with_parameters(EventBus, "boss_defeated", [&"test_boss"])
	# Story 3.8 (G3): F6 goes through the real defeat path: FIGHT holds during the animation.
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT, "FIGHT holds during the defeat animation")
	assert_eq(main.hud.top_bar_text(), "void testBoss() // hp 0")
	assert_false(keys.handle_key(_key(KEY_F6)), "a dead boss is not killed twice")
	assert_signal_emit_count(EventBus, "boss_defeated", 1)
	assert_false(main.poll_defeat(), "not before the animation ends")
	for i: int in 1 + BossController.DEFEAT_HITSTOP_FRAMES + BossController.DEFEAT_FRAMES:
		SimClock.tick()
	assert_true(boss.defeat_finished())
	assert_true(main.poll_defeat(), "Main leaves FIGHT after the tick")
	assert_eq(Game.flow_state, GameScript.FlowState.HARVEST, "Fight 1 -> HARVEST")
	assert_true(main.current_screen is HarvestScreen)
	SimClock.begin_fight(0)


func test_boss_keys_do_nothing_without_a_boss_or_outside_fight() -> void:
	var main: Node2D = _main_with_debug()
	var keys: DebugKeys = main.get_node(^"DebugKeys")
	keys.handle_key(_key(KEY_F2, true, false, true)) # Story 6.3: the Shift+F2 sandbox is the only fight without a boss
	assert_false(keys.handle_key(_key(KEY_F6)), "F6 without a boss")
	assert_false(keys.handle_key(_key(KEY_F6, true, false, true)), "Shift+F6 without a boss")
	keys.handle_key(_key(KEY_F3, true, false, true))
	Game.flow_state = GameScript.FlowState.TITLE
	assert_false(keys.handle_key(_key(KEY_F6)), "F6 outside FIGHT")
	assert_eq(main.arena.boss.hp, 20)
	var bare: DebugKeys = autofree(DebugKeysScript.new())
	Game.flow_state = GameScript.FlowState.FIGHT
	assert_false(bare.handle_key(_key(KEY_F6)), "no arena injected")


func test_release_gate_has_no_test_boss() -> void:
	Debug.enabled = false
	var main: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	assert_false(main.wants_test_boss())
	main.apply_flow_state(GameScript.FlowState.FIGHT, 1)
	assert_true(main.arena.boss is NullPointerBody, "Story 5.1: boss 1 is the Null Pointer in release too")
	Game.segfault_enabled = true # Story 6.3: the shipped value, set here so the case does not depend on it
	main.apply_flow_state(GameScript.FlowState.FIGHT, 2)
	assert_eq(main.arena.boss.def.boss_id, &"segfault", "Story 6.3: boss 2 is the Segfault in release")
	assert_eq(main.hud.top_bar_text(), "void segfault() // hp 1000")
	Game.segfault_enabled = false # Story 6.3 (AC 2, AC 24): cut ladder #4
	main.apply_flow_state(GameScript.FlowState.FIGHT, 2)
	assert_null(main.arena.boss, "boss 2 cut: placeholder, no boss")
	assert_eq(main.hud.top_bar_text(), Hud.TOP_BAR)
	assert_eq(main.hud.sky_text(), Hud.SKY)
	# Story 3.3 (AC 9, D-S33-11, G3): the Infinite Loop is boss 0 in release too.
	main.apply_flow_state(GameScript.FlowState.FIGHT, 0)
	assert_true(main.arena.boss is InfiniteLoopBody)
	assert_eq(main.hud.top_bar_text(), "void infiniteLoop() // hp 400")
	main.apply_flow_state(GameScript.FlowState.TITLE, 0)
	assert_eq(main.hud.top_bar_text(), Hud.TOP_BAR, "leaving FIGHT detaches the header (B6)")
	assert_null(main.boss_view.boss, "and the view")


# --- Story 3.3: which boss a FIGHT loads (AC 9, D-S33-11, D-S33-13, D-S33-22) ---

func test_boss_def_path_for_precedence() -> void:
	assert_eq(MainScript.boss_def_path_for(false, 0), Arena.INFINITE_LOOP_DEF_PATH, "boss 0: the Infinite Loop")
	assert_eq(MainScript.boss_def_path_for(false, 1), Arena.NULL_POINTER_DEF_PATH, "boss 1: the Null Pointer (Story 5.1)")
	assert_eq(MainScript.boss_def_path_for(false, 2), Arena.SEGFAULT_DEF_PATH, "boss 2: the Segfault (Story 6.3)")
	assert_eq(MainScript.boss_def_path_for(false, 2, false, false), "", "boss 2 cut (FeatureFlags.segfault off): placeholder")
	assert_eq(MainScript.boss_def_path_for(true, 0), Arena.TEST_BOSS_DEF_PATH, "Shift+F3 wins over boss 0")
	assert_eq(MainScript.boss_def_path_for(true, 0, true), Arena.TEST_BOSS_DEF_PATH, "test boss wins over practice")
	assert_eq(MainScript.boss_def_path_for(false, 0, true), "", "Shift+F2 practice: no boss")
	assert_eq(Arena.boss_class_for(Arena.INFINITE_LOOP_DEF_PATH), InfiniteLoopBody)
	assert_eq(Arena.boss_class_for(Arena.TEST_BOSS_DEF_PATH), BossController)


func test_shift_f2_practice_has_no_boss_and_f6_keeps_working_on_the_loop() -> void:
	var main: Node2D = _main_with_debug()
	var keys: DebugKeys = main.get_node(^"DebugKeys")
	keys.handle_key(_key(KEY_F2, true, false, true))
	assert_null(main.arena.boss, "practice sandbox: no boss")
	assert_not_null(main.arena.practice_target)
	keys.handle_key(_key(KEY_F2))
	var boss: BossController = main.arena.boss
	assert_true(boss is InfiniteLoopBody)
	watch_signals(EventBus)
	assert_true(keys.handle_key(_key(KEY_F6, true, false, true)), "Shift+F6 skips to phase 2")
	assert_eq(boss.phase_index, 1)
	assert_eq(boss.hp, 264)
	assert_true(keys.handle_key(_key(KEY_F6)), "F6 kills the Infinite Loop")
	assert_signal_emitted_with_parameters(EventBus, "boss_defeated", [&"infinite_loop"])
	assert_eq(main.hud.top_bar_text(), "void infiniteLoop() // hp 0")



# --- Story 3.8 (G3, AC 4): F8 grants the drop bit without the fight ---

func test_f8_grants_the_loop_on_fight_1_and_goes_to_harvest() -> void:
	var main: Node2D = _main_with_debug()
	var keys: DebugKeys = main.get_node(^"DebugKeys")
	keys.handle_key(_key(KEY_F2))
	assert_true(main.arena.boss is InfiniteLoopBody)
	assert_false(keys.handle_key(_key(KEY_F8, true, false, true)), "Shift+F8 is not the grant key")
	assert_true(keys.handle_key(_key(KEY_F8)), "F8 is consumed")
	assert_eq(Game.flow_state, GameScript.FlowState.HARVEST)
	var screen := main.current_screen as HarvestScreen
	assert_not_null(screen)
	assert_eq(screen.bit, Register.Bit.LOOP)
	assert_eq(screen.shown_ring, PackedInt32Array([Register.Bit.ATTACK, Register.Bit.DASH, Register.Bit.LOOP]))
	Game.finish_harvest(SimClock.sim_frame)
	assert_eq(Game.run.boss_index, 1)
	assert_eq(main.arena.register.ring, PackedInt32Array([Register.Bit.ATTACK, Register.Bit.DASH, Register.Bit.LOOP]), "Fight 2 loadout [A, D, L]")


## Story 5.5: NULL has a BitDef now, so F8 on Fight 2 grants N through the existing Story 3.8 route
## (the debug path to try Null Dodge before Story 5.6's real Harvest, D-S55-1).
func test_f8_grants_null_on_fight_2_and_is_a_no_op_outside_fight() -> void:
	Game.segfault_enabled = true # Story 5.6: the flag-on route (the cut path is tested below)
	var main: Node2D = _main_with_debug()
	var keys: DebugKeys = main.get_node(^"DebugKeys")
	keys.handle_key(_key(KEY_F3)) # FIGHT boss 1: the Null Pointer, drop_bit = N
	assert_true(keys.handle_key(_key(KEY_F8)))
	assert_eq(Game.flow_state, GameScript.FlowState.HARVEST, "F8 grants N on Fight 2")
	var screen := main.current_screen as HarvestScreen
	assert_not_null(screen)
	assert_eq(screen.bit, Register.Bit.NULL_BIT)
	keys.handle_key(_key(KEY_F1))
	assert_true(keys.handle_key(_key(KEY_F8)))
	assert_eq(Game.flow_state, GameScript.FlowState.TITLE, "no grant outside FIGHT")


func test_f8_does_nothing_in_release() -> void:
	Debug.enabled = false
	var main: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	assert_null(main.get_node_or_null(^"DebugKeys"), "no debug node in release")
	main.apply_flow_state(GameScript.FlowState.FIGHT, 0)
	Game.flow_state = GameScript.FlowState.FIGHT
	assert_false(Game.debug_grant_bit(main.arena.boss), "the Game gate refuses too")
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)


## Story 5.6 (AC 7, D-S56-4): with the Segfault cut (cut ladder #4) F8 on Fight 2 grants nothing and
## leaves the flow alone; the flag-on behaviour is the Story 5.5 test above.
func test_f8_on_fight_2_with_segfault_off_does_nothing() -> void:
	var main: Node2D = _main_with_debug()
	Game.segfault_enabled = false # after Main's startup read (it copies FeatureFlags.segfault)
	var keys: DebugKeys = main.get_node(^"DebugKeys")
	keys.handle_key(_key(KEY_F3))
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
	assert_true(keys.handle_key(_key(KEY_F8)), "F8 is still consumed")
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT, "no flow change")
	assert_null(main.current_screen as HarvestScreen, "no Harvest")
	assert_false(Game.run.fight_start_ring.has(Register.Bit.NULL_BIT), "nothing granted")
	keys.handle_key(_key(KEY_F1)) # back to TITLE: a fresh RunState for the next test
