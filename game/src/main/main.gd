extends Node2D
## Persistent root scene (AD-08). Holds the render layers (AD-07) and hosts one flow screen at a
## time under Screens (Story 1.6): the screen follows Game.flow_state through
## EventBus.flow_state_changed. Main itself, the arena and the HUD are never freed during the flow.

const SMOKE_AUDIO_SCENE := "res://src/debug/smoke_audio/smoke_audio.tscn"
const SMOKE_VOICE_SCENE := "res://src/debug/smoke_voice/smoke_voice.tscn"
const TitleScreenScript := preload("res://src/ui/screens/title/title_screen.gd")
const PlaceholderScreenScript := preload("res://src/ui/screens/placeholder/placeholder_screen.gd")
const PauseScreenScript := preload("res://src/ui/screens/pause/pause_screen.gd")
const DeadScreenScript := preload("res://src/ui/screens/dead/dead_screen.gd")
const HarvestScreenScript := preload("res://src/ui/screens/harvest/harvest_screen.gd")
const DebugKeysScript := preload("res://src/debug/debug_keys.gd")
const GameFlow := preload("res://src/autoloads/game.gd")
const HudScene := preload("res://src/ui/hud/hud.tscn")
## Story 4.3 (AD-12, D-S43-2): the Breakpoint overlay, loaded by path only when the module is on.
const BREAKPOINT_OVERLAY_PATH := "res://src/skills/breakpoint/breakpoint_overlay.gd"
## Story 5.4 (AD-12, D-S54-3): the Watch read-outs, loaded by path only when the module is on.
const WATCH_OVERLAY_PATH := "res://src/skills/watch/watch_overlay.gd"
## Render layer order (AD-07): Arena -> Entities -> Particles -> HUD -> Pause -> ScreenFX.
const LAYER_ORDER: Array[StringName] = [&"Arena", &"Entities", &"Particles", &"Hud", &"Pause", &"ScreenFX"]
const HUD_LAYER := 10
## Pause overlay layer (Story 1.7 DC6): above the HUD, below ScreenFX. Empty unless paused.
const PAUSE_LAYER := 15
const SCREEN_FX_LAYER := 20

var arena: Arena
var hud: Hud
var screens: Node2D
var pause_layer: CanvasLayer
## The pause overlay while SimClock is paused; null otherwise.
var pause_screen: PauseScreen
## The screen instanced for the current flow state; null after it freed itself.
var current_screen: Node
## Shift juice (Story 2.4): slides the register panel, inverts the `@`, plays the click.
var juice_director: JuiceDirector
## F9 frame overlay (Story 2.5): exists only when Debug.enabled; null otherwise.
var frame_overlay: FrameOverlay
## F1-F5 / F9 / F11 / Shift+F2 keys: exists only when Debug.enabled; null otherwise.
var debug_keys: DebugKeys
## Practice target view (Story 2.7): exists only when Debug.enabled; draws only while a target exists.
var practice_view: PracticeTargetView
## Hit glyph particles (Story 2.8), in the Particles layer at the arena origin.
var particle_pool: ParticlePool
## Combo-hit shake (Story 2.8): owns the arena Camera2D (a child of the Arena).
var camera_shake: CameraShakeDriver
## Full-screen invert / dither rect in the ScreenFX layer (Story 2.8); driven only by JuiceDirector.
var screen_fx: ScreenFX
## F10 perf overlay (Story 2.8): exists only when Debug.enabled; null otherwise.
var perf_overlay: PerfOverlay
## The player's `hp: 0b11111` readout in the HUD (Story 2.9, D-S29-8).
var hp_readout: HpReadout
## The boss glyph line (Story 3.1): a child of the Arena; draws only while the arena has a boss.
var boss_view: BossView
## Tutorial beats T1-T4 (Story 3.6): reads the arena, requests lines through VoiceService.
var duck_director: DuckDirector
## Story 4.3 (AD-12): the cut-ladder flags the startup wiring reads. A test may swap it before the
## node enters the tree (flag-off runs).
var feature_flags: FeatureFlags = Defs.FEATURE_FLAGS
## Story 4.3: the red Breakpoint dot and line (a child of the Arena); null when the module is off.
var breakpoint_overlay: Node2D
## Story 4.3 (AC 10): the HUD `brk` cooldown readout; null when the module is off.
var breakpoint_readout: BreakpointReadout
## Story 5.4: the Watch read-outs above the boss (a child of the Arena); null when the module is off.
var watch_overlay: Node2D


