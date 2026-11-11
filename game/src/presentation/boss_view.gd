class_name BossView
extends Node2D
## Draws the boss (Story 3.1 placeholder body): its `name_signature` as a glyph line centred on
## BossController.body_center_px, shaken by the HP jitter level (D-S31-9), a `!` over it during a
## tell, and an inverted flash during the ROAR (E3). Presentation only (AD-05): reads the
## controller, never writes it. A child of the Arena (arena-local px), added by Main because
## arena/ may not reference presentation/. Real boss bodies replace it from 3.3.
## Story 3.2 (AC 5, D-S32-18, D-S32-22): while Patched, a `// patched` tag and a countdown bar
## (frames_left / 180) float above the body; the last boss hit's damage number shows over it for
## DAMAGE_NUMBER_FRAMES presentation frames, 1x unpatched, 2x patched. Reads only.
## Story 3.3 (D1, D-S33-16): an InfiniteLoopBody is drawn as its ring: 24 glyph cells at the segment
## positions (`{` / `}` alternating, the `;` at the junction: a lit, inverted cell while open, a
## plain `;` while closed, D-S33-24), and the `i = N` counter inside the ring above its centre
## (D-S33-23). The `// patched` stack is clamped to the arena's top edge (D3).
## Story 3.4 (G1, D-S34-12): the running attack's presentation, read through the BossAttack getters:
## a `!` one cell above each tell mark (Head Rush's origin, clamped into the arena), a `{` cell at each
## live hazard (the head), and an INK circle outline (Constrict's tell outline at nominal size, then
## the disc's edge while ACTIVE). INK/BG only. Reads only.
## Story 3.5 (Q1, D-S35-14): after the split both rings are drawn with the same glyphs (outer, then
## inner), each with its `;` at the junction; only the open ring's `;` is the lit (inverted) cell. The
## whole ring blinks during the Nested Loop TELL (blocks of the TELL countdown, read only), the Spit
## origin `;` gets an INK frame while the Spit glows, and every live projectile is an INK `;` cell.
## Story 5.1 (AC 1, 4-8, 11-13): a NullPointerBody is drawn as a ghost of two `null` lines only while
## visible_now(); its falling `null` column is drawn under it while it is alive, visible or not; the
## Patched stack and the damage number stay drawn while the ghost is hidden (a position hint, FR23).
## The hum (NullPointerHum) is a child of this view and follows the boss once per physics frame.
## Story 5.2 (D-S52-5): the ghost's attacks are drawn through the same getters: the attack's
## tell_glyph() (`*` on the mark itself, `!` above it), hazard_rects() as exact-size outlines, and
## the grab circle as an outline. Reads only.

const GLYPH_SCALE := 2
const TELL_MARK := "!"
## ROAR flash: inverted on alternate blocks of this many sim frames.
const FLASH_BLOCK := 6
const PATCHED_TAG := "// patched"
const TAG_SCALE := 1
## Countdown bar height in px, and the gap between the tag, the bar and the body line.
const BAR_HEIGHT := 2
const STACK_GAP := 2
## Damage number lifetime in presentation (_process) frames, not sim frames (D-S32-18).
const DAMAGE_NUMBER_FRAMES := 30
## Ring glyphs (Story 3.3).
const OPEN_BRACE := "{"
const CLOSE_BRACE := "}"
const SEMICOLON := ";"
const COUNTER_SCALE := 1
## The `i = N` counter sits this many tiles inside the ring's top (D-S33-23).
const COUNTER_INSET_TILES := 1.5
## Story 3.4: the Head Rush head glyph and the outline's segment count.
const HEAD_GLYPH := "{"
const OUTLINE_POINTS := 48
## Story 5.2 (D-S52-10): inset in px of the second outline of a live rect hazard (Null Rain ACTIVE).
const RECT_INSET := 3.0
## Story 5.1: the ghost's glyph lines (two rows of `null`) and the column glyph, at GHOST_SCALE.
const GHOST_LINES: PackedStringArray = ["null", "null"]
const TRAIL_GLYPH := "null"
const GHOST_SCALE := 1
## Story 3.8 (D1, D-S38-9): the reassembly swaps each ring glyph for its fixed-line character, and
## the fixed line's extra cells (27 vs 24) pop in, at this progress (INK/BG only: no alpha fade).
const REASSEMBLY_SWAP := 0.5

