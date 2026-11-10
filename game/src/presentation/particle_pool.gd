class_name ParticlePool
extends Node2D
## Glyph particles for hit feedback (Story 2.8 AC2, AD-07, NFR2). A fixed pool of CAPACITY slots in
## packed arrays allocated once; a spawn into a full pool drops the rest silently. Particles step
## once per new SimClock.sim_frame, so they freeze with hit-stop, pause and Breakpoint (D-S28-3);
## only the drawing runs per process frame, in one _draw. Presentation only (AD-05): it listens to
## EventBus.hit_landed, reads SimClock.sim_frame read-only, and is never read by the simulation.
## Randomness is presentation-owned (never SimContext.rng). Main places it at the arena origin, so
## the arena-local hit points line up.

const CAPACITY := 300
## Burst sizes (D-S28-2).
const SOLO_BURST := 12
const COMBO_BURST := 20
## Lifetime in sim frames (D-S28-2).
const LIFETIME := 14
const GLYPHS: PackedStringArray = ["*", "+", "'", ".", "x"]
## Initial speed range in px per sim frame, and the per-frame velocity damping.
const SPEED_MIN := 1.5
const SPEED_MAX := 3.5
const DRAG := 0.85
## Particles draw at 1x; the glyph is centred on the particle position.
const GLYPH_SCALE := 1
const HALF_CELL := Vector2(GlyphFont.CELL, GlyphFont.CELL) / 2.0
## `age` value of a free slot.
const FREE := -1

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _pos: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()
var _age: PackedInt32Array = PackedInt32Array()
var _glyph: PackedInt32Array = PackedInt32Array()
var _live: int = 0
## The sim frame the particles were last stepped to.
var _stepped_frame: int = 0
## True while the last _draw showed particles, so one more redraw clears them.
var _drawn: bool = false


func _init() -> void:
	_pos.resize(CAPACITY)
	_vel.resize(CAPACITY)
	_age.resize(CAPACITY)
	_glyph.resize(CAPACITY)
	_age.fill(FREE)
	rng.randomize()
	_stepped_frame = SimClock.sim_frame


func _enter_tree() -> void:
	if not EventBus.hit_landed.is_connected(_on_hit_landed):
		EventBus.hit_landed.connect(_on_hit_landed)
	_stepped_frame = SimClock.sim_frame


func _exit_tree() -> void:
	if EventBus.hit_landed.is_connected(_on_hit_landed):
		EventBus.hit_landed.disconnect(_on_hit_landed)


func _process(_delta: float) -> void:
	advance_to(SimClock.sim_frame)
	if _live > 0 or _drawn:
		queue_redraw()


## Places up to `count` particles at `at` (pool-local px); returns how many were placed. A full
## pool drops the rest silently (NFR2). No allocation: free slots are reused.
func spawn(at: Vector2, count: int) -> int:
	var placed: int = 0
	if count <= 0:
		return 0
	for i: int in CAPACITY:
		if placed >= count:
			break
		if _age[i] != FREE:
			continue
		var angle: float = rng.randf() * TAU
		_pos[i] = at
		_vel[i] = Vector2.from_angle(angle) * rng.randf_range(SPEED_MIN, SPEED_MAX)
		_age[i] = 0
		_glyph[i] = rng.randi_range(0, GLYPHS.size() - 1)
		placed += 1
	_live += placed
	return placed


## Steps every live particle once per sim frame between the last stepped frame and `sim_frame`.
## No step when the sim clock did not advance (hit-stop, pause, Breakpoint).
func advance_to(sim_frame: int) -> void:
	var steps: int = sim_frame - _stepped_frame
	_stepped_frame = sim_frame
	if _live == 0 or steps <= 0:
		return
	for _s: int in mini(steps, LIFETIME):
		step()


## One sim frame for every live particle: move, damp, age, expire.
func step() -> void:
	if _live == 0:
		return
	for i: int in CAPACITY:
		if _age[i] == FREE:
			continue
		_pos[i] += _vel[i]
		_vel[i] *= DRAG
		_age[i] += 1
		if _age[i] >= LIFETIME:
			_age[i] = FREE
			_live -= 1


## Live particles (F10 perf overlay).
func live_count() -> int:
	return _live


## Slot count of the pool (fixed at CAPACITY).
func slot_count() -> int:
	return _age.size()


## Pool-local position of slot `i` (tests).
func position_of(i: int) -> Vector2:
	return _pos[i]


## Burst size for a hit (D-S28-2). Story 3.2 (D-S32-18): a resisted (UNPATCHED) hit bursts half
## the glyphs. Pure.
static func burst_for(is_combo: bool, state: int = DamageState.Kind.BASE) -> int:
	var count: int = COMBO_BURST if is_combo else SOLO_BURST
	@warning_ignore("integer_division")
	return count / 2 if state == DamageState.Kind.UNPATCHED else count


func clear() -> void:
	_age.fill(FREE)
	_live = 0
	_stepped_frame = SimClock.sim_frame
	queue_redraw()


func _draw() -> void:
	_drawn = _live > 0
	if _live == 0:
		return
	for i: int in CAPACITY:
		if _age[i] == FREE:
			continue
		GlyphFont.draw_at(self, (_pos[i] - HALF_CELL).round(), GLYPHS[_glyph[i]], Palette.INK, GLYPH_SCALE)


func _on_hit_landed(_target: StringName, _damage: int, state: int, is_combo: bool, pos: Vector2) -> void:
	spawn(pos, burst_for(is_combo, state))
	queue_redraw()
