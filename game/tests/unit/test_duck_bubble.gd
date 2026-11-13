extends GutTest
## Story 3.6 AC 1-4, 12, 14 (B1, B2, E1-E6, H1): the wrap rule on the four tutorial lines, the
## typewriter arithmetic and pause freeze, the queue order and cap, clear(), the squeak on its own
## player, and the cells the bubble draws (the `>o` at (0, 22), text in cols 0-11, rows 23-37).

const LINES: DuckLinesDef = preload("res://data/duck/duck_lines.tres")
const AudioManagerScript := preload("res://src/autoloads/audio_manager.gd")
const GameScript := preload("res://src/autoloads/game.gd")

var _bubble: DuckBubble


func before_each() -> void:
	SimClock.paused = false
	_bubble = DuckBubble.new()
	add_child_autofree(_bubble)


func after_each() -> void:
	SimClock.paused = false


func _texts() -> PackedStringArray:
	var out := PackedStringArray()
	for e: DuckLineDef in LINES.entries:
		out.append(e.text)
	return out


## Shows the current line fully and runs out its hold.
func _finish_line() -> void:
	_bubble.step(100.0) # reveal completes (the step returns after revealing)
	_bubble.step(_bubble.hold_left() + 0.001)


# --- wrap (B1) ---

func test_wrap_fits_every_tutorial_line() -> void:
	# Story 3.8: + harvest_shared. Story 4.4: T1 rewritten (11 lines, D-S44-2) + the two hint lines.
	# Story 5.1: + the Null Pointer's D->L hint line. Story 5.6: + N1 (Breakpoint) and N2 (Hold R).
	# Story 6.3: + the Segfault's N->A and L->N hint windows (the template, D-039 counts it once).
	var expected_lines: Array[int] = [11, 7, 4, 7, 6, 2, 2, 2, 2, 2, 7, 4]
	var texts: PackedStringArray = _texts()
	for i: int in texts.size():
		var lines: PackedStringArray = DuckBubble.wrap(texts[i], DuckBubble.WRAP_WIDTH)
		assert_eq(lines.size(), expected_lines[i], texts[i])
		assert_lte(lines.size(), DuckBubble.MAX_LINES)
		for line: String in lines:
			assert_lte(line.length(), DuckBubble.WRAP_WIDTH, line)
		assert_eq(" ".join(lines), texts[i], "rejoined words equal the input")


func test_wrap_matches_the_story_t1_lines() -> void:
	# Story 4.4 (AC 11, D-S44-2): the rewritten T1 wraps to 11 of the 15 text rows (rows 23-33).
	var lines: PackedStringArray = DuckBubble.wrap(_texts()[0])
	assert_eq(lines, PackedStringArray([
		"Q or E", "shifts your", "bits. Go on,", "shift. It's", "waiting.", "Only the two", "on the left", "are live;",
		"the rest are", "in code", "review.",
	]))
	assert_lte(DuckBubble.line_cell(lines.size() - 1).y, 37, "the last row stays inside the duck region")
	for cell: Vector2i in DuckBubble.cells_for_text(_texts()[0]):
		assert_true(cell.x >= 0 and cell.x <= 11 and cell.y >= 22 and cell.y <= 37, "cell %s inside cols 0-11, rows 22-37" % cell)


func test_hint_lines_wrap_with_the_window_on_one_row() -> void:
	# Story 4.4 (AC 1): the window glyphs never split across rows.
	assert_eq(DuckBubble.wrap(DuckHint.window_text(Vector2i(Register.Bit.DASH, Register.Bit.ATTACK))), PackedStringArray([
		"Quack. Weak", "window: D→A.",
	]))


func test_wrap_never_splits_a_word() -> void:
	var lines: PackedStringArray = DuckBubble.wrap("tiny supercalifragilistic ok", 12)
	assert_eq(lines, PackedStringArray(["tiny", "supercalifragilistic", "ok"]), "a long word stays whole")
	assert_eq(DuckBubble.wrap("", 12), PackedStringArray())
	assert_eq(DuckBubble.wrap("a  b", 12), PackedStringArray(["a b"]), "runs of spaces collapse")
	assert_eq(DuckBubble.wrap("abcdef abcde", 12), PackedStringArray(["abcdef abcde"]), "exactly 12 fits")
	assert_eq(DuckBubble.wrap("abcdef abcdef", 12), PackedStringArray(["abcdef", "abcdef"]))


# --- TypewriterReveal (B2) ---

