extends GutTest
## Guards the Web export preset keys (Story 1.3 AC1) so an editor re-save cannot drop them.

const PRESET_PATH := "res://export_presets.cfg"
const OPTIONS := "preset.0.options"

var _cfg: ConfigFile


func before_each() -> void:
	_cfg = ConfigFile.new()
	assert_eq(_cfg.load(PRESET_PATH), OK, "export_presets.cfg must load")


func _excludes() -> PackedStringArray:
	var out := PackedStringArray()
	for raw: String in str(_cfg.get_value("preset.0", "exclude_filter", "")).split(","):
		var pattern := raw.strip_edges()
		if not pattern.is_empty():
			out.append(pattern)
	return out


func test_preset_is_web() -> void:
	assert_eq(_cfg.get_value("preset.0", "name", ""), "Web")
	assert_eq(_cfg.get_value("preset.0", "platform", ""), "Web")


func test_thread_support_off() -> void:
	assert_true(_cfg.has_section_key(OPTIONS, "variant/thread_support"), "key must be explicit")
	assert_eq(_cfg.get_value(OPTIONS, "variant/thread_support", true), false)


func test_extensions_support_on() -> void:
	assert_true(_cfg.has_section_key(OPTIONS, "variant/extensions_support"), "key must be explicit")
	assert_eq(_cfg.get_value(OPTIONS, "variant/extensions_support", false), true)


func test_vram_desktop_only() -> void:
	assert_true(_cfg.has_section_key(OPTIONS, "vram_texture_compression/for_desktop"), "key must be explicit")
	assert_true(_cfg.has_section_key(OPTIONS, "vram_texture_compression/for_mobile"), "key must be explicit")
	assert_eq(_cfg.get_value(OPTIONS, "vram_texture_compression/for_desktop", false), true)
	assert_eq(_cfg.get_value(OPTIONS, "vram_texture_compression/for_mobile", true), false)


func test_exclude_filter_has_gut_tests_tools() -> void:
	var excludes := _excludes()
	for pattern: String in ["addons/gut/*", "tests/*", "tools/*"]:
		assert_has(excludes, pattern, "exclude_filter must contain %s" % pattern)


func test_exclude_filter_has_gopeak_runtime() -> void:
	assert_has(_excludes(), "addons/godot_mcp_runtime/*", "GoPeak runtime addon must stay out of the export")


func test_exclude_filter_has_gopeak_editor_and_auto_reload() -> void:
	for pattern: String in ["addons/godot_mcp_editor/*", "addons/auto_reload/*"]:
		assert_has(_excludes(), pattern, "exclude_filter must contain %s" % pattern)


func test_no_committed_custom_template_path() -> void:
	# A machine-specific stripped-template path must never be committed (CI installs it as the stock file name).
	assert_eq(_cfg.get_value(OPTIONS, "custom_template/release", ""), "")
	assert_eq(_cfg.get_value(OPTIONS, "custom_template/debug", ""), "")
