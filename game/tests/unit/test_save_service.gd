extends GutTest
## Story 7.3 (AC 1-5, 8-11, 13): SaveService parse / clamp / round trip / silent fallback, the Game
## FIGHT-entry write rules, resume, and the title's [N] new run. No test touches user://save.cfg:
## a local SaveService (not in the tree, so no _ready) gets a scratch path, and the autoload runs
## with an empty path under GUT (in-memory only).

const SaveScript := preload("res://src/autoloads/save_service.gd")
const GameScript := preload("res://src/autoloads/game.gd")
const TitleScreenScript := preload("res://src/ui/screens/title/title_screen.gd")
const S := GameScript.FlowState
const SCRATCH := "user://test_save_7_3.cfg"
const UNWRITABLE := "user://no_such_dir_7_3/deeper/save.cfg"

var _saved: Dictionary = {}
var _saved_enabled: bool
var _saved_frame: int
var _saved_paused: bool
var _saved_flow: int
var _saved_run: RunState
var _saved_stats: RunStats
var _saved_first_input: int
var _saved_unlocked: bool


func before_each() -> void:
	_saved = {
		"path": SaveService.path, "highest_boss": SaveService.highest_boss, "assist": SaveService.assist,
		"muted": SaveService.muted, "storage_warned": SaveService.storage_warned,
		"track_fights": SaveService.track_fights,
	}
	_saved_enabled = Debug.enabled
	_saved_frame = SimClock.sim_frame
	_saved_paused = SimClock.paused
	_saved_flow = Game.flow_state
	_saved_run = Game.run
	_saved_stats = Game.stats
	_saved_first_input = Game.first_input_frame
	_saved_unlocked = AudioManager.is_unlocked()
	SaveService.highest_boss = 1
	SaveService.track_fights = true
	_delete(SCRATCH)


func after_each() -> void:
	for key: String in _saved:
		SaveService.set(key, _saved[key])
	Debug.enabled = _saved_enabled
	SimClock.sim_frame = _saved_frame
	SimClock.paused = _saved_paused
	Game.flow_state = _saved_flow as GameScript.FlowState
	Game.run = _saved_run
	Game.stats = _saved_stats
	Game.first_input_frame = _saved_first_input
	if not _saved_unlocked:
		AudioManager.set("_unlocked", false)
	_delete(SCRATCH)


func _delete(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _service(p: String = SCRATCH) -> Node:
	var svc: Node = autofree(SaveScript.new())
	svc.path = p
	return svc


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


# --- SaveService (AC 1-5) ---------------------------------------------------------------------

func test_autoload_is_in_memory_only_under_gut() -> void:
	assert_true(SaveScript.running_under_gut())
	assert_eq(_saved["path"], "", "the autoload never reads or writes user://save.cfg in tests")
	assert_false(_saved["track_fights"], "and fights played by other tests never raise it")


func test_max_boss_matches_game() -> void:
	assert_eq(SaveScript.MAX_BOSS, GameScript.LAST_BOSS_INDEX + 1)


func test_missing_file_is_a_fresh_save_without_warning() -> void:
	var svc: Node = _service("user://does_not_exist_7_3.cfg")
	svc.highest_boss = 3
	svc.assist = true
	svc.muted = true
	svc.load_save()
	assert_eq(svc.highest_boss, 1)
	assert_false(svc.assist)
	assert_false(svc.muted)
	assert_false(svc.storage_warned)


func test_round_trip() -> void:
	var svc: Node = _service()
	svc.highest_boss = 2
	svc.assist = true
	svc.muted = true
	assert_true(svc.save())
	var other: Node = _service()
	other.load_save()
	assert_eq(other.highest_boss, 2)
	assert_true(other.assist)
	assert_true(other.muted)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(SCRATCH), OK)
	assert_eq(cfg.get_value("save", "version"), 1)
	assert_eq(cfg.get_value("save", "highest_boss"), 2)


func test_bad_version_resets_to_defaults_and_warns_once() -> void:
	var cfg := SaveScript.to_config(3, true, true)
	cfg.set_value("save", "version", 2)
	assert_eq(cfg.save(SCRATCH), OK)
	var svc: Node = _service()
	svc.load_save()
	assert_eq(svc.highest_boss, 1)
	assert_false(svc.assist)
	assert_true(svc.storage_warned)
	svc.load_save()
	assert_true(svc.storage_warned, "still one warn for the session")


