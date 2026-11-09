class_name CombatResolver
extends SimSystem
## Resolves hits by shape math once per world tick (Story 2.7, AD-04, ADR-02, NP-4). A SimSystem in
## the COMBAT phase, after ACTIONS and PLAYER, so it reads the action frame that just executed
## (D-S27-5). No Area2D, no physics body: the running action's HitShape, anchored at the action's
## start (D-S27-13), is tested against each target's circular hurtbox. Inputs are injected
## (D-S27-11); holds no node. Order per hit (NP-4): interactions (Epic 3), damage, hit_landed.
## Story 2.7 targets are practice targets only (x1, never Patched); hit-stop is Story 2.8.
## The hit's frame stamp is SimClock.sim_frame, the same frame as the Log `[f=...]` prefix (D-S27-8).

var actions: ActionStateMachine
var player: Player
var targets: Array[PracticeTarget] = []


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
	var hit: Array[PracticeTarget] = hits_for(def.hit_shape, actions.action_origin_px, Vector2(actions.facing).normalized(), targets, serial)
	var is_combo: bool = actions.combo != null
	for target: PracticeTarget in hit:
		var damage: int = DamageCalc.compute(def.base_damage, target.damage_multiplier(), false, 1.0)
		target.register_hit(serial, SimClock.sim_frame, def.id, damage)
		Log.debug(&"combat", "hit %s dmg=%d" % [def.id, damage])
		EventBus.hit_landed.emit(&"practice_target", damage, DamageCalc.STATE_BASE, is_combo, target.position_px)


## The targets the shape overlaps that the action with `serial` has not hit yet (D-S27-4). Pure.
static func hits_for(shape: HitShape, origin: Vector2, facing: Vector2, p_targets: Array[PracticeTarget], serial: int) -> Array[PracticeTarget]:
	var out: Array[PracticeTarget] = []
	if shape == null:
		return out
	for target: PracticeTarget in p_targets:
		if target == null or target.was_hit_by(serial):
			continue
		if shape.overlaps(origin, facing, target.position_px, target.hurtbox_radius_px):
			out.append(target)
	return out
