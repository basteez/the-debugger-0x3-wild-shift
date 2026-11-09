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

## Longest name_signature, so `void <name>() // hp <hp>` fits the top bar (Story 3.2, D-S32-16).
const NAME_SIGNATURE_MAX := 16


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if boss_id == &"":
		out.append("boss_id must not be empty")
	if name_signature.strip_edges() == "":
		out.append("name_signature must not be empty")
	elif name_signature.length() > NAME_SIGNATURE_MAX or not name_signature.is_valid_ascii_identifier():
		out.append("name_signature must be an identifier of at most %d characters (got \"%s\")" % [NAME_SIGNATURE_MAX, name_signature])
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
		if not is_valid_weak_window(phase.weak_window):
			out.append("phases[%d] weak_window must be two distinct bits (got %s)" % [i, phase.weak_window])
		for message: String in phase.validate():
			out.append("phases[%d]: %s" % [i, message])
		for attack: AttackDef in phase.attack_pool:
			if attack == null or attack.id == &"":
				continue
			if ids.has(attack.id) and ids[attack.id] != attack:
				out.append("attack id %s is used by two different attacks" % attack.id)
			ids[attack.id] = attack
	return out


## A weak window is two distinct valid register bits (Story 3.2, D-S32-16). Pure.
static func is_valid_weak_window(w: Vector2i) -> bool:
	return Register.is_bit(w.x) and Register.is_bit(w.y) and w.x != w.y
