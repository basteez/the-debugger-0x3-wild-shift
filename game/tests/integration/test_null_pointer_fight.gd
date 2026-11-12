extends GutTest
## Story 5.1 (AC 1-3, 8, 11, 13, 19): Main, the Arena, the real Null Pointer, the autoload Game and
## SimClock. FIGHT boss 1 boots with the NullPointerBody, the sky comment and the hum node, runs
## headless without errors in GAP (no attack), the hum follows the boss after each tick, and the
## view and sky are released when the fight is left.

const MainScene := preload("res://src/main/main.tscn")
const GameScript := preload("res://src/autoloads/game.gd")

var _saved_enabled: bool
var _saved_state: int
var _saved_run: RunState
var _saved_source: InputSource
var _main: Node2D


func before_each() -> void:
	_saved_enabled = Debug.enabled
	_saved_state = Game.flow_state
	_saved_run = Game.run
	_saved_source = SimClock.input_source
	SimClock.input_source = null # headless: no presses
	Game.run = RunState.new()
	Debug.enabled = true
	SimClock.paused = false
	_main = MainScene.instantiate()
	add_child_autofree(_main)


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	Game.run = _saved_run
	Debug.enabled = _saved_enabled
	SimClock.input_source = _saved_source
	SimClock.begin_fight(0)
	SimClock.paused = false


func test_fight_2_boots_the_null_pointer_and_idles_in_gap() -> void:
	Game.debug_jump(GameScript.FlowState.FIGHT, 1)
	var boss := _main.arena.boss as NullPointerBody
	assert_not_null(boss, "FIGHT boss 1 is the Null Pointer")
	assert_eq(_main.boss_view.boss, boss)
	assert_eq(_main.hud.top_bar_text(), "void nullPointer() // hp 700")
	assert_eq(_main.hud.sky_text(), "// FIXME: who owns this pointer?")
	var hum: NullPointerHum = _main.boss_view.hum
	assert_not_null(hum)
	var start: Vector2 = boss.body_center_px
	for i: int in 600:
		SimClock.tick()
		hum.sync_to(boss)
		assert_eq(hum.position, boss.body_center_px)
		assert_eq(boss.state, BossController.BossState.GAP, "no attack yet (tick %d)" % i)
	assert_ne(boss.body_center_px, start, "the ghost drifted")
	assert_false(boss.visible_now(), "invisible while idle")
	assert_push_error_count(0, "no Log.error during the fight")
	Game.debug_jump(GameScript.FlowState.TITLE, 0)
	assert_null(_main.boss_view.boss, "the view lets go of the boss")
	assert_eq(_main.hud.sky_text(), Hud.SKY, "the sky comment is restored")
	hum.sync_to(_main.boss_view.boss)
	assert_false(hum.playing, "the hum stops when the fight is left")
