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


# --- Story 3.3 AC 6: the Infinite Loop's data ---

func test_infinite_loop_boss_def_matches_the_gdd() -> void:
	var def: BossDef = load("res://data/bosses/infinite_loop/boss_def.tres")
	assert_eq(def.validate(), PackedStringArray(), "valid with empty pools (D-S33-9)")
	assert_eq(def.boss_id, &"infinite_loop")
	assert_eq(def.boss_id, Game.BOSS_IDS[0])
	assert_eq(def.name_signature, "infiniteLoop")
	assert_eq(def.max_hp, 400)
	assert_eq(def.drop_bit, Register.Bit.LOOP)
	assert_eq(def.fixed_line, "for (i = 0; i < n; i++) { }")
	var ring: RingDef = load("res://data/bosses/infinite_loop/ring_def.tres")
	assert_almost_eq(def.body_radius_tiles, ring.radius_tiles(), 0.01, "fallback body circle = ring radius (D-S33-3)")
	var a := Register.Bit.ATTACK
	var d := Register.Bit.DASH
	var expected: Array = [[100, Vector2i(a, d), 120], [66, Vector2i(d, a), 90], [33, Vector2i(a, d), 60]]
	assert_eq(def.phases.size(), 3)
	for i: int in 3:
		var p: PhaseDef = def.phases[i]
		assert_eq([p.hp_threshold, p.weak_window, p.gap_frames], expected[i], "phase %d" % (i + 1))
		assert_eq(p.attack_pool.size(), 0, "no attacks until 3.4")


func test_infinite_loop_ring_def_matches_the_gdd() -> void:
	var ring: RingDef = load("res://data/bosses/infinite_loop/ring_def.tres")
	assert_eq(ring.validate(), PackedStringArray())
	assert_eq([ring.segments, ring.base_speed_tps, ring.speed_cap_tps, ring.ramp_percent, ring.drift_tps, ring.open_frames], [24, 8, 12, 5, 2, 90])
	assert_eq(ring.contact_radius_tiles, 0.5)
	assert_eq(ring.hurt_radius_tiles, 0.5)
	assert_eq(RingDef.new().validate(), PackedStringArray(), "defaults are the GDD values")


func test_ring_def_reports_each_bad_value() -> void:
	var fields: Dictionary = {
		&"segments": 12, &"base_speed_tps": 9, &"speed_cap_tps": 7, &"ramp_percent": 10,
		&"drift_tps": 0, &"open_frames": 0, &"contact_radius_tiles": 0.0, &"hurt_radius_tiles": -1.0,
	}
	for field: StringName in fields:
		var r := RingDef.new()
		r.set(field, fields[field])
		var messages: PackedStringArray = r.validate()
		var found: bool = false
		for m: String in messages:
			found = found or m.begins_with(String(field))
		assert_true(found, "%s flagged (%s)" % [field, messages])
