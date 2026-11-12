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
		# Story 3.7 (G3): the MumbleVoice resource needs the mumble_speech GDExtension.
		if path.ends_with("/duck_voice.tres") and not ClassDB.class_exists(&"MumbleVoice"):
			continue
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


## Story 5.5: the NULL bit and Null Dodge are found by the scan; the new flags are validated.
func test_null_bit_data_is_scanned_and_new_flags_validate() -> void:
	var paths: PackedStringArray = _tres_under(DATA_ROOT)
	assert_true(paths.has("res://data/bits/bit_null.tres"))
	assert_true(paths.has("res://data/actions/null_dodge.tres"))
	var a := ActionDef.new()
	a.arms_clean_catch = true
	assert_eq(a.validate().size(), 1, "arms_clean_catch without an invulnerable range")
	a.invuln_from = 1
	a.invuln_to = 1
	assert_true(a.validate().is_empty())
	var b := ActionDef.new()
	b.slows_move = true
	b.active_frames = 0
	var text: String = "\n".join(b.validate())
	assert_true(text.contains("slows_move"), text)


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
	assert_eq(def.validate(), PackedStringArray(), "valid with the 3.4 pools")
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
	var ids: Array = []
	for p: PhaseDef in def.phases:
		var phase_ids: Array[StringName] = []
		for a_def: AttackDef in p.attack_pool:
			phase_ids.append(a_def.id)
		ids.append(phase_ids)
	assert_eq(ids, [[&"head_rush"], [&"head_rush", &"constrict"], [&"head_rush", &"constrict", &"nested_loop"]], "Story 3.5 AC 1 pools (the Spit is not a pool attack)")


# --- Story 5.1 AC 15-17: the Null Pointer's data ---

func test_null_pointer_boss_def_matches_the_gdd() -> void:
	var def: BossDef = load("res://data/bosses/null_pointer/boss_def.tres")
	assert_eq(def.validate(), PackedStringArray(), "valid with the 5.3 pools")
	assert_eq(def.boss_id, &"null_pointer")
	assert_eq(def.boss_id, Game.BOSS_IDS[1])
	assert_eq(def.name_signature, "nullPointer")
	assert_eq(def.max_hp, 700)
	assert_eq(def.drop_bit, Register.Bit.NULL_BIT)
	assert_eq(def.fixed_line, "if (ptr != null) ptr.deref();")
	assert_almost_eq(def.body_radius_tiles, 1.0, 0.001, "D-S51-5")
	var a := Register.Bit.ATTACK
	var d := Register.Bit.DASH
	var l := Register.Bit.LOOP
	var expected: Array = [[100, Vector2i(d, l), 90], [50, Vector2i(a, d), 60]]
	assert_eq(def.phases.size(), 2)
	for i: int in def.phases.size():
		var p: PhaseDef = def.phases[i]
		assert_eq([p.hp_threshold, p.weak_window, p.gap_frames], expected[i], "phase %d" % (i + 1))
	# Story 5.3 (AC 5, D-S53-10): Dangling Pointers joins phase 2 only.
	var pools: Array = [[&"pointer_grab", &"null_rain"], [&"pointer_grab", &"null_rain", &"dangling_pointers"]]
	for i: int in def.phases.size():
		var ids: Array[StringName] = []
		for a_def: AttackDef in def.phases[i].attack_pool:
			ids.append(a_def.id)
		assert_eq(ids, pools[i], "Story 5.3 (D-S53-10): phase %d pool" % (i + 1))


# --- Story 5.2 AC 7, 8: the Null Pointer's attacks ---

func test_null_pointer_attack_defs_match_the_gdd() -> void:
	var expected: Dictionary = {
		"res://data/bosses/null_pointer/attack_pointer_grab.tres": [&"pointer_grab", 40, 10, 60, &"tell_pointer_grab"],
		"res://data/bosses/null_pointer/attack_null_rain.tres": [&"null_rain", 45, 20, 40, &"tell_null_rain"],
		# Story 5.3 (AC 4, D-S53-1)
		"res://data/bosses/null_pointer/attack_dangling_pointers.tres": [&"dangling_pointers", 30, 60, 30, &"tell_dangling_pointers"],
	}
	for path: String in expected:
		var a_def: AttackDef = load(path)
		assert_eq(a_def.validate(), PackedStringArray(), path)
		assert_eq([a_def.id, a_def.tell, a_def.active, a_def.recovery, a_def.tell_sfx], expected[path], path)
		assert_gte(a_def.tell, 20, "Pillar 2: tell >= 20 frames")
		assert_ne(a_def.tell_sfx, &"", "non-empty tell_sfx")
		assert_eq(a_def.recovery_if_no_breakpoint, 0, "same recovery with or without Breakpoint")
		assert_true(a_def.attack_script.new() is BossAttack)
	var def: BossDef = load("res://data/bosses/null_pointer/boss_def.tres")
	assert_same(def.phases[0].attack_pool[0], load("res://data/bosses/null_pointer/attack_pointer_grab.tres"), "the pool shares the .tres")


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


# --- Story 3.5 AC 12 (A1, A3): the phase-3 numbers on the ring ---

