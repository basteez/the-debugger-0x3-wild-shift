class_name Cooldowns
extends RefCounted
## Remaining cooldown frames per bit id (Story 2.5, D-S25-4). Counted in sim frames, decremented
## once per tick at the start of the ACTIONS phase. Owned by the ActionStateMachine.

var _remaining: Dictionary[int, int] = {}


## Starts (or restarts) `bit`'s cooldown. `frames` <= 0 clears it.
func start(bit: int, frames: int) -> void:
	if frames <= 0:
		_remaining.erase(bit)
		return
	_remaining[bit] = frames


func ready(bit: int) -> bool:
	return remaining(bit) == 0


func remaining(bit: int) -> int:
	return _remaining.get(bit, 0)


## One sim frame: every running cooldown loses one frame; finished ones are dropped.
func tick() -> void:
	for bit: int in _remaining.keys():
		var left: int = _remaining[bit] - 1
		if left <= 0:
			_remaining.erase(bit)
		else:
			_remaining[bit] = left


func reset() -> void:
	_remaining.clear()