func test_visible_chars_arithmetic() -> void:
	assert_eq(TypewriterReveal.visible_chars(0.0, 30.0, 88), 0)
	assert_eq(TypewriterReveal.visible_chars(0.1, 30.0, 88), 3)
	assert_eq(TypewriterReveal.visible_chars(1.0, 30.0, 88), 30)
	assert_eq(TypewriterReveal.visible_chars(88.0 / 30.0, 30.0, 88), 88, "full at length / 30 s")
	assert_eq(TypewriterReveal.visible_chars(10.0, 30.0, 88), 88, "clamped to length")
	assert_eq(TypewriterReveal.visible_chars(-1.0, 30.0, 88), 0)


func test_reveal_advances_and_completes() -> void:
	var r := TypewriterReveal.new()
	assert_eq(r.chars_per_second, 30.0)
	r.set_line(44)
	assert_false(r.is_done())
	r.advance(0.5)
	assert_eq(r.revealed, 15)
	r.advance(1.0)
	assert_eq(r.revealed, 44)
	assert_true(r.is_done())


func test_set_revealed_overrides_the_timer() -> void:
	var r := TypewriterReveal.new()
	r.set_line(20)
	r.set_revealed(7)
	assert_eq(r.revealed, 7)
	r.advance(10.0)
	assert_eq(r.revealed, 7, "the timer no longer drives it")
	r.set_revealed(99)
	assert_eq(r.revealed, 20, "clamped")
	r.set_line(5)
	r.advance(1.0)
	assert_eq(r.revealed, 5, "a new line gives the timer back")


func test_visible_lines_cut_each_wrapped_line() -> void:
	var lines := PackedStringArray(["Q and E", "shift your"])
	assert_eq(DuckBubble.revealable_length(lines), 18)
	assert_eq(DuckBubble.visible_lines(lines, 0), PackedStringArray(["", ""]))
	assert_eq(DuckBubble.visible_lines(lines, 3), PackedStringArray(["Q a", ""]))
	assert_eq(DuckBubble.visible_lines(lines, 8), PackedStringArray(["Q and E", ""]))
	assert_eq(DuckBubble.visible_lines(lines, 10), PackedStringArray(["Q and E", "sh"]))
	assert_eq(DuckBubble.visible_lines(lines, 18), PackedStringArray(["Q and E", "shift your"]))


# --- the bubble node (E1-E6) ---

func test_connects_on_enter_and_disconnects_on_exit() -> void:
	assert_true(EventBus.duck_line_requested.is_connected(_bubble._on_duck_line_requested))
	assert_true(EventBus.flow_state_changed.is_connected(_bubble._on_flow_state_changed))
	remove_child(_bubble)
	assert_false(EventBus.duck_line_requested.is_connected(_bubble._on_duck_line_requested))
	assert_false(EventBus.flow_state_changed.is_connected(_bubble._on_flow_state_changed))
	add_child(_bubble)


func test_a_request_shows_the_line_with_a_typewriter() -> void:
	EventBus.duck_line_requested.emit(&"t3_dash_strike", "J then K: Dash Strike. Two bits, one commit.")
	assert_true(_bubble.is_showing())
	assert_eq(_bubble.current_id(), &"t3_dash_strike")
	assert_eq(_bubble.current_lines().size(), 4)
	assert_eq(_bubble.reveal().revealed, 0)
	_bubble.step(0.1)
	assert_eq(_bubble.reveal().revealed, 3)


func test_the_bubble_hides_after_reveal_and_hold() -> void:
	var text := "J then K: Dash Strike. Two bits, one commit."
	_bubble.enqueue(text, &"t3_dash_strike")
	_bubble.step(float(text.length()) / DuckBubble.CHARS_PER_S + 0.001)
	assert_true(_bubble.reveal().is_done())
	assert_almost_eq(_bubble.hold_left(), DuckBubble.hold_seconds(text.length()), 0.0001)
	_bubble.step(DuckBubble.hold_seconds(text.length()) - 0.1)
	assert_true(_bubble.is_showing(), "still holding")
	_bubble.step(0.2)
	assert_false(_bubble.is_showing())


func test_hold_time_formula() -> void:
	assert_almost_eq(DuckBubble.hold_seconds(88), DuckBubble.HOLD_BASE_S + DuckBubble.HOLD_PER_CHAR_S * 88.0, 0.0001)
	assert_almost_eq(DuckBubble.hold_seconds(0), DuckBubble.HOLD_BASE_S, 0.0001)


func test_pause_freezes_reveal_and_hold() -> void:
	_bubble.enqueue("See the semicolon?", &"x")
	_bubble.step(0.1)
	SimClock.paused = true
	_bubble.step(5.0)
	assert_eq(_bubble.reveal().revealed, 3, "reveal frozen")
	SimClock.paused = false
	_bubble.step(100.0)
	var hold: float = _bubble.hold_left()
	SimClock.paused = true
	_bubble.step(100.0)
	assert_eq(_bubble.hold_left(), hold, "hold frozen")
	assert_true(_bubble.is_showing())


