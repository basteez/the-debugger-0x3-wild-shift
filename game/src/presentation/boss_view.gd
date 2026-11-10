class_name BossView
extends Node2D
## Draws the boss (Story 3.1 placeholder body): its `name_signature` as a glyph line centred on
## BossController.body_center_px, shaken by the HP jitter level (D-S31-9), a `!` over it during a
## tell, and an inverted flash during the ROAR (E3). Presentation only (AD-05): reads the
## controller, never writes it. A child of the Arena (arena-local px), added by Main because
## arena/ may not reference presentation/. Real boss bodies replace it from 3.3.

const GLYPH_SCALE := 2
const TELL_MARK := "!"
## ROAR flash: inverted on alternate blocks of this many sim frames.
const FLASH_BLOCK := 6

var boss: BossController


func _ready() -> void:
	EventBus.boss_roar_started.connect(_on_boss_event)
	EventBus.boss_hp_changed.connect(_on_boss_hp)
	EventBus.boss_defeated.connect(_on_boss_event)


func _process(_delta: float) -> void:
	if boss != null and boss.active:
		queue_redraw()


func _draw() -> void:
	if boss == null or boss.def == null or boss.state == BossController.BossState.DEFEATED:
		return
	var text: String = boss.def.name_signature
	var size := Vector2(GlyphFont.text_width(text, GLYPH_SCALE), GlyphFont.CELL * GLYPH_SCALE)
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


func _on_boss_event(_value: Variant) -> void:
	queue_redraw()


func _on_boss_hp(_hp: int, _max_hp: int) -> void:
	queue_redraw()


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