func test_parse_rejects_bad_versions_and_values() -> void:
	var no_version := ConfigFile.new()
	no_version.set_value("save", "highest_boss", 3)
	assert_false(SaveScript.parse(no_version)["valid"])
	var bad_value := SaveScript.to_config(2, false, false)
	bad_value.set_value("save", "assist", "yes")
	var parsed: Dictionary = SaveScript.parse(bad_value)
	assert_false(parsed["valid"])
	assert_eq(parsed["highest_boss"], 1)
	var good: Dictionary = SaveScript.parse(SaveScript.to_config(3, true, false))
	assert_true(good["valid"])
	assert_eq(good["highest_boss"], 3)
	assert_true(good["assist"])


func test_parse_clamps_highest_boss() -> void:
	var cfg := SaveScript.to_config(1, false, false)
	cfg.set_value("save", "highest_boss", 9)
	assert_eq(SaveScript.parse(cfg)["highest_boss"], 3)
	cfg.set_value("save", "highest_boss", 0)
	assert_eq(SaveScript.parse(cfg)["highest_boss"], 1)


func test_clamp_highest() -> void:
	assert_eq(SaveScript.clamp_highest(0), 1)
	assert_eq(SaveScript.clamp_highest(9), 3)
	assert_eq(SaveScript.clamp_highest("x"), 1)
	assert_eq(SaveScript.clamp_highest(null), 1)
	assert_eq(SaveScript.clamp_highest(2), 2)
	assert_eq(SaveScript.clamp_highest(2.0), 2)


func test_set_assist_writes_assist() -> void:
	var svc: Node = _service()
	svc.set_assist(true)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(SCRATCH), OK)
	assert_eq(cfg.get_value("save", "assist"), true)


func test_set_muted_writes_muted() -> void:
	var svc: Node = _service()
	svc.set_muted(true)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(SCRATCH), OK)
	assert_eq(cfg.get_value("save", "muted"), true)


func test_unwritable_path_warns_once_and_keeps_memory() -> void:
	var svc: Node = _service(UNWRITABLE)
	svc.highest_boss = 2
	assert_false(svc.save())
	assert_true(svc.storage_warned)
	svc.note_fight_start(2)
	assert_eq(svc.highest_boss, 3, "the in-memory value still moves")
	assert_false(svc.save())
	assert_true(svc.storage_warned)
	for err: Variant in get_errors(): # a refused write is not a test failure (AC 5)
		err.handled = true


func test_empty_path_is_in_memory_only() -> void:
	var svc: Node = _service("")
	svc.note_fight_start(1)
	assert_eq(svc.highest_boss, 2)
	assert_false(svc.save())
	assert_false(svc.storage_warned, "in-memory only is not a storage failure")


func test_note_fight_start_only_raises() -> void:
	var svc: Node = _service()
	svc.note_fight_start(2)
	assert_eq(svc.highest_boss, 3)
	svc.note_fight_start(0)
	assert_eq(svc.highest_boss, 3, "never lowered by a fight")
	svc.reset_run_progress()
	assert_eq(svc.highest_boss, 1, "the [N] new run resets it")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(SCRATCH), OK)
	assert_eq(cfg.get_value("save", "highest_boss"), 1)


# --- Game (AC 2, 6, 7, 11) --------------------------------------------------------------------

func _game() -> Node:
	var game: Node = autofree(GameScript.new())
	game.segfault_enabled = true
	return game


func test_fight_entry_raises_highest_boss() -> void:
	var game: Node = _game()
	game.start_run_from_title(0)
	assert_eq(SaveService.highest_boss, 1, "the Intro writes nothing")
	game.finish_intro(GameScript.INTRO_MAX_FRAMES)
	assert_eq(game.flow_state, S.FIGHT)
	assert_eq(SaveService.highest_boss, 1)
	game.advance() # FIGHT -> HARVEST
	assert_eq(SaveService.highest_boss, 1, "HARVEST writes nothing")
	assert_true(game.finish_harvest(0))
	assert_eq(game.run.boss_index, 1)
	assert_eq(SaveService.highest_boss, 2)
	game.advance()
	assert_true(game.finish_harvest(0))
	assert_eq(SaveService.highest_boss, 3, "Harvest -> Boss 3 saves 3")


