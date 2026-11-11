extends GutTest
## Story 3.8 (G6, AC 1-3, 5, 7, 9, 10; F1, F2): Main, the Arena, the real Infinite Loop, the autoload
## Game and SimClock. A defeat freezes the world for the 20-frame hit-stop, reassembles for 60 world
## ticks with FIGHT held, then Main (after the tick) routes FIGHT -> HARVEST; the HARVEST screen
## requests the harvest line, its skip opens at 120 sim frames, its cap ends it at 480, and Fight 2
## starts with full HP, cleared cooldowns, [A, D, L], the run seed kept and one more attempt.

const MainScene := preload("res://src/main/main.tscn")
const GameScript := preload("res://src/autoloads/game.gd")
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP

var _saved_enabled: bool
var _saved_state: int
var _saved_run: RunState
var _saved_first: int
var _saved_source: InputSource
var _main: Node2D


func before_each() -> void:
	_saved_enabled = Debug.enabled
	_saved_state = Game.flow_state
	_saved_run = Game.run
	_saved_first = Game.first_input_frame
	_saved_source = SimClock.input_source
	SimClock.input_source = null # headless: no presses
	Game.run = RunState.new()
	Debug.enabled = true
	SimClock.paused = false
	_main = MainScene.instantiate()
	add_child_autofree(_main)


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	Game.run = _saved_run
	Game.first_input_frame = _saved_first
	Game.harvest_start_frame = -1
	Debug.enabled = _saved_enabled
	SimClock.input_source = _saved_source
	SimClock.begin_fight(0)
	SimClock.paused = false
	Game.segfault_enabled = Defs.FEATURE_FLAGS.segfault # Story 5.6: tests may flip the cut flag


func _tick(times: int) -> void:
	for i: int in times:
		SimClock.tick()


## FIGHT 1 with the Infinite Loop, killed through the debug path; returns the boss.
func _kill_fight_1() -> BossController:
	Game.debug_jump(GameScript.FlowState.FIGHT, 0)
	var boss: BossController = _main.arena.boss
	assert_true(boss is InfiniteLoopBody)
	boss.debug_kill()
	return boss


