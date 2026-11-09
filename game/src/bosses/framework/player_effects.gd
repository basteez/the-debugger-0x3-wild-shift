class_name PlayerEffects
extends SimSystem
## The NP-3 boss-to-player effect queue (Story 3.1, D-S31-11): bosses push commands here and never
## call Player or Register. Ticks in SimPhase.PLAYER_EFFECTS (after BOSS_HAZARDS, before COMBAT)
## and drains the queue. A slot only: no command types until 6.5 (RotateRegister) and 6.6
## (InsertTemporaryBit), so the queue stays empty in 3.1.

var _queue: Array[RefCounted] = []


func _init() -> void:
	phase = SimPhase.PLAYER_EFFECTS


func tick(_ctx: SimContext) -> void:
	apply_all()


## Queues one command for the next PLAYER_EFFECTS tick.
func push(command: RefCounted) -> void:
	_queue.append(command)


## Applies and drops every queued command. No command types exist yet, so this only drains.
func apply_all() -> void:
	if _queue.is_empty():
		return
	_queue.clear()


func pending() -> int:
	return _queue.size()


## Fight start and retry: nothing carries over.
func clear() -> void:
	_queue.clear()
