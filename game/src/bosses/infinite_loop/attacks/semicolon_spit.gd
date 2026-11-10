extends RefCounted
## Infinite Loop, `;` Spit (Story 3.5, FR35, D-S35-8 to D-S35-11): phase 3 only, a timed behaviour on
## a fixed cycle, not a pool attack. The body ticks it on every live phase-3 tick except ROAR (attacks
## do not freeze it). The cycle counts down from spit_period_frames; the origin `;` glows for the
## last spit_tell_frames ticks (presentation reads glowing()), and when it reaches zero one
## projectile leaves the origin junction toward the aim at spit_tps (an integer milli-tile step
## rounded once at fire time). Projectiles live in a fixed pool of spit_slots preallocated slots (no
## allocation in tick); a slot frees when its position leaves the play area; a shot with no free
## slot is skipped. State is integer (hashed by the replay test); px positions are derived.
## Aims only through ctx.target_position() (NP-3); draws no RNG (D-S34-14). Contact with the player
## is asked by the body (touches_player, D-S35-11), never here.

const MILLI := 1000
const TICKS_PER_SECOND := 60

## Ticks left in the current cycle; 0 = off (outside phase 3).
var timer: int = 0
## Projectile slots, parallel arrays sized once (spit_slots).
var slot_active: PackedByteArray = PackedByteArray()
var slot_pos_mtiles: Array[Vector2i] = []
var slot_step_mtiles: Array[Vector2i] = []
## Shots fired / skipped for a full pool since the last reset (tests, debug).
var shots: int = 0
var skipped: int = 0

var _period: int = 360
var _tell: int = 20
var _step_len_mtiles: int = 100


## Sizes the pool and reads the numbers from `ring` (once per fight; allocation only here).
func configure(ring: RingDef) -> void:
	_period = ring.spit_period_frames
	_tell = ring.spit_tell_frames
	@warning_ignore("integer_division")
	_step_len_mtiles = ring.spit_tps * MILLI / TICKS_PER_SECOND
	if slot_active.size() != ring.spit_slots:
		slot_active.resize(ring.spit_slots)
		slot_pos_mtiles.resize(ring.spit_slots)
		slot_step_mtiles.resize(ring.spit_slots)
	clear()
	timer = 0


## Starts the cycle (phase-3 entry, D-S35-15): the first shot is spit_period_frames ticks away.
func start() -> void:
	clear()
	timer = _period


## Stops the cycle and frees every projectile (phase change, defeat, retry).
func stop() -> void:
	clear()
	timer = 0


## Frees every projectile slot.
func clear() -> void:
	slot_active.fill(0)
	slot_pos_mtiles.fill(Vector2i.ZERO)
	slot_step_mtiles.fill(Vector2i.ZERO)


func is_running() -> bool:
	return timer > 0


## True during the last _tell ticks of the cycle (the origin `;` glows).
func glowing() -> bool:
	return timer > 0 and timer <= _tell


## One live tick: move every projectile (freeing those that left the play area), then count the
## cycle down and fire from `origin_px` toward the aim at zero. Returns true when a shot fired.
func tick(origin_px: Vector2, ctx: ArenaContext) -> bool:
	if timer <= 0:
		return false
	_move()
	timer -= 1
	if timer > 0:
		return false
	timer = _period
	return fire(origin_px, Arena.clamp_to_play_area(ctx.target_position()))


## Puts one projectile at `origin_px` aimed at `aim_px` in the first free slot. False (logged in
## debug builds) when the pool is full.
func fire(origin_px: Vector2, aim_px: Vector2) -> bool:
	var slot: int = slot_active.find(0)
	if slot < 0:
		skipped += 1
		if Debug.enabled:
			Log.debug(&"boss", "spit skipped: pool full")
		return false
	slot_active[slot] = 1
	slot_pos_mtiles[slot] = px_to_mtiles(origin_px)
	slot_step_mtiles[slot] = step_for(origin_px, aim_px, _step_len_mtiles)
	shots += 1
	if Debug.enabled:
		Log.debug(&"boss", "spit fired")
	return true


func _move() -> void:
	for k: int in slot_active.size():
		if slot_active[k] == 0:
			continue
		var p: Vector2i = slot_pos_mtiles[k] + slot_step_mtiles[k]
		if not ArenaContext.inside_play_area(mtiles_to_px(p)):
			slot_active[k] = 0
			slot_pos_mtiles[k] = Vector2i.ZERO
			slot_step_mtiles[k] = Vector2i.ZERO
			continue
		slot_pos_mtiles[k] = p


## Live projectile count.
func live_count() -> int:
	return slot_active.count(1)


## Arena-local px centres of the live projectiles (presentation, contact).
func projectile_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	for k: int in slot_active.size():
		if slot_active[k] != 0:
			out.append(mtiles_to_px(slot_pos_mtiles[k]))
	return out


## Every point a shot from `origin_px` toward the (clamped) aim would occupy until it leaves the
## play area, origin and aim included (AC 15). The same step math as fire().
func declared_positions(origin_px: Vector2, ctx: ArenaContext) -> PackedVector2Array:
	var aim: Vector2 = Arena.clamp_to_play_area(ctx.target_position())
	var out := PackedVector2Array([origin_px, aim])
	var p: Vector2i = px_to_mtiles(origin_px)
	var step: Vector2i = step_for(origin_px, aim, _step_len_mtiles)
	if step == Vector2i.ZERO:
		return out
	while true:
		p += step
		var px: Vector2 = mtiles_to_px(p)
		if not ArenaContext.inside_play_area(px):
			break
		out.append(px)
	return out


## The integer per-tick step of a shot from `origin` toward `aim` (px), `len_mtiles` long: the unit
## direction rounded once to whole milli-tiles (straight down when the aim gives none). Pure.
static func step_for(origin: Vector2, aim: Vector2, len_mtiles: int) -> Vector2i:
	var d: Vector2 = (aim - origin).normalized()
	if d == Vector2.ZERO:
		d = Vector2.DOWN
	return Vector2i(roundi(d.x * len_mtiles), roundi(d.y * len_mtiles))


## Arena-local px to whole milli-tiles (rounded). Pure.
static func px_to_mtiles(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / Const.TILE_PX * MILLI), roundi(p.y / Const.TILE_PX * MILLI))


## Whole milli-tiles to arena-local px. Pure.
static func mtiles_to_px(m: Vector2i) -> Vector2:
	return Vector2(float(m.x), float(m.y)) / float(MILLI) * Const.TILE_PX
