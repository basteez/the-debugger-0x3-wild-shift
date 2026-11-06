extends GutTest
## Ports the Story 1.1 autoload order and presence checks.

const EXPECTED_ORDER: Array[String] = [
	"Log", "EventBus", "SimClock", "Game", "Debug", "AudioManager", "VoiceService", "SaveService",
]


## Autoload names from the raw [autoload] section, in file order (DC4).
func _autoload_names_in_file_order() -> Array[String]:
	var names: Array[String] = []
	var text := FileAccess.get_file_as_string("res://project.godot")
	var in_section := false
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("["):
			in_section = line == "[autoload]"
			continue
		if in_section and line.contains("="):
			names.append(line.get_slice("=", 0).strip_edges())
	return names


func test_autoload_order_log_first_to_save_service() -> void:
	assert_eq(_autoload_names_in_file_order(), EXPECTED_ORDER)


func test_autoloads_present_at_runtime() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	for autoload_name: String in EXPECTED_ORDER:
		assert_true(root.has_node(autoload_name), "autoload %s not mounted under root" % autoload_name)
