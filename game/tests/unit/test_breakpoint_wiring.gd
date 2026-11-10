extends GutTest
## Story 4.3 (AC 2, 3, 12, 13): wiring of the Breakpoint module. Flag on: Arena builds and registers
## it, Main adds the overlay and HUD readout, fight entry resets it, leaving clears the gate. Flag
## off: nothing is built, Space does nothing, no events, bosses get breakpoint_on = false. Leaf rule:
## no file under src/ outside src/skills/breakpoint/ names the module's classes.

const MainScene := preload("res://src/main/main.tscn")
const GameScript := preload("res://src/autoloads/game.gd")
const LEAF_DIR := "res://src/skills/breakpoint/"


## Space on every poll.
class SpaceInput:
	extends InputSource

	func presses_for_frame() -> Array[StringName]:
		return [&"breakpoint"] as Array[StringName]


var _saved_source: InputSource


func before_each() -> void:
	_saved_source = SimClock.input_source
	SimClock.paused = false


func after_each() -> void:
	SimClock.input_source = _saved_source
	SimClock.breakpoint_gate_active = false
	SimClock.begin_fight(0)


func _flags(on: bool) -> FeatureFlags:
	var f := FeatureFlags.new()
	f.breakpoint_enabled = on
	return f


func _arena(on: bool) -> Arena:
	var arena := Arena.new()
	arena.set_breakpoint_enabled(on)
	add_child_autofree(arena)
	return arena


func test_arena_default_follows_the_shipped_flag() -> void:
	var arena := Arena.new()
	assert_eq(arena.breakpoint_enabled, Defs.FEATURE_FLAGS.breakpoint_enabled)
	assert_eq(arena.breakpoint_skill != null, Defs.FEATURE_FLAGS.breakpoint_enabled, "built only when on")
	arena.free()


func test_flag_on_arena_registers_and_resets_the_skill() -> void:
	var arena := _arena(true)
	assert_not_null(arena.breakpoint_skill)
	assert_true(SimClock.get(&"_systems").has(arena.breakpoint_skill))
	arena.enter_fight(Register.fight_start_for_boss(1), false, "", true)
	assert_true(arena.breakpoint_skill.is_unlocked())
	assert_eq(arena.breakpoint_skill.cooldown_left_frames(), 0)
	arena.enter_fight(Register.fight_start_for_boss(0), false, "", false)
	assert_false(arena.breakpoint_skill.is_unlocked(), "Fight 1 is locked")


func test_flag_on_space_starts_and_leave_fight_clears_the_gate() -> void:
	var arena := _arena(true)
	arena.enter_fight(Register.fight_start_for_boss(1), false, "", true)
	SimClock.input_source = SpaceInput.new()
	watch_signals(EventBus)
	SimClock.tick()
	assert_true(arena.breakpoint_skill.is_active())
	assert_true(SimClock.breakpoint_gate_active)
	arena.leave_fight()
	assert_false(SimClock.breakpoint_gate_active, "leaving the fight never stays frozen (AC 12)")
	assert_signal_emit_count(EventBus, "breakpoint_ended", 1)


func test_retry_entry_resets_a_running_breakpoint() -> void:
	var arena := _arena(true)
	arena.enter_fight(Register.fight_start_for_boss(1), false, "", true)
	SimClock.input_source = SpaceInput.new()
	SimClock.tick()
	watch_signals(EventBus)
	arena.enter_fight(Register.fight_start_for_boss(1), false, "", true)
	assert_false(arena.breakpoint_skill.is_active())
	assert_false(SimClock.breakpoint_gate_active)
	assert_signal_emit_count(EventBus, "breakpoint_ended", 1)


func test_flag_off_arena_builds_nothing_and_space_does_nothing() -> void:
	var arena := _arena(false)
	assert_null(arena.breakpoint_skill)
	for s: SimSystem in SimClock.get(&"_systems"):
		assert_false(s is FightSkill, "no skill registered")
	arena.enter_fight(Register.fight_start_for_boss(1), false, Arena.TEST_BOSS_DEF_PATH, true)
	assert_false(arena.boss.breakpoint_on, "the SIGSEGV fallback sees the flag off")
	SimClock.input_source = SpaceInput.new()
	watch_signals(EventBus)
	var before: int = SimClock.sim_frame
	SimClock.tick()
	SimClock.tick()
	assert_false(SimClock.breakpoint_gate_active)
	assert_eq(SimClock.sim_frame, before + 2, "the world keeps ticking")
	assert_signal_emit_count(EventBus, "breakpoint_started", 0)
	assert_signal_emit_count(EventBus, "breakpoint_ended", 0)


func test_flag_toggle_off_drops_a_running_skill() -> void:
	var arena := _arena(true)
	arena.enter_fight(Register.fight_start_for_boss(1), false, Arena.TEST_BOSS_DEF_PATH, true)
	assert_true(arena.boss.breakpoint_on)
	SimClock.input_source = SpaceInput.new()
	SimClock.tick()
	var skill: FightSkill = arena.breakpoint_skill
	arena.set_breakpoint_enabled(false)
	assert_null(arena.breakpoint_skill)
	assert_false(SimClock.breakpoint_gate_active)
	assert_false(SimClock.get(&"_systems").has(skill))
	assert_false(arena.boss.breakpoint_on)


func test_main_flag_on_adds_overlay_and_readout() -> void:
	var main: Node2D = MainScene.instantiate()
	main.feature_flags = _flags(true)
	add_child_autofree(main)
	assert_not_null(main.breakpoint_overlay)
	assert_eq(main.breakpoint_overlay.get_parent(), main.arena)
	assert_not_null(main.breakpoint_readout)
	assert_eq(main.breakpoint_readout.get_parent(), main.hud)
	assert_eq(main.breakpoint_readout.skill, main.arena.breakpoint_skill)


func test_main_flag_off_has_no_views_and_no_skill() -> void:
	var main: Node2D = MainScene.instantiate()
	main.feature_flags = _flags(false)
	add_child_autofree(main)
	assert_null(main.arena.breakpoint_skill)
	assert_null(main.breakpoint_overlay)
	assert_null(main.breakpoint_readout)
	assert_null(main.arena.get_node_or_null(^"BreakpointWarning"))
	assert_null(main.hud.get_node_or_null(^"BreakpointReadout"))


func test_unlock_rule() -> void:
	var MainScript: GDScript = load("res://src/main/main.gd")
	assert_false(MainScript.breakpoint_unlocked_for(0))
	assert_true(MainScript.breakpoint_unlocked_for(1))
	assert_true(MainScript.breakpoint_unlocked_for(2))


## AC 2 (D-S43-2): the leaf rule, also enforced by check_guards.sh.
func test_no_class_reference_outside_the_leaf() -> void:
	var regex := RegEx.create_from_string("\\b(BreakpointSkill|BreakpointOverlay)\\b")
	for path: String in _gd_under("res://src/"):
		if path.begins_with(LEAF_DIR):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			assert_null(regex.search(line), "%s names the Breakpoint module: %s" % [path, line.strip_edges()])


func _gd_under(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_gd_under(dir.path_join(sub)))
	return out
