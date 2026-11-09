extends BossAttack
## Framework test fixture (Story 3.1, D-S31-17): a pulse centred on the aim point. Deals no
## damage; it only aims through ctx.target_position() and counts its hooks so tests can check the
## FSM. The tell position is clamped into the play area (no off-screen tells, Pillar 2).

var aim_px: Vector2 = Vector2.ZERO
var tells: int = 0
var actives: int = 0
var recoveries: int = 0


func on_tell(ctx: ArenaContext) -> void:
	tells += 1
	aim_px = Arena.clamp_to_play_area(ctx.target_position())


func on_active(_ctx: ArenaContext) -> void:
	actives += 1


func on_recovery(_ctx: ArenaContext) -> void:
	recoveries += 1


func reset() -> void:
	aim_px = Vector2.ZERO
	tells = 0
	actives = 0
	recoveries = 0


func declared_positions(ctx: ArenaContext) -> PackedVector2Array:
	return PackedVector2Array([Arena.clamp_to_play_area(ctx.target_position())])