func test_queue_is_fifo() -> void:
	_bubble.enqueue("one", &"a")
	_bubble.enqueue("two", &"b")
	_bubble.enqueue("three", &"c")
	assert_eq(_bubble.current_lines(), PackedStringArray(["one"]))
	assert_eq(_bubble.pending(), ["two", "three"] as Array[String])
	_finish_line()
	assert_eq(_bubble.current_id(), &"b")
	assert_eq(_bubble.reveal().revealed, 0, "the next line starts unrevealed")
	_finish_line()
	assert_eq(_bubble.current_id(), &"c")
	_finish_line()
	assert_false(_bubble.is_showing())


func test_queue_caps_at_max_pending() -> void:
	_bubble.enqueue("showing", &"s")
	for i: int in DuckBubble.MAX_PENDING + 2:
		_bubble.enqueue("line %d" % i, &"q")
	assert_eq(DuckBubble.MAX_PENDING, 4)
	assert_eq(_bubble.pending().size(), DuckBubble.MAX_PENDING, "requests beyond the cap are dropped")
	assert_eq(_bubble.pending()[0], "line 0")
	assert_eq(_bubble.pending()[3], "line 3")


func test_clear_drops_queue_and_hides() -> void:
	_bubble.enqueue("one", &"a")
	_bubble.enqueue("two", &"b")
	_bubble.clear()
	assert_false(_bubble.is_showing())
	assert_eq(_bubble.pending().size(), 0)
	assert_eq(_bubble.current_lines().size(), 0)


func test_leaving_fight_clears_and_entering_fight_does_not() -> void:
	_bubble.enqueue("one", &"a")
	EventBus.flow_state_changed.emit(GameScript.FlowState.DEAD, GameScript.FlowState.FIGHT)
	assert_true(_bubble.is_showing(), "FIGHT keeps the bubble")
	for to: int in [GameScript.FlowState.DEAD, GameScript.FlowState.HARVEST, GameScript.FlowState.TITLE, GameScript.FlowState.ENDING]:
		_bubble.enqueue("one", &"a")
		_bubble.enqueue("two", &"b")
		EventBus.flow_state_changed.emit(GameScript.FlowState.FIGHT, to)
		assert_false(_bubble.is_showing(), "cleared on %d" % to)
		assert_eq(_bubble.pending().size(), 0)


# --- cells (AC 1) ---

func test_duck_glyph_cell_and_text_origin() -> void:
	assert_eq(DuckBubble.DUCK_GLYPH, PlayerView.DUCK_GLYPH)
	assert_eq(DuckBubble.DUCK_CELL, Vector2i(0, 22))
	assert_eq(DuckBubble.DUCK_CELL, Hud.DUCK.position)
	assert_eq(DuckBubble.line_cell(0), Vector2i(0, 23))
	assert_eq(DuckBubble.line_cells(1, "abc"), [Vector2i(0, 24), Vector2i(1, 24), Vector2i(2, 24)] as Array[Vector2i])
	assert_eq(DuckBubble.WRAP_WIDTH, Hud.DUCK.size.x)


func test_no_cell_outside_the_duck_region() -> void:
	var text_area := Rect2i(0, 23, 12, 15) # cols 0-11, rows 23-37
	for text: String in _texts():
		var cells: Array[Vector2i] = DuckBubble.cells_for_text(text)
		assert_eq(cells[0], Vector2i(0, 22), "the duck first")
		assert_eq(cells[1], Vector2i(1, 22))
		for i: int in range(2, cells.size()):
			assert_true(text_area.has_point(cells[i]), "%s outside the text area" % cells[i])
		for cell: Vector2i in cells:
			assert_eq(Hud.region_of(cell), &"duck", "%s" % cell)


# --- squeak (AC 4, D1-D2) ---

func test_squeak_uses_its_own_player_after_unlock() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.play_squeak()
	assert_eq(am.get_child_count(), 0, "locked: nothing plays")
	assert_eq(am.get("locked_warn_count"), 1)
	am.play_squeak()
	assert_eq(am.get("locked_warn_count"), 1, "warn once")
	am.unlock()
	am.play_squeak()
	var squeak := am.get_node_or_null(^"DuckSqueak") as AudioStreamPlayer
	assert_not_null(squeak)
	assert_eq(squeak.bus, &"SFX")
	assert_not_null(squeak.stream)
	assert_null(am.get_node_or_null(^"ShiftSfx"), "never the ShiftSfx player")
	am.play_squeak()
	assert_eq(am.get_child_count(), 1, "one squeak player, reused")


