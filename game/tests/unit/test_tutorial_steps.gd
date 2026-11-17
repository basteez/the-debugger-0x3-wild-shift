extends GutTest
## Story 8.2 (D4, AC 3-8): the pure tutorial step machine. Each step passes only on its own condition,
## only once its predecessor passed (D3); the threshold edges; a crit never passes on the applying hit.

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const S := TutorialSteps.Step
const J := TutorialSteps.ACTION_J
const K := TutorialSteps.ACTION_K
const PATCHED := DamageState.Kind.PATCHED
const UNPATCHED := DamageState.Kind.UNPATCHED


## Steps advanced to (not including) `s` through their real observations.
func _at(s: int) -> TutorialSteps:
	var t := TutorialSteps.new()
	if s > S.MOVE:
		t.observe_move(48.0)
	if s > S.ACTIONS:
		t.observe_action(J)
		t.observe_action(K)
	if s > S.SHIFT:
		t.observe_window(Vector2i(A, D))
	if s > S.COMBO:
		t.observe_hit(true, UNPATCHED, false)
	if s > S.PATCH:
		t.observe_patched(&"tutorial_dummy")
	if s > S.CRIT:
		t.observe_hit(false, PATCHED, false)
	assert_eq(t.current_step(), s)
	return t


func test_move_threshold_edges() -> void:
	assert_false(TutorialSteps.tiles_moved_ok(47.9))
	assert_true(TutorialSteps.tiles_moved_ok(48.0))
	var t := TutorialSteps.new()
	t.observe_move(20.0)
	t.observe_move(27.9)
	assert_eq(t.current_step(), S.MOVE, "47.9 px: not yet")
	t.observe_move(0.1)
	assert_true(t.passed(S.MOVE), "48 px of path length")
	assert_eq(t.current_step(), S.ACTIONS)


func test_actions_need_both_keys() -> void:
	assert_false(TutorialSteps.actions_done(true, false))
	assert_true(TutorialSteps.actions_done(true, true))
	var t := _at(S.ACTIONS)
	t.observe_action(J)
	t.observe_action(J)
	assert_eq(t.current_step(), S.ACTIONS, "J only fails")
	t.observe_action(K)
	assert_true(t.passed(S.ACTIONS))


func test_actions_before_move_do_not_count() -> void:
	var t := TutorialSteps.new()
	t.observe_action(J)
	t.observe_action(K)
	t.observe_move(48.0)
	assert_eq(t.current_step(), S.ACTIONS, "the keys pressed during the move step are not kept")


func test_shift_passes_only_on_a_d() -> void:
	assert_true(TutorialSteps.window_ok(Vector2i(A, D)))
	assert_false(TutorialSteps.window_ok(Vector2i(D, A)))
	var t := _at(S.SHIFT)
	t.observe_window(Vector2i(D, A))
	assert_eq(t.current_step(), S.SHIFT)
	t.observe_window(Vector2i(A, D))
	assert_true(t.passed(S.SHIFT))


func test_window_before_its_step_passes_nothing() -> void:
	var t := _at(S.ACTIONS)
	t.observe_window(Vector2i(A, D))
	assert_eq(t.current_step(), S.ACTIONS)


func test_combo_passes_on_a_combo_hit_only() -> void:
	var t := _at(S.COMBO)
	t.observe_hit(false, UNPATCHED, false)
	assert_eq(t.current_step(), S.COMBO, "a solo hit is not a combo")
	t.observe_hit(true, UNPATCHED, false)
	assert_true(t.passed(S.COMBO), "any combo hit on the dummy, whatever the state (D3)")


func test_dash_strike_before_the_shift_step_passes_nothing() -> void:
	var t := _at(S.SHIFT)
	t.observe_hit(true, UNPATCHED, false)
	assert_eq(t.current_step(), S.SHIFT)


func test_patch_needs_the_dummy_and_its_step() -> void:
	var early := _at(S.COMBO)
	early.observe_patched(&"tutorial_dummy")
	assert_eq(early.current_step(), S.COMBO, "a patch during the combo step is not kept")
	var t := _at(S.PATCH)
	t.observe_patched(&"infinite_loop")
	assert_eq(t.current_step(), S.PATCH, "another boss's Patched never counts")
	t.observe_patched(&"tutorial_dummy")
	assert_true(t.passed(S.PATCH))


func test_crit_never_passes_on_the_applying_hit() -> void:
	assert_true(TutorialSteps.is_crit(PATCHED, false))
	assert_false(TutorialSteps.is_crit(PATCHED, true))
	assert_false(TutorialSteps.is_crit(UNPATCHED, false))
	var t := _at(S.CRIT)
	t.observe_hit(true, PATCHED, true)
	assert_eq(t.current_step(), S.CRIT, "the hit that applied Patched")
	t.observe_hit(false, UNPATCHED, false)
	assert_eq(t.current_step(), S.CRIT, "a resisted hit")
	t.observe_hit(false, PATCHED, false)
	assert_true(t.all_passed())


func test_all_passed_and_reset() -> void:
	var t := _at(TutorialSteps.STEP_COUNT)
	assert_true(t.all_passed())
	for s: int in TutorialSteps.STEP_COUNT:
		assert_true(t.passed(s))
	t.reset()
	assert_eq(t.current_step(), S.MOVE)
	assert_false(t.all_passed())
	assert_eq(t.moved_px, 0.0)
	assert_false(t.j_used)


func test_step_text_key_is_the_step_index() -> void:
	for s: int in TutorialSteps.STEP_COUNT:
		assert_eq(TutorialSteps.step_text_key(s), s)
	assert_eq(TutorialSteps.step_text_key(TutorialSteps.STEP_COUNT), TutorialSteps.STEP_COUNT - 1)


func test_combo_hit_that_applies_patched_passes_combo_and_patch() -> void:
	# [design call] coordinator (review): one Dash Strike on an open `;` is enough for both tests.
	var t := _at(S.COMBO)
	t.observe_hit(true, PATCHED, true)
	assert_true(t.passed(S.COMBO))
	assert_true(t.passed(S.PATCH))
	assert_eq(t.current_step(), S.CRIT, "the crit must be a later hit")
	var solo := _at(S.COMBO)
	solo.observe_hit(true, UNPATCHED, false)
	assert_eq(solo.current_step(), S.PATCH, "a closed-`;` Dash Strike passes the combo only")
