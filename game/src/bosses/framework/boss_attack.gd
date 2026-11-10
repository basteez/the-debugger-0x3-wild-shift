class_name BossAttack
extends RefCounted
## Base of every boss attack script (Story 3.1, AD-06): one subclass per attack, instanced once by
## BossController.setup and reused every fight (no allocation in tick, D-S31-18). Hooks run from
## the sim tick only: on_tell at TELL entry, on_active on every ACTIVE tick, on_recovery at
## RECOVERY entry (D-S31-5). Attacks aim only through ctx.target_position() and affect the player
## only through ctx.player_effects or PlayerHealth requests (NP-3); they hold no node.
## Story 3.4 (D-S34-9, D-S34-11): an attack's hazards reach the player only through the boss body's
## touches_player, which asks hazard_hit (with the real player position the body read) while the
## boss is in ACTIVE. The attack reaches its boss through a weak back-reference set by
## BossController.setup (no ref cycle, no new ArenaContext channel). Presentation reads the
## tell_marks / hazard_positions / outline_circle getters (AD-05).

var _boss_ref: WeakRef = null


## BossController.setup: the boss that runs this attack (held weakly).
func bind_boss(p_boss: BossController) -> void:
	_boss_ref = weakref(p_boss) if p_boss != null else null


## The boss running this attack, or null (unbound, or freed).
func boss() -> BossController:
	if _boss_ref == null:
		return null
	return _boss_ref.get_ref() as BossController


## True while this attack is the boss's current attack and the boss is in ACTIVE.
func is_live() -> bool:
	var b: BossController = boss()
	return b != null and b.state == BossController.BossState.ACTIVE and b.current_attack() == self


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


## True when the player's centre `p` (arena-local px, given by the body) touches this attack's
## hazard. The body asks only while the boss is ACTIVE on this attack (D-S34-9). Default: none.
func hazard_hit(_p: Vector2) -> bool:
	return false


## True when the attack's hazard replaces the body's own contact area while live (Constrict's disc
## replaces the ring segments, D-S34-7). Default: false.
func replaces_body_contact() -> bool:
	return false


## Centres of the live hazard cells (presentation and tests). Default: none.
func hazard_positions() -> PackedVector2Array:
	return PackedVector2Array()


## Where the tell mark(s) `!` attach during TELL (presentation). Default: none.
func tell_marks() -> PackedVector2Array:
	return PackedVector2Array()


## A circle outline to draw (x, y = centre px, z = radius px); z <= 0 means none. Default: none.
func outline_circle() -> Vector3:
	return Vector3.ZERO
