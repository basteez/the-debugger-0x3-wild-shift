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

var actions: ActionStateMachine
## Unused (2.7 deferred, D-S32-13); kept so the constructor used by Arena and tests stays put.
var player: Player
var targets: Array[PracticeTarget] = []
## The fight's boss (Story 3.2, D-S32-23): set and cleared by the Arena; null = no boss.
var boss: BossController = null


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
	var hit: Array[PracticeTarget] = hits_for(def.hit_shape, origin, facing, targets, serial)
	var boss_hit: bool = boss_overlapped(def.hit_shape, origin, facing, boss, serial)
	if hit.is_empty() and not boss_hit:
		return
	var is_combo: bool = actions.combo != null
	var hitstop: int = 0
	if boss_hit:
		hitstop = _resolve_boss_hit(def, serial, is_combo)
	for target: PracticeTarget in hit:
		var damage: int = DamageCalc.compute(def.base_damage, DamageState.multiplier(DamageState.Kind.BASE), false, 1.0)
		target.register_hit(serial, SimClock.sim_frame, def.id, damage)
		Log.debug(&"combat", "hit %s dmg=%d" % [def.id, damage])
		EventBus.hit_landed.emit(target.hit_target_id(), damage, DamageState.Kind.BASE, is_combo, target.position_px)
		hitstop = maxi(hitstop, HitFeedback.hitstop_for(is_combo, def.hitstop_frames))
	SimClock.request_hitstop(hitstop)


## The boss hit of this tick (NP-4, D-S32-12): interactions, patch, damage, take_hit, hit_landed.
## Returns the hit's hit-stop frames.
func _resolve_boss_hit(def: ActionDef, serial: int, is_combo: bool) -> int:
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
	var damage: int = DamageCalc.compute(def.base_damage, DamageState.multiplier(state), false, 1.0)
	var pos: Vector2 = boss.body_center_px
	boss.mark_hit(serial)
	boss.take_hit(damage)
	Log.debug(&"combat", "boss hit %s dmg=%d state=%d" % [def.id, damage, state])
	EventBus.hit_landed.emit(boss.hit_target_id(), damage, state, is_combo, pos)
	return HitFeedback.hitstop_for_boss_hit(state, is_combo, def.hitstop_frames, applied)


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
## hittable, not yet hit by that action, and its body circle overlaps the shape. Pure.
static func boss_overlapped(shape: HitShape, origin: Vector2, facing: Vector2, p_boss: BossController, serial: int) -> bool:
	if shape == null or p_boss == null or not p_boss.is_hittable() or p_boss.was_hit_by(serial):
		return false
	return shape.overlaps(origin, facing, p_boss.body_center_px, p_boss.body_radius_px())