var boss: BossController
## Story 5.1: the Null Pointer's hum, a child built in _ready; silent unless the boss is one.
var hum: NullPointerHum

## The last boss hit's number and its scale; _number_left counts presentation frames down.
var _number_text: String = ""
var _number_scale: int = 1
var _number_left: int = 0


func _ready() -> void:
	hum = NullPointerHum.new()
	add_child(hum)
	EventBus.boss_roar_started.connect(_on_boss_event)
	EventBus.boss_hp_changed.connect(_on_boss_hp)
	EventBus.boss_defeated.connect(_on_boss_event)
	EventBus.hit_landed.connect(_on_hit_landed)


func _process(_delta: float) -> void:
	if _number_left > 0:
		_number_left -= 1
		queue_redraw()
	if boss != null and (boss.active or boss.state == BossController.BossState.DEFEATED):
		queue_redraw() # Story 3.8: the reassembly moves while the boss is inactive


## Story 5.1 (AC 11): the hum follows the boss once per physics frame, after SimClock's tick (an
## autoload, so it processes first). Reads only.
func _physics_process(_delta: float) -> void:
	if hum != null:
		hum.sync_to(boss)


func _exit_tree() -> void:
	if hum != null:
		hum.stop()


## Story 3.2: a boss hit sets the damage number (presentation only): shown for DAMAGE_NUMBER_FRAMES _process frames.
func _on_hit_landed(target: StringName, damage: int, state: int, _is_combo: bool, _pos: Vector2) -> void:
	if target != &"boss":
		return
	_number_text = str(maxi(damage, 0))
	_number_scale = damage_number_scale(state)
	_number_left = DAMAGE_NUMBER_FRAMES
	queue_redraw()


## The damage number being shown ("" when none).
func damage_number() -> String:
	return _number_text if _number_left > 0 else ""


func _draw() -> void:
	if boss == null or boss.def == null:
		return
	if boss is InfiniteLoopBody:
		_draw_ring(boss as InfiniteLoopBody)
		return
	if boss is NullPointerBody:
		_draw_ghost(boss as NullPointerBody)
		return
	var text: String = boss.def.name_signature
	var size := Vector2(GlyphFont.text_width(text, GLYPH_SCALE), GlyphFont.CELL * GLYPH_SCALE)
	if boss.state == BossController.BossState.DEFEATED:
		_draw_number(size) # review: the killing blow's number still shows after defeat
		return
	var top_left: Vector2 = line_top_left(boss.body_center_px, size) \
			+ Vector2(jitter_offset(boss.jitter_level(), SimClock.sim_frame), 0)
	if roar_flash_on(boss.state == BossController.BossState.ROAR, boss.frames_left):
		draw_rect(Rect2(top_left, size), Palette.INK)
		GlyphFont.draw_at(self, top_left, text, Palette.BG, GLYPH_SCALE)
	else:
		GlyphFont.draw_at(self, top_left, text, Palette.INK, GLYPH_SCALE)
	if boss.state == BossController.BossState.TELL:
		var mark_size := Vector2(GlyphFont.text_width(TELL_MARK, GLYPH_SCALE), size.y)
		GlyphFont.draw_at(self, top_left + Vector2((size.x - mark_size.x) / 2.0, -size.y), TELL_MARK, Palette.INK, GLYPH_SCALE)
	if boss.weak_window.is_patched():
		_draw_patched(top_left, size, boss.weak_window.frames_left)
	_draw_number(size)