func test_line_start_advances_to_next_queued_line() -> void:
	# The squeak call itself is covered by the own-player test above (the autoload is locked here).
	_bubble.enqueue("one", &"a")
	_bubble.enqueue("two", &"b")
	assert_eq(_bubble.current_id(), &"a")
	_finish_line()
	assert_eq(_bubble.current_id(), &"b")


# --- Story 3.7 voice wiring (AC 4-6, D1-D4, G2) ---

## Stands in for VoiceService: can_speak / speak_pending / stop, and stop emits like the real one.
class FakeVoice:
	extends Node
	var speakable: bool = true
	var starts: bool = true
	var spoken: Array = []
	var stops: int = 0
	var _speaking_id: StringName = &""
	var _speaking: bool = false

	func can_speak() -> bool:
		return speakable

	func speak_pending(line_id: StringName, text: String) -> bool:
		spoken.append([line_id, text])
		_speaking = starts
		_speaking_id = line_id
		return starts

	func stop() -> void:
		stops += 1
		if _speaking:
			_speaking = false
			EventBus.duck_line_finished.emit(_speaking_id, false)


const T3 := "J then K: Dash Strike. Two bits, one commit."


func _voiced() -> FakeVoice:
	var fake := FakeVoice.new()
	add_child_autofree(fake)
	_bubble.voice = fake
	return fake


## Starts T3 on a voiced bubble and runs out the squeak lead.
func _start_voiced(fake: FakeVoice) -> void:
	_bubble.enqueue(T3, &"t3_dash_strike")
	_bubble.step(DuckBubble.SQUEAK_LEAD_S + 0.001)
	assert_eq(fake.spoken.size(), 1, "the voice started after the lead")


func test_bubble_connects_the_voice_signals() -> void:
	assert_true(EventBus.duck_character_spoken.is_connected(_bubble._on_duck_character_spoken))
	assert_true(EventBus.duck_line_finished.is_connected(_bubble._on_duck_line_finished))
	remove_child(_bubble)
	assert_false(EventBus.duck_character_spoken.is_connected(_bubble._on_duck_character_spoken))
	assert_false(EventBus.duck_line_finished.is_connected(_bubble._on_duck_line_finished))
	add_child(_bubble)


func test_squeak_first_then_the_voice_after_the_lead() -> void:
	var fake: FakeVoice = _voiced()
	assert_almost_eq(DuckBubble.SQUEAK_LEAD_S, 0.15, 0.0001)
	_bubble.enqueue(T3, &"t3_dash_strike")
	_bubble.step(0.1)
	assert_eq(fake.spoken.size(), 0, "no voice during the squeak lead")
	assert_eq(_bubble.reveal().revealed, 0, "nothing shows before the voice")
	assert_true(_bubble.reveal().driven_externally, "the timer does not run on a voiced line")
	_bubble.step(0.06)
	assert_eq(fake.spoken, [[&"t3_dash_strike", T3]], "the joined wrapped text is spoken")
	assert_true(_bubble.is_voice_speaking())


func test_characters_drive_the_reveal_and_the_timer_stays_off() -> void:
	var fake: FakeVoice = _voiced()
	_start_voiced(fake)
	EventBus.duck_character_spoken.emit(0)
	assert_eq(_bubble.reveal().revealed, 1)
	EventBus.duck_character_spoken.emit(6)
	assert_eq(_bubble.reveal().revealed, 7, "char_index + 1")
	_bubble.step(10.0)
	assert_eq(_bubble.reveal().revealed, 7, "the 30 chars/s timer does not drive a voiced line")
	assert_almost_eq(_bubble.hold_left(), DuckBubble.hold_seconds(T3.length()), 0.0001, "no hold yet")


func test_completed_line_reveals_the_rest_and_holds() -> void:
	var fake: FakeVoice = _voiced()
	_start_voiced(fake)
	EventBus.duck_character_spoken.emit(10)
	EventBus.duck_line_finished.emit(&"t3_dash_strike", true)
	assert_eq(_bubble.reveal().revealed, T3.length())
	assert_false(_bubble.is_voice_speaking())
	_bubble.step(DuckBubble.hold_seconds(T3.length()) - 0.1)
	assert_true(_bubble.is_showing(), "holding")
	_bubble.step(0.2)
	assert_false(_bubble.is_showing())


