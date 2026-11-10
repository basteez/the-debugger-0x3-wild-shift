class_name BossDef
extends Def
## One boss's data (Story 3.1, AD-06, FR30, FR32): signature, HP, phases, drop bit, the fixed
## line and the body hurtbox radius (D-S31-12). Read-only at runtime; BossController runs it.

## The id emitted with EventBus.boss_defeated (Game.BOSS_IDS for real bosses).
@export var boss_id: StringName = &""
## The HUD header name: `void <name_signature>() // hp <hp>` (FR32, D-S31-14).
@export var name_signature: String = ""
@export var max_hp: int = 1
## Phases in order; thresholds strictly decreasing, the first at 100 (D-S31-4).
@export var phases: Array[PhaseDef] = []
## The bit this boss drops at Harvest (Story 3.8).
@export var drop_bit: int = 0
## The boss's fixed log line (presentation; final text in later stories).
@export var fixed_line: String = ""
## Radius of the single body hurtbox circle in tiles (D-S31-12).
@export var body_radius_tiles: float = 1.0


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if boss_id == &"":
		out.append("boss_id must not be empty")
	if name_signature.strip_edges() == "":
		out.append("name_signature must not be empty")
	if max_hp < 1:
		out.append("max_hp must be >= 1 (got %d)" % max_hp)
	if drop_bit < 0:
		out.append("drop_bit must be >= 0 (got %d)" % drop_bit)
	if not is_finite(body_radius_tiles) or body_radius_tiles <= 0.0:
		out.append("body_radius_tiles must be > 0 (got %s)" % body_radius_tiles)
	if phases.is_empty():
		out.append("a boss needs at least one phase")
	var previous: int = 101
	var ids: Dictionary[StringName, AttackDef] = {}
	for i: int in phases.size():
		var phase: PhaseDef = phases[i]
		if phase == null:
			out.append("phases[%d] is null" % i)
			continue
		if i == 0 and phase.hp_threshold != 100:
			out.append("phases[0] hp_threshold must be 100 (got %d)" % phase.hp_threshold)
		if phase.hp_threshold >= previous:
			out.append("phases[%d] hp_threshold must be lower than the previous phase (%d >= %d)" % [i, phase.hp_threshold, previous])
		previous = phase.hp_threshold
		for message: String in phase.validate():
			out.append("phases[%d]: %s" % [i, message])
		for attack: AttackDef in phase.attack_pool:
			if attack == null or attack.id == &"":
				continue
			if ids.has(attack.id) and ids[attack.id] != attack:
				out.append("attack id %s is used by two different attacks" % attack.id)
			ids[attack.id] = attack
	return out