## The Infinite Loop's ring (Story 3.3, D1, D2): the segment cells with the HP jitter and the ROAR
## flash, the `;`, the `i = N` counter, then the Patched stack and the damage number. After defeat
## the ring stays where it stopped, `;` closed, no flash (D-S33-17).
func _draw_ring(body: InfiniteLoopBody) -> void:
	var defeated: bool = body.state == BossController.BossState.DEFEATED
	var cell := Vector2(GlyphFont.CELL * GLYPH_SCALE, GlyphFont.CELL * GLYPH_SCALE)
	var jitter := Vector2(0.0 if defeated else jitter_offset(body.jitter_level(), SimClock.sim_frame), 0.0)
	var flash: bool = roar_flash_on(body.state == BossController.BossState.ROAR, body.frames_left)
	var open: bool = body.is_open() and not defeated
	var hidden: bool = not defeated and nested_flash_hidden(nested_telling(body), body.frames_left)
	if defeated and body.def.fixed_line != "":
		_draw_reassembly(body, cell)
		_draw_number(Vector2(0, 0))
		return
	if not hidden:
		var outer_open: bool = open and body.open_ring != InfiniteLoopBody.INNER
		for k: int in body.outer_segments():
			_draw_ring_cell(body.segment_px(k), ring_glyph(k), flash != (k == 0 and outer_open), cell, jitter)
		var inner_open: bool = open and body.open_ring == InfiniteLoopBody.INNER
		for k: int in body.inner_segment_count():
			_draw_ring_cell(body.inner_segment_px(k), ring_glyph(k), flash != (k == 0 and inner_open), cell, jitter)
	if not defeated and spit_glow_on(body):
		var glow_left: Vector2 = line_top_left(body.spit_origin_px(), cell) + jitter
		draw_rect(Rect2(glow_left - Vector2.ONE, cell + Vector2(2, 2)), Palette.INK, false, 1.0)
	if not defeated:
		for p: Vector2 in body.spit.projectile_positions():
			var p_left: Vector2 = line_top_left(p, cell)
			draw_rect(Rect2(p_left, cell), Palette.BG)
			GlyphFont.draw_at(self, p_left, SEMICOLON, Palette.INK, GLYPH_SCALE)
	var counter: String = counter_text(body.iteration)
	var counter_size := Vector2(GlyphFont.text_width(counter, COUNTER_SCALE), GlyphFont.CELL * COUNTER_SCALE)
	var counter_left: Vector2 = line_top_left(counter_centre(body.body_center_px, body.radius_px()), counter_size) + jitter
	GlyphFont.draw_at(self, counter_left, counter, Palette.INK, COUNTER_SCALE)
	if body.weak_window.is_patched() and not defeated:
		_draw_patched(counter_left, counter_size, body.weak_window.frames_left)
	if not defeated:
		_draw_attack(body.current_attack(), cell)
	_draw_number(Vector2(0, 0))


## The Null Pointer (Story 5.1): the falling column while alive, the ghost lines only while
## visible_now(), then the Patched stack (also while hidden, AC 8) and the damage number. Reads only.
func _draw_ghost(body: NullPointerBody) -> void:
	var line_h: float = GlyphFont.CELL * GHOST_SCALE
	var width: float = GlyphFont.text_width(GHOST_LINES[0], GHOST_SCALE)
	var size := Vector2(width, line_h * GHOST_LINES.size())
	var top_left: Vector2 = line_top_left(body.body_center_px, size)
	if body.state != BossController.BossState.DEFEATED:
		var trail_size := Vector2(GlyphFont.text_width(TRAIL_GLYPH, GHOST_SCALE), line_h)
		var area: Rect2 = Arena.play_area()
		for p: Vector2 in body.trail_positions():
			if trail_glyph_inside(p, trail_size, area):
				GlyphFont.draw_at(self, line_top_left(p, trail_size), TRAIL_GLYPH, Palette.INK, GHOST_SCALE)
	if body.visible_now():
		var jitter := Vector2(jitter_offset(body.jitter_level(), SimClock.sim_frame), 0.0)
		for row: int in GHOST_LINES.size():
			GlyphFont.draw_at(self, top_left + jitter + Vector2(0.0, row * line_h), GHOST_LINES[row], Palette.INK, GHOST_SCALE)
	if body.weak_window.is_patched() and body.state != BossController.BossState.DEFEATED:
		_draw_patched(top_left, Vector2(size.x, line_h), body.weak_window.frames_left)
	if body.state != BossController.BossState.DEFEATED: # Story 5.2: the attacks' tells and hazards
		_draw_attack(body.current_attack(), Vector2(GlyphFont.CELL * GLYPH_SCALE, GlyphFont.CELL * GLYPH_SCALE), body.state == BossController.BossState.ACTIVE)
	_draw_number(size)