func test_retry_does_not_write() -> void:
	var game: Node = _game()
	game.start_run_from_title(0)
	game.finish_intro(GameScript.INTRO_MAX_FRAMES)
	SaveService.highest_boss = 1
	game.run.boss_index = 1 # a value a retry would raise to 2 if it wrote
	assert_true(game.record_death(100))
	assert_true(game.retry(100 + GameScript.RETRY_DELAY_FRAMES))
	assert_eq(game.flow_state, S.FIGHT)
	assert_eq(SaveService.highest_boss, 1, "a retry never writes")


func test_debug_jump_does_not_write() -> void:
	Debug.enabled = true
	var game: Node = _game()
	game.debug_jump(S.FIGHT, 2)
	assert_eq(game.flow_state, S.FIGHT)
	assert_eq(SaveService.highest_boss, 1, "a debug jump never raises the save")
	SaveService.highest_boss = 3
	game.debug_jump(S.FIGHT, 0)
	assert_eq(SaveService.highest_boss, 3, "nor lowers it")


func test_ending_and_new_run_never_lower() -> void:
	SaveService.highest_boss = 3
	var game: Node = _game()
	game.start_run_from_title(0)
	game.finish_intro(GameScript.INTRO_MAX_FRAMES)
	assert_eq(SaveService.highest_boss, 3, "Fight 1 of a new run keeps the earned value")


func test_resume_lands_in_fight_at_boss_two_without_intro() -> void:
	var game: Node = _game()
	watch_signals(EventBus)
	game.resume_run_from_title(42, 2)
	assert_eq(game.flow_state, S.FIGHT)
	assert_eq(game.run.boss_index, 1)
	assert_eq(game.first_input_frame, 42, "the 30-s clock starts on the title input")
	assert_eq(game.intro_start_frame, -1)
	assert_eq(game.run.fight_start_ring, Register.fight_start_for_boss(1))
	assert_eq(game.run.deaths_on_boss, 0)
	assert_false(game.stats.debug_jumped)
	assert_signal_emitted_with_parameters(EventBus, "flow_state_changed", [S.TITLE, S.FIGHT])
	assert_eq(SaveService.highest_boss, 2, "the resumed FIGHT entry saves the same value")


func test_resume_reads_save_service_by_default() -> void:
	SaveService.highest_boss = 3
	var game: Node = _game()
	game.resume_run_from_title(0)
	assert_eq(game.run.boss_index, 2)


func test_resume_outside_title_is_ignored() -> void:
	var game: Node = _game()
	game.start_run_from_title(0)
	game.resume_run_from_title(5, 3)
	assert_eq(game.flow_state, S.INTRO)


func test_resume_index_caps_with_segfault_cut() -> void:
	assert_eq(GameScript.resume_index(1, true), 0)
	assert_eq(GameScript.resume_index(2, true), 1)
	assert_eq(GameScript.resume_index(3, true), 2)
	assert_eq(GameScript.resume_index(3, false), 1, "the cut Segfault fight is never resumed into")
	assert_eq(GameScript.resume_index(0, true), 0)


func test_resume_with_segfault_cut_keeps_the_saved_value() -> void:
	var game: Node = _game()
	game.segfault_enabled = false
	SaveService.highest_boss = 3
	game.resume_run_from_title(0, 3)
	assert_eq(game.run.boss_index, 1)
	assert_eq(SaveService.highest_boss, 3, "only the resume is capped (D-S73-4)")


func test_start_new_run_resets_and_keeps_intro() -> void:
	SaveService.highest_boss = 3
	var game: Node = _game()
	game.start_new_run_from_title(7)
	assert_eq(SaveService.highest_boss, 1)
	assert_eq(game.flow_state, S.INTRO)
	assert_false(game.can_skip_intro(7), "the title input never counts as an Intro skip")


# --- Full HP on the resumed fight (AC 6, Task 4.4) --------------------------------------------

func test_resumed_fight_starts_at_full_hp() -> void:
	var main: Node2D = load("res://src/main/main.tscn").instantiate()
	add_child_autofree(main)
	var arena := main.get_node(^"Arena") as Arena
	main.apply_flow_state(S.FIGHT, 0)
	arena.health.hp = 1 # a hurt player from an earlier fight
	main.apply_flow_state(S.TITLE, 0)
	main.apply_flow_state(S.FIGHT, 1) # the resumed Boss 2 fight
	assert_eq(arena.health.hp, arena.health.def.max_hp)


