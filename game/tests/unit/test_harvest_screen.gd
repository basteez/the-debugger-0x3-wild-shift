extends GutTest
## Story 3.8 (E1-E5, AC 2, 3, 5, 9): the HARVEST screen's pure helpers (register copy, windows,
## texts), its skip / cap, the harvest duck line, the boss view's reassembly helpers, the defeat
## squeak, and that presentation never writes sim state (G8).

const GameScript := preload("res://src/autoloads/game.gd")
const HarvestScript := preload("res://src/ui/screens/harvest/harvest_screen.gd")
const IsolationScript := preload("res://tests/unit/test_attack_isolation.gd")
const DuckIsolation := preload("res://tests/unit/test_duck_isolation.gd")
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT
const FIXED := "for (i = 0; i < n; i++) { }"

var _saved_state: int
var _saved_run: RunState
var _saved_harvest: int


func before_each() -> void:
	_saved_state = Game.flow_state
	_saved_run = Game.run
	_saved_harvest = Game.harvest_start_frame
	Game.run = RunState.new()
	SimClock.paused = false


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	Game.run = _saved_run
	Game.harvest_start_frame = _saved_harvest


func _ring(bits: Array) -> PackedInt32Array:
	return PackedInt32Array(bits)


func test_harvest_ring_inserts_on_a_copy() -> void:
	var previous: PackedInt32Array = _ring([D, A])
	assert_eq(HarvestScreen.harvest_ring(previous, L), _ring([D, A, L]))
	assert_eq(previous, _ring([D, A]), "the input is untouched")
	assert_eq(HarvestScreen.harvest_ring(previous, 0), _ring([D, A]), "no bit: unchanged")
	assert_eq(HarvestScreen.harvest_ring(_ring([A, D]), L), _ring([A, D, L]))


func test_display_ring_is_the_next_fight_start_when_it_holds_the_same_bits() -> void:
	assert_eq(HarvestScreen.display_ring(_ring([D, A]), L, 0), _ring([A, D, L]), "Fight 2 order (D-S38-17)")
	assert_eq(HarvestScreen.display_ring(_ring([A, D, L]), N, 1), _ring([A, D, L, N]))
	assert_eq(HarvestScreen.display_ring(_ring([D, A]), 0, 0), _ring([D, A]), "test boss: no bit")


func test_windows_and_new_windows() -> void:
	assert_eq(HarvestScreen.windows_of(_ring([D, A])), [Vector2i(D, A), Vector2i(A, D)])
	assert_eq(HarvestScreen.windows_of(_ring([A, D, L])), [Vector2i(A, D), Vector2i(D, L), Vector2i(L, A)])
	assert_eq(HarvestScreen.new_windows(_ring([D, A]), _ring([A, D, L])), [Vector2i(D, L), Vector2i(L, A)])


func test_texts() -> void:
	assert_eq(HarvestScreen.register_text(_ring([A, D, L])), "[A, D, L] = 0x07")
	assert_eq(HarvestScreen.window_text(Vector2i(A, D)), "A>D  Dash Strike")
	assert_eq(HarvestScreen.window_text(Vector2i(D, L)), "D>L  Echo Dash", "Story 4.2 shipped D->L")
	assert_eq(HarvestScreen.window_text(Vector2i(L, A)), "L>A  --")
	var text: String = HarvestScreen.register_text(_ring([A, D, L]))
	assert_eq(text[HarvestScreen.slot_char_index(2)], "L", "slot index points at the glyph")
	assert_eq(text[HarvestScreen.slot_char_index(0)], "A")


func test_flight_progress() -> void:
	assert_eq(HarvestScreen.BIT_FLIGHT_FRAMES, 30)
	assert_eq(HarvestScreen.flight_progress(0), 0.0)
	assert_eq(HarvestScreen.flight_progress(15), 0.5)
	assert_eq(HarvestScreen.flight_progress(90), 1.0)


func test_every_row_fits_the_base_width_and_the_font() -> void:
	var screen: HarvestScreen = autofree(HarvestScript.new())
	screen.setup(0, FIXED, L, _ring([D, A]))
	var font: Font = GlyphFont.font()
	for row: String in screen.text_rows():
		assert_lte(GlyphFont.text_width(row, HarvestScreen.TEXT_SCALE), Const.BASE_RES.x, row)
		for i: int in row.length():
			assert_true(row[i] == " " or font.has_char(row.unicode_at(i)), "glyph %s" % row[i])
	assert_eq(screen.fixed_text(), FIXED)
	screen.setup(0, "", 0, _ring([D, A]))
	assert_eq(screen.fixed_text(), HarvestScreen.FIXED_FALLBACK)


func test_skip_opens_after_120_frames_and_finishes_into_fight_2() -> void:
	Game.flow_state = GameScript.FlowState.HARVEST
	Game.harvest_start_frame = 1000
	var screen: HarvestScreen = autofree(HarvestScript.new())
	screen.setup(0, FIXED, L, _ring([D, A]))
	assert_false(screen.try_skip(1119), "before 2 s: consumed, nothing")
	assert_eq(Game.flow_state, GameScript.FlowState.HARVEST)
	assert_true(screen.try_skip(1120))
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
	assert_eq(Game.run.boss_index, 1)
	assert_eq(Game.run.fight_start_ring, _ring([A, D, L]))


