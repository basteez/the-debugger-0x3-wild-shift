class_name CorruptedTiles
extends RefCounted
## Segfault's corrupted-tile grid (Story 6.4, FR42, D-S64-3): one 32 x 18 PackedByteArray of tile
## states, owned by SegfaultBody, allocated once (on the body's first reset_for_fight) and cleared in
## place afterwards. Nothing here allocates per tick. Shared by Corrupt Memory and Core Dump; the boss
## FSM is serial, so only one tile attack writes it at a time. The pickers take the RNG as a
## parameter (the attacks never name it, test_attack_isolation). D-S64-5: the one-hit-per-entry latch
## lives here and is updated once per sim tick by the body's contact check. Cut-ladder leaf
## (FeatureFlags.segfault): never named outside src/bosses/segfault/.

enum TileState { CLEAR, MARKED, HAZARD, SAFE }

const SIZE := Const.ARENA_TILES
const CELL_COUNT := Const.ARENA_TILES.x * Const.ARENA_TILES.y

## One byte per tile, row-major (index = y * SIZE.x + x).
var states := PackedByteArray()
## How many tiles are MARKED or HAZARD (the attack's set).
var attack_cells: int = 0
## D-S64-5: true when the player's centre was on an attack tile on the previous contact check.
var was_on_attack_tile: bool = false


func _init() -> void:
	states.resize(CELL_COUNT)
	states.fill(TileState.CLEAR)


## Fight start, retry, RECOVERY, cancel: every tile CLEAR and the latch released, in place.
func reset() -> void:
	states.fill(TileState.CLEAR)
	attack_cells = 0
	was_on_attack_tile = false


func is_empty() -> bool:
	return attack_cells == 0 and not states.has(TileState.SAFE)


static func in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y


static func index_of(cell: Vector2i) -> int:
	return cell.y * SIZE.x + cell.x


static func cell_of_index(i: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(i % SIZE.x, i / SIZE.x)


## The tile under arena-local px `p` (floor), possibly outside the grid. Pure.
static func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / Const.TILE_PX), floori(p.y / Const.TILE_PX))


## The arena-local px centre of tile `cell`. Pure.
static func centre_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * Const.TILE_PX


## D-S64-6: true for the Core Dump hazard parity ((x + y) odd). Pure.
static func is_hazard_parity(cell: Vector2i) -> bool:
	return (cell.x + cell.y) % 2 == 1


func state_at(cell: Vector2i) -> TileState:
	if not in_grid(cell):
		return TileState.CLEAR
	return states[index_of(cell)] as TileState


## MARKED or HAZARD: part of the live attack's set.
func is_attack_tile(cell: Vector2i) -> bool:
	var s: TileState = state_at(cell)
	return s == TileState.MARKED or s == TileState.HAZARD


func set_state(cell: Vector2i, s: TileState) -> void:
	if not in_grid(cell):
		return
	var i: int = index_of(cell)
	var was_attack: bool = states[i] == TileState.MARKED or states[i] == TileState.HAZARD
	var is_attack: bool = s == TileState.MARKED or s == TileState.HAZARD
	states[i] = s
	attack_cells += int(is_attack) - int(was_attack)


## D-S64-4: `count` distinct CLEAR tiles, uniform over the grid, marked from `rng` (rejection draw:
## at most 12 of 576 tiles are taken, deterministic for a seed). Returns how many were marked.
func mark_random(rng: RandomNumberGenerator, count: int) -> int:
	var marked: int = 0
	var n: int = mini(count, CELL_COUNT - attack_cells)
	while marked < n:
		var i: int = rng.randi_range(0, CELL_COUNT - 1)
		if states[i] != TileState.CLEAR:
			continue
		set_state(cell_of_index(i), TileState.MARKED)
		marked += 1
	return marked


## D-S64-6: the whole grid as a checkerboard: the hazard parity MARKED, the other parity SAFE.
func mark_checkerboard() -> void:
	for i: int in CELL_COUNT:
		set_state(cell_of_index(i), TileState.MARKED if is_hazard_parity(cell_of_index(i)) else TileState.SAFE)


## ACTIVE: every MARKED tile becomes HAZARD, every SAFE tile CLEAR (D-S64-6, D-S64-7). Idempotent.
func arm() -> void:
	for i: int in CELL_COUNT:
		if states[i] == TileState.MARKED:
			states[i] = TileState.HAZARD
		elif states[i] == TileState.SAFE:
			states[i] = TileState.CLEAR


## D-S64-5: one hit per entry. Called once per contact check with the player's centre `p`; `live`
## is true while the boss is ACTIVE on a tile attack. True only when the centre is on an attack tile
## now, was not on one at the previous check, and the attack is live. Being on a marked tile during
## the TELL counts as "on", so a player standing there when ACTIVE starts is not hit until they leave
## and come back.
func entry_hit(p: Vector2, live: bool) -> bool:
	var on: bool = is_attack_tile(cell_at(p))
	var hit: bool = live and on and not was_on_attack_tile
	was_on_attack_tile = on
	return hit


## The px centres of every tile in state `s` (presentation and tests; allocates, never in tick).
func centres_in(s: TileState) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in CELL_COUNT:
		if states[i] == s:
			out.append(centre_of(cell_of_index(i)))
	return out


## The px centres of the attack's tiles (MARKED or HAZARD). Allocates; presentation and tests only.
func attack_centres() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in CELL_COUNT:
		if states[i] == TileState.MARKED or states[i] == TileState.HAZARD:
			out.append(centre_of(cell_of_index(i)))
	return out