# --- Title (AC 8-10) --------------------------------------------------------------------------

func _title(highest_boss: int) -> TitleScreen:
	var title: TitleScreen = autofree(TitleScreenScript.new())
	title.set_saved_progress(highest_boss)
	return title


func test_new_run_option_only_with_progress() -> void:
	assert_false(_title(1).is_option_available(&"new_run"))
	assert_false(_title(1).label_rects.has(&"new_run"))
	assert_true(_title(2).is_option_available(&"new_run"))
	assert_true(_title(2).label_rects.has(&"new_run"))


func test_title_reads_save_service_on_ready() -> void:
	SaveService.highest_boss = 2
	var title: TitleScreen = TitleScreenScript.new()
	add_child_autofree(title)
	assert_true(title.is_option_available(&"new_run"))


func test_label_text_and_rect() -> void:
	assert_eq(TitleScreenScript.NEW_RUN_TEXT, "[N] new run")
	var rect: Rect2 = TitleScreenScript.new_run_label_rect()
	assert_true(rect.position.y > TitleScreenScript.PROMPT_TOP_Y)
	assert_true(rect.end.y <= Const.BASE_RES.y)


func _title_state() -> void:
	Game.flow_state = S.TITLE
	SimClock.paused = false


func test_n_resets_and_goes_to_intro() -> void:
	_title_state()
	SaveService.highest_boss = 2
	var title := _title(2)
	assert_eq(title.handle_input(_key(KEY_N)), TitleScreenScript.Action.OPTION)
	assert_eq(SaveService.highest_boss, 1)
	assert_eq(Game.flow_state, S.INTRO)


func test_click_on_label_is_the_same_as_n() -> void:
	_title_state()
	SaveService.highest_boss = 3
	var title := _title(3)
	title.handle_input(_click(TitleScreenScript.new_run_label_rect().get_center()))
	assert_eq(SaveService.highest_boss, 1)
	assert_eq(Game.flow_state, S.INTRO)


func test_other_key_with_save_resumes_at_boss_two() -> void:
	_title_state()
	SaveService.highest_boss = 2
	var title := _title(2)
	assert_eq(title.handle_input(_key(KEY_SPACE)), TitleScreenScript.Action.START)
	assert_eq(Game.flow_state, S.FIGHT)
	assert_eq(Game.run.boss_index, 1)
	assert_eq(SaveService.highest_boss, 2, "a resume never resets the save")
	assert_true(AudioManager.is_unlocked(), "the title input unlocks audio first")


func test_click_elsewhere_with_save_resumes() -> void:
	_title_state()
	SaveService.highest_boss = 2
	var title := _title(2)
	title.handle_input(_click(Vector2(8, 8)))
	assert_eq(Game.flow_state, S.FIGHT)
	assert_eq(Game.run.boss_index, 1)


func test_n_without_save_is_a_start_key() -> void:
	_title_state()
	var title := _title(1)
	assert_eq(title.handle_input(_key(KEY_N)), TitleScreenScript.Action.START)
	assert_eq(Game.flow_state, S.INTRO)
	assert_eq(SaveService.highest_boss, 1)


func test_title_never_starts_twice() -> void:
	_title_state()
	SaveService.highest_boss = 2
	var title := _title(2)
	title.handle_input(_key(KEY_SPACE))
	Game.flow_state = S.TITLE
	assert_eq(title.handle_input(_key(KEY_N)), TitleScreenScript.Action.IGNORE)
	assert_eq(SaveService.highest_boss, 2)


# --- Mute persistence (D-S73-7 overturned) ----------------------------------------------------

func test_pause_mute_toggle_writes_muted() -> void:
	var was_muted: bool = AudioManager.is_master_muted()
	SaveService.path = SCRATCH
	var pause: Node2D = PauseScreen.new()
	add_child_autofree(pause)
	var m := InputEventKey.new()
	m.physical_keycode = KEY_M
	m.pressed = true
	pause._input(m)
	assert_eq(SaveService.muted, not was_muted)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(SCRATCH), OK)
	assert_eq(cfg.get_value("save", "muted"), not was_muted)
	AudioManager.set_master_muted(was_muted)
