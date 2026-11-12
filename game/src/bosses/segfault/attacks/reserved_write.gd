class_name ReservedWrite
extends BossAttack
## Segfault, Reserved Write (Story 6.6, FR44, cut ladder #1, NP-3): phase 3 only. TELL (45 frames):
## the register panel's `reserved` nibble flashes, read by presentation through reserved_tell()
## (D-S66-8, ink only). ACTIVE (600 frames, D-S66-2): one PlayerEffects InsertTemporaryBit of the
## garbage bit `?` for 600 ticks, pushed on the first ACTIVE tick and applied in the PLAYER_EFFECTS
## phase of that tick. RECOVERY: 30 frames. A cut (phase change, defeat) ends the garbage bit at
## once (D-S66-6). No ground hazard, no aim, no RNG (test_attack_isolation). Built only when
## FeatureFlags.reserved_write is on (the pool entry is dropped otherwise).

## D-S66-2: the garbage bit's lifetime in PLAYER_EFFECTS ticks (the GDD's 600 frames).
const GARBAGE_FRAMES := 600

## One insertion per attack (the 6.5 latch), even if ACTIVE lasts many frames.
var fired: bool = false
## True from TELL entry until the tell ends (ACTIVE), the recovery or a cut.
var _reserved: bool = false


func on_tell(_ctx: ArenaContext) -> void:
	fired = false
	_reserved = true


func on_active(ctx: ArenaContext) -> void:
	_reserved = false
	if fired or ctx == null:
		return
	fired = true
	ctx.player_effects.push(PlayerEffects.InsertTemporaryBit.new(PlayerEffects.GARBAGE_BIT, GARBAGE_FRAMES))


## The latch stays set through RECOVERY (a late on_active queues nothing); the next TELL rearms it.
## The garbage bit expires on its own counter in PlayerEffects.
func on_recovery(_ctx: ArenaContext) -> void:
	_reserved = false


## D-S66-6 (AC 13): a cut during TELL or ACTIVE fires nothing more and ends a live garbage bit now.
func on_cancel(ctx: ArenaContext) -> void:
	_clear()
	if ctx != null:
		ctx.player_effects.end_temporary(PlayerEffects.GARBAGE_BIT)


func reset() -> void:
	_clear()


## Presentation (AD-05): true while this attack's reserved tell runs (the boss is in TELL on it).
func reserved_tell() -> bool:
	var b: BossController = boss()
	return _reserved and b != null and b.state == BossController.BossState.TELL and b.current_attack() == self


func _clear() -> void:
	fired = false
	_reserved = false
