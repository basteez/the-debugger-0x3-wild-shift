class_name InputRecorder
extends RefCounted
## Debug input recorder (AC5, D-S21-5). SimClock calls record() once per polled frame while a
## recorder is set; frame 0 is the first poll after start. Never created in release builds.

const FORMAT_VERSION := 1

var seed_value: int = 0
var _frames: Array[Array] = []
var _recording: bool = false


## Release gate (C3): a recorder exists only when debug tools are enabled.
static func create(debug_enabled: bool) -> InputRecorder:
	if not debug_enabled:
		return null
	return InputRecorder.new()


func start(recorded_seed: int) -> void:
	seed_value = recorded_seed
	_frames.clear()
	_recording = true


func is_recording() -> bool:
	return _recording


func record(presses: Array[StringName]) -> void:
	if not _recording:
		return
	var frame: Array[String] = []
	for action: StringName in presses:
		frame.append(String(action))
	_frames.append(frame)


## Ends the recording and returns {"version", "seed", "frames"}.
func stop() -> Dictionary:
	_recording = false
	return {"version": FORMAT_VERSION, "seed": seed_value, "frames": _frames.duplicate(true)}


## Pure: one-line JSON for a recording (also the web console print, D-S21-7).
static func to_json(data: Dictionary) -> String:
	return JSON.stringify(data)


## Writes a recording to `path`. Environment failure → Log.warn and false (the recording is dropped).
static func save(data: Dictionary, path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		Log.warn(&"replay", "cannot write %s (%s); recording dropped" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(to_json(data))
	file.close()
	return true
