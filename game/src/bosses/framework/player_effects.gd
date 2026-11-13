class_name PlayerEffects
extends SimSystem
## The NP-3 boss-to-player effect queue (Story 3.1, D-S31-11): bosses push commands here and never
## call Player or Register. Ticks in SimPhase.PLAYER_EFFECTS (after BOSS_HAZARDS, before COMBAT)
## and applies the queue there. Story 6.5 (D-S65-3): the first command type, RotateRegister
## (SIGSEGV); 6.6 adds InsertTemporaryBit. The Arena binds the fight's Register and LinkState; an
## unbound queue logs an error and drops its commands.


## Story 6.5 (NP-3, D-S65-3, D-S65-4, D-S65-5): rotates the register `count` slots (sign =
## direction, +2 = `>>` for SIGSEGV) and closes the combo link (NP-1). The Register emits
## register_shifted once with `source`. Plain data: holds no node or system.
class RotateRegister:
	extends RefCounted

	var count: int = 0
	var source: StringName = &"sigsegv"

	func _init(p_count: int = 0, p_source: StringName = &"sigsegv") -> void:
		count = p_count
		source = p_source

	func apply(register: Register, link: LinkState) -> void:
		register.rotate(count, source)
		if link != null:
			link.close()


var _queue: Array[RefCounted] = []
var _register: Register = null
var _link: LinkState = null


func _init() -> void:
	phase = SimPhase.PLAYER_EFFECTS


func tick(_ctx: SimContext) -> void:
	apply_all()


## Story 6.5: the fight's Register and LinkState the commands act on (the Arena wiring).
func bind(p_register: Register, p_link: LinkState) -> void:
	_register = p_register
	_link = p_link


func is_bound() -> bool:
	return _register != null


## Queues one command for the next PLAYER_EFFECTS tick.
func push(command: RefCounted) -> void:
	_queue.append(command)


## Applies every queued command in push order, then empties the queue. Unbound, or a command with
## no apply(): Log.error and the command is dropped.
func apply_all() -> void:
	if _queue.is_empty():
		return
	var batch: Array[RefCounted] = _queue.duplicate() # a command may push; those run next tick
	_queue.clear()
	if _register == null:
		Log.error(&"effects", "PlayerEffects not bound: %d command(s) dropped" % batch.size())
		return
	for command: RefCounted in batch:
		if command == null or not command.has_method(&"apply"):
			Log.error(&"effects", "PlayerEffects: command without apply() dropped")
			continue
		command.call(&"apply", _register, _link)


func pending() -> int:
	return _queue.size()


## Fight start and retry: nothing carries over.
func clear() -> void:
	_queue.clear()