func test_harvest_requests_the_shared_line_once_and_only_in_harvest() -> void:
	Game.flow_state = GameScript.FlowState.HARVEST
	var screen: HarvestScreen = HarvestScript.new()
	screen.setup(0, FIXED, L, _ring([D, A]))
	add_child_autofree(screen)
	watch_signals(EventBus)
	screen.request_line()
	screen.request_line()
	assert_signal_emit_count(EventBus, "duck_line_requested", 1)
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"harvest_shared", "Bug squashed. It dropped a bit: new windows, new combos."])
	var other: HarvestScreen = HarvestScript.new()
	other.setup(0, FIXED, L, _ring([D, A]))
	add_child_autofree(other)
	Game.flow_state = GameScript.FlowState.FIGHT
	other.request_line()
	assert_signal_emit_count(EventBus, "duck_line_requested", 1, "not after HARVEST was left")


func test_main_harvest_bit_for() -> void:
	var MainScript: GDScript = load("res://src/main/main.gd")
	assert_eq(MainScript.harvest_bit_for(0), L)
	assert_eq(MainScript.harvest_bit_for(1), N)
	assert_eq(MainScript.harvest_bit_for(2), 0, "the last boss drops nothing")


# --- BossView reassembly helpers (D1, D-S38-9) ---

func test_reassembly_progress_and_cells() -> void:
	assert_eq(BossView.reassembly_progress(0), 0.0)
	assert_eq(BossView.reassembly_progress(30), 0.5)
	assert_eq(BossView.reassembly_progress(600), 1.0)
	var cell: float = GlyphFont.CELL * BossView.GLYPH_SCALE
	var centre := Vector2(256, 100)
	assert_eq(BossView.fixed_cell_centre(centre, 13, 27), centre, "the middle cell sits on the centre")
	assert_eq(BossView.fixed_cell_centre(centre, 0, 27), centre - Vector2(13 * cell, 0))
	var pushed: Vector2 = BossView.fixed_line_centre(Vector2(20, 100), 27)
	var half: float = 27 * cell / 2.0
	assert_eq(pushed.x, half, "pushed in from the left edge")
	assert_eq(BossView.fixed_line_centre(Vector2(500, 100), 27).x, Arena.play_area().end.x - half)


# --- Defeat squeak (D2, AC 1) ---

func test_defeat_squeaks_once_per_fight() -> void:
	var before: int = AudioManager.defeat_squeak_count
	EventBus.flow_state_changed.emit(GameScript.FlowState.INTRO, GameScript.FlowState.FIGHT)
	EventBus.boss_defeated.emit(&"infinite_loop")
	EventBus.boss_defeated.emit(&"infinite_loop")
	assert_eq(AudioManager.defeat_squeak_count, before + 1, "a second emission never squeaks twice")
	EventBus.flow_state_changed.emit(GameScript.FlowState.HARVEST, GameScript.FlowState.FIGHT)
	EventBus.boss_defeated.emit(&"infinite_loop")
	assert_eq(AudioManager.defeat_squeak_count, before + 2, "the next fight squeaks again")


# --- G8: presentation never writes sim state ---

func test_harvest_screen_and_boss_view_never_write_sim_state() -> void:
	for path: String in ["res://src/ui/screens/harvest/harvest_screen.gd", "res://src/presentation/boss_view.gd"]:
		var code: String = IsolationScript.code_of(path)
		var forbidden: Array[String] = [
			"\\btick\\s*\\(",
			"\\.rng\\b",
			"\\bboss\\.(take_hit|debug_\\w+|reset_for_fight|set_active)\\s*\\(",
			"\\b(arena|boss|body|run)\\.[\\w.]+\\s*([-+*/]?=[^=])",
			"\\bGame\\.(flow_state|run|harvest_start_frame)\\s*=[^=]",
			"\\bSimClock\\.(request_hitstop|hitstop_frames|begin_fight)",
		]
		assert_eq(DuckIsolation.violations(code, forbidden), PackedStringArray(), path)
	var harvest: String = IsolationScript.code_of("res://src/ui/screens/harvest/harvest_screen.gd")
	assert_false(harvest.contains("arena"), "the harvest screen never reads the arena (D-S38-5)")


# --- Story 5.6 (B2, B3; D-S56-6): the NULL harvest after the Null Pointer ---

func test_null_harvest_display_ring_reads_0x0f() -> void:
	var previous: PackedInt32Array = Register.fight_start_for_boss(1)
	var shown: PackedInt32Array = HarvestScreen.display_ring(previous, N, 1)
	assert_eq(shown, _ring([A, D, L, N]))
	assert_eq(shown, Register.fight_start_for_boss(2), "the Fight 3 start set")
	assert_eq(HarvestScreen.register_text(shown), "[A, D, L, N] = 0x0F")
	assert_eq(previous, _ring([A, D, L]), "the copy-based insert never writes its input")


func test_inserting_an_owned_null_is_rejected_not_duplicated() -> void:
	var owned: PackedInt32Array = _ring([A, D, L, N])
	assert_eq(HarvestScreen.harvest_ring(owned, N), owned, "unchanged, N once")
	assert_push_error("insert into a full register")
	assert_eq(HarvestScreen.harvest_ring(_ring([A, D, N]), N), _ring([A, D, N]), "an owned N is never duplicated")
	assert_push_error("insert of owned bit N")
	var reg := Register.new()
	assert_true(reg.set_fight_start(_ring([A, D, N])))
	assert_false(reg.insert(N), "the Register error path")
	assert_push_error("insert of owned bit N")
	assert_eq(reg.ring.count(N), 1)


func test_fight_3_start_set_holds_null_once() -> void:
	var ring: PackedInt32Array = Register.fight_start_for_boss(2)
	assert_eq(ring, _ring([A, D, L, N]))
	assert_eq(ring.count(N), 1)
	assert_false(Register.fight_start_for_boss(1).has(N), "the Fight 2 start ring never owns N")