func test_the_hold_waits_for_the_finished_event() -> void:
	var fake: FakeVoice = _voiced()
	_start_voiced(fake)
	EventBus.duck_character_spoken.emit(T3.length() - 1) # every character shown
	assert_true(_bubble.reveal().is_done())
	_bubble.step(100.0)
	assert_true(_bubble.is_showing(), "no hold countdown while the voice speaks")
	assert_almost_eq(_bubble.hold_left(), DuckBubble.hold_seconds(T3.length()), 0.0001)
	EventBus.duck_line_finished.emit(&"t3_dash_strike", true)
	_bubble.step(1.0)
	assert_almost_eq(_bubble.hold_left(), DuckBubble.hold_seconds(T3.length()) - 1.0, 0.0001)


func test_a_cut_line_hands_the_reveal_back_to_the_timer() -> void:
	var fake: FakeVoice = _voiced()
	_start_voiced(fake)
	EventBus.duck_character_spoken.emit(9)
	EventBus.duck_line_finished.emit(&"t3_dash_strike", false)
	assert_eq(_bubble.reveal().revealed, 10, "keeps what the voice showed")
	assert_false(_bubble.reveal().driven_externally)
	_bubble.step(0.1)
	assert_eq(_bubble.reveal().revealed, 13, "the timer continues from there, silently")
	_bubble.step(100.0)
	assert_true(_bubble.reveal().is_done())


func test_finished_for_another_line_is_ignored() -> void:
	var fake: FakeVoice = _voiced()
	_start_voiced(fake)
	EventBus.duck_line_finished.emit(&"other", true)
	assert_true(_bubble.is_voice_speaking())
	assert_eq(_bubble.reveal().revealed, 0)


func test_clear_stops_the_voice_and_late_events_do_nothing() -> void:
	var fake: FakeVoice = _voiced()
	_start_voiced(fake)
	EventBus.duck_character_spoken.emit(3)
	_bubble.clear()
	assert_eq(fake.stops, 1, "clear() calls VoiceService.stop()")
	assert_false(_bubble.is_showing())
	EventBus.duck_character_spoken.emit(8)
	EventBus.duck_line_finished.emit(&"t3_dash_strike", true)
	assert_false(_bubble.is_showing(), "a late event never revives a cleared bubble")
	assert_eq(_bubble.reveal().revealed, 0)
	assert_eq(_bubble.hold_left(), 0.0, "no hold running")


## Story 3.8 (E5, AC 9): leaving HARVEST clears the harvest line and cuts the voice.
func test_leaving_harvest_stops_the_voice() -> void:
	var fake: FakeVoice = _voiced()
	_start_voiced(fake)
	EventBus.flow_state_changed.emit(GameScript.FlowState.HARVEST, GameScript.FlowState.FIGHT)
	assert_false(_bubble.is_showing(), "no harvest line in the next fight")
	assert_gte(fake.stops, 1)


func test_leaving_fight_stops_the_voice() -> void:
	var fake: FakeVoice = _voiced()
	_start_voiced(fake)
	EventBus.flow_state_changed.emit(GameScript.FlowState.FIGHT, GameScript.FlowState.DEAD)
	assert_eq(fake.stops, 1)
	assert_false(_bubble.is_showing())


func test_pause_stops_the_voice_once_and_the_text_finishes_silently() -> void:
	var fake: FakeVoice = _voiced()
	_start_voiced(fake)
	EventBus.duck_character_spoken.emit(4)
	SimClock.paused = true
	_bubble.step(0.016)
	_bubble.step(0.016)
	_bubble.step(0.016)
	assert_eq(fake.stops, 1, "one stop for the pause")
	assert_eq(_bubble.reveal().revealed, 5, "frozen while paused")
	assert_true(_bubble.is_showing())
	SimClock.paused = false
	_bubble.step(0.1)
	assert_eq(_bubble.reveal().revealed, 8, "the timer finishes the rest after resume (D-S37-7)")
	assert_eq(fake.spoken.size(), 1, "the voice does not resume")


func test_a_voice_that_does_not_start_leaves_the_timer() -> void:
	var fake: FakeVoice = _voiced()
	fake.starts = false
	_start_voiced(fake)
	assert_false(_bubble.is_voice_speaking())
	_bubble.step(0.1)
	assert_eq(_bubble.reveal().revealed, 3, "silent line on the 3.6 timer")


func test_unvoiced_lines_keep_the_3_6_timing() -> void:
	var fake: FakeVoice = _voiced()
	fake.speakable = false
	_bubble.enqueue(T3, &"t3_dash_strike")
	assert_eq(_bubble.lead_left(), 0.0)
	_bubble.step(0.1)
	assert_eq(_bubble.reveal().revealed, 3)
	assert_eq(fake.spoken.size(), 0)
