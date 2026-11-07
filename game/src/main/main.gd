extends Node2D
## Persistent root scene (AD-08). Draws one test glyph for the pixel-perfect check.

const SMOKE_AUDIO_SCENE := "res://src/debug/smoke_audio/smoke_audio.tscn"
const GLYPH_CELL_PX := 2
const GLYPH_ORIGIN := Vector2(312, 172)
## 8x8 test glyph, one row per entry, MSB is the leftmost cell.
const GLYPH_ROWS: Array[int] = [
	0b11111111,
	0b10000001,
	0b10111101,
	0b10100101,
	0b10100101,
	0b10111101,
	0b10000001,
	0b11111111,
]


var _show_glyph: bool = true


func _ready() -> void:
	Log.info(&"flow", "boot")
	# Story 1.3 day-1 audio smoke test, web only, behind ?debug&smoke=audio (DC6).
	# Story 1.6 replaces this URL read with the Debug autoload's ?debug check.
	if wants_audio_smoke(_web_location_search()):
		var scene := load(SMOKE_AUDIO_SCENE) as PackedScene
		if scene != null:
			_show_glyph = false
			add_child(scene.instantiate())
			Log.info(&"flow", "audio smoke scene opened")


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


func _draw() -> void:
	if not _show_glyph:
		return
	for y: int in GLYPH_ROWS.size():
		var row: int = GLYPH_ROWS[y]
		for x: int in 8:
			if row & (0b10000000 >> x) != 0:
				var pos := GLYPH_ORIGIN + Vector2(x * GLYPH_CELL_PX, y * GLYPH_CELL_PX)
				draw_rect(Rect2(pos, Vector2(GLYPH_CELL_PX, GLYPH_CELL_PX)), Palette.INK)
