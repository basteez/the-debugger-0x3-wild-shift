extends Node
## Duck voice entry point (AD-14, Story 3.6, D-S36-2, D-S36-11). say() is the only way any duck
## speech starts: it resolves a DuckLinesDef id (or passes raw text through) and emits
## EventBus.duck_line_requested once. 3.6 is the text-only backend: _speak() does nothing beyond
## the emit; Story 3.7 replaces its body with the mumble-speech backend without touching DuckBubble
## or DuckDirector. Declares no signal (signals live in event_bus.gd only).

const LINES: DuckLinesDef = preload("res://data/duck/duck_lines.tres")


## Resolves `line` (a known id, else raw text), requests it once and returns the resolved text.
func say(line: String) -> String:
	var entry: DuckLineDef = LINES.find(StringName(line)) if not line.is_empty() else null
	var line_id: StringName = entry.id if entry != null else &""
	var text: String = entry.text if entry != null else line
	Log.debug(&"voice", "say %s" % (line_id if line_id != &"" else &"<raw>"))
	EventBus.duck_line_requested.emit(line_id, text)
	_speak(line_id, text)
	return text


## Cuts any speech in progress. A no-op in the text-only backend (3.7 stops the voice here).
func stop() -> void:
	pass


## Backend seam: the text-only backend has nothing to do beyond the emit in say().
func _speak(_line_id: StringName, _text: String) -> void:
	pass
