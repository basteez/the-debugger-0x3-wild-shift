extends GutTest
## Ports the Story 1.1 Log format check through the pure helpers (DC5, no stdout capture).

const LogScript := preload("res://src/autoloads/log.gd")


func test_log_info_format_boot_line() -> void:
	assert_eq(LogScript.format_line(&"INFO", &"flow", "boot", 0), "[f=0][INFO][flow] boot")


func test_log_frame_number_in_prefix() -> void:
	assert_eq(LogScript.format_line(&"INFO", &"flow", "boot", 1234), "[f=1234][INFO][flow] boot")


func test_log_warn_and_error_same_shape() -> void:
	assert_eq(LogScript.format_line(&"WARN", &"save", "slow", 7), "[f=7][WARN][save] slow")
	assert_eq(LogScript.format_line(&"ERROR", &"save", "lost", 7), "[f=7][ERROR][save] lost")


func test_log_debug_suppressed_when_debug_disabled() -> void:
	assert_false(LogScript.emits(&"DEBUG", false))
	assert_true(LogScript.emits(&"DEBUG", true))


func test_log_non_debug_levels_always_emitted() -> void:
	for level: StringName in [&"INFO", &"WARN", &"ERROR"]:
		assert_true(LogScript.emits(level, false), "%s suppressed with debug off" % level)
