extends BossAttack
## Infinite Loop, Nested Loop (Story 3.5, FR36, D-S35-2 to D-S35-4): phase 3, once per fight (the body's
## candidate list forces it as the first phase-3 pick and drops it afterwards, D-S35-3). TELL (40
## frames): nothing moves; BossView flashes the body. ACTIVE (1 frame): nothing. on_recovery (called
## by the FSM on normal completion, recovery 0): the body splits into the outer (16) and inner (8)
## rings and starts the timed `;` schedule with the outer ring open (split_rings, idempotent). A cut
## before completion (defeat) leaves the ring whole. No hazard of its own; draws no RNG (D-S34-14);
## reads nothing from the arena (NP-3).


func on_recovery(_ctx: ArenaContext) -> void:
	var body: InfiniteLoopBody = boss() as InfiniteLoopBody
	if body != null:
		body.split_rings()


## The split ring's segment centres (both rings) if the body split now, from its current centre
## (AC 15). The body's own split geometry, so the test reads the positions the body uses.
func declared_positions(_ctx: ArenaContext) -> PackedVector2Array:
	var body: InfiniteLoopBody = boss() as InfiniteLoopBody
	if body == null:
		return PackedVector2Array()
	return body.split_positions()
