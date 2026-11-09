extends GutTest
## Story 2.2 AC1: every .tres under res://data/ validates clean, and PlayerDef reports bad values.

const DATA_ROOT := "res://data/"
const PLAYER_DEF_PATH := "res://data/player/player_def.tres"


## Recursive list of .tres paths under `dir` (sorted for stable output).
func _tres_under(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file: String in DirAccess.get_files_at(dir):
		# Exported builds list remapped files; strip the suffix so load() resolves them.
		var name: String = file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			out.append(dir.path_join(name))
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_tres_under(dir.path_join(sub)))
	out.sort()
	return out


func test_every_data_resource_validates() -> void:
	var paths: PackedStringArray = _tres_under(DATA_ROOT)
	assert_true(paths.has(PLAYER_DEF_PATH), "player_def.tres is found by the scan")
	for path: String in paths:
		var res: Resource = load(path)
		assert_not_null(res, "loads: %s" % path)
		if res != null and res.has_method(&"validate"):
			var messages: PackedStringArray = res.call(&"validate")
			assert_eq(messages.size(), 0, "%s: %s" % [path, ", ".join(messages)])


func test_player_def_tres_has_gdd_values() -> void:
	var def := load(PLAYER_DEF_PATH) as PlayerDef
	assert_not_null(def)
	assert_almost_eq(def.speed_tiles_s, 7.0, 0.0001)
	assert_eq(def.accel_frames, 4)
	assert_eq(def.decel_frames, 3)
	assert_eq(def.max_hp, 5)
	assert_eq(def.invuln_frames, 60)
	assert_almost_eq(def.hurtbox_tiles, 0.6, 0.0001)


func test_default_player_def_is_valid() -> void:
	assert_eq(PlayerDef.new().validate().size(), 0)


func test_def_base_validates_empty() -> void:
	assert_eq(Def.new().validate().size(), 0)


func _messages_for(field: StringName, value: Variant) -> PackedStringArray:
	var def := PlayerDef.new()
	def.set(field, value)
	return def.validate()


func test_player_def_reports_each_bad_value() -> void:
	var cases: Array[Array] = [
		[&"speed_tiles_s", 0.0, "speed_tiles_s"],
		[&"speed_tiles_s", -1.0, "speed_tiles_s"],
		[&"accel_frames", 0, "accel_frames"],
		[&"decel_frames", 0, "decel_frames"],
		[&"max_hp", 0, "max_hp"],
		[&"invuln_frames", -1, "invuln_frames"],
		[&"hurtbox_tiles", 0.0, "hurtbox_tiles"],
		[&"hurtbox_tiles", 1.5, "hurtbox_tiles"],
	]
	for c: Array in cases:
		var messages: PackedStringArray = _messages_for(c[0], c[1])
		assert_eq(messages.size(), 1, "%s = %s" % [c[0], c[1]])
		if messages.size() == 1:
			assert_string_contains(messages[0], c[2])


func test_player_def_edge_values_are_valid() -> void:
	assert_eq(_messages_for(&"invuln_frames", 0).size(), 0)
	assert_eq(_messages_for(&"hurtbox_tiles", 1.0).size(), 0)
	assert_eq(_messages_for(&"accel_frames", 1).size(), 0)
