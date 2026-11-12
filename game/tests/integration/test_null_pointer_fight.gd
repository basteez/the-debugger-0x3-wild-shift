extends GutTest
## Story 5.1 (AC 1-3, 8, 11, 13, 19): Main, the Arena, the real Null Pointer, the autoload Game and
## SimClock. FIGHT boss 1 boots with the NullPointerBody, the sky comment and the hum node, runs
## headless without errors in GAP (no attack), the hum follows the boss after each tick, and the
## view and sky are released when the fight is left.
## Story 5.2 (AC 11, 15): the fight runs from FIGHT boss 1 with a fixed seed through phase 1 and
## phase 2, both attacks running in each and hitting the idle player through PlayerHealth, with no
## Log.error; and the visible recovery of each attack is the strike-back window: a real Echo Dash
## (phase 1, D->L) and a real Dash Strike (phase 2, A->D) Patch the ghost through CombatResolver.
## Story 5.3 (AC 23): phase 2 also runs Dangling Pointers from a fixed seed: its decoys spawn, the
## body re-casts them after 900 live ticks, and a real slash dispels one, with no Log.error.

const MainScene := preload("res://src/main/main.tscn")
const GameScript := preload("res://src/autoloads/game.gd")
const NP_DEF: BossDef = preload("res://data/bosses/null_pointer/boss_def.tres")
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const J := &"action_1"
const K := &"action_2"
const SPAWN := Vector2(256, 144)
const S := BossController.BossState
const SEED := 5252

var _saved_enabled: bool
var _saved_state: int
var _saved_run: RunState
var _saved_source: InputSource
var _main: Node2D


func before_each() -> void:
	_saved_enabled = Debug.enabled
	_saved_state = Game.flow_state
	_saved_run = Game.run
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
	Debug.enabled = _saved_enabled
	SimClock.input_source = _saved_source
	SimClock.begin_fight(0)
	SimClock.paused = false


func test_fight_2_boots_the_null_pointer_and_idles_in_gap() -> void:
	Game.debug_jump(GameScript.FlowState.FIGHT, 1)
	var boss := _main.arena.boss as NullPointerBody
	assert_not_null(boss, "FIGHT boss 1 is the Null Pointer")
	assert_eq(_main.boss_view.boss, boss)
	assert_eq(_main.hud.top_bar_text(), "void nullPointer() // hp 700")
	assert_eq(_main.hud.sky_text(), "// FIXME: who owns this pointer?")
	var hum: NullPointerHum = _main.boss_view.hum
	assert_not_null(hum)
	var start: Vector2 = boss.body_center_px
	for i: int in 89:
		SimClock.tick()
		hum.sync_to(boss)
		assert_eq(hum.position, boss.body_center_px)
		assert_eq(boss.state, BossController.BossState.GAP, "the 90-frame gap (tick %d)" % i)
		assert_false(boss.visible_now(), "invisible while idle")
	assert_ne(boss.body_center_px, start, "the ghost drifted")
	assert_push_error_count(0, "no Log.error during the fight")
	Game.debug_jump(GameScript.FlowState.TITLE, 0)
	assert_null(_main.boss_view.boss, "the view lets go of the boss")
	assert_eq(_main.hud.sky_text(), Hud.SKY, "the sky comment is restored")
	hum.sync_to(_main.boss_view.boss)
	assert_false(hum.playing, "the hum stops when the fight is left")


# --- Story 5.2 AC 15: both phases, both attacks, a fixed seed ---

