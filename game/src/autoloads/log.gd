extends Node
## The only logging path. Format: [f=<sim_frame>][LEVEL][tag] msg


func error(tag: StringName, msg: String) -> void:
	var line := _format(&"ERROR", tag, msg)
	print(line)
	push_error(line)


func warn(tag: StringName, msg: String) -> void:
	push_warning(_format(&"WARN", tag, msg))


func info(tag: StringName, msg: String) -> void:
	print(_format(&"INFO", tag, msg))


func debug(tag: StringName, msg: String) -> void:
	if not emits(&"DEBUG", Debug.enabled):
		return
	print(_format(&"DEBUG", tag, msg))


## Pure line formatter, tested directly (no stdout capture).
static func format_line(level: StringName, tag: StringName, msg: String, frame: int) -> String:
	return "[f=%d][%s][%s] %s" % [frame, level, tag, msg]


## Whether a line of this level is written. DEBUG lines need debug mode on.
static func emits(level: StringName, debug_enabled: bool) -> bool:
	return level != &"DEBUG" or debug_enabled


func _format(level: StringName, tag: StringName, msg: String) -> String:
	return format_line(level, tag, msg, SimClock.sim_frame)
