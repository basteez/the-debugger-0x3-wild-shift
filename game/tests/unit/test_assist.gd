extends GutTest
## Story 7.4 (AC 1-12): the "debug build" assist. Pure helpers (max HP, tell scaling, cooldown),
## the arena injection, a seeded boss TELL, the Breakpoint cooldown, the per-attempt copy in Game,
## Main's pass-through, the HUD readout, the title and pause toggles, persistence.
## Seam rule (7.3 review): the SaveService autoload runs with an empty path under GUT (in-memory);
## the tests that check the file set a scratch path and delete it. Never user://save.cfg.

const GameScript := preload("res://src/autoloads/game.gd")
const SaveScript := preload("res://src/autoloads/save_service.gd")
const TitleScreenScript := preload("res://src/ui/screens/title/title_screen.gd")
const MainScene := preload("res://src/main/main.tscn")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
const TEST_BOSS: BossDef = preload("res://data/bosses/test_boss/boss_def.tres")
const S := GameScript.FlowState
const SCRATCH := "user://test_assist_7_4.cfg"

var _saved_path: String
var _saved_assist: bool
var _saved_highest: int
var _saved_track: bool
var _saved_flow: int
var _saved_paused: bool
var _saved_run: RunState
var _saved_stats: RunStats
var _saved_unlocked: bool


func before_each() -> void:
	_saved_path = SaveService.path
	_saved_assist = SaveService.assist
	_saved_highest = SaveService.highest_boss
	_saved_track = SaveService.track_fights
	_saved_flow = Game.flow_state
	_saved_paused = SimClock.paused
	_saved_run = Game.run
	_saved_stats = Game.stats
	_saved_unlocked = AudioManager.is_unlocked()
	SaveService.assist = false
	SaveService.highest_boss = 1
	_delete(SCRATCH)


func after_each() -> void:
	SaveService.path = _saved_path
	SaveService.assist = _saved_assist
	SaveService.highest_boss = _saved_highest
	SaveService.track_fights = _saved_track
	Game.flow_state = _saved_flow as GameScript.FlowState
	SimClock.paused = _saved_paused
	Game.run = _saved_run
	Game.stats = _saved_stats
	if not _saved_unlocked:
		AudioManager.set("_unlocked", false)
	_delete(SCRATCH)