func test_fight_2_runs_both_attacks_in_both_phases() -> void:
	Game.debug_jump(GameScript.FlowState.FIGHT, 1)
	SimClock.begin_fight(SEED)
	var boss := _main.arena.boss as NullPointerBody
	var health: PlayerHealth = _main.arena.health
	watch_signals(EventBus)
	var seen: Array = [{}, {}]
	for phase: int in 2:
		if phase == 1:
			boss.take_hit(350) # the debug route to phase 2 (50%)
			assert_eq(boss.phase_index, 1)
			assert_eq(boss.state, S.ROAR)
		var ticks: int = 0
		var want: int = 2 if phase == 0 else 3 # Story 5.3: Dangling Pointers joins phase 2
		while seen[phase].size() < want and ticks < 3000:
			SimClock.tick()
			ticks += 1
			# The idle player would die; keep it alive so the fight continues (hits still land).
			health.hp = health.def.max_hp
			assert_eq(boss.visible_now(), boss.state == S.ACTIVE or boss.state == S.RECOVERY \
					or boss.hit_reveal_left > 0 or boss.pass_reveal_left > 0 or boss.fallback_visible(), \
					"visible only in ACTIVE / RECOVERY (or the Story 5.4 flag-off flicker)")
			if boss.current != null:
				seen[phase][boss.current.id] = true
				var ids: Array = [&"pointer_grab", &"null_rain"] if phase == 0 else [&"pointer_grab", &"null_rain", &"dangling_pointers"]
				assert_true(boss.current.id in ids)
		assert_eq(seen[phase].size(), want, "phase %d ran every pool attack within %d ticks" % [phase + 1, ticks])
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
	assert_gt(get_signal_emit_count(EventBus, "player_damaged"), 0, "the attacks hit the idle player through PlayerHealth")
	var tells: Array = []
	for i: int in get_signal_emit_count(EventBus, "boss_tell_started"):
		var params: Array = get_signal_parameters(EventBus, "boss_tell_started", i)
		if not tells.has(params):
			tells.append(params)
	assert_true(tells.has([&"pointer_grab", &"tell_pointer_grab"]), "the grab's tell SFX id")
	assert_true(tells.has([&"null_rain", &"tell_null_rain"]), "the rain's tell SFX id")
	assert_push_error_count(0, "no Log.error during the fight")


# --- Story 5.2 AC 11: the visible recovery is the strike-back window ---

## `with_health` (Story 5.5): a PlayerHealth bound to the boss, and the attacks aimed at the player.
func _combat_rig(bits: Array, with_health: bool = false) -> Dictionary:
	var buf := InputBuffer.new()
	var player := Player.new(load("res://data/player/player_def.tres") as PlayerDef, Arena.player_bounds())
	player.reset_for_fight(SPAWN)
	player.set_active(true)
	var reg := Register.new(buf)
	reg.set_active(true)
	assert_true(reg.set_fight_start(PackedInt32Array(bits)))
	var fsm := ActionStateMachine.new(buf, player, reg)
	fsm.reset_for_fight()
	fsm.set_active(true)
	var combat := CombatResolver.new(fsm, player)
	var ctx := SimContext.new()
	ctx.reseed(SEED)
	var arena := ArenaContext.new()
	arena.target_source = func() -> Vector2: return Vector2(40, 40) # attacks land far from the player
	arena.contact_source = func() -> Vector2: return player.position_px
	var health: PlayerHealth = null
	if with_health:
		health = PlayerHealth.new(player.def, fsm)
		health.reset_for_fight()
		health.set_active(true)
		arena.target_source = func() -> Vector2: return player.position_px
	var boss := NullPointerBody.new()
	assert_true(boss.setup(NP_DEF, health, arena))
	boss.reset_for_fight()
	combat.boss = boss
	return {"buf": buf, "player": player, "reg": reg, "fsm": fsm, "combat": combat, "ctx": ctx, "boss": boss, "health": health, "t": 0}


## One tick in SimClock phase order (SHIFTS, ACTIONS, PLAYER, BOSS_HAZARDS, COMBAT).
func _rig_tick(rig: Dictionary) -> void:
	var ctx: SimContext = rig["ctx"]
	ctx.poll_frame = rig["t"]
	(rig["reg"] as Register).tick(ctx)
	(rig["fsm"] as ActionStateMachine).tick(ctx)
	(rig["player"] as Player).tick(ctx)
	(rig["boss"] as NullPointerBody).tick(ctx)
	(rig["combat"] as CombatResolver).tick(ctx)
	if rig["health"] != null:
		(rig["health"] as PlayerHealth).tick(ctx)
	rig["t"] = rig["t"] + 1


