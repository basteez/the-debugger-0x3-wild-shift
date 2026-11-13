class_name CorruptMemory
extends BossAttack
## Segfault, Corrupt Memory (Story 6.4, FR42, D-S64-4): phases 1-3. TELL (60 frames): 8-12 distinct
## tiles, drawn by the body from the fight's seeded RNG at TELL entry (D-S64-2), are marked `░` on
## the shared CorruptedTiles grid. ACTIVE (240 frames): those tiles are `▓` hazards; a player centre
## that enters one takes 1 HP through the body's contact path, once per entry (D-S64-5). RECOVERY
## (40 frames) and a cut (phase change, defeat): the grid is cleared. Draws no RNG and never reads
## the player: the body does both (test_attack_isolation).

## D-S64-4: the tile count range per use (inclusive).
const MIN_TILES := 8
const MAX_TILES := 12


func on_tell(_ctx: ArenaContext) -> void:
	var b: SegfaultBody = _body()
	if b == null or b.tiles == null:
		return
	b.tiles.reset()
	b.mark_random_tiles(MIN_TILES, MAX_TILES)


## D-S64-7: the marked tiles turn into hazards (idempotent, every ACTIVE tick).
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


## The player's centre `p` on one of this attack's tiles, ACTIVE only (a pure query; the body's
## entry latch decides the hit, D-S64-5).
func hazard_hit(p: Vector2) -> bool:
	var t: CorruptedTiles = _tiles()
	return t != null and is_live() and t.is_attack_tile(CorruptedTiles.cell_at(p))


## TELL: the centres of the `░` tiles (presentation).
func tile_marks() -> PackedVector2Array:
	var t: CorruptedTiles = _tiles()
	if t == null or not _in_state(BossController.BossState.TELL):
		return PackedVector2Array()
	return t.attack_centres()


## ACTIVE: the centres of the `▓` tiles (presentation and tests).
func hazard_positions() -> PackedVector2Array:
	var t: CorruptedTiles = _tiles()
	if t == null or not _in_state(BossController.BossState.ACTIVE):
		return PackedVector2Array()
	return t.attack_centres()


## Corrupt Memory has no safe-tile drawing (Core Dump only).
func safe_tiles() -> PackedVector2Array:
	return PackedVector2Array()


## Every marked tile's centre (AC 12): all inside the 32 x 18 play area by construction.
func declared_positions(_ctx: ArenaContext) -> PackedVector2Array:
	var t: CorruptedTiles = _tiles()
	return t.attack_centres() if t != null else PackedVector2Array()


func _clear() -> void:
	var t: CorruptedTiles = _tiles()
	if t != null:
		t.reset()


func _in_state(s: BossController.BossState) -> bool:
	var b: BossController = boss()
	return b != null and b.state == s and b.current_attack() == self


func _body() -> SegfaultBody:
	return boss() as SegfaultBody


func _tiles() -> CorruptedTiles:
	var b: SegfaultBody = _body()
	return b.tiles if b != null else null
