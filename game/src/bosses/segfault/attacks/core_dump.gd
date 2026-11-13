class_name CoreDump
extends BossAttack
## Segfault, Core Dump (Story 6.4, FR42, D-S64-6): phase 3 only. TELL (60 frames): the whole grid
## becomes a per-tile checkerboard on the shared CorruptedTiles grid: the hazard parity ((x + y)
## odd, 288 tiles) is marked `░` and the safe parity (288 tiles) is drawn `·`, so the safe tiles are
## visible for the whole tell. ACTIVE (180 frames): the hazard parity is `▓`; a player centre that
## enters one takes 1 HP through the body's contact path, once per entry (D-S64-5); the safe parity
## never hurts. RECOVERY (60 frames) and a cut: the grid is cleared. Deterministic (no draw at all).


func on_tell(_ctx: ArenaContext) -> void:
	var t: CorruptedTiles = _tiles()
	if t == null:
		return
	t.reset()
	t.mark_checkerboard()


## D-S64-7: the hazard parity turns `▓`, the safe dots go (idempotent, every ACTIVE tick).
func on_active(_ctx: ArenaContext) -> void:
	var t: CorruptedTiles = _tiles()
	if t != null:
		t.arm()


func on_recovery(_ctx: ArenaContext) -> void:
	_clear()


func on_cancel(_ctx: ArenaContext) -> void:
	_clear()


func reset() -> void:
	_clear()


## The player's centre `p` on a hazard-parity tile, ACTIVE only (a pure query; the body's entry
## latch decides the hit, D-S64-5).
func hazard_hit(p: Vector2) -> bool:
	var t: CorruptedTiles = _tiles()
	return t != null and is_live() and t.is_attack_tile(CorruptedTiles.cell_at(p))


## TELL: the centres of the `░` (hazard parity) tiles.
func tile_marks() -> PackedVector2Array:
	var t: CorruptedTiles = _tiles()
	if t == null or not _in_state(BossController.BossState.TELL):
		return PackedVector2Array()
	return t.attack_centres()


## TELL: the centres of the `·` (safe parity) tiles, a presentation getter only (D-S64-6).
func safe_tiles() -> PackedVector2Array:
	var t: CorruptedTiles = _tiles()
	if t == null or not _in_state(BossController.BossState.TELL):
		return PackedVector2Array()
	return t.centres_in(CorruptedTiles.TileState.SAFE)


## ACTIVE: the centres of the `▓` tiles.
func hazard_positions() -> PackedVector2Array:
	var t: CorruptedTiles = _tiles()
	if t == null or not _in_state(BossController.BossState.ACTIVE):
		return PackedVector2Array()
	return t.attack_centres()


## Every hazard-parity tile's centre (AC 12), whatever the grid holds: a pure function of the grid.
func declared_positions(_ctx: ArenaContext) -> PackedVector2Array:
	return hazard_parity_centres()


## The 288 hazard-parity tile centres, row-major. Pure.
static func hazard_parity_centres() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in CorruptedTiles.CELL_COUNT:
		var cell: Vector2i = CorruptedTiles.cell_of_index(i)
		if CorruptedTiles.is_hazard_parity(cell):
			out.append(CorruptedTiles.centre_of(cell))
	return out


func _clear() -> void:
	var t: CorruptedTiles = _tiles()
	if t != null:
		t.reset()


func _in_state(s: BossController.BossState) -> bool:
	var b: BossController = boss()
	return b != null and b.state == s and b.current_attack() == self


func _tiles() -> CorruptedTiles:
	var b: SegfaultBody = boss() as SegfaultBody
	return b.tiles if b != null else null
