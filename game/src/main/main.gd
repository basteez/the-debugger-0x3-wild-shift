extends Node2D
## Persistent root scene (AD-08). Opens the title screen (Story 1.4) unless the 1.3 smoke gate is open.

const SMOKE_AUDIO_SCENE := "res://src/debug/smoke_audio/smoke_audio.tscn"
const TitleScreenScript := preload("res://src/ui/screens/title/title_screen.gd")


func _ready() -> void:
	Log.info(&"flow", "boot")
	# Story 1.3 day-1 audio smoke test, web only, behind ?debug&smoke=audio (DC6).
	# Story 1.6 replaces this URL read with the Debug autoload's ?debug check.
	if wants_audio_smoke(_web_location_search()):
		var scene := load(SMOKE_AUDIO_SCENE) as PackedScene
		if scene != null:
			add_child(scene.instantiate())
			Log.info(&"flow", "audio smoke scene opened")
			return
		Log.warn(&"flow", "audio smoke scene missing, opening title")
	add_child(TitleScreenScript.new())


## True only when the query string has a bare or valued `debug` key AND `smoke=audio`.
static func wants_audio_smoke(search: String) -> bool:
	var has_debug: bool = false
	var has_smoke_audio: bool = false
	for pair: String in search.trim_prefix("?").split("&", false):
		var key: String = pair.get_slice("=", 0)
		if key == "debug":
			var val: String = pair.get_slice("=", 1) if pair.contains("=") else ""
			has_debug = val != "0" and val != "false"
		elif key == "smoke" and pair.get_slice_count("=") == 2 and pair.get_slice("=", 1) == "audio":
			has_smoke_audio = true
	return has_debug and has_smoke_audio


## location.search on web, "" anywhere else or if the bridge returns nothing usable.
static func _web_location_search() -> String:
	if not OS.has_feature("web"):
		return ""
	var value: Variant = JavaScriptBridge.eval("window.location.search", true)
	return value if value is String else ""