## Story 5.1: true when a column glyph of `size` centred on `p` lies wholly inside `area`. Pure.
static func trail_glyph_inside(p: Vector2, size: Vector2, area: Rect2) -> bool:
	return area.encloses(Rect2(p - size / 2.0, size))


## Story 3.8 (D1, AC 7, D-S38-9): after the defeat every ring segment (outer, then inner) moves from
## where the ring stopped to its cell of the boss's fixed line over BossController.DEFEAT_FRAMES
## world ticks (sim progress, so the hit-stop and the pause freeze it). Segment k goes to cell k; the
## cells past the last segment pop in at REASSEMBLY_SWAP. The `;` stays a plain (closed) glyph.
func _draw_reassembly(body: InfiniteLoopBody, cell: Vector2) -> void:
	var line: String = body.def.fixed_line
	var progress: float = reassembly_progress(body.defeat_frames_elapsed)
	var line_centre: Vector2 = fixed_line_centre(body.body_center_px, line.length())
	var sources := PackedVector2Array()
	for k: int in body.outer_segments():
		sources.append(body.segment_px(k))
	for k: int in body.inner_segment_count():
		sources.append(body.inner_segment_px(k))
	var swapped: bool = progress >= REASSEMBLY_SWAP
	for k: int in sources.size():
		if k >= line.length():
			if not swapped: # a segment with no cell (never with 24 segments) leaves at the swap
				_draw_ring_cell(sources[k], ring_glyph(k), false, cell, Vector2.ZERO)
			continue
		var target: Vector2 = fixed_cell_centre(line_centre, k, line.length())
		var glyph: String = line[k] if swapped else ring_glyph(k)
		if glyph != " ":
			_draw_ring_cell(sources[k].lerp(target, progress), glyph, false, cell, Vector2.ZERO)
	if swapped:
		for k: int in range(sources.size(), line.length()):
			if line[k] != " ":
				_draw_ring_cell(fixed_cell_centre(line_centre, k, line.length()), line[k], false, cell, Vector2.ZERO)


## Story 3.8: 0..1 reassembly progress after `elapsed` defeat ticks. Pure.
static func reassembly_progress(elapsed: int) -> float:
	return clampf(float(elapsed) / float(BossController.DEFEAT_FRAMES), 0.0, 1.0)


## Story 3.8: the centre of the reassembled fixed line of `n` glyphs: the ring's centre, pushed in so
## the whole line stays inside the play area. Pure.
static func fixed_line_centre(ring_centre: Vector2, n: int) -> Vector2:
	var half: float = n * GlyphFont.CELL * GLYPH_SCALE / 2.0
	var area: Rect2 = Arena.play_area()
	var x: float = ring_centre.x
	if half * 2.0 <= area.size.x:
		x = clampf(x, area.position.x + half, area.end.x - half)
	return Vector2(x, ring_centre.y)


## Story 3.8: the centre of cell `index` of a fixed line of `n` glyphs centred on `line_centre`. Pure.
static func fixed_cell_centre(line_centre: Vector2, index: int, n: int) -> Vector2:
	return line_centre + Vector2((index - (n - 1) / 2.0) * GlyphFont.CELL * GLYPH_SCALE, 0.0)


## One ring glyph cell: inverted (INK block, BG glyph) when `lit`, plain INK otherwise.
func _draw_ring_cell(centre: Vector2, glyph: String, lit: bool, cell: Vector2, jitter: Vector2) -> void:
	var top_left: Vector2 = line_top_left(centre, cell) + jitter
	if lit:
		draw_rect(Rect2(top_left, cell), Palette.INK)
		GlyphFont.draw_at(self, top_left, glyph, Palette.BG, GLYPH_SCALE)
	else:
		GlyphFont.draw_at(self, top_left, glyph, Palette.INK, GLYPH_SCALE)


