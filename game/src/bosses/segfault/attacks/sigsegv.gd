class_name Sigsegv
extends BossAttack
## Segfault, SIGSEGV (Story 6.5, FR43, NP-3): phases 2-3. TELL (60 frames): a warning tell, read by
## presentation through warning_tell() (the HUD border and the `SIGSEGV incoming` line, D-S65-7,
## D-S65-8). ACTIVE (1 frame): one PlayerEffects rotation by +2 (`>>`, D-S65-4), applied in the
## PLAYER_EFFECTS phase of the same tick. RECOVERY: 90 frames, 150 with Breakpoint cut (data,
## BossController.effective_recovery). No ground hazard, no aim, no RNG (test_attack_isolation).

## D-S65-4: the rotation, a fixed +2 slots (the `>>` direction).
const ROTATION := 2

## D-S65-6: one rotation per attack, even if a later data change makes ACTIVE longer than 1 frame.
var fired: bool = false
## True from TELL entry until the tell ends (ACTIVE), the recovery or a cut.
var _warning: bool = false


func on_tell(_ctx: ArenaContext) -> void:
	fired = false
	_warning = true


func on_active(ctx: ArenaContext) -> void:
	_warning = false
	if fired or ctx == null:
		return
	fired = true
	ctx.player_effects.push(PlayerEffects.RotateRegister.new(ROTATION))


## The latch stays set through RECOVERY (a late on_active in the same attack queues nothing); the
## next TELL entry rearms it.
func on_recovery(_ctx: ArenaContext) -> void:
	_warning = false


## D-S65-11: a cut during TELL fires nothing. The queue is cleared by reset_for_fight on retry.
func on_cancel(_ctx: ArenaContext) -> void:
	_clear()


func reset() -> void:
	_clear()


## Presentation (AD-05): true while this attack's warning tell runs (the boss is in TELL on it).
func warning_tell() -> bool:
	var b: BossController = boss()
	return _warning and b != null and b.state == BossController.BossState.TELL and b.current_attack() == self


func _clear() -> void:
	fired = false
	_warning = false