func _ready() -> void:
	Log.info(&"flow", "boot")
	_build_layers()
	EventBus.pause_toggled.connect(apply_pause)
	if should_add_debug_keys(Debug.enabled):
		debug_keys = DebugKeysScript.new()
		debug_keys.name = &"DebugKeys"
		debug_keys.frame_overlay = frame_overlay
		debug_keys.perf_overlay = perf_overlay
		debug_keys.player_health = arena.health
		debug_keys.arena = arena
		add_child(debug_keys)
	# Story 1.3 day-1 audio smoke test, behind ?debug&smoke=audio and the Debug gate (1.6 AC8).
	if Debug.enabled and wants_audio_smoke(UrlQuery.web_search()):
		var scene := load(SMOKE_AUDIO_SCENE) as PackedScene
		if scene != null:
			add_child(scene.instantiate())
			Log.info(&"flow", "audio smoke scene opened")
			return
		Log.warn(&"flow", "audio smoke scene missing, opening title")
	# Story 3.7 duck voice smoke test, behind ?debug&smoke=voice and the same Debug gate.
	if Debug.enabled and wants_voice_smoke(UrlQuery.web_search()):
		var voice_scene := load(SMOKE_VOICE_SCENE) as PackedScene
		if voice_scene != null:
			add_child(voice_scene.instantiate())
			Log.info(&"flow", "voice smoke scene opened")
			return
		Log.warn(&"flow", "voice smoke scene missing, opening title")
	EventBus.flow_state_changed.connect(_on_flow_state_changed)
	apply_flow_state(Game.flow_state, Game.run.boss_index)


## Adds the render layers in AD-07 order, then the Screens host; arena and HUD start hidden.
func _build_layers() -> void:
	arena = Arena.new()
	arena.name = &"Arena"
	arena.visible = false
	arena.set_breakpoint_enabled(feature_flags.breakpoint_enabled) # D-S43-1: the one startup read
	arena.set_watch_enabled(feature_flags.watch) # Story 5.4 (D-S54-3): the one startup read
	add_child(arena)
	# The player view lives in presentation/, so Main (not the arena/ sim folder) attaches it.
	var player_view := PlayerView.new(arena.player)
	player_view.health = arena.health
	player_view.name = &"PlayerView"
	arena.add_child(player_view)
	# Story 3.1: the boss view lives in presentation/, so Main attaches it, beside the PlayerView.
	boss_view = BossView.new()
	boss_view.name = &"BossView"
	arena.add_child(boss_view)
	# Debug-only frame overlay (Story 2.5 AC7), above the `@`; lives in debug/, so Main attaches it.
	if Debug.enabled:
		frame_overlay = FrameOverlay.new()
		frame_overlay.name = &"FrameOverlay"
		frame_overlay.player = arena.player
		frame_overlay.actions = arena.actions
		frame_overlay.register = arena.register
		arena.add_child(frame_overlay)
	# Debug-only practice target view (Story 2.7, D-S27-9); lives in presentation/, so Main attaches it.
	if Debug.enabled:
		practice_view = PracticeTargetView.new()
		practice_view.name = &"PracticeTargetView"
		arena.add_child(practice_view)
	for layer_name: StringName in [&"Entities", &"Particles"]:
		var node := Node2D.new()
		node.name = layer_name
		add_child(node)
	# Story 2.8: the pool sits at the arena origin so hit_landed's arena-local points line up.
	particle_pool = ParticlePool.new()
	particle_pool.name = &"ParticlePool"
	particle_pool.position = Vector2(Arena.ORIGIN_CELL * GlyphFont.CELL)
	get_node(^"Particles").add_child(particle_pool)
	# Debug-only F10 perf overlay (Story 2.8 AC6), drawn over the arena (arena-local pixels).
	if Debug.enabled:
		perf_overlay = PerfOverlay.new()
		perf_overlay.name = &"PerfOverlay"
		perf_overlay.particle_pool = particle_pool
		arena.add_child(perf_overlay)
	hud = HudScene.instantiate() as Hud
	hud.name = &"Hud"
	hud.layer = HUD_LAYER
	hud.visible = false
	add_child(hud)
	# The panel lives in ui/, so Main (not the arena/ sim folder) hands it the register (D-S23-9).
	hud.register_panel.register = arena.register
	# Story 2.9: the HP readout reads the arena's PlayerHealth; it lives in ui/, so Main attaches it.
	hp_readout = HpReadout.new()
	hp_readout.name = &"HpReadout"
	hp_readout.health = arena.health
	hud.add_child(hp_readout)
	_build_breakpoint_views()
	_build_watch_views()
	pause_layer = CanvasLayer.new()
	pause_layer.name = &"Pause"
	pause_layer.layer = PAUSE_LAYER
	add_child(pause_layer)
	var fx := CanvasLayer.new()
	fx.name = &"ScreenFX"
	fx.layer = SCREEN_FX_LAYER
	add_child(fx)
	screen_fx = ScreenFX.new()
	screen_fx.name = &"ScreenFXRect"
	fx.add_child(screen_fx)
	screens = Node2D.new()
	screens.name = &"Screens"
	add_child(screens)
	# Presentation listener (Story 2.4): under Main, after the layers, so LAYER_ORDER is unchanged.
	juice_director = JuiceDirector.new()
	juice_director.name = &"JuiceDirector"
	juice_director.register_panel = hud.register_panel
	juice_director.player_view = player_view
	juice_director.screen_fx = screen_fx
	add_child(juice_director)
	# Story 3.6: the duck beats live in ui/, so Main attaches them and hands over the arena (read only).
	duck_director = DuckDirector.new()
	duck_director.name = &"DuckDirector"
	duck_director.arena = arena
	duck_director.bubble = hud.duck_bubble # Story 4.4 (D-S44-4): request only when it has room
	add_child(duck_director)
	# Story 2.8 combo shake: the camera is a child of the Arena, placed at the canvas origin so
	# offset zero keeps today's framing exactly (D-S28-5). The driver lives in presentation/, so
	# Main attaches it, after the layers so LAYER_ORDER is unchanged.
	camera_shake = CameraShakeDriver.new()
	camera_shake.name = &"CameraShakeDriver"
	add_child(camera_shake)
	camera_shake.camera.position = -Vector2(Arena.ORIGIN_CELL * GlyphFont.CELL)
	arena.add_child(camera_shake.camera)


