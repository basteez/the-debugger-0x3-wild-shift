class_name PracticeTarget
extends RefCounted
## The `/* test */` training dummy (Story 2.7, FR22, FR59; GDD "Practice Target"): infinite HP, no
## attacks, never Patched, always x1. Sim data only (D-S27-10): no FSM, no tick, no node.
## CombatResolver is the only writer, through register_hit; PracticeTargetView only reads.
## There is no HP field: infinite HP is the absence of damage state.

## Hurtbox radius (D-S27-2): 1.5 tiles.
const HURTBOX_RADIUS_TILES := 1.5
## Damage multiplier: the practice target is never a boss, never Patched (GDD, NP-4).
const DAMAGE_MULT := 1.0
## Hit records kept for the readout (ring of the last N).
const LOG_CAPACITY := 8

## Arena-local pixels, centre of the hurtbox.
var position_px: Vector2 = Vector2.ZERO
var hurtbox_radius_px: float = HURTBOX_RADIUS_TILES * Const.TILE_PX
## Hits registered since the last reset.
var hits: int = 0
## ActionStateMachine.action_serial of the last action that hit; -1 = none (D-S27-4).
var last_hit_serial: int = -1

## Fixed-capacity ring of hit records; _next is the slot the next record goes to.
var _frames: PackedInt32Array = PackedInt32Array()
var _actions: Array[StringName] = []
var _damages: PackedInt32Array = PackedInt32Array()
var _next: int = 0
var _count: int = 0


func _init(p_position_px: Vector2 = Vector2.ZERO) -> void:
	position_px = p_position_px
	_frames.resize(LOG_CAPACITY)
	_actions.resize(LOG_CAPACITY)
	_damages.resize(LOG_CAPACITY)


## Records one hit (sim frame, action id, damage) from the action with `serial`.
func register_hit(serial: int, frame: int, action_id: StringName, damage: int) -> void:
	hits += 1
	last_hit_serial = serial
	_frames[_next] = frame
	_actions[_next] = action_id
	_damages[_next] = damage
	_next = (_next + 1) % LOG_CAPACITY
	_count = mini(_count + 1, LOG_CAPACITY)


## True when the action with `serial` already hit this target.
func was_hit_by(serial: int) -> bool:
	return last_hit_serial == serial


## The damage multiplier this target takes: always x1.
func damage_multiplier() -> float:
	return DAMAGE_MULT


## The kept records, oldest first: [{frame, action, damage}], at most LOG_CAPACITY.
func records() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var start: int = (_next - _count + LOG_CAPACITY) % LOG_CAPACITY
	for i: int in _count:
		var at: int = (start + i) % LOG_CAPACITY
		out.append({&"frame": _frames[at], &"action": _actions[at], &"damage": _damages[at]})
	return out


## Fight start and retry: no hits, no records.
func reset() -> void:
	hits = 0
	last_hit_serial = -1
	_next = 0
	_count = 0