func test_ring_def_carries_the_phase_3_numbers() -> void:
	var ring: RingDef = load("res://data/bosses/infinite_loop/ring_def.tres")
	assert_eq(ring.validate(), PackedStringArray())
	assert_eq([ring.split_outer_segments, ring.split_inner_segments, ring.split_inner_speed_percent,
			ring.opening_period_frames, ring.spit_period_frames, ring.spit_tell_frames, ring.spit_tps, ring.spit_slots],
			[16, 8, 150, 180, 360, 20, 6, 16], "D-S35-13")
	var defaults := RingDef.new()
	assert_eq([defaults.split_outer_segments, defaults.split_inner_segments, defaults.split_inner_speed_percent,
			defaults.opening_period_frames, defaults.spit_period_frames, defaults.spit_tell_frames, defaults.spit_tps, defaults.spit_slots],
			[16, 8, 150, 180, 360, 20, 6, 16], "defaults are the GDD values")
	assert_gt(ring.opening_period_frames, 120, "the period beats the longest opening (Constrict recovery 120)")


func test_ring_def_rejects_bad_phase_3_numbers() -> void:
	var cases: Array = [
		[&"split_outer_segments", 12, "split_outer_segments"],
		[&"split_inner_segments", 6, "split_inner_segments"],
		[&"split_inner_speed_percent", 100, "split_inner_speed_percent"],
		[&"opening_period_frames", 90, "opening_period_frames"], # == open_frames
		[&"spit_period_frames", 1, "spit_period_frames"],
		[&"spit_tell_frames", 0, "spit_tell_frames"],
		[&"spit_tell_frames", 360, "spit_tell_frames"], # == period
		[&"spit_tps", 0, "spit_tps"],
		[&"spit_slots", 0, "spit_slots"],
	]
	for c: Array in cases:
		var ring := RingDef.new()
		ring.set(c[0], c[1])
		var messages: PackedStringArray = ring.validate()
		assert_gt(messages.size(), 0, "%s = %d flagged" % [c[0], c[1]])
		var found: bool = false
		for m: String in messages:
			found = found or m.begins_with(String(c[2]))
		assert_true(found, "%s = %d (%s)" % [c[0], c[1], messages])


# --- Story 3.4 AC 1 (A1, A4): the attack numbers on the ring ---

func test_ring_def_carries_the_attack_numbers() -> void:
	var ring: RingDef = load("res://data/bosses/infinite_loop/ring_def.tres")
	assert_eq([ring.head_charge_tiles, ring.constrict_chase_tps, ring.constrict_radius_tiles], [10, 8, 2], "D-S34-8")
	var player: PlayerDef = load("res://data/player/player_def.tres")
	assert_gt(float(ring.constrict_chase_tps), player.speed_tiles_s, "Constrict's chase beats the walk (D-S34-16)")


func test_ring_def_rejects_bad_attack_numbers() -> void:
	var cases: Array = [
		[&"head_charge_tiles", 0, "head_charge_tiles"],
		[&"constrict_chase_tps", 0, "constrict_chase_tps"],
		[&"constrict_radius_tiles", 0, "constrict_radius_tiles"],
		[&"constrict_radius_tiles", 4, "constrict_radius_tiles"], # >= the 3.82-tile ring radius
	]
	for c: Array in cases:
		var ring := RingDef.new()
		ring.set(c[0], c[1])
		var messages: PackedStringArray = ring.validate()
		assert_eq(messages.size(), 1, "%s = %d" % [c[0], c[1]])
		assert_true(messages.size() == 1 and messages[0].contains(c[2]))
	var ok := RingDef.new()
	ok.constrict_radius_tiles = 2
	assert_eq(ok.validate(), PackedStringArray(), "2 < 2.55 (Story 3.5: the split outer ring bounds it, D-S35-12)")
	var too_big_for_split := RingDef.new()
	too_big_for_split.constrict_radius_tiles = 3 # < 3.82 but >= the 2.55-tile split outer ring
	assert_eq(too_big_for_split.validate().size(), 1, "3 >= 2.55")


# --- Story 3.8 (G4, C1-C3): the LOOP bit; Story 4.1: its solo action is Echo, NOP stays ---

func test_bit_loop_echo_and_nop_validate_and_resolve() -> void:
	var bit := load("res://data/bits/bit_loop.tres") as BitDef
	var echo := load("res://data/actions/echo.tres") as ActionDef
	var nop := load("res://data/actions/nop.tres") as ActionDef
	assert_eq(bit.validate(), PackedStringArray())
	assert_eq(echo.validate(), PackedStringArray())
	assert_eq(nop.validate(), PackedStringArray())
	assert_eq(bit.id, Register.Bit.LOOP)
	assert_eq(bit.glyph, "L")
	assert_eq(bit.solo_action, echo, "Story 4.1: LOOP runs Echo, not NOP")
	assert_eq(echo.id, &"echo")
	assert_true(echo.echo_action)
	assert_eq(echo.cooldown_frames, 90)
	assert_eq(echo.echo_damage_pct, 70)
	assert_eq(echo.base_damage, 0)
	assert_null(echo.hit_shape)
	# NOP is kept for the Epic 6 garbage bit (NP-3), unchanged except echoable = false.
	assert_eq(nop.id, &"nop")
	assert_eq(nop.base_damage, 0)
	assert_null(nop.hit_shape)
	assert_eq(nop.cooldown_frames, 0)
	assert_eq(nop.hitstop_frames, 0)
	assert_eq(nop.total_frames(), 1)
	assert_false(nop.echoable)
	assert_not_null(Defs.bit(Register.Bit.LOOP))
	assert_eq(Defs.solo_action(Register.Bit.LOOP), Defs.ECHO)
	assert_same(Defs.solo_action(Register.Bit.NULL_BIT), Defs.NULL_DODGE, "Story 5.5: NULL is Null Dodge")
