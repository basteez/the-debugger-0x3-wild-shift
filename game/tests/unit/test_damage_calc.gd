extends GutTest
## Story 2.7 AC3: DamageCalc against the GDD "Weak Window and Patched" examples (D-S27-6). Pure.


func test_gdd_examples() -> void:
	assert_eq(DamageCalc.compute(15, 0.5, false, 1.0), 8, "unpatched slash 15 -> 7.5 -> 8")
	assert_eq(DamageCalc.compute(10, 0.7, false, 1.0), 7, "10 x 0.7")
	assert_eq(DamageCalc.compute(15, 1.0, false, 0.7), 11, "Echo of 15 -> 10.5 -> 11")
	assert_eq(DamageCalc.compute(15, 1.5, false, 0.7), 16, "Patched Echo of 15 -> 15.75 -> 16")
	assert_eq(DamageCalc.compute(20, 1.5, false, 1.0), 30, "Patched Dash Strike")
	assert_eq(DamageCalc.compute(20, 0.5, false, 1.0), 10, "unpatched Dash Strike")
	assert_eq(DamageCalc.compute(30, 1.5, true, 1.0), 68, "30 x 1.5 x 1.5 = 67.5 -> 68")


func test_gdd_damage_table_rows() -> void:
	assert_eq(DamageCalc.compute(10, 0.5, false, 1.0), 5)
	assert_eq(DamageCalc.compute(10, 1.5, false, 1.0), 15)
	assert_eq(DamageCalc.compute(10, 0.5, true, 1.0), 8, "x0.75: 7.5 -> 8")
	assert_eq(DamageCalc.compute(20, 1.5, true, 1.0), 45, "x2.25")
	assert_eq(DamageCalc.compute(15, 1.0, false, 1.5), 23, "22.5 -> 23")


func test_clean_catch_alone() -> void:
	assert_eq(DamageCalc.compute(10, 1.0, true, 1.0), 15)


func test_identity_returns_the_base() -> void:
	for base: int in [1, 7, 10, 15, 20, 999]:
		assert_eq(DamageCalc.compute(base, 1.0, false, 1.0), base)


func test_zero_base_is_zero() -> void:
	assert_eq(DamageCalc.compute(0, 1.5, true, 0.7), 0)


func test_half_boundary_rounds_up() -> void:
	assert_eq(DamageCalc.compute(15, 0.5, false, 1.0), 8, "7.5 -> 8")
	assert_eq(DamageCalc.compute(5, 0.5, false, 1.0), 3, "2.5 -> 3")
	assert_eq(DamageCalc.compute(1, 0.5, false, 1.0), 1, "0.5 -> 1")
	assert_eq(DamageCalc.compute(7, 0.7, false, 1.0), 5, "4.9 -> 5")
	assert_eq(DamageCalc.compute(3, 0.7, false, 1.0), 2, "2.1 -> 2")


func test_practice_target_multiplier_is_identity() -> void:
	assert_eq(DamageCalc.compute(15, PracticeTarget.DAMAGE_MULT, false, 1.0), 15)
	assert_eq(DamageCalc.STATE_BASE, 0)


# --- Story 3.2 (B2): the damage states through DamageState ---

func test_unpatched_halves_and_rounds_up() -> void:
	var m: float = DamageState.multiplier(DamageState.Kind.UNPATCHED)
	assert_eq(DamageCalc.compute(20, m, false, 1.0), 10, "Dash Strike 20 -> 10")
	assert_eq(DamageCalc.compute(15, m, false, 1.0), 8, "15 -> 7.5 -> 8")
	assert_eq(DamageCalc.compute(10, m, false, 1.0), 5, "slash 10 -> 5")


func test_patched_is_one_and_a_half() -> void:
	var m: float = DamageState.multiplier(DamageState.Kind.PATCHED)
	assert_eq(DamageCalc.compute(10, m, false, 1.0), 15)
	assert_eq(DamageCalc.compute(20, m, false, 1.0), 30)


func test_base_state_is_identity_and_zero_stays_zero() -> void:
	assert_eq(DamageCalc.compute(10, DamageState.multiplier(DamageState.Kind.BASE), false, 1.0), 10, "practice target x1")
	for kind: int in [DamageState.Kind.BASE, DamageState.Kind.UNPATCHED, DamageState.Kind.PATCHED]:
		assert_eq(DamageCalc.compute(0, DamageState.multiplier(kind), false, 1.0), 0)
