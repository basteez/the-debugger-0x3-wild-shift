extends Node2D
## Story 3.7 voice smoke test (B2, AC 2): after the first click or key, unlocks audio and speaks
## the T1 duck line through VoiceService only (the voice backend is VoiceService's business), and
## logs the first spoken character and the line's end. Opened only by main.gd with
## ?debug&smoke=voice behind the Debug gate. Debug code, presentation only.

const LINE_ID := &"t1_shift"

var _started: bool = false
var _first_char_logged: bool = false

@onready var _label: Label = $Status


func _ready() -> void:
	position = get_viewport_rect().size * 0.5
	_label.text = "click to hear the duck"
	EventBus.duck_character_spoken.connect(_on_duck_character_spoken)
	EventBus.duck_line_finished.connect(_on_duck_line_finished)
	Log.info(&"smoke", "voice smoke ready (backend %s), waiting for input" % backend_name())


func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	var mouse := event as InputEventMouseButton
	var key := event as InputEventKey
	if (mouse != null and mouse.pressed) or (key != null and key.pressed):
		_started = true
		get_viewport().set_input_as_handled()
		_start()


## The spoken text of the T1 line: its words joined by single spaces (what the bubble reveals).
static func line_text() -> String:
	var entry: DuckLineDef = VoiceService.LINES.find(LINE_ID)
	return " ".join(DuckBubble.wrap(entry.text)) if entry != null else ""


static func backend_name() -> String:
	return str(VoiceService.Backend.find_key(VoiceService.backend))


func _start() -> void:
	AudioManager.unlock()
	var started: bool = VoiceService.speak_pending(LINE_ID, line_text())
	_label.text = "speaking" if started else "voice did not start"
	Log.info(&"smoke", "voice smoke: speak %s on %s" % ["started" if started else "NOT started", backend_name()])


func _on_duck_character_spoken(char_index: int) -> void:
	if _first_char_logged:
		return
	_first_char_logged = true
	Log.info(&"smoke", "voice smoke: spoke %d chars" % (char_index + 1))


func _on_duck_line_finished(line_id: StringName, completed: bool) -> void:
	_label.text = "finished"
	Log.info(&"smoke", "voice smoke: finished %s completed=%s" % [line_id, completed])