## Story 4.3 (AC 9, AC 10, AC 13): the overlay and the HUD readout exist only when the arena built
## the Breakpoint module (flag on). The overlay sits above the player and boss views in the Arena.
func _build_breakpoint_views() -> void:
	if arena.breakpoint_skill == null:
		return
	var script := load(BREAKPOINT_OVERLAY_PATH) as GDScript
	if script != null:
		breakpoint_overlay = script.new() as Node2D
		breakpoint_overlay.name = &"BreakpointWarning"
		breakpoint_overlay.set(&"skill", arena.breakpoint_skill)
		breakpoint_overlay.set(&"player", arena.player)
		arena.add_child(breakpoint_overlay)
	breakpoint_readout = BreakpointReadout.new()
	breakpoint_readout.name = &"BreakpointReadout"
	breakpoint_readout.skill = arena.breakpoint_skill
	hud.add_child(breakpoint_readout)


## Story 5.4 (AC 8-10, AC 14): the read-out overlay and the register panel's weak-window marks exist
## only when the arena built the Watch module (flag on). The overlay sits above the boss view.
func _build_watch_views() -> void:
	if arena.watch_skill == null:
		return
	var script := load(WATCH_OVERLAY_PATH) as GDScript
	if script != null:
		watch_overlay = script.new() as Node2D
		watch_overlay.name = &"WatchReadouts"
		watch_overlay.set(&"skill", arena.watch_skill)
		arena.add_child(watch_overlay)
	hud.register_panel.watch_skill = arena.watch_skill
	var a: Arena = arena
	hud.register_panel.weak_window_source = func() -> Vector2i:
		return a.boss.current_weak_window() if a.boss != null else Vector2i.ZERO


func _on_flow_state_changed(_from: int, to: int) -> void:
	apply_flow_state(to, Game.run.boss_index)


