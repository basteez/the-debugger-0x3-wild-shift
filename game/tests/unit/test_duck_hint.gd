extends GutTest
## Story 4.4 AC 1, 2, 15 (Group A, E): the hint template text and id for every window, the text for
## every phase of every boss in the data (read from the BossDefs), the Infinite Loop's phase-3 ring
## cases driven through open_ring / next_ring, and a catalogue entry plus a clip for every window
## the data can show (the set derived from the data, not hard-coded).

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT
const BOSS_DIR := "res://data/bosses"
const LINES: DuckLinesDef = preload("res://data/duck/duck_lines.tres")
const CLIPS: DuckClipsDef = preload("res://data/duck/duck_clips.tres")

var _arena: Arena


func after_each() -> void:
	if is_instance_valid(_arena):
		_arena.free()


## Every boss_def.tres path in the data (data/bosses/<dir>/boss_def.tres that exists).
static func boss_def_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for dir: String in DirAccess.get_directories_at(BOSS_DIR):
		var path: String = BOSS_DIR.path_join(dir).path_join("boss_def.tres")
		if ResourceLoader.exists(path):
			out.append(path)
	return out


## Every BossDef in the data.
static func boss_defs() -> Array[BossDef]:
	var out: Array[BossDef] = []
	for path: String in boss_def_paths():
		out.append(load(path) as BossDef)
	return out


## Every window any boss phase can show, from the data.
static func all_windows() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for def: BossDef in boss_defs():
		for w: Vector2i in DuckHint.windows_of(def):
			if not out.has(w):
				out.append(w)
	return out


# --- AC 1: text and id ---

func test_window_text_uses_the_register_glyphs_and_the_arrow() -> void:
	assert_eq(DuckHint.window_text(Vector2i(D, A)), "Quack. Weak window: D→A.")
	assert_eq(DuckHint.window_text(Vector2i(A, D)), "Quack. Weak window: A→D.")
	assert_eq(DuckHint.window_text(Vector2i(L, N)), "Quack. Weak window: L→N.")
	assert_eq(DuckHint.window_text(Vector2i(0, 9)), "Quack. Weak window: ?→?.", "unknown bits fall back to glyph_of's ?")
	for x: int in [A, D, L, N]:
		for y: int in [A, D, L, N]:
			var text: String = DuckHint.window_text(Vector2i(x, y))
			assert_eq(text, "Quack. Weak window: %s→%s." % [Register.glyph_of(x), Register.glyph_of(y)])
			var def := DuckLineDef.new()
			def.id = DuckHint.line_id_for(Vector2i(x, y))
			def.text = text
			assert_eq(def.validate(), PackedStringArray(), "%s fits the bubble" % text)


func test_line_id_for() -> void:
	assert_eq(DuckHint.line_id_for(Vector2i(A, D)), &"hint_a_d")
	assert_eq(DuckHint.line_id_for(Vector2i(D, A)), &"hint_d_a")
	assert_eq(DuckHint.line_id_for(Vector2i(L, N)), &"hint_l_n")
	assert_true(DuckHint.is_hint_id(&"hint_a_d"))
	assert_false(DuckHint.is_hint_id(&"t1_shift"))


func test_the_font_draws_the_arrow() -> void:
	assert_true(GlyphFont.font().has_char(DuckHint.ARROW.unicode_at(0)), "U+2192 in the pixel font (D-S44-8)")


# --- AC 2: every phase of every boss ---

func test_windows_of_reads_every_phase() -> void:
	var il := load(Arena.INFINITE_LOOP_DEF_PATH) as BossDef
	assert_eq(DuckHint.windows_of(il), [Vector2i(A, D), Vector2i(D, A)] as Array[Vector2i])
	assert_eq(DuckHint.windows_of(null), [] as Array[Vector2i])


func test_hint_text_matches_each_phase_window_of_every_boss() -> void:
	var paths: PackedStringArray = boss_def_paths()
	assert_gt(paths.size(), 0, "boss defs found")
	for path: String in paths:
		var def := load(path) as BossDef
		_arena = Arena.new()
		_arena.enter_fight(Register.fight_start_for_boss(0), false, path)
		var boss: BossController = _arena.boss
		assert_not_null(boss, String(def.boss_id))
		if boss == null:
			_arena.free()
			continue
		for i: int in def.phases.size():
			boss.phase_index = i
			var w: Vector2i = def.phases[i].weak_window
			assert_eq(DuckHint.window_text(boss.current_weak_window()), DuckHint.window_text(w), "%s phase %d" % [def.boss_id, i + 1])
		_arena.free()


func test_infinite_loop_phases_and_ring_cases() -> void:
	_arena = Arena.new()
	_arena.enter_fight(Register.fight_start_for_boss(0), false, Arena.INFINITE_LOOP_DEF_PATH)
	var b := _arena.boss as InfiniteLoopBody
	assert_not_null(b)
	b.phase_index = 0
	assert_eq(DuckHint.window_text(b.current_weak_window()), "Quack. Weak window: A→D.", "phase 1")
	b.phase_index = 1
	assert_eq(DuckHint.window_text(b.current_weak_window()), "Quack. Weak window: D→A.", "phase 2")
	b.phase_index = InfiniteLoopBody.PHASE_3
	b.split_rings()
	b.open_ring = InfiniteLoopBody.OUTER
	assert_eq(DuckHint.window_text(b.current_weak_window()), "Quack. Weak window: A→D.", "phase 3, outer open")
	b.open_ring = InfiniteLoopBody.INNER
	assert_eq(DuckHint.window_text(b.current_weak_window()), "Quack. Weak window: D→A.", "phase 3, inner open")
	b.open_ring = -1
	b.next_ring = InfiniteLoopBody.OUTER
	assert_eq(DuckHint.window_text(b.current_weak_window()), "Quack. Weak window: A→D.", "phase 3, outer next")
	b.next_ring = InfiniteLoopBody.INNER
	assert_eq(DuckHint.window_text(b.current_weak_window()), "Quack. Weak window: D→A.", "phase 3, inner next")


# --- AC 15: catalogue entries and clips ---

func test_every_window_in_the_data_has_an_entry_and_a_clip() -> void:
	var windows: Array[Vector2i] = all_windows()
	assert_gt(windows.size(), 0)
	for w: Vector2i in windows:
		var id: StringName = DuckHint.line_id_for(w)
		var entry: DuckLineDef = LINES.find(id)
		assert_not_null(entry, "catalogue entry %s" % id)
		if entry == null:
			continue
		assert_eq(entry.text, DuckHint.window_text(w), "the entry text is the template (%s)" % id)
		var clip: DuckClipDef = CLIPS.find(id)
		assert_not_null(clip, "clip %s" % id)
		if clip != null:
			assert_true(clip.matches_text(" ".join(DuckBubble.wrap(entry.text))), "clip matches %s" % id)


func test_no_orphan_hint_entries() -> void:
	var windows: Array[Vector2i] = all_windows()
	var ids: Array[StringName] = []
	for w: Vector2i in windows:
		ids.append(DuckHint.line_id_for(w))
	for entry: DuckLineDef in LINES.entries:
		if DuckHint.is_hint_id(entry.id):
			assert_true(ids.has(entry.id), "%s matches a window in the data" % entry.id)
