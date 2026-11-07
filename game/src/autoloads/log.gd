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
	if not Debug.enabled:
		return
	print(_format(&"DEBUG", tag, msg))


func _format(level: StringName, tag: StringName, msg: String) -> String:
	return "[f=%d][%s][%s] %s" % [SimClock.sim_frame, level, tag, msg]
