extends GutTest
## Story 1.5 AC2/DC8 and Story 1.6 AC6/AC7: Main's render layers, boot visibility and screen host.

const MainScene := preload("res://src/main/main.tscn")
const MainScript := preload("res://src/main/main.gd")
const GameScript := preload("res://src/autoloads/game.gd")


func _main() -> Node2D:
	var main: Node2D = MainScene.instantiate()
	add_child_autofree(main)
	return main


func test_layer_children_in_ad07_order() -> void:
	var main: Node2D = _main()
	var names: Array[StringName] = []
	for child: Node in main.get_children():
		if child.name in MainScript.LAYER_ORDER:
			names.append(child.name)
	assert_eq(names, MainScript.LAYER_ORDER)
	for i: int in MainScript.LAYER_ORDER.size():
		assert_eq(main.get_child(i).name, MainScript.LAYER_ORDER[i], "child %d" % i)


func test_canvas_layer_values() -> void:
	var main: Node2D = _main()
	var hud := main.get_node(^"Hud") as CanvasLayer
	var fx := main.get_node(^"ScreenFX") as CanvasLayer
	assert_not_null(hud)
	assert_not_null(fx)
	assert_eq(hud.layer, 10)
	assert_eq(fx.layer, 20)
	assert_lt(hud.layer, fx.layer)


func test_arena_and_hud_exist_and_hidden_at_boot() -> void:
	var main: Node2D = _main()
	var arena := main.get_node(^"Arena") as Arena
	var hud := main.get_node(^"Hud") as Hud
	assert_not_null(arena)
	assert_not_null(hud)
	assert_false(arena.visible)
	assert_false(hud.visible)
	assert_eq(arena.position, Vector2(128, 16))
	assert_not_null(main.get_node_or_null(^"Entities"))
	assert_not_null(main.get_node_or_null(^"Particles"))


func test_boot_opens_title_without_smoke_query() -> void:
	var main: Node2D = _main()
	var titles: int = 0
	for child: Node in main.get_node(^"Screens").get_children():
		if child is TitleScreen:
			titles += 1
	assert_eq(titles, 1)


func _screen_of(main: Node2D) -> Node:
	return main.current_screen


func test_screen_host_exists_after_the_layers() -> void:
	var main: Node2D = _main()
	var screens := main.get_node_or_null(^"Screens") as Node2D
	assert_not_null(screens)
	assert_gt(screens.get_index(), main.get_node(^"ScreenFX").get_index())


func test_arena_and_hud_visible_only_in_fight() -> void:
	var main: Node2D = _main()
	for state: int in GameScript.FlowState.values():
		main.apply_flow_state(state, 0)
		var in_fight: bool = state == GameScript.FlowState.FIGHT
		assert_eq(main.get_node(^"Arena").visible, in_fight, "arena in state %d" % state)
		assert_eq(main.get_node(^"Hud").visible, in_fight, "hud in state %d" % state)


func test_screen_for_each_state() -> void:
	var main: Node2D = _main()
	main.apply_flow_state(GameScript.FlowState.TITLE, 0)
	assert_true(_screen_of(main) is TitleScreen)
	var labels: Dictionary[int, String] = {
		GameScript.FlowState.INTRO: "INTRO",
		GameScript.FlowState.FIGHT: "FIGHT 2",
		GameScript.FlowState.HARVEST: "HARVEST",
		GameScript.FlowState.ENDING: "ENDING",
	}
	for state: int in labels:
		var old: Node = _screen_of(main)
		main.apply_flow_state(state, 1)
		var screen := _screen_of(main) as PlaceholderScreen
		assert_not_null(screen, "placeholder for state %d" % state)
		assert_eq(screen.state, state)
		assert_eq(screen.lines[0], labels[state])
		assert_eq(screen.get_parent(), main.get_node(^"Screens"))
		assert_true(not is_instance_valid(old) or old.is_queued_for_deletion(), "old screen freed")
	main.apply_flow_state(GameScript.FlowState.DEAD, 0)
	assert_true(_screen_of(main) is DeadScreen, "DEAD shows the Process exited screen (2.9)")
	assert_eq(_screen_of(main).get_parent(), main.get_node(^"Screens"))


