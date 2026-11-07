class_name InputBuffer
extends RefCounted
## 8-frame input buffer (AC3, FR6, FR58). A press pushed at frame f can be consumed through
## f + PRESS_LIFETIME_FRAMES (inclusive), at most once, oldest first; unconsumed presses expire.

const PRESS_LIFETIME_FRAMES := 8

var _actions: Array[StringName] = []
var _frames: PackedInt64Array = PackedInt64Array()
var _consumed: Array[bool] = []


func push(action: StringName, frame: int) -> void:
	_prune(frame)
	_actions.append(action)
	_frames.append(frame)
	_consumed.append(false)


## Consumes the oldest live press of `action` at `frame`. True if one was found.
func consume(action: StringName, frame: int) -> bool:
	for i: int in _actions.size():
		if _consumed[i] or _actions[i] != action:
			continue
		if _is_live(_frames[i], frame):
			_consumed[i] = true
			return true
	return false


## Consumes the oldest live press whose action is in `actions` at `frame` (D-S23-3), so presses of
## several actions are handled in press order. Returns that action, or &"" when none is live.
func consume_oldest(actions: Array[StringName], frame: int) -> StringName:
	for i: int in _actions.size():
		if _consumed[i] or not actions.has(_actions[i]):
			continue
		if _is_live(_frames[i], frame):
			_consumed[i] = true
			return _actions[i]
	return &""


func clear() -> void:
	_actions.clear()
	_frames.clear()
	_consumed.clear()


## Entries currently stored (live or not yet pruned). For tests.
func size() -> int:
	return _actions.size()


static func _is_live(pushed_frame: int, frame: int) -> bool:
	return frame >= pushed_frame and frame - pushed_frame <= PRESS_LIFETIME_FRAMES


## Drops consumed and expired entries, in place, keeping order.
func _prune(frame: int) -> void:
	var keep: int = 0
	for i: int in _actions.size():
		if _consumed[i] or frame - _frames[i] > PRESS_LIFETIME_FRAMES:
			continue
		_actions[keep] = _actions[i]
		_frames[keep] = _frames[i]
		_consumed[keep] = _consumed[i]
		keep += 1
	_actions.resize(keep)
	_frames.resize(keep)
	_consumed.resize(keep)
