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

var boss: BossController

## The last boss hit's number and its scale; _number_left counts presentation frames down.
var _number_text: String = ""
var _number_scale: int = 1
var _number_left: int = 0


func _ready() -> void:
	EventBus.boss_roar_started.connect(_on_boss_event)
	EventBus.boss_hp_changed.connect(_on_boss_hp)
	EventBus.boss_defeated.connect(_on_boss_event)
	EventBus.hit_landed.connect(_on_hit_landed)


func _process(_delta: float) -> void:
	if _number_left > 0:
		_number_left -= 1
		queue_redraw()
	if boss != null and boss.active:
		queue_redraw()


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


## One ring glyph cell: inverted (INK block, BG glyph) when `lit`, plain INK otherwise.
func _draw_ring_cell(centre: Vector2, glyph: String, lit: bool, cell: Vector2, jitter: Vector2) -> void:
	var top_left: Vector2 = line_top_left(centre, cell) + jitter
	if lit:
		draw_rect(Rect2(top_left, cell), Palette.INK)
		GlyphFont.draw_at(self, top_left, glyph, Palette.BG, GLYPH_SCALE)
	else:
		GlyphFont.draw_at(self, top_left, glyph, Palette.INK, GLYPH_SCALE)


## Story 3.4 (G1): the running attack's tell marks, hazard cells and outline. Reads only.
func _draw_attack(attack: BossAttack, cell: Vector2) -> void:
	if attack == null:
		return
	for p: Vector2 in attack.tell_marks():
		GlyphFont.draw_at(self, line_top_left(tell_mark_centre(p), cell), TELL_MARK, Palette.INK, GLYPH_SCALE)
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
	var half: float = GlyphFont.CELL * GLYPH_SCALE / 2.0
	var area: Rect2 = Arena.play_area()
	var p: Vector2 = anchor - Vector2(0.0, Const.TILE_PX)
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
