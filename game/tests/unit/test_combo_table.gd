extends GutTest
## Story 2.6 AC1, AC9: ComboDef / ComboTable data and the ordered lookup (never sorted).

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT
const TILE := Const.TILE_PX


func _combo(first: int, second: int, name: String = "Test") -> ComboDef:
	var c := ComboDef.new()
	c.first = first
	c.second = second
	c.action = Defs.DASH_STRIKE
	c.display_name = name
	return c


func test_a_then_d_is_dash_strike() -> void:
	var c: ComboDef = Defs.COMBOS.get_combo(A, D)
	assert_not_null(c)
	if c == null:
		return
	assert_eq(c.display_name, "Dash Strike")
	assert_eq(c.action, Defs.DASH_STRIKE)
	assert_eq(c.first, A)
	assert_eq(c.second, D)


func test_d_then_a_is_no_combo() -> void:
	assert_null(Defs.COMBOS.get_combo(D, A), "ordered: [D, A] has no combo")


func test_lookup_is_never_sorted() -> void:
	var t := ComboTable.new()
	t.combos = [_combo(D, A)]
	assert_not_null(t.get_combo(D, A))
	assert_null(t.get_combo(A, D), "the reversed pair is a different window")
	assert_ne(ComboTable.key(A, D), ComboTable.key(D, A))


func test_unknown_pairs_are_null() -> void:
	# Story 4.2 (AC 8c): (D, L) dropped, it is now Echo Dash. Story 6.1: (L, N) is Ghost Echo.
	# Story 6.2: (N, A) is Dereference.
	for pair: Vector2i in [Vector2i(L, A), Vector2i(0, 0), Vector2i(A, A)]:
		assert_null(Defs.COMBOS.get_combo(pair.x, pair.y), "%s" % pair)


func test_shipped_table_validates() -> void:
	assert_eq(Defs.COMBOS.validate(), PackedStringArray())
	for c: ComboDef in Defs.COMBOS.combos:
		assert_eq(c.validate(), PackedStringArray(), c.display_name)


func test_duplicate_ordered_pair_rejected() -> void:
	var t := ComboTable.new()
	t.combos = [_combo(A, D), _combo(A, D, "Other")]
	assert_eq(t.validate().size(), 1)
	var ok := ComboTable.new()
	ok.combos = [_combo(A, D), _combo(D, A)]
	assert_eq(ok.validate().size(), 0, "the reversed pair is not a duplicate")


func test_combo_def_rules() -> void:
	assert_eq(_combo(A, D, "Dash Strike").validate().size(), 0, "11 characters is the limit")
	assert_eq(_combo(A, D, "Dash Strikes").validate().size(), 1, "12 characters")
	assert_eq(_combo(A, D, "").validate().size(), 1, "empty name")
	assert_gt(_combo(A, A).validate().size(), 0, "same bit twice")
	assert_gt(_combo(0, D).validate().size(), 0, "unknown first bit")
	var no_action: ComboDef = _combo(A, D)
	no_action.action = null
	assert_gt(no_action.validate().size(), 0)


func test_dash_strike_frame_data() -> void:
	var def: ActionDef = Defs.DASH_STRIKE
	assert_eq(def.id, &"dash_strike")
	assert_eq(def.startup_frames, 0)
	assert_eq(def.active_frames, 12)
	assert_eq(def.recovery_frames, 8)
	assert_eq(def.total_frames(), 20)
	assert_almost_eq(def.move_tiles, 5.0, 0.0001)
	assert_eq(def.base_damage, 20)
	assert_eq(def.cooldown_frames, 0, "the second bit's cooldown applies (D-S26-3)")
	assert_eq(def.cancel_into.size(), 0)
	for f: int in range(1, 21):
		assert_eq(def.is_invulnerable_frame(f), f <= 10, "frame %d" % f)


func test_dash_strike_shape_covers_the_path() -> void:
	var shape: HitShape = Defs.DASH_STRIKE.hit_shape
	assert_true(shape is HitCapsule)
	var o := Vector2(100, 100)
	var right := Vector2(1, 0)
	assert_true(shape.contains(o, right, o + Vector2(4 * TILE, 0)), "4 tiles ahead")
	assert_true(shape.contains(o, right, o + Vector2(5 * TILE, 0)), "the end of the dash")
	assert_false(shape.contains(o, right, o - Vector2(1 * TILE, 0)), "1 tile behind")
	assert_false(shape.contains(o, right, o + Vector2(2 * TILE, 1 * TILE)), "1 tile to the side")


## Story 6.6 (AC 8, D-S66-5): every pair containing the garbage bit `?` (id 5) has no combo, in
## both orders, and the shipped table names no id 5.
func test_every_garbage_pair_has_no_combo() -> void:
	var g := Register.Bit.GARBAGE
	for x: int in [A, D, L, N, g]:
		assert_null(Defs.COMBOS.get_combo(x, g), "(%d, ?)" % x)
		assert_null(Defs.COMBOS.get_combo(g, x), "(?, %d)" % x)
	for c: ComboDef in Defs.COMBOS.combos:
		assert_ne(c.first, g)
		assert_ne(c.second, g)
