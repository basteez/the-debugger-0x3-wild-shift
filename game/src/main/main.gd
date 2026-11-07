extends Node2D
## Persistent root scene (AD-08). Holds the render layers (AD-07) and opens the title screen
## (Story 1.4) unless a smoke gate is open (1.3 audio, 1.5 arena).

const SMOKE_AUDIO_SCENE := "res://src/debug/smoke_audio/smoke_audio.tscn"
const TitleScreenScript := preload("res://src/ui/screens/title/title_screen.gd")
const HudScene := preload("res://src/ui/hud/hud.tscn")
## Render layer order (AD-07): Arena -> Entities -> Particles -> HUD -> ScreenFX.
const LAYER_ORDER: Array[StringName] = [&"Arena", &"Entities", &"Particles", &"Hud", &"ScreenFX"]
const HUD_LAYER := 10
const SCREEN_FX_LAYER := 20

var arena: Arena
var hud: Hud


func _ready() -> void:
	Log.info(&"flow", "boot")
	_build_layers()
	var search: String = _web_location_search()
	# Story 1.3 day-1 audio smoke test, web only, behind ?debug&smoke=audio (DC6).
	# Story 1.6 replaces these URL reads with the Debug autoload's ?debug check.
	if wants_audio_smoke(search):
		var scene := load(SMOKE_AUDIO_SCENE) as PackedScene
		if scene != null:
			add_child(scene.instantiate())
			Log.info(&"flow", "audio smoke scene opened")
			return
		Log.warn(&"flow", "audio smoke scene missing, opening title")
	# Story 1.5 DC9: before 1.6 the arena and HUD are shown only behind ?debug&smoke=arena.
	if wants_arena_smoke(search):
		show_arena(true)
		Log.info(&"flow", "arena smoke view opened")
		return
	add_child(TitleScreenScript.new())


## Adds the render layers in AD-07 order; arena and HUD start hidden (DC8, DC9).
func _build_layers() -> void:
	arena = Arena.new()
	arena.name = &"Arena"
	arena.visible = false
	add_child(arena)
	for layer_name: StringName in [&"Entities", &"Particles"]:
		var node := Node2D.new()
		node.name = layer_name
		add_child(node)
	hud = HudScene.instantiate() as Hud
	hud.name = &"Hud"
	hud.layer = HUD_LAYER
	hud.visible = false
	add_child(hud)
	var fx := CanvasLayer.new()
	fx.name = &"ScreenFX"
	fx.layer = SCREEN_FX_LAYER
	add_child(fx)


func show_arena(shown: bool) -> void:
	arena.visible = shown
	hud.visible = shown


## True only when the query string has a bare or valued `debug` key AND `smoke=audio`.
static func wants_audio_smoke(search: String) -> bool:
	return UrlQuery.has_debug(search) and UrlQuery.has_smoke(search, "audio")


## True only when the query string has a bare or valued `debug` key AND `smoke=arena`.
static func wants_arena_smoke(search: String) -> bool:
	return UrlQuery.has_debug(search) and UrlQuery.has_smoke(search, "arena")


## location.search on web, "" anywhere else or if the bridge returns nothing usable.
static func _web_location_search() -> String:
	return UrlQuery.web_search()
