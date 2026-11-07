extends GutTest
## Story 1.6 AC4/AC5/AC8: the single debug gate, Debug.gate_enabled(is_debug_build, search).

const DebugScript := preload("res://src/autoloads/debug.gd")


func test_release_build_needs_a_debug_key() -> void:
	assert_true(DebugScript.gate_enabled(false, "?debug"))
	assert_true(DebugScript.gate_enabled(false, "?debug&smoke=x"))
	assert_true(DebugScript.gate_enabled(false, "?smoke=x&debug=1"))


func test_release_build_rejects_off_or_lookalike_keys() -> void:
	assert_false(DebugScript.gate_enabled(false, ""))
	assert_false(DebugScript.gate_enabled(false, "?debug=0"))
	assert_false(DebugScript.gate_enabled(false, "?debug=false"))
	assert_false(DebugScript.gate_enabled(false, "?debugger"))
	assert_false(DebugScript.gate_enabled(false, "?nodebug"))
	assert_false(DebugScript.gate_enabled(false, "?smoke=audio"))


func test_debug_build_is_always_enabled() -> void:
	assert_true(DebugScript.gate_enabled(true, ""))
	assert_true(DebugScript.gate_enabled(true, "?debug=0"))


func test_autoload_flag_matches_the_gate_for_this_run() -> void:
	assert_eq(Debug.enabled, DebugScript.gate_enabled(OS.is_debug_build(), UrlQuery.web_search()))
