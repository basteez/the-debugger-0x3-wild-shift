class_name ReplayInput
extends InputSource
## Plays back a recording (AC6, D-S21-5). Frame i of the recording is returned on the i-th poll,
## counted by this source (independent of sim_frame); empty arrays once exhausted.

## Seed the recording was made with; the replay run calls SimClock.begin_fight(seed_value) first.
var seed_value: int = 0
var _frames: Array[Array] = []
var _poll_index: int = 0


func _init(frames: Array = [], recorded_seed: int = 0) -> void:
	seed_value = recorded_seed
	for frame: Variant in frames:
		var presses: Array[StringName] = []
		if frame is Array:
			for action: Variant in frame:
				presses.append(StringName(str(action)))
		_frames.append(presses)


func presses_for_frame() -> Array[StringName]:
	var out: Array[StringName] = []
	if _poll_index < _frames.size():
		out.assign(_frames[_poll_index])
	_poll_index += 1
	return out


## Number of recorded frames.
func frame_count() -> int:
	return _frames.size()


## Pure: builds a replay from a recording dictionary ({"version", "seed", "frames"}).
## Bad data is a data error: Log.error and an empty replay, never a crash.
static func from_data(data: Variant) -> ReplayInput:
	var dict: Dictionary = data if data is Dictionary else {}
	if not (dict.get("frames") is Array):
		Log.error(&"replay", "bad replay data (no frames array)")
		return ReplayInput.new()
	return ReplayInput.new(dict["frames"], int(dict.get("seed", 0)))


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
