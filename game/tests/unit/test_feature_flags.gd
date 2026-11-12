extends GutTest
## Story 4.3 (AC 1, D-S43-1, D-S43-17): FeatureFlags, its shipped .tres and the Defs preload.

const FLAGS_PATH := "res://data/config/feature_flags.tres"


func test_shipped_flags_are_all_on_and_valid() -> void:
	var flags := load(FLAGS_PATH) as FeatureFlags
	assert_not_null(flags)
	assert_true(flags.reserved_write)
	assert_true(flags.watch)
	assert_true(flags.breakpoint_enabled)
	assert_true(flags.segfault)
	assert_eq(flags.validate().size(), 0)


func test_defs_preloads_the_shipped_flags() -> void:
	assert_not_null(Defs.FEATURE_FLAGS)
	assert_eq(Defs.FEATURE_FLAGS.resource_path, FLAGS_PATH)
	assert_true(Defs.FEATURE_FLAGS is Def, "a Def, so test_data_validation covers it")


func test_defaults_are_on() -> void:
	var flags := FeatureFlags.new()
	assert_true(flags.reserved_write and flags.watch and flags.breakpoint_enabled and flags.segfault)


func test_feature_flags_does_not_reference_defs() -> void:
	var text: String = FileAccess.get_file_as_string("res://src/core/feature_flags.gd")
	var regex := RegEx.create_from_string("^[^#]*\\bDefs\\b")
	for line: String in text.split("\n"):
		assert_null(regex.search(line), "no Defs reference (preload cycle, 4.2 lesson): %s" % line)


## Story 5.6 (C5, D-S56-8): the four cut-ladder flags exist, ship on, and the comments follow the GDD
## ladder (#1 reserved_write, #2 watch, #3 breakpoint, #4 segfault).
func test_four_cut_ladder_flags_exist_and_are_numbered_like_the_gdd() -> void:
	var flags := load(FLAGS_PATH) as FeatureFlags
	for flag: StringName in [&"reserved_write", &"watch", &"breakpoint_enabled", &"segfault"]:
		assert_true(flag in flags, String(flag))
		assert_true(flags.get(flag), "%s ships on" % flag)
	var text: String = FileAccess.get_file_as_string("res://src/core/feature_flags.gd")
	var order: Array[String] = []
	for line: String in text.split("\n"):
		var m: RegExMatch = RegEx.create_from_string("^## Cut #(\\d)").search(line)
		if m != null:
			order.append(m.get_string(1))
	assert_eq(order, ["1", "2", "3", "4"] as Array[String], "declared in ladder order")
