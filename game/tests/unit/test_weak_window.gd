extends GutTest
## Story 3.2 AC 1, 4, 6 (D-S32-4, D-S32-6, D-S32-8): the weak-window completion rule, the Patched
## tracker and boss-hit hit-stop precedence. Pure: no SimClock, no scene tree.

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const AD := Vector2i(Register.Bit.ATTACK, Register.Bit.DASH)
const DA := Vector2i(Register.Bit.DASH, Register.Bit.ATTACK)


func _hit(window: Vector2i, combo: bool, link_second: bool) -> BossInteraction:
	return BossInteraction.new(BossInteraction.Kind.HIT, window, combo, link_second)


# --- completes_weak_window (D-S32-6) ---

func test_combo_on_the_window_completes() -> void:
	assert_true(BossInteraction.completes_weak_window(_hit(AD, true, false), AD))


func test_combo_on_a_wrong_window_never_completes() -> void:
	assert_false(BossInteraction.completes_weak_window(_hit(AD, true, false), DA), "order matters")
	assert_false(BossInteraction.completes_weak_window(_hit(Vector2i(A, L), true, false), AD))


func test_solo_non_link_hit_never_completes() -> void:
	assert_false(BossInteraction.completes_weak_window(_hit(AD, false, false), AD), "right bits, plain solo")


func test_link_second_on_the_window_completes() -> void:
	assert_true(BossInteraction.completes_weak_window(_hit(DA, false, true), DA))


func test_link_second_on_a_wrong_window_never_completes() -> void:
	assert_false(BossInteraction.completes_weak_window(_hit(DA, false, true), AD))


func test_pass_through_and_decoy_on_the_window_complete() -> void:
	var pass_through := BossInteraction.new(BossInteraction.Kind.PASS_THROUGH, AD)
	var decoy := BossInteraction.new(BossInteraction.Kind.DECOY_STRUCK, AD)
	assert_true(BossInteraction.completes_weak_window(pass_through, AD), "non-damaging interactions count (D-017)")
	assert_true(BossInteraction.completes_weak_window(decoy, AD))


func test_pass_through_and_decoy_on_a_wrong_window_never_complete() -> void:
	assert_false(BossInteraction.completes_weak_window(BossInteraction.new(BossInteraction.Kind.PASS_THROUGH, DA), AD))
	assert_false(BossInteraction.completes_weak_window(BossInteraction.new(BossInteraction.Kind.DECOY_STRUCK, DA), AD))


func test_null_or_zero_window_never_completes() -> void:
	assert_false(BossInteraction.completes_weak_window(null, AD))
	assert_false(BossInteraction.completes_weak_window(_hit(Vector2i.ZERO, true, false), Vector2i.ZERO), "no weak window set")


func test_process_is_true_when_any_interaction_completes() -> void:
	var none: Array[BossInteraction] = []
	assert_false(WeakWindowTracker.process(none, AD))
	var miss: Array[BossInteraction] = [_hit(AD, false, false), _hit(DA, true, false)]
	assert_false(WeakWindowTracker.process(miss, AD))
	var one: Array[BossInteraction] = [_hit(AD, false, false), BossInteraction.new(BossInteraction.Kind.DECOY_STRUCK, AD)]
	assert_true(WeakWindowTracker.process(one, AD))


# --- WeakWindowTracker (D-S32-4) ---

func test_apply_sets_180_and_a_second_apply_refreshes_to_180() -> void:
	var t := WeakWindowTracker.new()
	assert_false(t.is_patched())
	assert_eq(WeakWindowTracker.PATCHED_FRAMES, 180)
	t.apply_patched(WeakWindowTracker.PATCHED_FRAMES)
	assert_eq(t.frames_left, 180)
	assert_true(t.is_patched())
	for i: int in 50:
		t.tick()
	assert_eq(t.frames_left, 130)
	t.apply_patched()
	assert_eq(t.frames_left, 180, "refresh, not stack")


func test_tick_counts_down_to_zero_and_stays() -> void:
	var t := WeakWindowTracker.new()
	t.apply_patched(3)
	t.tick()
	t.tick()
	assert_true(t.is_patched())
	t.tick()
	assert_eq(t.frames_left, 0)
	assert_false(t.is_patched())
	t.tick()
	assert_eq(t.frames_left, 0, "floors at 0")


func test_patched_lasts_exactly_180_ticks() -> void:
	var t := WeakWindowTracker.new()
	t.apply_patched()
	var patched_ticks: int = 0
	for i: int in 400:
		if t.is_patched():
			patched_ticks += 1
		t.tick()
	assert_eq(patched_ticks, 180)


func test_clear() -> void:
	var t := WeakWindowTracker.new()
	t.apply_patched()
	t.clear()
	assert_false(t.is_patched())


# --- DamageState (D-S32-7) ---

func test_damage_state_ints_and_multipliers() -> void:
	assert_eq(DamageState.Kind.BASE, 0)
	assert_eq(DamageState.Kind.UNPATCHED, 1)
	assert_eq(DamageState.Kind.PATCHED, 2)
	assert_eq(DamageCalc.STATE_BASE, DamageState.Kind.BASE)
	assert_eq(DamageState.multiplier(DamageState.Kind.BASE), 1.0)
	assert_eq(DamageState.multiplier(DamageState.Kind.UNPATCHED), 0.5)
	assert_eq(DamageState.multiplier(DamageState.Kind.PATCHED), 1.5)
	assert_eq(DamageState.multiplier_pct(DamageState.Kind.UNPATCHED), 50)
	assert_eq(DamageState.multiplier_pct(DamageState.Kind.PATCHED), 150)
	assert_eq(DamageState.multiplier_pct(DamageState.Kind.BASE), 100)


# --- hitstop_for_boss_hit (D-S32-8) ---

func test_the_patching_hit_takes_4() -> void:
	assert_eq(HitFeedback.PATCHED_APPLIED_HITSTOP, 4)
	assert_eq(HitFeedback.hitstop_for_boss_hit(DamageState.Kind.PATCHED, true, 6, true), 4, "Dash Strike patch (AC 1)")
	assert_eq(HitFeedback.hitstop_for_boss_hit(DamageState.Kind.PATCHED, false, 3, true), 4, "link_second slash patch (AC 2)")


func test_a_patched_hit_that_does_not_apply_is_a_crit_8() -> void:
	assert_eq(HitFeedback.CRIT_HITSTOP, 8)
	assert_eq(HitFeedback.hitstop_for_boss_hit(DamageState.Kind.PATCHED, false, 3, false), 8)
	assert_eq(HitFeedback.hitstop_for_boss_hit(DamageState.Kind.PATCHED, true, 6, false), 8)


func test_an_unpatched_hit_uses_the_normal_ladder() -> void:
	assert_eq(HitFeedback.hitstop_for_boss_hit(DamageState.Kind.UNPATCHED, false, 6, false), 3, "solo 3")
	assert_eq(HitFeedback.hitstop_for_boss_hit(DamageState.Kind.UNPATCHED, true, 6, false), 6, "combo value")
	assert_eq(HitFeedback.hitstop_for_boss_hit(DamageState.Kind.UNPATCHED, true, 1, false), 3, "never below 3")
