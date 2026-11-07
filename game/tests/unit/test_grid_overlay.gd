extends GutTest
## Story 1.5 AC2/DC7: the F9 grid overlay action, default visibility and the debug gate.


func test_debug_grid_action_bound_to_f9() -> void:
	assert_true(InputMap.has_action(&"debug_grid"))
	var found: bool = false
	for ev: InputEvent in InputMap.action_get_events(&"debug_grid"):
		var key := ev as InputEventKey
		if key != null and key.physical_keycode == KEY_F9:
			found = true
	assert_true(found, "debug_grid is not bound to physical F9")


func test_overlay_hidden_by_default() -> void:
	var hud: Hud = (load("res://src/ui/hud/hud.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	assert_false(hud.get_node(^"GridOverlay").visible)


func test_gate_release_build_without_debug_is_closed() -> void:
	assert_false(Hud.grid_toggle_allowed(false, ""))
	assert_false(Hud.grid_toggle_allowed(false, "?smoke=arena"))
	assert_false(Hud.grid_toggle_allowed(false, "?debug=0"))
	assert_false(Hud.grid_toggle_allowed(false, "?debugger"))


func test_gate_open_in_debug_build_or_with_debug_query() -> void:
	assert_true(Hud.grid_toggle_allowed(true, ""))
	assert_true(Hud.grid_toggle_allowed(false, "?debug"))
	assert_true(Hud.grid_toggle_allowed(false, "?debug&smoke=arena"))


func test_f9_toggles_overlay_when_hud_visible() -> void:
	var hud: Hud = (load("res://src/ui/hud/hud.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	var ev := InputEventAction.new()
	ev.action = &"debug_grid"
	ev.pressed = true
	# GUT runs a debug build, so the gate is open.
	hud._unhandled_input(ev)
	assert_true(hud.get_node(^"GridOverlay").visible)
	hud._unhandled_input(ev)
	assert_false(hud.get_node(^"GridOverlay").visible)
	hud.visible = false
	hud._unhandled_input(ev)
	assert_false(hud.get_node(^"GridOverlay").visible, "ignored while the HUD is hidden")
