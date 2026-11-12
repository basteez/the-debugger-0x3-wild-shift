class_name CombatResolver
extends SimSystem
## Resolves hits by shape math once per world tick (Story 2.7, AD-04, ADR-02, NP-4). A SimSystem in
## the COMBAT phase, after ACTIONS and PLAYER, so it reads the action frame that just executed
## (D-S27-5). No Area2D, no physics body: the running action's HitShape, anchored at the action's
## start (D-S27-13), is tested against each target's circular hurtbox. Inputs are injected
## (D-S27-11); holds no node. Practice targets are x1 and never Patched. Story 2.8: after the hit loop
## the tick requests hit-stop once, the maximum HitFeedback value of its hits (AD-01, D-S28-12).
## The hit's frame stamp is SimClock.sim_frame, the same frame as the Log `[f=...]` prefix (D-S27-8).
## Story 3.2 (NP-4, D-S32-12): with a hittable boss the order is interactions (BossInteraction.HIT)
## -> WeakWindowTracker.process (Patched applied, patched_applied emitted) -> damage with the
## post-patch state (DamageCalc only) -> take_hit / register_hit -> hit_landed -> one hit-stop
## request (HitFeedback.hitstop_for_boss_hit for the boss, hitstop_for for practice targets).
## Story 4.1 (D-S41-5): an Echo hit passes ActionStateMachine.echo_scale() (0.7) to DamageCalc.
## Story 4.2 (D-S42-2): a pass_through action (Echo Dash) produces BossInteraction.PASS_THROUGH on a
## boss overlap and nothing else (no damage, practice targets skipped).
## Story 5.3 (D-S53-5, D-S53-6, D-S53-11): a non-pass-through action also dispels the boss's decoys
## (BossController.decoy_hit: no damage, no Patched, not a boss hit, hit-stop like a practice hit),
## and an ATTACK slash (Defs.SLASH_1..3, not a combo, not an Echo) that reaches its last ACTIVE frame
## having landed nothing (boss, decoy or practice target), with no K follow-up held by its link
## (D-S53-12), with the boss centre within
## BossController.whiff_stun_range_px() asks ActionStateMachine.begin_stun(NPE_STUN_FRAMES).
## Story 5.5 (D-S55-5, D-S55-6): ActionStateMachine.clean_catch_armed is passed to DamageCalc as the
## Clean Catch factor (x1.5 on top of the state) for every hit of the tick, boss and practice
## targets alike; it is consumed once, after the tick's hits, only when one of them dealt damage > 0.
## Whiffs, decoy dispels and pass-throughs never reach the damage path, so they keep it armed.

## Story 5.3 (D-S53-6): the NullPointerException stun length in sim frames.
const NPE_STUN_FRAMES := 20
## The log / EventBus reason of the whiff stun.
const NPE_REASON := &"NullPointerException"

var actions: ActionStateMachine
## Story 5.3: read only for the whiff range (the player's centre); null falls back to the action origin.
var player: Player
var targets: Array[PracticeTarget] = []
## The fight's boss (Story 3.2, D-S32-23): set and cleared by the Arena; null = no boss.
var boss: BossController = null
## Story 5.3: ActionStateMachine.action_serial of the last action that landed anything (boss hit,
## decoy dispel, practice target hit); -1 = none. Read by the whiff rule.
var _landed_serial: int = -1


func _init(p_actions: ActionStateMachine = null, p_player: Player = null) -> void:
	phase = SimPhase.COMBAT
	actions = p_actions
	player = p_player


