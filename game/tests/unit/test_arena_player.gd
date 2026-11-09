extends GutTest
## Story 2.2 D2/D3: the Arena owns the player, registers it with SimClock while in the tree, and
## Main activates it only in FIGHT (every route), resetting it to the spawn.

const MainScene := preload("res://src/main/main.tscn")
const GameScript := preload("res://src/autoloads/game.gd")


func test_arena_spawn_is_play_area_centre() -> void:
	assert_eq(Arena.SPAWN_PX, Vector2(256, 144))


func test_player_bounds_keep_the_glyph_inside_the_play_area() -> void:
	assert_eq(Arena.player_bounds(), Rect2(8, 8, 496, 272))


func test_arena_player_uses_player_bounds() -> void:
	var arena := Arena.new()
	assert_eq(arena.player.bounds_px, Arena.player_bounds())
	arena.free()


func test_enter_and_leave_fight() -> void:
	var arena := Arena.new()
	arena.player.position_px = Vector2(10, 10)
	arena.player.facing = Vector2i(-1, 0)
	arena.enter_fight()
	assert_true(arena.player.active)
	assert_eq(arena.player.position_px, Vector2(256, 144))
	assert_eq(arena.player.facing, Vector2i(1, 0))
	arena.leave_fight()
	assert_false(arena.player.active)
	arena.free()


func test_main_activates_player_only_in_fight() -> void:
	var main: Node2D = MainScene.instantiate()
	add_child_autofree(main)
	var arena := main.get_node(^"Arena") as Arena
	assert_not_null(arena.get_node_or_null(^"PlayerView"), "view attached under the arena")
	assert_false(arena.player.active, "inactive on the title")
	arena.player.position_px = Vector2(20, 20)
	main.apply_flow_state(GameScript.FlowState.FIGHT, 0)
	assert_true(arena.player.active)
	assert_eq(arena.player.position_px, Vector2(256, 144), "reset on FIGHT entry")
	main.apply_flow_state(GameScript.FlowState.HARVEST, 0)
	assert_false(arena.player.active)


func test_main_registers_and_unregisters_player() -> void:
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	var arena := main.get_node(^"Arena") as Arena
	var systems: Array = SimClock.get(&"_systems")
	assert_true(systems.has(arena.player), "registered while in the tree")
	remove_child(main)
	assert_false((SimClock.get(&"_systems") as Array).has(arena.player), "unregistered on exit")
	main.free()