func test_flow_signal_swaps_screen_and_keeps_layers() -> void:
	var main: Node2D = _main()
	var arena: Node = main.get_node(^"Arena")
	var hud: Node = main.get_node(^"Hud")
	EventBus.flow_state_changed.emit(GameScript.FlowState.TITLE, GameScript.FlowState.FIGHT)
	assert_true(_screen_of(main) is PlaceholderScreen)
	assert_true(arena.visible)
	EventBus.flow_state_changed.emit(GameScript.FlowState.FIGHT, GameScript.FlowState.TITLE)
	assert_true(_screen_of(main) is TitleScreen)
	assert_false(arena.visible)
	assert_same(main.get_node(^"Arena"), arena)
	assert_same(main.get_node(^"Hud"), hud)


func _pause_screens(main: Node2D) -> int:
	var count: int = 0
	for child: Node in main.get_node(^"Pause").get_children():
		if child is PauseScreen and not child.is_queued_for_deletion():
			count += 1
	return count


func test_pause_layer_between_hud_and_screen_fx() -> void:
	var main: Node2D = _main()
	var pause := main.get_node(^"Pause") as CanvasLayer
	assert_not_null(pause)
	assert_eq(pause.layer, MainScript.PAUSE_LAYER)
	assert_gt(pause.layer, (main.get_node(^"Hud") as CanvasLayer).layer)
	assert_lt(pause.layer, (main.get_node(^"ScreenFX") as CanvasLayer).layer)
	assert_eq(_pause_screens(main), 0, "empty unless paused")


func test_pause_toggled_adds_and_frees_the_pause_screen() -> void:
	var main: Node2D = _main()
	var arena: Node = main.get_node(^"Arena")
	var hud: Node = main.get_node(^"Hud")
	EventBus.pause_toggled.emit(true)
	assert_eq(_pause_screens(main), 1)
	EventBus.pause_toggled.emit(true)
	assert_eq(_pause_screens(main), 1, "a second true does not stack overlays")
	var shown: Node = main.pause_screen
	EventBus.pause_toggled.emit(false)
	assert_eq(_pause_screens(main), 0)
	assert_true(not is_instance_valid(shown) or shown.is_queued_for_deletion())
	assert_null(main.pause_screen)
	assert_same(main.get_node(^"Arena"), arena)
	assert_same(main.get_node(^"Hud"), hud)


# --- Story 2.9: DEAD keeps the log, the HP readout, the fight-start ring ---

func test_dead_keeps_the_log_and_fight_clears_it() -> void:
	var main: Node2D = _main()
	main.apply_flow_state(GameScript.FlowState.FIGHT, 0)
	main.hud.log_panel.append_line("WARN: hp--")
	main.apply_flow_state(GameScript.FlowState.DEAD, 0)
	assert_eq(main.hud.log_panel.lines(), PackedStringArray(["WARN: hp--"]), "DEAD keeps the fight's lines")
	assert_false(main.hud.visible, "the HUD is hidden in DEAD")
	assert_false(main.arena.visible, "the arena is hidden in DEAD")
	assert_false(main.arena.health.active, "no hits while dead")
	main.apply_flow_state(GameScript.FlowState.FIGHT, 0)
	assert_eq(main.hud.log_panel.lines().size(), 0, "the next fight starts with a clean log")


func test_hp_readout_reads_the_arena_health() -> void:
	var main: Node2D = _main()
	assert_not_null(main.hp_readout)
	assert_eq(main.hp_readout.get_parent(), main.hud)
	assert_eq(main.hp_readout.health, main.arena.health)
	main.apply_flow_state(GameScript.FlowState.FIGHT, 0)
	assert_eq(main.hp_readout.current_text(), "hp: 0b11111")
	assert_eq(HpReadout.cell_for("hp: 0b11111"), Vector2i(69, 0))
	assert_eq(Hud.region_of(HpReadout.cell_for("hp: 0b11111")), &"top_bar")
	assert_lt(Hud.TOP_BAR.length(), 69, "the readout never overlaps the top bar text")


func test_fight_start_ring_prefers_the_matching_snapshot() -> void:
	var run := RunState.new()
	assert_eq(MainScript.fight_start_ring(run, 1), Register.fight_start_for_boss(1), "no snapshot: boss set")
	run.start_boss(1)
	run.fight_start_ring = PackedInt32Array([Register.Bit.DASH, Register.Bit.LOOP])
	assert_eq(MainScript.fight_start_ring(run, 1), run.fight_start_ring)
	assert_eq(MainScript.fight_start_ring(run, 0), Register.fight_start_for_boss(0), "other boss: its set")