## Ticks until the boss enters RECOVERY, then places it (test only) at `p`; it holds still there.
func _to_recovery_at(rig: Dictionary, p: Vector2) -> NullPointerBody:
	var boss: NullPointerBody = rig["boss"]
	var n: int = 0
	while boss.state != S.RECOVERY and n < 1000:
		_rig_tick(rig)
		n += 1
	assert_eq(boss.state, S.RECOVERY)
	assert_true(boss.visible_now(), "the ghost is visible in recovery")
	boss.pos_mtiles = Vector2i((p * NullPointerBody.MILLI / float(Const.TILE_PX)).round())
	boss.body_center_px = p
	return boss


func test_echo_dash_through_the_visible_recovery_patches_phase_1() -> void:
	SimClock._pending_hitstop = 0
	var rig: Dictionary = _combat_rig([D, L])
	var boss: NullPointerBody = _to_recovery_at(rig, SPAWN + Vector2(56, 0))
	var buf: InputBuffer = rig["buf"]
	buf.push(J, rig["t"])
	for i: int in 3:
		_rig_tick(rig)
	buf.push(K, rig["t"])
	var n: int = 0
	while not boss.weak_window.is_patched() and n < 30:
		_rig_tick(rig)
		n += 1
	assert_true(boss.weak_window.is_patched(), "D->L Echo Dash through the visible ghost Patches phase 1")
	assert_eq(boss.state, S.RECOVERY, "within the recovery")
	assert_eq(boss.pass_reveal_left, NullPointerBody.PASS_REVEAL_FRAMES)
	SimClock._pending_hitstop = 0


func test_dash_strike_on_the_visible_recovery_patches_phase_2() -> void:
	SimClock._pending_hitstop = 0
	var rig: Dictionary = _combat_rig([A, D])
	var boss: NullPointerBody = rig["boss"]
	boss.take_hit(350)
	assert_eq(boss.phase_index, 1)
	assert_eq(boss.current_weak_window(), Vector2i(A, D))
	_to_recovery_at(rig, SPAWN + Vector2(64, 0))
	var hp_before: int = boss.hp
	var buf: InputBuffer = rig["buf"]
	buf.push(J, rig["t"])
	for i: int in 3:
		_rig_tick(rig)
	buf.push(K, rig["t"])
	var n: int = 0
	while not boss.weak_window.is_patched() and n < 30:
		_rig_tick(rig)
		n += 1
	assert_true(boss.weak_window.is_patched(), "A->D Dash Strike on the visible ghost Patches phase 2")
	assert_eq(boss.state, S.RECOVERY, "within the recovery")
	assert_lt(boss.hp, hp_before, "the existing damage path")
	SimClock._pending_hitstop = 0


# --- Story 5.3 AC 23: Dangling Pointers through the real flow ---

func test_fight_2_phase_2_casts_and_recasts_dangling_pointers() -> void:
	Game.debug_jump(GameScript.FlowState.FIGHT, 1)
	SimClock.begin_fight(SEED)
	var boss := _main.arena.boss as NullPointerBody
	var health: PlayerHealth = _main.arena.health
	boss.take_hit(350)
	assert_eq(boss.phase_index, 1)
	var spawned_at: int = -1
	var recast_seen: bool = false
	var ticks: int = 0
	while ticks < 4000 and not recast_seen:
		SimClock.tick()
		ticks += 1
		health.hp = health.def.max_hp
		if spawned_at < 0 and not boss.decoys.is_empty():
			spawned_at = ticks
		if boss.recast_flicker_left > 0:
			recast_seen = true
		assert_lte(boss.decoys.size(), NullPointerBody.DECOY_CAP)
		for p: Vector2 in boss.decoy_positions():
			assert_true(ArenaContext.inside_play_area(p))
		if boss.decoys.size() >= NullPointerBody.DECOY_CAP:
			boss.decoys.remove_at(0) # keep room so the re-cast has spots to flicker
	assert_gt(spawned_at, 0, "Dangling Pointers spawned decoys")
	assert_true(recast_seen, "the body re-cast after its timer (%d ticks)" % ticks)
	assert_push_error_count(0, "no Log.error during the fight")


