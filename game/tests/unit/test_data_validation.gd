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


## Review 2.5: a chain_next cycle is rejected.
func test_action_def_chain_cycle_is_invalid() -> void:
	var a := ActionDef.new()
	var b := ActionDef.new()
	a.chain_next = b
	b.chain_next = a
	assert_false(a.validate().is_empty(), "cycle must be flagged")
	b.chain_next = null
	assert_true(a.validate().is_empty())


# --- Story 3.2 (C7, D-S32-16): weak windows and name_signature rules ---

func _valid_boss() -> BossDef:
	var pulse: AttackDef = load("res://data/bosses/test_boss/attack_pulse.tres")
	var sweep: AttackDef = load("res://data/bosses/test_boss/attack_sweep.tres")
	var p := PhaseDef.new()
	p.hp_threshold = 100
	p.weak_window = Vector2i(Register.Bit.ATTACK, Register.Bit.DASH)
	p.attack_pool = [pulse, sweep]
	var d := BossDef.new()
	d.boss_id = &"unit_boss"
	d.name_signature = "unitBoss"
	d.max_hp = 10
	d.phases = [p]
	return d


func _boss_messages_contain(d: BossDef, needle: String) -> bool:
	for m: String in d.validate():
		if m.contains(needle):
			return true
	return false


func test_test_boss_weak_windows() -> void:
	var def: BossDef = load("res://data/bosses/test_boss/boss_def.tres")
	assert_eq(def.phases[0].weak_window, Vector2i(Register.Bit.ATTACK, Register.Bit.DASH), "phase 1 A>D")
	assert_eq(def.phases[1].weak_window, Vector2i(Register.Bit.DASH, Register.Bit.ATTACK), "phase 2 D>A")
	assert_eq(def.max_hp, 20)
	assert_eq(def.validate(), PackedStringArray())


func test_boss_def_weak_window_rules() -> void:
	assert_eq(_valid_boss().validate(), PackedStringArray())
	for bad: Vector2i in [Vector2i.ZERO, Vector2i(1, 1), Vector2i(1, 0), Vector2i(9, 2), Vector2i(2, -1)]:
		var d: BossDef = _valid_boss()
		d.phases[0].weak_window = bad
		assert_true(_boss_messages_contain(d, "weak_window"), "rejects %s" % bad)
	assert_true(BossDef.is_valid_weak_window(Vector2i(Register.Bit.LOOP, Register.Bit.NULL_BIT)))


func test_boss_def_name_signature_rules() -> void:
	var ok: BossDef = _valid_boss()
	ok.name_signature = "abcdefghijklmnop" # 16
	assert_eq(ok.validate(), PackedStringArray())
	for bad: String in ["abcdefghijklmnopq", "infinite loop", "9lives", "loop()"]:
		var d: BossDef = _valid_boss()
		d.name_signature = bad
		assert_true(_boss_messages_contain(d, "name_signature"), "rejects \"%s\"" % bad)
