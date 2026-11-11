extends GutTest
## Story 5.4 (AC 12, 13, 22): the flag-off fallback (cut ladder #2). With watch_fallback injected the
## Null Pointer ghost flickers visible for 20 live ticks every 120, paused in ROAR and DEFEATED,
## reset per fight; with the flag on the fallback is inert. With the flag off the Arena builds no
## Watch module, R does nothing and the boss gets watch_fallback = true.

const NP_DEF: BossDef = preload("res://data/bosses/null_pointer/boss_def.tres")
const CYCLE := NullPointerBody.FALLBACK_CYCLE_TICKS
const ON := NullPointerBody.FALLBACK_VISIBLE_FRAMES

var _ctx: SimContext
var _saved_source: InputSource


## Holds its attacks, so the ghost stays in GAP and only the fallback can show it.
class IdleBody:
	extends NullPointerBody

	func _attacks_allowed() -> bool:
		return false


## R held on every poll.
class HoldR:
	extends InputSource

	func watch_held_for_frame() -> bool:
		return true


func before_each() -> void:
	_ctx = SimContext.new()
	_ctx.reseed(5454)
	_saved_source = SimClock.input_source
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0
	SimClock.paused = false


func after_each() -> void:
	SimClock.input_source = _saved_source
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0
	SimClock.watch_gate_active = false
	SimClock.ctx.watch_held = false
	SimClock.begin_fight(0)


func _body(fallback: bool) -> IdleBody:
	var b := IdleBody.new()
	assert_true(b.setup(NP_DEF, null, null))
	b.watch_fallback = fallback
	b.reset_for_fight()
	return b


## Ticks `n` times and returns the visibility after each tick.
func _visibility(b: NullPointerBody, n: int) -> Array[bool]:
	var out: Array[bool] = []
	for i: int in n:
		b.tick(_ctx)
		out.append(b.visible_now())
	return out


func test_constants_match_the_gdd() -> void:
	assert_eq(CYCLE, 120, "every 2 s")
	assert_eq(ON, 20, "20 frames")


func test_flicker_20_on_every_120_live_ticks() -> void:
	var b := _body(true)
	assert_false(b.visible_now(), "fight start: hidden")
	var seen: Array[bool] = _visibility(b, CYCLE * 3)
	assert_eq(seen.count(true), ON * 3)
	for i: int in seen.size():
		var in_window: bool = (i % CYCLE) >= CYCLE - ON - 1 and (i % CYCLE) < CYCLE - 1
		assert_eq(seen[i], in_window, "tick %d" % i)


func test_flicker_is_one_contiguous_block_per_cycle() -> void:
	var b := _body(true)
	var seen: Array[bool] = _visibility(b, CYCLE)
	var first: int = seen.find(true)
	assert_gt(first, 0)
	for i: int in ON:
		assert_true(seen[first + i])
	assert_eq(seen.count(true), ON)


func test_flag_on_fallback_is_inert() -> void:
	var b := _body(false)
	var seen: Array[bool] = _visibility(b, CYCLE * 2)
	assert_eq(seen.count(true), 0, "no flicker with Watch on")
	assert_eq(b.fallback_cycle_left, CYCLE, "the counter does not run")


func test_paused_in_roar() -> void:
	var b := _body(true)
	_visibility(b, 10)
	var left: int = b.fallback_cycle_left
	b.take_hit(int(NP_DEF.max_hp * 0.5)) # phase change: ROAR
	SimClock._pending_hitstop = 0
	assert_eq(b.state, BossController.BossState.ROAR)
	for i: int in BossController.ROAR_FRAMES - 1:
		b.tick(_ctx)
		assert_eq(b.fallback_cycle_left, left, "paused in ROAR")


func test_paused_when_defeated() -> void:
	var b := _body(true)
	_visibility(b, 30)
	var left: int = b.fallback_cycle_left
	b.take_hit(NP_DEF.max_hp)
	SimClock._pending_hitstop = 0
	assert_eq(b.state, BossController.BossState.DEFEATED)
	_visibility(b, 50)
	assert_eq(b.fallback_cycle_left, left, "paused while DEFEATED")


func test_reset_per_fight() -> void:
	var b := _body(true)
	_visibility(b, 77)
	b.reset_for_fight()
	assert_eq(b.fallback_cycle_left, CYCLE)
	assert_false(b.visible_now())


func test_decoys_never_hum_or_show_under_the_fallback() -> void:
	var b := _body(true)
	b.decoys.append(Vector2i(5000, 5000))
	var seen: Array[bool] = _visibility(b, CYCLE)
	assert_eq(seen.count(true), ON, "only the ghost's own flicker, decoys add nothing")


# --- Arena wiring (AC 12, 13, 14) ---

func test_flag_off_builds_no_skill_and_injects_the_fallback() -> void:
	var arena := Arena.new()
	arena.set_watch_enabled(false)
	add_child_autofree(arena)
	assert_null(arena.watch_skill, "nothing under src/skills/watch/ is built")
	for s: SimSystem in SimClock.get(&"_systems"):
		assert_false(s.get_script().resource_path == Arena.WATCH_SKILL_PATH, "no Watch skill registered")
	arena.enter_fight(Register.fight_start_for_boss(1), false, Arena.NULL_POINTER_DEF_PATH, true, true)
	assert_true(arena.boss.get(&"watch_fallback"), "the ghost flickers with Watch cut")
	SimClock.input_source = HoldR.new()
	watch_signals(EventBus)
	SimClock.tick()
	SimClock.tick()
	assert_false(SimClock.watch_gate_active, "R does nothing")
	assert_false(SimClock.ctx.watch_held, "no held state reaches the sim")
	assert_signal_emit_count(EventBus, "watch_started", 0)
	assert_signal_emit_count(EventBus, "watch_ended", 0)
	arena.leave_fight()


func test_flag_on_boss_gets_no_fallback() -> void:
	var arena := Arena.new()
	arena.set_watch_enabled(true)
	add_child_autofree(arena)
	arena.enter_fight(Register.fight_start_for_boss(1), false, Arena.NULL_POINTER_DEF_PATH, true, true)
	assert_false(arena.boss.get(&"watch_fallback"))
	arena.set_watch_enabled(false)
	assert_true(arena.boss.get(&"watch_fallback"), "toggling the flag follows at once")
	arena.leave_fight()
