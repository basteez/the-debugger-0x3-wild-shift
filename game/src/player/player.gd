class_name Player
extends SimSystem
## The player `@` movement system (Story 2.2): linear speed ramp, 8-direction facing and the
## arena bounds clamp (D-S22-1, D-S22-2). Pure simulation: reads ctx.move_dir, no Input, no delta,
## no scene tree. Drawn by PlayerView (presentation reads, never writes).

## Default facing at spawn (D-S22-6): right.
const DEFAULT_FACING := Vector2i(1, 0)
## Story 5.4 (GDD Skills, D-S54-5): top speed factor while Watch is held (ctx.watch_held).
const WATCH_SPEED_FACTOR := 0.5

var def: PlayerDef
## Rect the glyph centre may occupy, arena-local (Arena.player_bounds()). Injected rather than read
## from Arena so player/ and arena/ scripts do not reference each other (a script cycle leaks).
var bounds_px: Rect2
## Arena-local pixels, centre of the `@` glyph. The only non-integer sim state (rounded when drawn).
var position_px: Vector2 = Vector2.ZERO
## Pixels per sim frame.
var velocity_px: Vector2 = Vector2.ZERO
## Last non-zero movement direction, always one of the 8 directions (persists while idle).
var facing: Vector2i = DEFAULT_FACING
## Only an active player ticks (D-S22-5): on in FIGHT, off elsewhere.
var active: bool = false
## Movement lock (Story 2.5, D-S25-6): while true, tick() moves at `locked_velocity_px` and keeps
## `facing`. Written only through lock_movement / unlock_movement (by the ActionStateMachine).
var locked: bool = false
var locked_velocity_px: Vector2 = Vector2.ZERO


func _init(p_def: PlayerDef, p_bounds_px: Rect2) -> void:
	phase = SimPhase.PLAYER
	bounds_px = p_bounds_px
	if p_def == null:
		Log.error(&"data", "Player created without a PlayerDef, using defaults")
		assert(false, "Player needs a PlayerDef")
		p_def = PlayerDef.new()
	def = p_def


## One world frame (only SimClock calls this).
func tick(ctx: SimContext) -> void:
	if not active:
		return
	if locked:
		velocity_px = locked_velocity_px
		position_px += velocity_px
		_clamp_to_bounds()
		return
	var dir: Vector2i = sanitize_dir(ctx.move_dir)
	if dir != Vector2i.ZERO:
		facing = dir
	var v_max: float = Const.tiles_per_s_to_px_per_frame(def.speed_tiles_s)
	# Story 5.4 (D-S54-5): Watch halves the top speed, same ramp shape. Story 5.5 (D-S55-3): so do
	# Null Dodge's active frames (ctx.move_slowed); one factor, the two never stack.
	if ctx.watch_held or ctx.move_slowed:
		v_max *= WATCH_SPEED_FACTOR
	var target: Vector2 = Vector2.ZERO
	var step: float = v_max / def.decel_frames
	if dir != Vector2i.ZERO:
		target = Vector2(dir).normalized() * v_max
		step = v_max / def.accel_frames
	velocity_px = velocity_px.move_toward(target, step)
	position_px += velocity_px
	_clamp_to_bounds()


## Fight entry (every route into FIGHT, D-S22-5): spawn, zero velocity, default facing.
func reset_for_fight(spawn_px: Vector2) -> void:
	position_px = spawn_px
	velocity_px = Vector2.ZERO
	facing = DEFAULT_FACING


func set_active(on: bool) -> void:
	active = on


## Forces the per-frame velocity and freezes facing until unlock_movement (Story 2.5).
func lock_movement(p_velocity_px: Vector2) -> void:
	locked = true
	locked_velocity_px = p_velocity_px


## Releases the lock. The carried velocity is capped at walking top speed, so the normal decel ramp
## stops the player within decel_frames after a dash ([design call] D-S25-15). No-op when unlocked.
func unlock_movement() -> void:
	if not locked:
		return
	locked = false
	locked_velocity_px = Vector2.ZERO
	velocity_px = velocity_px.limit_length(Const.tiles_per_s_to_px_per_frame(def.speed_tiles_s))


## Any direction reduced to its per-axis sign, so components are always in {-1, 0, 1} (C4).
static func sanitize_dir(dir: Vector2i) -> Vector2i:
	return Vector2i(signi(dir.x), signi(dir.y))


## Clamps the centre into bounds_px and zeroes velocity components that point into a wall, so the
## player does not stick to the edge after reversing (D-S22-7).
func _clamp_to_bounds() -> void:
	var clamped: Vector2 = position_px.clamp(bounds_px.position, bounds_px.end)
	if clamped.x != position_px.x:
		velocity_px.x = 0.0
	if clamped.y != position_px.y:
		velocity_px.y = 0.0
	position_px = clamped