## One world frame (only SimClock calls this).
func tick(_ctx: SimContext) -> void:
	if actions == null or actions.state != ActionStateMachine.ActionState.ACTIVE:
		return
	var def: ActionDef = actions.action
	if def == null or def.hit_shape == null:
		return
	var serial: int = actions.action_serial
	var origin: Vector2 = actions.action_origin_px
	var facing: Vector2 = Vector2(actions.facing).normalized()
	if def.pass_through:
		# Story 4.2 (D-S42-2): no damage, no hit_landed, no hit-stop, no practice targets.
		if boss_overlapped(def.hit_shape, origin, facing, boss, serial):
			_resolve_pass_through(def, serial)
		return
	var hit: Array[PracticeTarget] = hits_for(def.hit_shape, origin, facing, targets, serial)
	var boss_hit: bool = boss_overlapped(def.hit_shape, origin, facing, boss, serial)
	# Story 5.3 (D-S53-5, D-S53-8): decoys first, so a boss hit that ends the phase cannot clear them
	# under this very hit; each overlapped decoy is removed, so it is dispelled once.
	var dispelled: int = boss.decoy_hit(def.hit_shape, origin, facing) if boss != null else 0
	if hit.is_empty() and not boss_hit and dispelled == 0:
		_check_whiff(def, serial)
		return
	_landed_serial = serial
	var is_combo: bool = actions.combo != null
	var hitstop: int = 0
	var clean: bool = actions.clean_catch_armed
	var dealt: int = 0
	if dispelled > 0:
		Log.debug(&"combat", "decoy dispelled x%d by %s" % [dispelled, def.id])
		hitstop = HitFeedback.hitstop_for(is_combo, def.hitstop_frames)
	if boss_hit:
		var boss_damage: Array[int] = [0]
		hitstop = maxi(hitstop, _resolve_boss_hit(def, serial, is_combo, clean, boss_damage))
		dealt += boss_damage[0]
	for target: PracticeTarget in hit:
		var damage: int = DamageCalc.compute(def.base_damage, DamageState.multiplier(DamageState.Kind.BASE), clean, actions.echo_scale())
		dealt += damage
		target.register_hit(serial, SimClock.sim_frame, def.id, damage)
		Log.debug(&"combat", "hit %s dmg=%d" % [def.id, damage])
		EventBus.hit_landed.emit(target.hit_target_id(), damage, DamageState.Kind.BASE, is_combo, target.position_px)
		hitstop = maxi(hitstop, HitFeedback.hitstop_for(is_combo, def.hitstop_frames))
	if clean and dealt > 0:
		actions.consume_clean_catch()
	SimClock.request_hitstop(hitstop)


## Story 5.3 (AC 13-17, D-S53-6, D-S53-11): NullPointerException. On the last ACTIVE frame of a
## solo or chain ATTACK slash the player started (not an Echo, not a combo) that landed nothing,
## with a hittable boss whose whiff range is > 0 and whose centre is within it (centre to centre,
## edge included): the FSM is stunned. The stun starts on the next tick (ACTIONS ran already).
func _check_whiff(def: ActionDef, serial: int) -> void:
	if boss == null or _landed_serial == serial:
		return
	if actions.action_frame != def.startup_frames + def.active_frames:
		return
	if actions.echoing or actions.combo != null or not is_attack_slash(def):
		return
	# [design call] D-S53-12: a slash whose combo link already holds the K follow-up (A->D Dash
	# Strike, a link_second) is a combo opener, not a blind swing: it never stuns.
	if actions.link.held:
		return
	var reach: float = boss.whiff_stun_range_px()
	if reach <= 0.0 or not boss.is_hittable():
		return
	var at: Vector2 = player.position_px if player != null else actions.action_origin_px
	if at.distance_to(boss.body_center_px) > reach:
		return
	Log.debug(&"combat", "whiff %s: %s" % [def.id, NPE_REASON])
	actions.begin_stun(NPE_STUN_FRAMES, NPE_REASON)


## True for the ATTACK bit's slashes (Defs identity, D-S53-11). Pure.
static func is_attack_slash(def: ActionDef) -> bool:
	return def == Defs.SLASH_1 or def == Defs.SLASH_2 or def == Defs.SLASH_3