func _delete(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func _click(pos: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	return ev


# --- Pure helpers (AC 5-7) --------------------------------------------------------------------

func test_max_hp_for() -> void:
	assert_eq(PlayerHealth.ASSIST_MAX_HP, 8)
	assert_eq(PlayerHealth.max_hp_for(PLAYER_DEF, true), 8)
	assert_eq(PlayerHealth.max_hp_for(PLAYER_DEF, false), 5)
	assert_eq(PLAYER_DEF.max_hp, 5, "the .tres is never mutated")
	assert_eq(PlayerHealth.max_hp_for(null, true), 0)


func test_scaled_tell() -> void:
	assert_eq(BossController.scaled_tell(20, true), 30)
	assert_eq(BossController.scaled_tell(21, true), 32, "31.5 rounds half up (roundi)")
	assert_eq(BossController.scaled_tell(25, true), 38, "37.5 -> 38")
	assert_eq(BossController.scaled_tell(20, false), 20)
	assert_eq(BossController.scaled_tell(21, false), 21)


func test_cooldown_for() -> void:
	assert_eq(BreakpointSkill.cooldown_for(true), 360)
	assert_eq(BreakpointSkill.cooldown_for(false), 720)
	assert_eq(BreakpointSkill.COOLDOWN_FRAMES, 720, "the constant is unchanged")


# --- Player HP and the HUD (AC 5, 9) ----------------------------------------------------------

func test_reset_for_fight_sets_the_live_max() -> void:
	var h := PlayerHealth.new(PLAYER_DEF)
	assert_eq(h.max_hp, 5)
	h.reset_for_fight(true)
	assert_eq(h.max_hp, 8)
	assert_eq(h.hp, 8)
	h.reset_for_fight()
	assert_eq(h.max_hp, 5, "the no-arg call is the unassisted value")
	assert_eq(h.hp, 5)


func test_hp_readout_shows_the_assisted_max() -> void:
	var h := PlayerHealth.new(PLAYER_DEF)
	h.reset_for_fight(true)
	var readout: HpReadout = autofree(HpReadout.new())
	readout.health = h
	assert_eq(readout.current_text(), "hp: 0b11111111")
	h.apply_hit()
	assert_eq(readout.current_text(), "hp: 0b01111111")
	h.reset_for_fight(false)
	assert_eq(readout.current_text(), "hp: 0b11111")


# --- Breakpoint cooldown (AC 6) ---------------------------------------------------------------

func test_breakpoint_cooldown_is_360_world_ticks_under_assist() -> void:
	var skill := BreakpointSkill.new(null)
	var ctx := SimContext.new()
	skill.set_assist(true)
	skill.reset_for_fight(true)
	assert_true(skill.can_start(), "the first use of the attempt is free")
	skill.poll([&"breakpoint"] as Array[StringName], ctx)
	assert_true(skill.is_active())
	skill.poll([&"action_1"] as Array[StringName], ctx)
	assert_false(skill.is_active())
	assert_eq(skill.cooldown_left_frames(), 360)
	skill.tick(ctx) # the ending tick never counts
	for i: int in 359:
		skill.tick(ctx)
	assert_eq(skill.cooldown_left_frames(), 1)
	assert_false(skill.can_start())
	skill.tick(ctx)
	assert_true(skill.can_start(), "ready after 360 world ticks")


func test_breakpoint_cooldown_stays_720_without_assist() -> void:
	var skill := BreakpointSkill.new(null)
	var ctx := SimContext.new()
	skill.set_assist(false)
	skill.reset_for_fight(true)
	skill.poll([&"breakpoint"] as Array[StringName], ctx)
	skill.poll([&"action_1"] as Array[StringName], ctx)
	assert_eq(skill.cooldown_left_frames(), 720)


# --- Arena injection (AC 5-7, 9, 12) ----------------------------------------------------------

func test_arena_enter_fight_injects_assist_per_attempt() -> void:
	var arena: Arena = autofree(Arena.new())
	arena.set_breakpoint_enabled(true)
	arena.enter_fight(Register.fight_start_for_boss(0), false, Arena.TEST_BOSS_DEF_PATH, true, false, true)
	assert_eq(arena.health.max_hp, 8)
	assert_eq(arena.health.hp, 8)
	assert_true(arena.boss.assist)
	assert_eq(arena.breakpoint_skill.get(&"cooldown_frames"), 360)
	# A retry without assist (the toggle applies from the next attempt).
	arena.enter_fight(Register.fight_start_for_boss(0), false, Arena.TEST_BOSS_DEF_PATH, true, false, false)
	assert_eq(arena.health.max_hp, 5)
	assert_false(arena.boss.assist, "a kept controller is re-injected")
	assert_eq(arena.breakpoint_skill.get(&"cooldown_frames"), 720)
	arena.leave_fight()


func test_arena_default_is_unassisted() -> void:
	var arena: Arena = autofree(Arena.new())
	arena.enter_fight(Register.fight_start_for_boss(0))
	assert_eq(arena.health.max_hp, PLAYER_DEF.max_hp)
	arena.leave_fight()


# --- Boss TELL timing, seeded (AC 7) ----------------------------------------------------------

func _run_to_first_tell(assist: bool) -> BossController:
	var ctx := SimContext.new()
	ctx.reseed(7404) # boss attacks are random picks: the seed fixes the attack
	var arena_ctx := ArenaContext.new()
	arena_ctx.contact_source = func() -> Vector2: return Vector2(-1000, -1000)
	var c := BossController.new()
	c.assist = assist
	assert_true(c.setup(TEST_BOSS, null, arena_ctx))
	c.reset_for_fight()
	var guard: int = 0
	while c.state != BossController.BossState.TELL and guard < 1000:
		c.tick(ctx)
		guard += 1
	assert_eq(c.state, BossController.BossState.TELL)
	return c


func _ticks_in(c: BossController, state: BossController.BossState) -> int:
	var ctx := SimContext.new()
	ctx.reseed(1)
	var n: int = 0
	while c.state == state and n < 1000:
		c.tick(ctx)
		n += 1
	return n


func test_assisted_tell_lasts_one_and_a_half_times() -> void:
	var plain: BossController = _run_to_first_tell(false)
	var assisted: BossController = _run_to_first_tell(true)
	assert_eq(assisted.current, plain.current, "same seed, same attack")
	var tell: int = plain.current.tell
	assert_eq(plain.tell_frames, tell)
	assert_eq(assisted.tell_frames, roundi(tell * 1.5))
	assert_eq(assisted.frames_left, assisted.tell_frames)
	assert_eq(_ticks_in(plain, BossController.BossState.TELL), tell)
	assert_eq(_ticks_in(assisted, BossController.BossState.TELL), roundi(tell * 1.5))
	assert_eq(assisted.state, BossController.BossState.ACTIVE)
	var active: int = assisted.current.active
	assert_eq(_ticks_in(assisted, BossController.BossState.ACTIVE), active, "ACTIVE is unchanged")
	assert_eq(assisted.current.tell, tell, "the AttackDef is never written")


func test_hud_reserved_flash_follows_the_scaled_tell() -> void:
	var c: BossController = _run_to_first_tell(true)
	# Hud.flash_phase_on reads tell_frames - frames_left: 0 elapsed at TELL entry, then it grows.
	assert_eq(c.tell_frames - c.frames_left, 0)
	var ctx := SimContext.new()
	ctx.reseed(1)
	for i in 9:
		c.tick(ctx)
	assert_eq(c.state, BossController.BossState.TELL)
	assert_eq(c.tell_frames - c.frames_left, 9)
	assert_false(Hud.flash_phase_on(c.tell_frames - c.frames_left), "9 frames in: second phase")


# --- Game: the per-attempt copy (AC 9, 12) ----------------------------------------------------

func _game() -> Node:
	var game: Node = autofree(GameScript.new())
	game.segfault_enabled = true
	return game


func test_begin_fight_copies_save_service_assist_per_attempt() -> void:
	SaveService.track_fights = false
	var game: Node = _game()
	SaveService.assist = true
	game.start_run_from_title(0)
	assert_true(game.finish_intro(GameScript.INTRO_MAX_FRAMES))
	assert_eq(game.flow_state, S.FIGHT)
	assert_true(game.run.assist, "copied on FIGHT entry")
	SaveService.assist = false # a pause toggle mid-fight
	assert_true(game.run.assist, "the attempt in progress keeps its value")
	assert_true(game.record_death(100))
	assert_true(game.retry(100 + GameScript.RETRY_DELAY_FRAMES))
	assert_false(game.run.assist, "the retry takes the new value")


func test_main_passes_run_assist_to_the_arena() -> void:
	var main: Node2D = MainScene.instantiate()
	add_child_autofree(main)
	var arena := main.get_node(^"Arena") as Arena
	Game.run = RunState.new()
	Game.run.assist = true
	main.apply_flow_state(S.FIGHT, 0)
	assert_eq(arena.health.max_hp, 8)
	assert_eq(arena.health.hp, 8)
	main.apply_flow_state(S.TITLE, 0)
	Game.run.assist = false
	main.apply_flow_state(S.FIGHT, 0)
	assert_eq(arena.health.max_hp, 5, "assist off is the 7.3 behaviour")


# --- Title (AC 1, 3, 4, 10) -------------------------------------------------------------------

func _title() -> TitleScreen:
	Game.flow_state = S.TITLE
	SimClock.paused = false
	var title: TitleScreen = autofree(TitleScreenScript.new())
	title.set_saved_progress(SaveService.highest_boss)
	title.set_assist_shown(SaveService.assist)
	return title


func test_title_labels_are_neutral_game_text() -> void:
	assert_eq(TitleScreenScript.debug_build_text(true), "[B] debug build on")
	assert_eq(TitleScreenScript.debug_build_text(false), "[B] debug build off")
	var rect: Rect2 = TitleScreenScript.debug_build_label_rect(false)
	assert_true(rect.position.y >= TitleScreenScript.new_run_label_rect().end.y, "below the new-run row")
	assert_true(rect.end.y <= Const.BASE_RES.y)
	assert_eq(TitleScreenScript.DEBUG_BUILD_TOP_Y % GlyphFont.CELL, 0)


func test_title_b_toggles_and_does_not_start() -> void:
	var title := _title()
	assert_true(title.is_option_available(&"debug_build"))
	assert_eq(title.handle_input(_key(KEY_B)), TitleScreenScript.Action.OPTION)
	assert_eq(Game.flow_state, S.TITLE, "B never starts the run")
	assert_true(SaveService.assist)
	assert_true(title.assist_shown)
	assert_true(AudioManager.is_unlocked(), "the press unlocks audio")
	title.handle_input(_key(KEY_B))
	assert_false(SaveService.assist)
	assert_false(title.assist_shown)
	assert_eq(Game.flow_state, S.TITLE)


func test_title_click_on_label_toggles() -> void:
	var title := _title()
	title.handle_input(_click(TitleScreenScript.debug_build_label_rect(false).get_center()))
	assert_true(SaveService.assist)
	assert_eq(Game.flow_state, S.TITLE)
	assert_eq(title.label_rects[&"debug_build"], TitleScreenScript.debug_build_label_rect(true))


func test_title_other_keys_still_start() -> void:
	SaveService.track_fights = false
	var title := _title()
	title.handle_input(_key(KEY_B))
	assert_eq(title.handle_input(_key(KEY_N)), TitleScreenScript.Action.START, "N without a save starts")
	assert_eq(Game.flow_state, S.INTRO)


func test_title_reads_assist_on_ready() -> void:
	SaveService.assist = true
	var title: TitleScreen = TitleScreenScript.new()
	add_child_autofree(title)
	assert_true(title.assist_shown)
	assert_true(title.label_rects.has(&"debug_build"))


func test_title_toggle_is_saved_at_once() -> void:
	SaveService.path = SCRATCH
	var title := _title()
	title.handle_input(_key(KEY_B))
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(SCRATCH), OK)
	assert_eq(cfg.get_value("save", "assist"), true)


# --- Pause (AC 2, 3, 4) -----------------------------------------------------------------------

func test_pause_rows_and_rect() -> void:
	# Story 7.7: the fullscreen row follows the assist row.
	assert_eq(PauseScreen.lines_for(false, true)[-2], "[B] DEBUG BUILD ON")
	assert_eq(PauseScreen.lines_for(false, false)[-2], "[B] DEBUG BUILD OFF")
	assert_eq(PauseScreen.row_tops()[-2], PauseScreen.ASSIST_TOP_Y)
	var rect: Rect2 = PauseScreen.assist_label_rect(false)
	assert_false(rect.intersects(PauseScreen.mute_label_rect(false)), "does not overlap the mute row")
	assert_true(rect.end.y <= Const.BASE_RES.y)


func test_pause_is_assist_toggle() -> void:
	assert_true(PauseScreen.is_assist_toggle(_key(KEY_B), false))
	var echo := _key(KEY_B)
	echo.echo = true
	assert_false(PauseScreen.is_assist_toggle(echo, false), "echo ignored")
	assert_false(PauseScreen.is_assist_toggle(_key(KEY_M), false), "M is the mute")
	assert_false(PauseScreen.is_assist_toggle(_key(KEY_ESCAPE), false), "Esc belongs to Game")
	assert_false(PauseScreen.is_assist_toggle(_key(KEY_P), false), "P belongs to Game")
	assert_true(PauseScreen.is_assist_toggle(_click(PauseScreen.assist_label_rect(true).get_center()), true))
	assert_false(PauseScreen.is_assist_toggle(_click(PauseScreen.mute_label_rect(false).get_center()), false))
	assert_false(PauseScreen.is_mute_toggle(_key(KEY_B), false), "B is not the mute")


func test_pause_b_toggles_saves_and_stays_paused() -> void:
	SaveService.path = SCRATCH
	SimClock.paused = true
	var was_muted: bool = AudioManager.is_master_muted()
	var pause: Node2D = PauseScreen.new()
	add_child_autofree(pause)
	pause._input(_key(KEY_B))
	assert_true(SaveService.assist)
	assert_true(SimClock.paused, "the game stays paused")
	assert_eq(AudioManager.is_master_muted(), was_muted, "the mute is untouched")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(SCRATCH), OK)
	assert_eq(cfg.get_value("save", "assist"), true)
	pause._input(_click(PauseScreen.assist_label_rect(true).get_center()))
	assert_false(SaveService.assist)
	assert_true(SimClock.paused)


# --- Persistence (AC 3, 10) -------------------------------------------------------------------

func test_set_assist_round_trip_and_fresh_default() -> void:
	var svc: Node = autofree(SaveScript.new())
	svc.path = SCRATCH
	svc.set_assist(true)
	var other: Node = autofree(SaveScript.new())
	other.path = SCRATCH
	other.load_save()
	assert_true(other.assist, "read back at the next boot")
	_delete(SCRATCH)
	var fresh: Node = autofree(SaveScript.new())
	fresh.path = SCRATCH
	fresh.assist = true
	fresh.load_save()
	assert_false(fresh.assist, "no file: assist off")
