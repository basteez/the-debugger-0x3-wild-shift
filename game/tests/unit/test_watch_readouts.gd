extends GutTest
## Story 5.4 (AC 7-11, 19, 23): the Watch read-outs. Next-attack label (TELL / ACTIVE name, `NEXT: ?`
## while no attack is picked, none when defeated or with no pool), bit label (drop bit and weak
## window glyphs), the overlay and the register panel's weak-window marks only while held, the real
## ghost revealed by the held state, and decoys outside every reveal path (AC 11).

const NP_DEF: BossDef = preload("res://data/bosses/null_pointer/boss_def.tres")
const OVERLAY_PATH := "res://src/skills/watch/watch_overlay.gd"
const SKILL_PATH := "res://src/skills/watch/watch_skill.gd"
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT
const DECOY_GETTERS: Array[String] = [
	"decoy_positions", "planned_positions", "recast_flicker_positions", "dispel_flash_positions",
	"decoys", "planned", "recast_spots", "flash_spots", "decoy_hit",
]

var _ctx: SimContext


## A FightSkill stand-in the views read.
class FakeSkill:
	extends FightSkill
	var on: bool = false

	func is_active() -> bool:
		return on


func before_each() -> void:
	_ctx = SimContext.new()
	_ctx.reseed(5455)
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0


func after_each() -> void:
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0


func _overlay_script() -> GDScript:
	return load(OVERLAY_PATH) as GDScript


func _np() -> NullPointerBody:
	var b := NullPointerBody.new()
	assert_true(b.setup(NP_DEF, null, null))
	b.reset_for_fight()
	return b


## Ticks until the boss is in `state` (at most `limit` ticks).
func _until(b: BossController, state: BossController.BossState, limit: int = 400) -> void:
	for i: int in limit:
		if b.state == state:
			return
		b.tick(_ctx)
	assert_eq(b.state, state, "reached %s" % BossController.BossState.keys()[state])


# --- AC 8: next attack label ---

func test_gap_reads_next_unknown() -> void:
	var b := _np()
	assert_eq(b.state, BossController.BossState.GAP)
	assert_eq(_overlay_script().next_attack_label(b), "NEXT: ?", "no pick before GAP ends (D-S54-7)")


func test_tell_and_active_show_the_attack_id() -> void:
	var b := _np()
	_until(b, BossController.BossState.TELL)
	assert_eq(_overlay_script().next_attack_label(b), "NEXT: " + String(b.current.id))
	_until(b, BossController.BossState.ACTIVE)
	assert_eq(_overlay_script().next_attack_label(b), "NEXT: " + String(b.current.id))


func test_label_reading_draws_no_rng() -> void:
	var b := _np()
	var before: int = _ctx.rng.state
	for i: int in 10:
		_overlay_script().lines_for(b)
	assert_eq(_ctx.rng.state, before)


func test_defeated_shows_nothing() -> void:
	var b := _np()
	b.take_hit(NP_DEF.max_hp)
	SimClock._pending_hitstop = 0
	assert_eq(b.state, BossController.BossState.DEFEATED)
	assert_eq(_overlay_script().next_attack_label(b), "")
	assert_eq(_overlay_script().lines_for(b), PackedStringArray())


func test_empty_pool_shows_no_attack_name() -> void:
	var def := BossDef.new()
	def.boss_id = &"empty"
	def.name_signature = "empty"
	def.max_hp = 10
	def.drop_bit = L
	var phase := PhaseDef.new()
	phase.weak_window = Vector2i(A, D)
	def.phases = [phase] as Array[PhaseDef]
	var b := BossController.new()
	assert_true(b.setup(def, null, null))
	b.reset_for_fight()
	assert_eq(_overlay_script().next_attack_label(b), "", "no attack planned")
	assert_eq(_overlay_script().lines_for(b), PackedStringArray(["drop L  weak A D"]))


func test_no_boss_shows_nothing() -> void:
	assert_eq(_overlay_script().next_attack_label(null), "")
	assert_eq(_overlay_script().bit_label(null), "")
	assert_eq(_overlay_script().lines_for(null), PackedStringArray())


# --- AC 9: bit label ---

func test_bit_label_is_drop_bit_and_weak_window() -> void:
	var b := _np()
	var w: Vector2i = NP_DEF.phases[0].weak_window
	var want: String = "drop %s  weak %s %s" % [Register.glyph_of(NP_DEF.drop_bit), Register.glyph_of(w.x), Register.glyph_of(w.y)]
	assert_eq(_overlay_script().bit_label(b), want)
	assert_eq(Register.glyph_of(NP_DEF.drop_bit), "N", "the Null Pointer drops NULL")
	b.take_hit(int(NP_DEF.max_hp * 0.5))
	SimClock._pending_hitstop = 0
	var w2: Vector2i = b.current_weak_window()
	assert_true(_overlay_script().bit_label(b).ends_with("weak %s %s" % [Register.glyph_of(w2.x), Register.glyph_of(w2.y)]),
			"follows the current phase")