## Story 3.4 (G1): the running attack's tell marks, hazard cells and outline. Reads only.
func _draw_attack(attack: BossAttack, cell: Vector2, live: bool = false) -> void:
	if attack == null:
		return
	var glyph: String = attack.tell_glyph()
	for p: Vector2 in attack.tell_marks():
		GlyphFont.draw_at(self, line_top_left(glyph_mark_centre(p, glyph == TELL_MARK), cell), glyph, Palette.INK, GLYPH_SCALE)
	# Story 5.2 (D-S52-5, D-S52-10): rect hazards are drawn as outlines at their exact size (a double
	# outline while ACTIVE); their centres get no glyph.
	var rects: Array[Rect2] = attack.hazard_rects()
	for r: Rect2 in rects:
		draw_rect(r, Palette.INK, false, 1.0)
		if live:
			draw_rect(r.grow(-RECT_INSET), Palette.INK, false, 1.0)
	if rects.is_empty():
		for p: Vector2 in attack.hazard_positions():
			var top_left: Vector2 = line_top_left(p, cell)
			draw_rect(Rect2(top_left, cell), Palette.BG)
			GlyphFont.draw_at(self, top_left, HEAD_GLYPH, Palette.INK, GLYPH_SCALE)
	var outline: Vector3 = attack.outline_circle()
	if outline.z > 0.0:
		draw_arc(Vector2(outline.x, outline.y), outline.z, 0.0, TAU, OUTLINE_POINTS, Palette.INK, 1.0)


func _draw_number(size: Vector2) -> void:
	if _number_left > 0:
		var num_size := Vector2(GlyphFont.text_width(_number_text, _number_scale), GlyphFont.CELL * _number_scale)
		var num_left: Vector2 = line_top_left(boss.body_center_px, num_size) + Vector2(0, size.y + STACK_GAP)
		GlyphFont.draw_at(self, num_left, _number_text, Palette.INK, _number_scale)


## `// patched` and the countdown bar, stacked above the body line (over the tell mark's row).
func _draw_patched(top_left: Vector2, size: Vector2, frames_left: int) -> void:
	var bar_full: float = float(GlyphFont.text_width(PATCHED_TAG, TAG_SCALE))
	var centre_x: float = top_left.x + size.x / 2.0
	var tops: Vector2 = patched_stack_tops(top_left.y, size.y)
	var tag_top: float = tops.x
	var bar_top: float = tops.y
	var left: float = roundf(centre_x - bar_full / 2.0)
	GlyphFont.draw_at(self, Vector2(left, tag_top), PATCHED_TAG, Palette.INK, TAG_SCALE)
	draw_rect(Rect2(left, bar_top, bar_full, BAR_HEIGHT), Palette.INK, false, 1.0)
	draw_rect(Rect2(left, bar_top, roundf(bar_full * bar_fraction(frames_left)), BAR_HEIGHT), Palette.INK)


func _on_boss_event(_value: Variant) -> void:
	queue_redraw()


func _on_boss_hp(hp: int, max_hp: int) -> void:
	if hp >= max_hp: # fight (re)start: drop the previous fight's number
		_number_left = 0
		_number_text = ""
	queue_redraw()


## Top y of the `// patched` tag (x) and of its bar (y), stacked above a line whose top is
## `line_top` and height `line_h` (over the tell mark's row), pushed down as one block so the tag
## never leaves the arena's top edge (Story 3.3, D3). Pure.
static func patched_stack_tops(line_top: float, line_h: float) -> Vector2:
	var bar_top: float = line_top - line_h - STACK_GAP - BAR_HEIGHT
	var tag_top: float = bar_top - STACK_GAP - GlyphFont.CELL * TAG_SCALE
	var push: float = maxf(0.0, Arena.play_area().position.y - tag_top)
	return Vector2(tag_top + push, bar_top + push)