## Frees the old screen, instances the one for `state`, and shows the arena and HUD only in
## FIGHT (Story 1.6 AC6, AC7, DC9). The player and the register are reset and active only in FIGHT
## (Stories 2.2, 2.3): the register starts at the boss's fight-start set.
func apply_flow_state(state: int, boss_index: int) -> void:
	if is_instance_valid(current_screen):
		# Deaf for the rest of the frame: queue_free keeps it in the tree until then.
		current_screen.set_process_unhandled_input(false)
		current_screen.set_physics_process(false)
		current_screen.queue_free()
	current_screen = _make_screen(state, boss_index)
	if current_screen != null:
		screens.add_child(current_screen)
	# No slide or inversion carries across screens (D-S24-9). Story 2.8 [design call]: nor do
	# particles, the shake or the console lines; every fight starts with a clean log. Story 2.9
	# (D-S29-10): the log is cleared on FIGHT entry only, so DEAD keeps the lines of the fight.
	juice_director.reset()
	particle_pool.clear()
	camera_shake.reset()
	var in_fight: bool = state == GameFlow.FlowState.FIGHT
	if in_fight:
		hud.log_panel.clear()
	arena.visible = in_fight
	# Story 3.8 (D-S38-16): HARVEST shows the HUD's duck bubble only (the harvest line).
	var harvest: bool = state == GameFlow.FlowState.HARVEST
	hud.visible = in_fight or harvest
	hud.set_duck_only(harvest)
	if in_fight:
		var practice: bool = wants_practice()
		arena.enter_fight(fight_start_ring(Game.run, boss_index), practice, boss_def_path_for(wants_test_boss(), boss_index, practice), breakpoint_unlocked_for(boss_index), watch_unlocked_for(boss_index))
	else:
		arena.leave_fight()
	_attach_practice_target()
	_attach_boss(in_fight)


## Story 3.8 (B4, D-S38-8, D-S38-11): the defeat exit is polled here, after SimClock's tick of the
## same physics frame (SimClock is an autoload, so it processes first), never inside the tick.
func _physics_process(_delta: float) -> void:
	poll_defeat()


## Asks Game to leave FIGHT once the arena's boss has finished its defeat animation. True if it moved.
func poll_defeat() -> bool:
	if Game.flow_state != GameFlow.FlowState.FIGHT or not is_instance_valid(arena) or arena.boss == null:
		return false
	if not arena.boss.defeat_finished():
		return false
	return Game.finish_defeat(arena.boss)


## The register ring a fight starts from (Story 2.9, AC 6): the RunState snapshot Game captured on
## FIGHT enter (a retry restores it), or the boss's fight-start set when no snapshot matches this
## boss (direct calls in tests). Pure.
static func fight_start_ring(run: RunState, boss_index: int) -> PackedInt32Array:
	if run != null and run.boss_index == boss_index and not run.fight_start_ring.is_empty():
		return run.fight_start_ring
	return Register.fight_start_for_boss(boss_index)


## Breakpoint is usable from Fight 2 on, i.e. after Boss 1 (Story 4.3, AC 3, D-S43-6). Pure.
static func breakpoint_unlocked_for(boss_index: int) -> bool:
	return boss_index >= 1


## Watch is usable from Boss 2 on (Story 5.4, AC 1, D-S54-4): the same rule as Breakpoint. Pure.
static func watch_unlocked_for(boss_index: int) -> bool:
	return boss_index >= 1


## The boss def a FIGHT loads (Story 3.3, D-S33-11, D-S33-13): the framework test boss on
## Shift+F3 (takes precedence), no boss in the Shift+F2 practice sandbox (D-S33-22), the Infinite
## Loop for boss 0 in every build, the Null Pointer for boss 1 (Story 5.1), none (placeholder
## header) for boss 2 until its story.
## Pure.
static func boss_def_path_for(debug_test_boss: bool, boss_index: int, practice: bool = false) -> String:
	if debug_test_boss:
		return Arena.TEST_BOSS_DEF_PATH
	if practice:
		return ""
	if boss_index == 0:
		return Arena.INFINITE_LOOP_DEF_PATH
	if boss_index == 1: # Story 5.1 (AC 3)
		return Arena.NULL_POINTER_DEF_PATH
	return ""


## True when the fight should have the practice target: Shift+F2 was the last jump (Story 2.7,
## D-S27-3). Always false without the debug gate (no DebugKeys node).
func wants_practice() -> bool:
	return Debug.enabled and is_instance_valid(debug_keys) and debug_keys.practice_requested


