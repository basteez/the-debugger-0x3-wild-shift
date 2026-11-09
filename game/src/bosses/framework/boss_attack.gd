class_name BossAttack
extends RefCounted
## Base of every boss attack script (Story 3.1, AD-06): one subclass per attack, instanced once by
## BossController.setup and reused every fight (no allocation in tick, D-S31-18). Hooks run from
## the sim tick only: on_tell at TELL entry, on_active on every ACTIVE tick, on_recovery at
## RECOVERY entry (D-S31-5). Attacks aim only through ctx.target_position() and affect the player
## only through ctx.player_effects or PlayerHealth requests (NP-3); they hold no node.


## TELL entry: choose the aim point, start the telegraph.
func on_tell(_ctx: ArenaContext) -> void:
	pass


## Every ACTIVE tick: move or spawn hazards.
func on_active(_ctx: ArenaContext) -> void:
	pass


## RECOVERY entry: the attack is spent. Not called when a phase change cuts the attack (on_cancel runs instead).
func on_recovery(_ctx: ArenaContext) -> void:
	pass


## A phase change or defeat cuts the attack mid-flight: clear hazards and markers. No on_recovery.
func on_cancel(_ctx: ArenaContext) -> void:
	pass


## Fight start and retry: clear any per-fight fields.
func reset() -> void:
	pass


## Every tell and spawn position (arena-local px) this attack would use against `ctx`, so a test
## can check none is off-screen (Pillar 2, AC 5). Empty by default.
func declared_positions(_ctx: ArenaContext) -> PackedVector2Array:
	return PackedVector2Array()
