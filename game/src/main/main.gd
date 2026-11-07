extends Node2D
## Persistent root scene (AD-08). Holds the render layers (AD-07) and hosts one flow screen at a
## time under Screens (Story 1.6): the screen follows Game.flow_state through
## EventBus.flow_state_changed. Main itself, the arena and the HUD are never freed during the flow.

const SMOKE_AUDIO_SCENE := "res://src/debug/smoke_audio/smoke_audio.tscn"
const TitleScreenScript := preload("res://src/ui/screens/title/title_screen.gd")
const PlaceholderScreenScript := preload("res://src/ui/screens/placeholder/placeholder_screen.gd")
const DebugKeysScript := preload("res://src/debug/debug_keys.gd")
const GameFlow := preload("res://src/autoloads/game.gd")
const HudScene := preload("res://src/ui/hud/hud.tscn")
## Render layer order (AD-07): Arena -> Entities -> Particles -> HUD -> ScreenFX.
const LAYER_ORDER: Array[StringName] = [&"Arena", &"Entities", &"Particles", &"Hud", &"ScreenFX"]
const HUD_LAYER := 10
const SCREEN_FX_LAYER := 20

var arena: Arena
var hud: Hud
var screens: Node2D
## The screen instanced for the current flow state; null in DEAD (2.9) or after it freed itself.
var current_screen: Node


func _ready() -> void:
	Log.info(&"flow", "boot")
	_build_layers()
	if should_add_debug_keys(Debug.enabled):
		var keys: Node = DebugKeysScript.new()
		keys.name = &"DebugKeys"
		add_child(keys)
	# Story 1.3 day-1 audio smoke test, behind ?debug&smoke=audio and the Debug gate (1.6 AC8).
	if Debug.enabled and wants_audio_smoke(UrlQuery.web_search()):
		var scene := load(SMOKE_AUDIO_SCENE) as PackedScene
		if scene != null:
			add_child(scene.instantiate())
			Log.info(&"flow", "audio smoke scene opened")
			return
		Log.warn(&"flow", "audio smoke scene missing, opening title")
	EventBus.flow_state_changed.connect(_on_flow_state_changed)
	apply_flow_state(Game.flow_state, Game.run.boss_index)


## Adds the render layers in AD-07 order, then the Screens host; arena and HUD start hidden.
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
	screens = Node2D.new()
	screens.name = &"Screens"
	add_child(screens)


func _on_flow_state_changed(_from: int, to: int) -> void:
	apply_flow_state(to, Game.run.boss_index)


## Frees the old screen, instances the one for `state`, and shows the arena and HUD only in
## FIGHT (Story 1.6 AC6, AC7, DC9).
func apply_flow_state(state: int, boss_index: int) -> void:
	if is_instance_valid(current_screen):
		# Deaf for the rest of the frame: queue_free keeps it in the tree until then.
		current_screen.set_process_unhandled_input(false)
		current_screen.set_physics_process(false)
		current_screen.queue_free()
	current_screen = _make_screen(state, boss_index)
	if current_screen != null:
		screens.add_child(current_screen)
	var in_fight: bool = state == GameFlow.FlowState.FIGHT
	arena.visible = in_fight
	hud.visible = in_fight


func _make_screen(state: int, boss_index: int) -> Node:
	match state:
		GameFlow.FlowState.TITLE:
			var title: TitleScreen = TitleScreenScript.new()
			title.name = &"TitleScreen"
			return title
		GameFlow.FlowState.INTRO, GameFlow.FlowState.FIGHT, GameFlow.FlowState.HARVEST, GameFlow.FlowState.ENDING:
			var screen: PlaceholderScreen = PlaceholderScreenScript.new()
			screen.setup(state, boss_index)
			return screen
	return null # DEAD: no placeholder until 2.9


## DebugKeys exists only when the debug gate is open (AC5).
static func should_add_debug_keys(debug_enabled: bool) -> bool:
	return debug_enabled


## True only when the query string has a bare or valued `debug` key AND `smoke=audio`.
static func wants_audio_smoke(search: String) -> bool:
	return UrlQuery.has_debug(search) and UrlQuery.has_smoke(search, "audio")
