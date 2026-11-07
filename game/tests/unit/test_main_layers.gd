extends GutTest
## Story 1.5 AC2/DC8/DC9: Main's render layer order and boot visibility.

const MainScene := preload("res://src/main/main.tscn")
const MainScript := preload("res://src/main/main.gd")


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
	for child: Node in main.get_children():
		if child is TitleScreen:
			titles += 1
	assert_eq(titles, 1)


func test_wants_arena_smoke() -> void:
	assert_true(MainScript.wants_arena_smoke("?debug&smoke=arena"))
	assert_true(MainScript.wants_arena_smoke("?smoke=arena&debug=1"))
	assert_false(MainScript.wants_arena_smoke("?smoke=arena"))
	assert_false(MainScript.wants_arena_smoke("?debug&smoke=audio"))
	assert_false(MainScript.wants_arena_smoke("?debug=false&smoke=arena"))
	assert_false(MainScript.wants_arena_smoke("?debug&smoke=arenax"))
	assert_false(MainScript.wants_audio_smoke("?debug&smoke=arena"))


func test_show_arena_reveals_arena_and_hud() -> void:
	var main: Node2D = _main()
	main.show_arena(true)
	assert_true(main.get_node(^"Arena").visible)
	assert_true(main.get_node(^"Hud").visible)
