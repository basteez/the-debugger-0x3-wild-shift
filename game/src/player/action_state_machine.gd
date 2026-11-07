class_name ActionStateMachine
extends SimSystem
## The player's action state machine (Story 2.5, NP-1): runs one ActionDef at a time, one action
## frame per world tick (D-S25-1). Ticked by SimClock in the ACTIONS phase (after SHIFTS, before
## PLAYER). The only writer of action state; ActionResolver is the only path from J/K to an action.
## Holds the Player and Register; neither holds this (no script cycle, 2.2 lesson).

## STUNNED and WATCHING are declared for Epics 4-6 and never entered in Story 2.5.
enum ActionState { IDLE_MOVE, STARTUP, ACTIVE, RECOVERY, STUNNED, WATCHING }

var state: ActionState = ActionState.IDLE_MOVE
## The running action, or null.
var action: ActionDef = null
## The last executed action frame (1-based); 0 when no action runs.
var action_frame: int = 0
## Facing captured when the action started; held for the whole action (D-S25-6).
var facing: Vector2i = Player.DEFAULT_FACING
## Chain record (D-S25-2): the key and slot that started the ATTACK chain and the register's
## shift serial at its start; chain_serial -1 = no chain.
var chain_key: StringName = &""
var chain_slot: int = -1
var chain_serial: int = -1
var cooldowns: Cooldowns = Cooldowns.new()
## Only an active FSM ticks: on in FIGHT, off elsewhere.
var active: bool = false

var _buffer: InputBuffer
var _player: Player
var _register: Register


func _init(p_buffer: InputBuffer = null, p_player: Player = null, p_register: Register = null) -> void:
	phase = SimPhase.ACTIONS
	_buffer = p_buffer
	_player = p_player
	_register = p_register


## One world frame (only SimClock calls this).
func tick(ctx: SimContext) -> void:
	if not active:
		return
	cooldowns.tick()
	var window: Vector2i = _register.active_window() if _register != null else Vector2i.ZERO
	var serial: int = _register.shift_serial if _register != null else 0
	var request: ActionRequest = ActionResolver.resolve(_buffer, ctx.poll_frame, window, action, action_frame, chain_key, chain_serial, serial, cooldowns)
	if request != null:
		_start(request, serial)
	elif action != null:
		if action_frame >= action.total_frames():
			_finish()
		else:
			action_frame += 1
	state = state_for(action, action_frame)
	_apply_movement()


## True while the executing frame is inside the running action's invulnerable range (FR11).
func invulnerable() -> bool:
	return action != null and action.is_invulnerable_frame(action_frame)


## 1-based frame inside the current state; 0 in IDLE_MOVE.
func frame_in_state() -> int:
	if action == null:
		return 0
	match state:
		ActionState.STARTUP:
			return action_frame
		ActionState.ACTIVE:
			return action_frame - action.startup_frames
		ActionState.RECOVERY:
			return action_frame - action.startup_frames - action.active_frames
	return 0


## Fight start (D-049 b): idle, no action, cooldowns and chain cleared, Player unlocked.
func reset_for_fight() -> void:
	_finish()
	cooldowns.reset()
	facing = Player.DEFAULT_FACING
	state = ActionState.IDLE_MOVE
	if _player != null:
		_player.unlock_movement()


## On in FIGHT, off elsewhere; turning off unlocks the Player.
func set_active(on: bool) -> void:
	active = on
	if not on:
		_finish()
		state = ActionState.IDLE_MOVE
		if _player != null:
			_player.unlock_movement()


## The state of an executing action frame (D-S25-1). Pure.
static func state_for(def: ActionDef, frame: int) -> ActionState:
	if def == null or frame <= 0:
		return ActionState.IDLE_MOVE
	if frame <= def.startup_frames:
		return ActionState.STARTUP
	if frame <= def.startup_frames + def.active_frames:
		return ActionState.ACTIVE
	return ActionState.RECOVERY


static func state_name(s: ActionState) -> String:
	return ActionState.keys()[s]


func _start(request: ActionRequest, serial: int) -> void:
	action = request.def
	action_frame = 1
	facing = _player.facing if _player != null else Player.DEFAULT_FACING
	if request.def.cooldown_frames > 0:
		cooldowns.start(request.bit, request.def.cooldown_frames)
	if request.chain:
		Log.debug(&"action", "chain %s" % request.def.id)
	elif request.def.chain_next != null:
		chain_key = request.key
		chain_slot = request.slot
		chain_serial = serial
		Log.debug(&"action", "%s %s" % ["cancel" if request.cancel else "start", request.def.id])
	else:
		_clear_chain()
		Log.debug(&"action", "%s %s" % ["cancel" if request.cancel else "start", request.def.id])


func _finish() -> void:
	action = null
	action_frame = 0
	_clear_chain()


func _clear_chain() -> void:
	chain_key = &""
	chain_slot = -1
	chain_serial = -1


## Movement rules (D-S25-6): STARTUP and ACTIVE of a stationary action lock in place; ACTIVE of a
## moving action locks at move_tiles * TILE_PX / active_frames along the captured facing; every
## other state is unlocked.
func _apply_movement() -> void:
	if _player == null:
		return
	match state:
		ActionState.STARTUP:
			_player.lock_movement(Vector2.ZERO)
		ActionState.ACTIVE:
			_player.lock_movement(dash_velocity(action, facing))
		_:
			_player.unlock_movement()


## Per-frame velocity of an action's ACTIVE frames along `dir` (zero for stationary actions). Pure.
static func dash_velocity(def: ActionDef, dir: Vector2i) -> Vector2:
	if def == null or def.move_tiles <= 0.0 or def.active_frames <= 0:
		return Vector2.ZERO
	var speed: float = def.move_tiles * Const.TILE_PX / def.active_frames
	return Vector2(dir).normalized() * speed