## True when the fight should have the framework test boss: Shift+F3 was the last jump (Story 3.1,
## D-S31-3). Always false without the debug gate (no DebugKeys node), so release never runs it.
func wants_test_boss() -> bool:
	return Debug.enabled and is_instance_valid(debug_keys) and debug_keys.test_boss_requested


## Hands the arena's boss (or null) to the boss view and the HUD header (Story 3.1). Story 3.3
## (B6): null-safe, and outside FIGHT the views are detached (the arena keeps the controller for
## the retry).
func _attach_boss(in_fight: bool = true) -> void:
	var b: BossController = arena.boss if in_fight else null
	if is_instance_valid(boss_view):
		boss_view.boss = b
		boss_view.queue_redraw()
	if is_instance_valid(watch_overlay):
		watch_overlay.set(&"boss", b) # Story 5.4: the read-outs follow the fight's boss
	if is_instance_valid(hud):
		hud.set_boss(b)


## Hands the arena's practice target (or null) to the debug views.
func _attach_practice_target() -> void:
	if is_instance_valid(practice_view):
		practice_view.target = arena.practice_target
		practice_view.queue_redraw()
	if is_instance_valid(frame_overlay):
		frame_overlay.practice_target = arena.practice_target


## Shows the pause overlay while paused and frees it on resume (Story 1.7 AC2, DC6). Game owns
## the state; Main only follows EventBus.pause_toggled.
func apply_pause(paused: bool) -> void:
	if paused:
		if not is_instance_valid(pause_screen) or pause_screen.is_queued_for_deletion():
			pause_screen = PauseScreenScript.new()
			pause_screen.name = &"PauseScreen"
			pause_layer.add_child(pause_screen)
		return
	if is_instance_valid(pause_screen):
		pause_screen.set_process_input(false)
		pause_screen.queue_free()
	pause_screen = null


func _make_screen(state: int, boss_index: int) -> Node:
	match state:
		GameFlow.FlowState.TITLE:
			var title: TitleScreen = TitleScreenScript.new()
			title.name = &"TitleScreen"
			return title
		GameFlow.FlowState.HARVEST:
			return make_harvest_screen(boss_index)
		GameFlow.FlowState.INTRO, GameFlow.FlowState.FIGHT, GameFlow.FlowState.ENDING:
			var screen: PlaceholderScreen = PlaceholderScreenScript.new()
			screen.setup(state, boss_index)
			return screen
		GameFlow.FlowState.DEAD:
			var dead: DeadScreen = DeadScreenScript.new()
			dead.name = &"DeadScreen"
			return dead
	return null


## Story 3.8 (E3): the HARVEST screen for the defeated boss (the arena keeps the controller after the
## fight, so its def gives the fixed line and the drop bit). Without a boss def (a placeholder fight
## left with advance()), the drop is the bit the next fight's start set adds.
func make_harvest_screen(boss_index: int) -> HarvestScreen:
	var def: BossDef = arena.boss.def if is_instance_valid(arena) and arena.boss != null else null
	var bit: int = def.drop_bit if def != null else harvest_bit_for(boss_index)
	var previous: PackedInt32Array = fight_start_ring(Game.run, boss_index)
	var screen: HarvestScreen = HarvestScreenScript.new()
	screen.setup(boss_index, def.fixed_line if def != null else "", bit, previous)
	return screen


## The bit the fight after `boss_index` adds to its start set (0 = none). Pure.
static func harvest_bit_for(boss_index: int) -> int:
	if boss_index < 0 or boss_index >= GameFlow.LAST_BOSS_INDEX:
		return 0
	var before: PackedInt32Array = Register.fight_start_for_boss(boss_index)
	for b: int in Register.fight_start_for_boss(boss_index + 1):
		if not before.has(b):
			return b
	return 0


## DebugKeys exists only when the debug gate is open (AC5).
static func should_add_debug_keys(debug_enabled: bool) -> bool:
	return debug_enabled


## True only when the query string has a bare or valued `debug` key AND `smoke=audio`.
static func wants_audio_smoke(search: String) -> bool:
	return UrlQuery.has_debug(search) and UrlQuery.has_smoke(search, "audio")


## True only when the query string has a bare or valued `debug` key AND `smoke=voice` (Story 3.7).
static func wants_voice_smoke(search: String) -> bool:
	return UrlQuery.has_debug(search) and UrlQuery.has_smoke(search, "voice")