## The glyph of ring segment `k` (Story 3.3, D1): the `;` at the junction (k = 0), then `}` and `{`
## alternating. Pure.
static func ring_glyph(k: int) -> String:
	if k == 0:
		return SEMICOLON
	return CLOSE_BRACE if k % 2 == 1 else OPEN_BRACE


## Centre of a tell `!` (Story 3.4, D-S34-12): one cell above `anchor`, clamped so the whole cell
## stays inside the play area. Pure.
static func tell_mark_centre(anchor: Vector2) -> Vector2:
	return glyph_mark_centre(anchor, true)


## Story 5.2 (D-S52-5): centre of a tell glyph: one cell above `anchor` for the `!` (`above`), on
## `anchor` itself otherwise (Pointer Grab's `*`), clamped so the whole cell stays in the play area. Pure.
static func glyph_mark_centre(anchor: Vector2, above: bool) -> Vector2:
	var half: float = GlyphFont.CELL * GLYPH_SCALE / 2.0
	var area: Rect2 = Arena.play_area()
	var p: Vector2 = anchor - Vector2(0.0, Const.TILE_PX) if above else anchor
	return Vector2(clampf(p.x, area.position.x + half, area.end.x - half), clampf(p.y, area.position.y + half, area.end.y - half))


## Story 3.5 (D-S35-14): true while the boss is in the Nested Loop's TELL. Reads only.
static func nested_telling(body: InfiniteLoopBody) -> bool:
	return body.state == BossController.BossState.TELL and body.current != null \
			and body.current.id == InfiniteLoopBody.NESTED_LOOP_ID


## Story 3.5 (D-S35-14): the ring is hidden on alternate FLASH_BLOCK blocks of the Nested Loop TELL
## countdown (the blink), shown otherwise. Pure.
static func nested_flash_hidden(telling: bool, frames_left: int) -> bool:
	if not telling:
		return false
	@warning_ignore("integer_division")
	return (frames_left / FLASH_BLOCK) % 2 == 1


## Story 3.5 (D-S35-9): true while the Spit's origin `;` glows (its last spit_tell_frames ticks). Reads only.
static func spit_glow_on(body: InfiniteLoopBody) -> bool:
	return body.spit.glowing()


## The loop counter text (AC 1). Pure.
static func counter_text(iteration: int) -> String:
	return "i = %d" % iteration


## Centre of the `i = N` counter: inside the ring, COUNTER_INSET_TILES below its top (D-S33-23). Pure.
static func counter_centre(centre: Vector2, ring_radius_px: float) -> Vector2:
	return centre - Vector2(0.0, ring_radius_px - COUNTER_INSET_TILES * Const.TILE_PX)


## Countdown bar fill (AC 5): frames_left / PATCHED_FRAMES, clamped to 0..1. Pure.
static func bar_fraction(frames_left: int) -> float:
	return clampf(float(frames_left) / float(WeakWindowTracker.PATCHED_FRAMES), 0.0, 1.0)


## Damage number scale (D-S32-18): 2x for a Patched hit, 1x otherwise. Pure.
static func damage_number_scale(state: int) -> int:
	return 2 if state == DamageState.Kind.PATCHED else 1


## Top-left pixel of a glyph line of `size` centred on `centre`, on the pixel grid. Pure.
static func line_top_left(centre: Vector2, size: Vector2) -> Vector2:
	return (centre - size / 2.0).round()


## Horizontal jitter in px (D-S31-9): `level` px, sign from sin(sim_frame), so it is deterministic
## and never touches the sim RNG. Pure.
static func jitter_offset(level: int, frame: int) -> float:
	return float(level) * signf(sin(float(frame)))


## True on the inverted blocks of the ROAR flash. Pure.
static func roar_flash_on(roaring: bool, frames_left: int) -> bool:
	if not roaring:
		return false
	@warning_ignore("integer_division")
	return (frames_left / FLASH_BLOCK) % 2 == 0
