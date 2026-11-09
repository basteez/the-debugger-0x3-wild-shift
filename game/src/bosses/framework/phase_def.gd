class_name PhaseDef
extends Def
## One boss phase (Story 3.1, FR30, D-S31-4): the integer HP percent at which it starts, the gap
## between attacks and the attack pool. `weak_window` (an ordered bit pair) is unused until 3.2.

## HP percent at which this phase starts (1..100; the first phase is 100).
@export var hp_threshold: int = 100
## Ordered bit pair (first, second) the boss is weak to. Story 3.2.
@export var weak_window: Vector2i = Vector2i.ZERO
## Frames of GAP between one attack's recovery and the next tell (>= 1).
@export var gap_frames: int = 30
## Attacks drawn uniformly (no-triple-repeat, D-S31-6). At least two distinct attacks.
@export var attack_pool: Array[AttackDef] = []


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if hp_threshold < 1 or hp_threshold > 100:
		out.append("phase hp_threshold must be in 1..100 (got %d)" % hp_threshold)
	if gap_frames < 1:
		out.append("phase gap_frames must be >= 1 (got %d)" % gap_frames)
	var distinct: Array[AttackDef] = []
	for i: int in attack_pool.size():
		var attack: AttackDef = attack_pool[i]
		if attack == null:
			out.append("phase attack_pool[%d] is null" % i)
			continue
		if distinct.has(attack):
			out.append("phase attack_pool lists %s twice" % attack.id)
			continue
		distinct.append(attack)
		out.append_array(attack.validate())
	if distinct.size() < 2:
		out.append("phase attack_pool needs at least 2 distinct attacks (got %d)" % distinct.size())
	return out