func test_defeat_hitstop_reassembly_then_harvest_after_the_tick() -> void:
	var arena: Arena = _main.arena
	Game.debug_jump(GameScript.FlowState.FIGHT, 0)
	var boss: BossController = arena.boss
	# Dirty the fight: a shift, a cooldown, a hit taken.
	arena.register.shift(Register.LEFT)
	arena.actions.cooldowns.start(D, 300)
	arena.health.queue_hit()
	_tick(1 + HitFeedback.PLAYER_HITSTOP + Arena.PLAYER_DEF.invuln_frames)
	assert_eq(arena.health.hp, Arena.PLAYER_DEF.max_hp - 1)
	var seed_before: int = Game.run.run_seed
	var attempt_before: int = Game.run.fight_attempt
	watch_signals(EventBus)
	boss.debug_kill()
	assert_signal_emitted_with_parameters(EventBus, "boss_defeated", [&"infinite_loop"])
	_tick(1) # the requested hit-stop lands at the end of this tick
	assert_eq(SimClock.hitstop_frames, BossController.DEFEAT_HITSTOP_FRAMES)
	var frozen_at: int = SimClock.sim_frame
	var elapsed_at: int = boss.defeat_frames_elapsed
	_tick(BossController.DEFEAT_HITSTOP_FRAMES)
	assert_eq(SimClock.sim_frame, frozen_at, "20 frames of hit-stop: no world tick")
	assert_eq(boss.defeat_frames_elapsed, elapsed_at, "the reassembly pauses with the hit-stop")
	assert_eq(_main.hud.top_bar_text(), "void infiniteLoop() // hp 0", "hp 0 during the animation")
	assert_false(boss.is_hittable())
	while not boss.defeat_finished():
		assert_false(_main.poll_defeat(), "FIGHT holds while reassembling")
		assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
		_tick(1)
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT, "the tick itself never changes the flow (D-S38-11)")
	assert_true(_main.poll_defeat())
	assert_eq(Game.flow_state, GameScript.FlowState.HARVEST)
	var screen := _main.current_screen as HarvestScreen
	assert_not_null(screen, "the real Harvest screen (AC 5)")
	assert_eq(screen.fixed_text(), "for (i = 0; i < n; i++) { }")
	assert_eq(screen.bit, L)
	assert_eq(screen.shown_ring, PackedInt32Array([A, D, L]))
	assert_false(arena.visible, "no arena in HARVEST")
	assert_true(_main.hud.is_duck_only(), "only the duck bubble of the HUD")
	assert_eq(arena.register.ring, PackedInt32Array([A, D]), "the arena register is never written outside FIGHT")
	await get_tree().process_frame # the deferred line request
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"harvest_shared", "Bug squashed. It dropped a bit: new windows, new combos."])
	assert_true(_main.hud.duck_bubble.is_showing(), "the harvest line shows")
	# Skip gate (AC 3)
	var start: int = Game.harvest_start_frame
	# The awaited frame may have run real physics ticks: count from the recorded entry frame.
	while SimClock.sim_frame < start + GameScript.HARVEST_SKIP_FRAMES - 1:
		_tick(1)
	assert_false(screen.try_skip(SimClock.sim_frame), "before 2 s")
	_tick(1)
	assert_eq(SimClock.sim_frame - start, GameScript.HARVEST_SKIP_FRAMES)
	assert_true(screen.try_skip(SimClock.sim_frame))
	# Fight 2 (AC 3, F1, F2)
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
	assert_eq(Game.run.boss_index, 1)
	assert_eq(Game.run.deaths_on_boss, 0)
	assert_eq(Game.run.fight_start_ring, PackedInt32Array([A, D, L]))
	assert_eq(arena.register.ring, PackedInt32Array([A, D, L]))
	assert_eq(arena.register.byte_value(), 0x07)
	assert_eq(arena.health.hp, Arena.PLAYER_DEF.max_hp, "full HP (D-049 b)")
	assert_true(arena.actions.cooldowns.ready(D), "cooldowns reset on a non-retry entry")
	assert_eq(Game.run.run_seed, seed_before)
	assert_eq(Game.run.fight_attempt, attempt_before + 1)
	assert_false(_main.hud.duck_bubble.is_showing(), "the harvest line never finishes into FIGHT (AC 9)")
	assert_false(_main.hud.is_duck_only())
	assert_true(arena.boss is NullPointerBody, "Story 5.1: Fight 2 is the Null Pointer")


func test_harvest_cap_ends_it_at_480_frames() -> void:
	var boss: BossController = _kill_fight_1()
	_tick(1 + BossController.DEFEAT_HITSTOP_FRAMES + BossController.DEFEAT_FRAMES)
	assert_true(boss.defeat_finished())
	assert_true(_main.poll_defeat())
	var screen := _main.current_screen as HarvestScreen
	_tick(GameScript.HARVEST_MAX_FRAMES - 1)
	screen._physics_process(0.0)
	assert_eq(Game.flow_state, GameScript.FlowState.HARVEST, "479 frames: still open")
	_tick(1)
	screen._physics_process(0.0)
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT, "8 s cap")
	assert_eq(Game.run.boss_index, 1)


func test_a_lethal_hit_during_the_defeat_window_is_a_normal_death() -> void:
	var arena: Arena = _main.arena
	var boss: BossController = _kill_fight_1()
	_tick(1 + BossController.DEFEAT_HITSTOP_FRAMES + 10)
	assert_true(arena.player.active, "the player stays live (D-S38-3)")
	for i: int in Arena.PLAYER_DEF.max_hp:
		arena.health.queue_hit()
		_tick(1 + HitFeedback.PLAYER_HITSTOP + Arena.PLAYER_DEF.invuln_frames)
		if Game.flow_state == GameScript.FlowState.DEAD:
			break
	assert_eq(Game.flow_state, GameScript.FlowState.DEAD)
	assert_false(_main.poll_defeat(), "no harvest from DEAD")
	assert_eq(boss.state, BossController.BossState.DEFEATED)


func test_fight_line_is_cut_when_the_defeat_leaves_fight() -> void:
	var boss: BossController = _kill_fight_1()
	VoiceService.say("t3_dash_strike")
	assert_true(_main.hud.duck_bubble.is_showing())
	_tick(1 + BossController.DEFEAT_HITSTOP_FRAMES + BossController.DEFEAT_FRAMES)
	assert_true(boss.defeat_finished())
	_main.poll_defeat()
	assert_eq(Game.flow_state, GameScript.FlowState.HARVEST)
	assert_false(_main.hud.duck_bubble.is_showing(), "the fight line is cleared on the flow exit")
	assert_false(VoiceService.is_speaking())


