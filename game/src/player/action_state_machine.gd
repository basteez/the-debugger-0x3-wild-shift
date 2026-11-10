class_name ActionStateMachine
extends SimSystem
## The player's action state machine (Story 2.5, NP-1): runs one ActionDef at a time, one action
## frame per world tick (D-S25-1). Ticked by SimClock in the ACTIONS phase (after SHIFTS, before
## PLAYER). The only writer of action state; ActionResolver is the only path from J/K to an action.
## Holds the Player and Register; neither holds this (no script cycle, 2.2 lesson).
## Story 2.6: owns the combo LinkState (D-S26-4) and starts combos and link follow-ups.

## STUNNED and WATCHING are declared for Epics 4-6 and never entered in Story 2.5.
enum ActionState { IDLE_MOVE, STARTUP, ACTIVE, RECOVERY, STUNNED, WATCHING }

var state: ActionState = ActionState.IDLE_MOVE
## The running action, or null.
var action: ActionDef = null
## The last executed action frame (1-based); 0 when no action runs.
var action_frame: int = 0
## Facing captured when the action started; held for the whole action (D-S25-6).
var facing: Vector2i = Player.DEFAULT_FACING
## Hit-shape anchor (Story 2.7, D-S27-13): the player's position when the running action started,
## held for the whole action, so Dash Strike's capsule covers the path it travels. Arena-local px.
var action_origin_px: Vector2 = Vector2.ZERO
## Incremented on every action start, never reset in a session (Story 2.7, D-S27-4): a target
## remembers the serial of the action that last hit it, so each action hits it once.
var action_serial: int = 0
## Chain record (D-S25-2): the key and slot that started the ATTACK chain and the register's
## shift serial at its start; chain_serial -1 = no chain.
var chain_key: StringName = &""
var chain_slot: int = -1
var chain_serial: int = -1
var cooldowns: Cooldowns = Cooldowns.new()
## The combo link (Story 2.6, D-S26-4): written only here, read by the resolver and the F9 overlay.
var link: LinkState = LinkState.new()
## The slot (0 = J, 1 = K) of the running action; -1 when none. Only J actions open the link.
var action_slot: int = -1
## The running action's combo (null = none) and its link_second flag (FR20); read by 2.7.
var combo: ComboDef = null
var link_second: bool = false
## The register window (J bit, K bit) the running action started on (Story 3.2, D-S32-5): for a
## combo the combo's pair, for a link_second the link's pair. ZERO when no action runs.
var action_window: Vector2i = Vector2i.ZERO
## The combo table (Defs.COMBOS; tests may inject a stub).
var combos: ComboTable = Defs.COMBOS
## Only an active FSM ticks: on in FIGHT, off elsewhere.
var active: bool = false

## The serial at the running J action's start; the link opens only if no shift happened since (review).
var _start_serial: int = -1

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
	_age_link(serial)
	var request: ActionRequest = ActionResolver.resolve(_resolve_input(ctx.poll_frame, window, serial))
	if request != null and request.def == null:
		_apply_link_op(request)
		request = null
	if request != null:
		_start(request, serial, window)
	elif action != null:
		if action_frame >= action.total_frames():
			_finish()
		else:
			action_frame += 1
	state = state_for(action, action_frame)
	_update_link(window, serial)
	_apply_movement()


## The resolver's inputs for this tick (Story 2.7 AC6): one object instead of 11 arguments.
func _resolve_input(poll_frame: int, window: Vector2i, serial: int) -> ResolveInput:
	var input := ResolveInput.new()
	input.buffer = _buffer
	input.frame = poll_frame
	input.window = window
	input.action = action
	input.action_frame = action_frame
	input.chain_key = chain_key
	input.chain_serial = chain_serial
	input.shift_serial = serial
	input.cooldowns = cooldowns
	input.link = link
	input.combos = combos
	return input


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