# --- Overlay only while held ---

func test_overlay_lines_only_while_held() -> void:
	var overlay: Node2D = _overlay_script().new()
	var skill := FakeSkill.new()
	overlay.set(&"skill", skill)
	overlay.set(&"boss", _np())
	add_child_autofree(overlay)
	assert_eq(overlay.call(&"current_lines"), PackedStringArray(), "released: nothing")
	skill.on = true
	assert_eq((overlay.call(&"current_lines") as PackedStringArray).size(), 2)
	assert_eq((overlay.call(&"current_lines") as PackedStringArray)[0], "NEXT: ?")
	skill.on = false
	assert_eq(overlay.call(&"current_lines"), PackedStringArray())


func test_overlay_without_skill_or_boss_draws_nothing() -> void:
	var overlay: Node2D = _overlay_script().new()
	add_child_autofree(overlay)
	assert_eq(overlay.call(&"current_lines"), PackedStringArray())
	var skill := FakeSkill.new()
	skill.on = true
	overlay.set(&"skill", skill)
	assert_eq(overlay.call(&"current_lines"), PackedStringArray(), "no boss")


# --- AC 10: register panel marks ---

func test_mark_cells_follow_the_weak_window() -> void:
	var ring := PackedInt32Array([A, D, L])
	var cells: Array[Vector2i] = RegisterPanel.watch_mark_cells(ring, Vector2i(D, L))
	var high: int = RegisterPanel.BYTE_BITS - Register.MAX_BITS
	assert_eq(cells, [Vector2i(RegisterPanel.LEFT_COL + high + 1, RegisterPanel.BYTE_ROW),
			Vector2i(RegisterPanel.LEFT_COL + high + 2, RegisterPanel.BYTE_ROW)] as Array[Vector2i])
	assert_eq(ring, PackedInt32Array([A, D, L]), "the ring is never changed")


func test_mark_cells_skip_unowned_bits_and_zero() -> void:
	var ring := PackedInt32Array([A, D])
	assert_eq(RegisterPanel.watch_mark_cells(ring, Vector2i(D, N)).size(), 1, "NULL not owned yet")
	assert_eq(RegisterPanel.watch_mark_cells(ring, Vector2i.ZERO).size(), 0)


func test_panel_marks_only_while_held() -> void:
	var panel := RegisterPanel.new()
	add_child_autofree(panel)
	assert_eq(panel.current_weak_window(), Vector2i.ZERO, "Watch cut: no marks")
	var skill := FakeSkill.new()
	panel.watch_skill = skill
	panel.weak_window_source = func() -> Vector2i: return Vector2i(A, D)
	assert_eq(panel.current_weak_window(), Vector2i.ZERO, "released: no marks")
	skill.on = true
	assert_eq(panel.current_weak_window(), Vector2i(A, D))
	skill.on = false
	assert_eq(panel.current_weak_window(), Vector2i.ZERO, "release removes every mark")


# --- AC 7: the real ghost is revealed by the held state ---

func test_held_state_reveals_the_real_ghost() -> void:
	var b := _np()
	assert_false(b.visible_now())
	_ctx.watch_held = true
	b.tick(_ctx)
	assert_true(b.visible_now(), "Watch held: the ghost shows")
	_ctx.watch_held = false
	b.tick(_ctx)
	assert_false(b.visible_now(), "released: hidden again (GAP)")


# --- AC 11, 19: decoys stay out of every Watch path ---

func test_decoys_do_not_change_under_watch_and_stay_hidden() -> void:
	var b := _np()
	b.decoys.append(Vector2i(5000, 5000))
	_ctx.watch_held = true
	b.tick(_ctx)
	assert_eq(b.decoys, [Vector2i(5000, 5000)] as Array[Vector2i], "Watch writes no decoy")
	var lines: PackedStringArray = _overlay_script().lines_for(b)
	for line: String in lines:
		assert_false(line.contains("null"), "no decoy read-out")


func test_watch_sources_read_no_decoy_getter() -> void:
	for path: String in [SKILL_PATH, OVERLAY_PATH, "res://src/presentation/boss_view.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		assert_ne(text, "", path)
		if path == "res://src/presentation/boss_view.gd":
			assert_false(text.contains("watch"), "boss_view.gd has no Watch branch")
			continue
		var code: String = _code_only(text)
		for getter: String in DECOY_GETTERS:
			assert_false(code.contains(getter), "%s never reads %s" % [path.get_file(), getter])
		assert_false(code.contains("randi") or code.contains("randf") or code.contains(".rng"),
				"%s draws no RNG" % path.get_file())


func test_skill_writes_only_the_gate() -> void:
	var code: String = _code_only(FileAccess.get_file_as_string(SKILL_PATH))
	assert_false(code.contains("boss"), "the skill never touches the boss")
	assert_false(code.contains("ctx.watch_held ="), "SimClock copies the gate, not the skill")


## The source without comment lines (doc comments may name the getters to say they are not read).
static func _code_only(text: String) -> String:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)