# --- Story 5.6 (B1, B4, C2, C3; AC 4, 5, 6): the Null Pointer defeat ---

const N := Register.Bit.NULL_BIT
const NP_FIXED := "if (ptr != null) ptr.deref();"


## FIGHT 2 with the Null Pointer, killed through the debug path and run through its defeat animation.
func _defeat_fight_2() -> BossController:
	Game.debug_jump(GameScript.FlowState.FIGHT, 1)
	var boss: BossController = _main.arena.boss
	assert_true(boss is NullPointerBody)
	boss.debug_kill()
	_tick(1 + BossController.DEFEAT_HITSTOP_FRAMES + BossController.DEFEAT_FRAMES)
	assert_true(boss.defeat_finished())
	return boss


func test_null_pointer_defeat_harvests_null_and_starts_fight_3() -> void:
	Game.segfault_enabled = true
	var arena: Arena = _main.arena
	var boss: BossController = _defeat_fight_2()
	assert_eq(boss.def.drop_bit, N)
	assert_eq(boss.def.fixed_line, NP_FIXED)
	arena.actions.cooldowns.start(D, 300)
	arena.health.queue_hit()
	_tick(1 + HitFeedback.PLAYER_HITSTOP + Arena.PLAYER_DEF.invuln_frames)
	var attempt_before: int = Game.run.fight_attempt
	watch_signals(EventBus)
	assert_true(_main.poll_defeat())
	assert_eq(Game.flow_state, GameScript.FlowState.HARVEST)
	var screen := _main.current_screen as HarvestScreen
	assert_not_null(screen, "B1: the generic 3.8 Harvest for boss index 1")
	assert_eq(screen.boss_index, 1)
	assert_eq(screen.fixed_text(), NP_FIXED, "AC 4: the Null Pointer's fixed line reassembles")
	assert_eq(screen.bit, N, "drop_bit 4")
	assert_eq(screen.shown_ring, PackedInt32Array([A, D, L, N]))
	assert_eq(HarvestScreen.register_text(screen.shown_ring), "[A, D, L, N] = 0x0F")
	assert_eq(arena.register.ring, PackedInt32Array([A, D, L]), "the arena register is never written outside FIGHT")
	await get_tree().process_frame # the deferred line request
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"harvest_shared", "Bug squashed. It dropped a bit: new windows, new combos."])
	assert_true(Game.finish_harvest(SimClock.sim_frame))
	# AC 5: Fight 3 starts from [A, D, L, N], N once, full HP, cooldowns reset, one more attempt.
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
	assert_eq(Game.run.boss_index, 2)
	assert_eq(Game.run.fight_start_ring, Register.fight_start_for_boss(2))
	assert_eq(Game.run.fight_start_ring.count(N), 1, "no duplicate N")
	assert_eq(arena.register.ring, PackedInt32Array([A, D, L, N]))
	assert_eq(arena.register.byte_value(), 0x0F)
	assert_eq(arena.health.hp, Arena.PLAYER_DEF.max_hp, "full HP (D-049 b)")
	assert_true(arena.actions.cooldowns.ready(D), "cooldowns reset")
	assert_eq(Game.run.fight_attempt, attempt_before + 1, "fight_attempt incremented once")


func test_null_pointer_defeat_with_segfault_off_goes_to_the_ending() -> void:
	Game.segfault_enabled = false
	var arena: Arena = _main.arena
	_defeat_fight_2()
	assert_true(_main.poll_defeat())
	assert_eq(Game.flow_state, GameScript.FlowState.ENDING, "AC 6: FIGHT -> ENDING, no HARVEST")
	assert_null(_main.current_screen as HarvestScreen, "no HarvestScreen is built on the cut path")
	assert_true(_main.current_screen is PlaceholderScreen, "the ENDING placeholder (6.8 replaces it)")
	assert_eq(_main.find_children("*", "HarvestScreen", true, false).size(), 0)
	assert_false(Game.run.fight_start_ring.has(N), "NULL is never dropped")
	assert_eq(arena.register.ring, PackedInt32Array([A, D, L]), "no bit inserted")
