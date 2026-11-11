extends GutTest
## Story 5.4 (AC 1, 2, 12-17, 25): wiring of the Watch module. Flag on: Arena builds and registers it,
## fight entry resets it with the unlock rule, retry and leaving FIGHT release it, Main adds the
## read-out overlay and hands the register panel the skill. Flag off: nothing is built, no views.
## Leaf rule: no file under src/ outside src/skills/watch/ names the module's classes.

const MainScene := preload("res://src/main/main.tscn")
const LEAF_DIR := "res://src/skills/watch/"


## R held on every poll.
class HoldR:
	extends InputSource

	func watch_held_for_frame() -> bool:
		return true


var _saved_source: InputSource


func before_each() -> void:
	_saved_source = SimClock.input_source
	SimClock.paused = false


func after_each() -> void:
	SimClock.input_source = _saved_source
	SimClock.watch_gate_active = false
	SimClock.ctx.watch_held = false
	SimClock.begin_fight(0)


func _flags(on: bool) -> FeatureFlags:
	var f := FeatureFlags.new()
	f.watch = on
	return f


func _arena(on: bool) -> Arena:
	var arena := Arena.new()
	arena.set_watch_enabled(on)
	add_child_autofree(arena)
	return arena


func test_arena_default_follows_the_shipped_flag() -> void:
	var arena := Arena.new()
	assert_eq(arena.watch_enabled, Defs.FEATURE_FLAGS.watch)
	assert_eq(arena.watch_skill != null, Defs.FEATURE_FLAGS.watch, "built only when on")
	arena.free()


func test_flag_on_arena_registers_and_resets_the_skill() -> void:
	var arena := _arena(true)
	assert_not_null(arena.watch_skill)
	assert_eq(arena.watch_skill.get_script().resource_path, Arena.WATCH_SKILL_PATH)
	assert_true(SimClock.get(&"_systems").has(arena.watch_skill))
	arena.enter_fight(Register.fight_start_for_boss(1), false, "", true, true)
	assert_true(arena.watch_skill.is_unlocked())
	arena.enter_fight(Register.fight_start_for_boss(0), false, "", false, false)
	assert_false(arena.watch_skill.is_unlocked(), "Boss 1 is locked")


func test_held_r_reaches_the_sim_and_leave_fight_releases() -> void:
	var arena := _arena(true)
	arena.enter_fight(Register.fight_start_for_boss(1), false, "", true, true)
	SimClock.input_source = HoldR.new()
	watch_signals(EventBus)
	SimClock.tick()
	assert_true(arena.watch_skill.is_active())
	assert_true(SimClock.watch_gate_active)
	assert_true(SimClock.ctx.watch_held)
	assert_eq(arena.actions.state, ActionStateMachine.ActionState.WATCHING)
	arena.leave_fight()
	assert_false(SimClock.watch_gate_active, "leaving FIGHT releases Watch")
	assert_signal_emit_count(EventBus, "watch_started", 1)
	assert_signal_emit_count(EventBus, "watch_ended", 1)


func test_retry_entry_releases_a_held_watch() -> void:
	var arena := _arena(true)
	arena.enter_fight(Register.fight_start_for_boss(1), false, "", true, true)
	SimClock.input_source = HoldR.new()
	SimClock.tick()
	watch_signals(EventBus)
	arena.enter_fight(Register.fight_start_for_boss(1), false, "", true, true)
	assert_false(arena.watch_skill.is_active())
	assert_false(SimClock.watch_gate_active)
	assert_signal_emit_count(EventBus, "watch_ended", 1)


func test_locked_fight_r_does_nothing() -> void:
	var arena := _arena(true)
	arena.enter_fight(Register.fight_start_for_boss(0), false, "", false, false)
	SimClock.input_source = HoldR.new()
	SimClock.tick()
	assert_false(SimClock.watch_gate_active)
	assert_eq(arena.actions.state, ActionStateMachine.ActionState.IDLE_MOVE)


func test_flag_off_arena_builds_nothing() -> void:
	var arena := _arena(false)
	assert_null(arena.watch_skill)
	for s: SimSystem in SimClock.get(&"_systems"):
		assert_false(s.get_script().resource_path == Arena.WATCH_SKILL_PATH, "no Watch skill registered")


func test_flag_toggle_off_drops_a_held_skill() -> void:
	var arena := _arena(true)
	arena.enter_fight(Register.fight_start_for_boss(1), false, "", true, true)
	SimClock.input_source = HoldR.new()
	SimClock.tick()
	var skill: FightSkill = arena.watch_skill
	arena.set_watch_enabled(false)
	assert_null(arena.watch_skill)
	assert_false(SimClock.watch_gate_active)
	assert_false(SimClock.get(&"_systems").has(skill))


func test_main_flag_on_adds_overlay_and_panel_wiring() -> void:
	var main: Node2D = MainScene.instantiate()
	main.feature_flags = _flags(true)
	add_child_autofree(main)
	assert_not_null(main.arena.watch_skill)
	assert_not_null(main.watch_overlay)
	assert_eq(main.watch_overlay.get_parent(), main.arena)
	assert_eq(main.watch_overlay.get(&"skill"), main.arena.watch_skill)
	assert_eq(main.watch_overlay.get_script().resource_path, Arena.WATCH_SKILL_PATH.replace("watch_skill", "watch_overlay"))
	assert_eq(main.hud.register_panel.watch_skill, main.arena.watch_skill)
	assert_true(main.hud.register_panel.weak_window_source.is_valid())


func test_main_flag_off_has_no_views_and_no_skill() -> void:
	var main: Node2D = MainScene.instantiate()
	main.feature_flags = _flags(false)
	add_child_autofree(main)
	assert_null(main.arena.watch_skill)
	assert_null(main.watch_overlay)
	assert_null(main.arena.get_node_or_null(^"WatchReadouts"))
	assert_null(main.hud.register_panel.watch_skill)


func test_feature_flags_still_does_not_reference_defs() -> void:
	var text: String = FileAccess.get_file_as_string("res://src/core/feature_flags.gd")
	assert_ne(text, "")
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		assert_false(line.contains("Defs"), "4.2 lesson: no preload cycle")


## AC 15 (D-S54-3): the leaf rule, also enforced by check_guards.sh.
func test_no_class_reference_outside_the_leaf() -> void:
	var regex := RegEx.create_from_string("\\b(WatchSkill|WatchOverlay)\\b")
	for path: String in _gd_under("res://src/"):
		if path.begins_with(LEAF_DIR):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			assert_null(regex.search(line), "%s names the Watch module: %s" % [path, line.strip_edges()])


func _gd_under(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_gd_under(dir.path_join(sub)))
	return out
