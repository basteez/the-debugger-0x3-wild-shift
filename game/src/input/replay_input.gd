class_name ReplayInput
extends InputSource
## Plays back a recording (AC6, D-S21-5). Frame i of the recording is returned on the i-th poll,
## counted by this source (independent of sim_frame); empty arrays once exhausted.
## Format v2 adds a parallel `moves` list ([x, y] per frame, Story 2.2 D-S22-4); a v1 recording
## (no `moves`) replays with zero movement.

## Seed the recording was made with; the replay run calls SimClock.begin_fight(seed_value) first.
var seed_value: int = 0
var _frames: Array[Array] = []
var _moves: Array[Vector2i] = []
## Poll counters: SimClock calls presses_for_frame and move_for_frame once each per polled frame,
## so both advance in lockstep and frame i's presses and move come back on the i-th poll.
var _poll_index: int = 0
var _move_index: int = 0


func _init(frames: Array = [], recorded_seed: int = 0, moves: Array = []) -> void:
	seed_value = recorded_seed
	for frame: Variant in frames:
		var presses: Array[StringName] = []
		if frame is Array:
			for action: Variant in frame:
				presses.append(StringName(str(action)))
		_frames.append(presses)
	var bad: int = 0
	for move: Variant in moves:
		var parsed: Vector2i = Vector2i.ZERO
		if _is_valid_move(move):
			parsed = Vector2i(int(move[0]), int(move[1]))
		else:
			bad += 1
		_moves.append(parsed)
	if bad > 0:
		Log.error(&"replay", "bad move entries in replay (%d), replayed as no movement" % bad)


func presses_for_frame() -> Array[StringName]:
	var out: Array[StringName] = []
	if _poll_index < _frames.size():
		out.assign(_frames[_poll_index])
	_poll_index += 1
	return out


## Entry i on the i-th poll; ZERO when exhausted or for a v1 recording.
func move_for_frame() -> Vector2i:
	var out: Vector2i = Vector2i.ZERO
	if _move_index < _moves.size():
		out = _moves[_move_index]
	_move_index += 1
	return out


## A move entry is [x, y] with each component an integral number in {-1, 0, 1}.
static func _is_valid_move(move: Variant) -> bool:
	if not (move is Array) or (move as Array).size() != 2:
		return false
	for v: Variant in move:
		if not (v is int or v is float):
			return false
		var f: float = float(v)
		if f != roundf(f) or absf(f) > 1.0:
			return false
	return true


## Number of recorded frames.
func frame_count() -> int:
	return _frames.size()


## Pure: builds a replay from a recording dictionary ({"version", "seed", "frames"[, "moves"]}).
## Bad data is a data error: Log.error and an empty replay, never a crash.
static func from_data(data: Variant) -> ReplayInput:
	var dict: Dictionary = data if data is Dictionary else {}
	if not (dict.get("frames") is Array):
		Log.error(&"replay", "bad replay data (no frames array)")
		return ReplayInput.new()
	var moves: Variant = dict.get("moves", [])
	if not (moves is Array):
		Log.error(&"replay", "bad replay data (moves is not an array), replayed as no movement")
		moves = []
	return ReplayInput.new(dict["frames"], int(dict.get("seed", 0)), moves)


## Loads a replay JSON file written by InputRecorder. Errors → Log.error + empty replay.
static func from_file(path: String) -> ReplayInput:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.error(&"replay", "cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return ReplayInput.new()
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		Log.error(&"replay", "bad JSON in %s: %s" % [path, json.get_error_message()])
		return ReplayInput.new()
	return from_data(json.data)