func test_a_real_slash_dispels_a_decoy_without_a_stun() -> void:
	var rig: Dictionary = _combat_rig([A, D])
	var boss: NullPointerBody = rig["boss"]
	boss.take_hit(350)
	var n: int = 0
	while boss.decoys.is_empty() and n < 4000:
		_rig_tick(rig)
		n += 1
	assert_false(boss.decoys.is_empty(), "Dangling Pointers spawned decoys (%d ticks)" % n)
	var spot: Vector2 = boss.decoy_positions()[0]
	var player: Player = rig["player"]
	player.reset_for_fight(spot - Vector2(Const.TILE_PX, 0)) # facing right, the decoy in the arc
	var before: int = boss.decoys.size()
	var hp: int = boss.hp
	var buf: InputBuffer = rig["buf"]
	buf.push(J, rig["t"])
	for i: int in 10:
		_rig_tick(rig)
	SimClock._pending_hitstop = 0
	assert_eq(boss.decoys.size(), before - 1, "the slash dispelled the decoy")
	assert_eq(boss.dispel_flash_positions().size(), 1)
	var fsm: ActionStateMachine = rig["fsm"]
	assert_eq(fsm.stun_left, 0, "a dispel is a landed hit: no NullPointerException")
	assert_true(boss.hp <= hp, "the boss took at most the slash's own hit")
	assert_push_error_count(0)


# --- Story 5.5 AC 5, 6: a real Null Pointer attack through Null Dodge arms Clean Catch ---

func test_null_dodge_through_an_attack_then_a_slash_deals_clean_catch() -> void:
	SimClock._pending_hitstop = 0
	var saved: int = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE # a hit outside the dodge must not record a death
	var rig: Dictionary = _combat_rig([Register.Bit.NULL_BIT, A], true)
	var boss: NullPointerBody = rig["boss"]
	var fsm: ActionStateMachine = rig["fsm"]
	var health: PlayerHealth = rig["health"]
	var buf: InputBuffer = rig["buf"]
	var n: int = 0
	var hp_lost_in_dodge: bool = false
	while not fsm.clean_catch_armed and n < 4000:
		# Dodge (J = N) whenever a live attack is out and N is ready (test-only grant of N, D-S55-1).
		if boss.state == S.ACTIVE and fsm.action == null and fsm.cooldowns.ready(Register.Bit.NULL_BIT):
			buf.push(J, rig["t"])
		var hp: int = health.hp
		var dodging: bool = fsm.action == Defs.NULL_DODGE and fsm.invulnerable()
		_rig_tick(rig)
		if dodging and fsm.invulnerable() and health.hp < hp:
			hp_lost_in_dodge = true
		if health.hp < health.def.max_hp:
			# A hit before the dodge started (its first ACTIVE tick): undo it and its blink, so the
			# next contact is rejected by the dodge itself (post-hit invulnerability does not arm).
			health.hp = health.def.max_hp
			health.dead = false
			health.invuln_left = 0
		n += 1
	SimClock._pending_hitstop = 0
	assert_true(fsm.clean_catch_armed, "a Null Pointer attack passed through the dodge (%d ticks)" % n)
	assert_false(hp_lost_in_dodge, "no HP lost on intangible frames")
	while fsm.action != null:
		_rig_tick(rig)
	health.invuln_left = 0
	var player: Player = rig["player"]
	_to_recovery_at(rig, player.position_px + Vector2(24, 0))
	assert_false(boss.weak_window.is_patched())
	watch_signals(EventBus)
	var hp_before: int = boss.hp
	buf.push(K, rig["t"]) # K = A: a solo slash on the unpatched ghost
	for i: int in 12:
		_rig_tick(rig)
	SimClock._pending_hitstop = 0
	assert_eq(hp_before - boss.hp, 8, "slash 10 x0.5 x1.5 = 7.5 -> 8")
	var hits: int = get_signal_emit_count(EventBus, "hit_landed")
	assert_eq(hits, 1, "one hit_landed")
	if hits == 1:
		var params: Array = get_signal_parameters(EventBus, "hit_landed", 0)
		assert_eq(params[1], 8, "hit_landed carries the Clean Catch damage")
		assert_eq(params[2], DamageState.Kind.UNPATCHED)
	assert_false(fsm.clean_catch_armed, "consumed by the hit")
	Game.flow_state = saved as GameScript.FlowState
	assert_push_error_count(0)
