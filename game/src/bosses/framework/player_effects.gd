class_name PlayerEffects
extends SimSystem
## The NP-3 boss-to-player effect queue (Story 3.1, D-S31-11): bosses push commands here and never
## call Player or Register. Ticks in SimPhase.PLAYER_EFFECTS (after BOSS_HAZARDS, before COMBAT)
## and applies the queue there. Story 6.5 (D-S65-3): the first command type, RotateRegister
## (SIGSEGV). Story 6.6 (D-S66-3, D-S66-4): InsertTemporaryBit (Reserved Write's garbage bit) and
## its expiry, counted here and applied in the same phase; commands share the PlayerCommand base.
## The Arena binds the fight's Register and LinkState; an unbound queue logs an error and drops
## its commands.

## Story 6.6 (AC 11): the garbage bit id, so attacks never name Register.
const GARBAGE_BIT := Register.Bit.GARBAGE


## Story 6.5 (NP-3, D-S65-3, D-S65-4, D-S65-5): rotates the register `count` slots (sign =
## direction, +2 = `>>` for SIGSEGV) and closes the combo link (NP-1). The Register emits
## register_shifted once with `source`. Plain data: holds no node or system.
class RotateRegister:
	extends PlayerCommand

	var count: int = 0
	var source: StringName = &"sigsegv"

	func _init(p_count: int = 0, p_source: StringName = &"sigsegv") -> void:
		count = p_count
		source = p_source

	func apply(register: Register, link: LinkState) -> bool:
		register.rotate(count, source)
		if link != null:
			link.close()
		return true


## Story 6.6 (NP-3, AC 6, AC 7, D-S66-3): writes `bit` into the ring as its temporary slot for
## `frames` PLAYER_EFFECTS ticks, counted from the application tick (the queue owns the counter).
## Closes the combo link (NP-1). Plain data: holds no node or system.
class InsertTemporaryBit:
	extends PlayerCommand

	var bit: int = 0
	var frames: int = 0

	func _init(p_bit: int = 0, p_frames: int = 0) -> void:
		bit = p_bit
		frames = p_frames

	func apply(register: Register, link: LinkState) -> bool:
		if frames <= 0 or not register.insert_temporary(bit, &"garbage_in"):
			return false
		if link != null:
			link.close()
		return true


var _queue: Array[PlayerCommand] = []
var _register: Register = null
var _link: LinkState = null
## Story 6.6: the live temporary bit (0 = none) and its remaining PLAYER_EFFECTS ticks.
var _temp_bit: int = 0
var _temp_left: int = 0


func _init() -> void:
	phase = SimPhase.PLAYER_EFFECTS


## Expiry first (a bit that ends this tick is gone before a new command lands), then the queue.
func tick(_ctx: SimContext) -> void:
	_tick_temporary()
	apply_all()


## Story 6.5: the fight's Register and LinkState the commands act on (the Arena wiring).
func bind(p_register: Register, p_link: LinkState) -> void:
	_register = p_register
	_link = p_link


func is_bound() -> bool:
	return _register != null


## Queues one command for the next PLAYER_EFFECTS tick.
func push(command: PlayerCommand) -> void:
	_queue.append(command)


## Applies every queued command in push order, then empties the queue. Unbound, or a null
## command: Log.error and the command is dropped.
func apply_all() -> void:
	if _queue.is_empty():
		return
	var batch: Array[PlayerCommand] = _queue.duplicate() # a command may push; those run next tick
	_queue.clear()
	if _register == null:
		Log.error(&"effects", "PlayerEffects not bound: %d command(s) dropped" % batch.size())
		return
	for command: PlayerCommand in batch:
		if command == null:
			Log.error(&"effects", "PlayerEffects: null command dropped")
			continue
		var applied: bool = command.apply(_register, _link)
		if applied and command is InsertTemporaryBit:
			var insert := command as InsertTemporaryBit
			_temp_bit = insert.bit
			_temp_left = insert.frames


func pending() -> int:
	return _queue.size()


## Story 6.6: the live temporary bit id (0 = none) and its remaining ticks (tests, presentation).
func temporary_bit() -> int:
	return _temp_bit


func temporary_frames_left() -> int:
	return _temp_left


## Story 6.6 (AC 13, D-S66-6): ends `bit` now: drops any queued insert of it and removes a live one
## from the register (register_changed `garbage_out`, link closed). No-op when neither exists.
func end_temporary(bit: int) -> void:
	for i: int in range(_queue.size() - 1, -1, -1):
		var insert := _queue[i] as InsertTemporaryBit
		if insert != null and insert.bit == bit:
			_queue.remove_at(i)
	if _temp_bit != 0 and _temp_bit == bit:
		_end_live()


## Fight start, retry and defeat: nothing carries over, and no temporary bit stays in the ring.
func clear() -> void:
	_queue.clear()
	if _temp_bit != 0:
		_end_live()


func _tick_temporary() -> void:
	if _temp_bit == 0:
		return
	_temp_left -= 1
	if _temp_left <= 0:
		_end_live()


func _end_live() -> void:
	_temp_bit = 0
	_temp_left = 0
	if _register != null and _register.remove_temporary(&"garbage_out") and _link != null:
		_link.close()