## Fight start (D-049 b): idle, no action, cooldowns, chain and link cleared, Player unlocked.
func reset_for_fight() -> void:
	_finish()
	cooldowns.reset()
	link.close()
	facing = Player.DEFAULT_FACING
	state = ActionState.IDLE_MOVE
	if _player != null:
		_player.unlock_movement()


## On in FIGHT, off elsewhere; turning off unlocks the Player.
func set_active(on: bool) -> void:
	active = on
	if not on:
		_finish()
		link.close()
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


func _start(request: ActionRequest, serial: int, window: Vector2i = Vector2i.ZERO) -> void:
	action = request.def
	action_window = window
	action_frame = 1
	action_slot = request.slot
	combo = request.combo
	link_second = request.link_second
	facing = _player.facing if _player != null else Player.DEFAULT_FACING
	action_origin_px = _player.position_px if _player != null else Vector2.ZERO
	action_serial += 1
	_start_serial = serial
	var cooldown: int = request.def.cooldown_frames
	if request.combo != null:
		# D-S26-3: the replaced solo action's cooldown applies to the second bit.
		var replaced: ActionDef = Defs.solo_action(request.bit)
		cooldown = replaced.cooldown_frames if replaced != null else 0
	if cooldown > 0:
		cooldowns.start(request.bit, cooldown)
	if request.combo != null or request.link_second:
		# D-S26-13: one link, one K follow-up.
		link.close()
	if request.combo != null:
		_clear_chain()
		Log.debug(&"action", "combo %s" % request.combo.display_name)
	elif request.chain:
		Log.debug(&"action", "chain %s" % request.def.id)
	elif request.def.chain_next != null:
		chain_key = request.key
		chain_slot = request.slot
		chain_serial = serial
		Log.debug(&"action", "%s %s" % [_start_verb(request), request.def.id])
	else:
		_clear_chain()
		Log.debug(&"action", "%s %s" % [_start_verb(request), request.def.id])


static func _start_verb(request: ActionRequest) -> String:
	if request.link_second:
		return "link_second"
	return "cancel" if request.cancel else "start"


## Before resolution (D-S26-7, B3): an applied shift closes the link and discards a held press; the
## 18-tick count loses one tick and closes the link when it runs out.
func _age_link(serial: int) -> void:
	if not link.is_open():
		return
	if link.serial != serial:
		var dropped: bool = link.held
		link.close()
		Log.debug(&"action", "link closed by shift%s" % (", held K discarded" if dropped else ""))
		return
	var dropped_on_expiry: bool = link.held
	if link.tick():
		Log.debug(&"action", "link closed%s" % (", held K discarded" if dropped_on_expiry else ""))


## After the frame executed (B2): a J action's first ACTIVE frame opens (or reopens) the link on the
## current window; its last ACTIVE frame starts the 18-tick count (k = 0).
func _update_link(window: Vector2i, serial: int) -> void:
	if action == null or action_slot != 0:
		return
	if action_frame == action.startup_frames + 1 and serial == _start_serial:
		link.open(window, serial)
		Log.debug(&"action", "link open %s %s" % [Register.glyph_of(window.x), Register.glyph_of(window.y)])
	if action_frame == action.startup_frames + action.active_frames:
		link.start_count()


func _apply_link_op(request: ActionRequest) -> void:
	match request.link_op:
		ActionRequest.LinkOp.HOLD:
			link.hold(request.key, request.slot, request.held_frame)
			Log.debug(&"action", "link holds K")
		ActionRequest.LinkOp.DROP:
			link.clear_hold()
			Log.debug(&"action", "link drops K (cooldown)")


func _finish() -> void:
	if link.is_open() and not link.counting:
		link.start_count()  # J ended before its last ACTIVE frame: never leave the link uncounted.
	action = null
	action_frame = 0
	action_slot = -1
	combo = null
	link_second = false
	action_window = Vector2i.ZERO
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
