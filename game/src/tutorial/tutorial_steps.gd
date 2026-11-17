class_name TutorialSteps
extends RefCounted
## Story 8.2 (D-E8-5, D-S82-3, D1-D3): the six tutorial steps ("running the test suite") as a pure
## state machine. It never reads the sim and never emits: the TUTORIAL screen (presentation) reads the
## sim each frame and feeds observations here, so the tutorial can never change a fight outcome.
## Steps pass strictly in order: an observation counts only for the current step, so a condition met
## early (a Dash Strike before the shift step) passes nothing (D3). The combo step counts a combo hit
## on the dummy whatever the window: with the tutorial's two bits the only combo is the Dash Strike.

enum Step { MOVE, ACTIONS, SHIFT, COMBO, PATCH, CRIT }

const STEP_COUNT := 6
## test_move: cumulative path length in px (3 tiles).
const MOVE_TILES := 3
## test_shift: the window the register must read, [A, D] (Register.Bit ATTACK, DASH).
const SHIFT_WINDOW := Vector2i(1, 2)
## The InputMap actions of the two live bits (ActionResolver.KEYS).
const ACTION_J := &"action_1"
const ACTION_K := &"action_2"
## The boss id of the tutorial dummy (its BossDef).
const DUMMY_ID := &"tutorial_dummy"

## The current step (STEP_COUNT once every step passed).
var step: int = Step.MOVE
## Path length moved during the move step, in px.
var moved_px: float = 0.0
var j_used: bool = false
var k_used: bool = false


## Back to step 1 with nothing observed.
func reset() -> void:
	step = Step.MOVE
	moved_px = 0.0
	j_used = false
	k_used = false


func current_step() -> int:
	return step


## True once `s` has passed (every earlier step passed with it).
func passed(s: int) -> bool:
	return s < step


func all_passed() -> bool:
	return step >= STEP_COUNT


## The index of step `s` into the screen text arrays (checklist names, prompts). Pure.
static func step_text_key(s: int) -> int:
	return clampi(s, 0, STEP_COUNT - 1)


## The player moved `distance_px` this frame.
func observe_move(distance_px: float) -> void:
	if step != Step.MOVE or distance_px <= 0.0:
		return
	moved_px += distance_px
	if tiles_moved_ok(moved_px):
		_pass()


## An action was started by the key of `action_id` (ACTION_J or ACTION_K).
func observe_action(action_id: StringName) -> void:
	if step != Step.ACTIONS:
		return
	if action_id == ACTION_J:
		j_used = true
	elif action_id == ACTION_K:
		k_used = true
	if actions_done(j_used, k_used):
		_pass()


## The register's active window this frame.
func observe_window(window: Vector2i) -> void:
	if step == Step.SHIFT and window_ok(window):
		_pass()


## A hit landed on the dummy: combo flag, its DamageState kind, and whether Patched was applied in
## the same tick (that hit is the patch, not a crit).
func observe_hit(is_combo: bool, state: int, applied_patch_this_tick: bool) -> void:
	if step == Step.COMBO and is_combo:
		_pass()
		# [design call] coordinator (review): a Dash Strike that lands AND applies Patched passes
		# test_combo and test_patch on the same event. The applying hit is never the crit (the crit step
		# is not reached until after it).
		if applied_patch_this_tick and step == Step.PATCH:
			_pass()
	elif step == Step.CRIT and is_crit(state, applied_patch_this_tick):
		_pass()


## Patched was applied to the boss `boss_id`.
func observe_patched(boss_id: StringName) -> void:
	if step == Step.PATCH and boss_id == DUMMY_ID:
		_pass()


func _pass() -> void:
	step += 1


## Pure (D2): 3 tiles or more of path length.
static func tiles_moved_ok(distance_px: float) -> bool:
	return distance_px >= MOVE_TILES * Const.TILE_PX


## Pure (D2): both live bits were used.
static func actions_done(p_j_used: bool, p_k_used: bool) -> bool:
	return p_j_used and p_k_used


## Pure (D2): the register reads [A, D].
static func window_ok(window: Vector2i) -> bool:
	return window == SHIFT_WINDOW


## Pure (D2): a Patched hit that did not itself apply Patched.
static func is_crit(state: int, applied_patch: bool) -> bool:
	return state == DamageState.Kind.PATCHED and not applied_patch