## The boss hit of this tick (NP-4, D-S32-12): interactions, patch, damage, take_hit, hit_landed.
## Returns the hit's hit-stop frames; the damage dealt is written to `out_damage[0]` (Story 5.5).
func _resolve_boss_hit(def: ActionDef, serial: int, is_combo: bool, clean: bool, out_damage: Array[int]) -> int:
	var interactions: Array[BossInteraction] = [
		BossInteraction.new(BossInteraction.Kind.HIT, actions.action_window, is_combo, actions.link_second),
	]
	var applied: bool = WeakWindowTracker.process(interactions, boss.current_weak_window())
	if applied:
		boss.weak_window.apply_patched(WeakWindowTracker.PATCHED_FRAMES)
		if Debug.enabled:
			Log.debug(&"combat", "patched %s by %s" % [boss.def.boss_id, def.id])
		EventBus.patched_applied.emit(boss.def.boss_id, WeakWindowTracker.PATCHED_FRAMES)
	var state: int = DamageState.Kind.PATCHED if boss.weak_window.is_patched() else DamageState.Kind.UNPATCHED
	var damage: int = DamageCalc.compute(def.base_damage, DamageState.multiplier(state), clean, actions.echo_scale())
	out_damage[0] = damage
	var pos: Vector2 = boss.hit_position() # Story 3.3 (D-S33-14): the `;` for the Infinite Loop
	boss.mark_hit(serial)
	boss.take_hit(damage)
	boss.on_player_hit() # Story 5.1 (AC 5): the Null Pointer's 10-frame flicker
	Log.debug(&"combat", "boss hit %s dmg=%d state=%d%s" % [def.id, damage, state, " clean" if clean else ""])
	EventBus.hit_landed.emit(boss.hit_target_id(), damage, state, is_combo, pos)
	return HitFeedback.hitstop_for_boss_hit(state, is_combo, def.hitstop_frames, applied)


## The PASS_THROUGH of this tick (Story 4.2, NP-4): one interaction on the action's window, the
## tracker decides Patched (the only writer), the boss is marked by the action's serial so one
## pass-through action fires once. No damage path at all.
func _resolve_pass_through(def: ActionDef, serial: int) -> void:
	var interactions: Array[BossInteraction] = [
		BossInteraction.new(BossInteraction.Kind.PASS_THROUGH, actions.action_window),
	]
	if WeakWindowTracker.process(interactions, boss.current_weak_window()):
		boss.weak_window.apply_patched(WeakWindowTracker.PATCHED_FRAMES)
		if Debug.enabled:
			Log.debug(&"combat", "patched %s by %s (pass-through)" % [boss.def.boss_id, def.id])
		EventBus.patched_applied.emit(boss.def.boss_id, WeakWindowTracker.PATCHED_FRAMES)
	boss.mark_hit(serial)
	boss.on_pass_through() # Story 5.1 (AC 6): the Null Pointer's 60-frame reveal
	Log.debug(&"combat", "boss pass-through %s" % def.id)


## The targets the shape overlaps that the action with `serial` has not hit yet (D-S27-4). A target
## listed twice is hit once (D-S32-24). Pure.
static func hits_for(shape: HitShape, origin: Vector2, facing: Vector2, p_targets: Array[PracticeTarget], serial: int) -> Array[PracticeTarget]:
	var out: Array[PracticeTarget] = []
	if shape == null:
		return out
	for target: PracticeTarget in p_targets:
		if target == null or target.was_hit_by(serial) or out.has(target):
			continue
		if shape.overlaps(origin, facing, target.position_px, target.hurtbox_radius_px):
			out.append(target)
	return out


## True when the shape hits `p_boss` for the action with `serial` (D-S32-9, D-S32-10): the boss is
## hittable, not yet hit by that action, and its hurtbox overlaps the shape (Story 3.3: through
## BossController.overlaps_shape, D-S33-14; a miss never marks the action, D-S33-5). Pure.
static func boss_overlapped(shape: HitShape, origin: Vector2, facing: Vector2, p_boss: BossController, serial: int) -> bool:
	if shape == null or p_boss == null or not p_boss.is_hittable() or p_boss.was_hit_by(serial):
		return false
	return p_boss.overlaps_shape(shape, origin, facing)
