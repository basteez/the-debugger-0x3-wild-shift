class_name WatchOverlay
extends Node2D
## The Watch read-outs (Story 5.4, AC 8, 9, D-S54-7, D-S54-8): while Watch is held, two text lines
## float above the boss: the next attack's name (`NEXT: <id>` for the attack in TELL or ACTIVE,
## `NEXT: ?` while no attack is picked yet) and its bits (`drop X  weak A B`: the bit it drops at
## Harvest and the current phase's weak window). A child of the Arena (arena-local pixels), added by
## Main only when FeatureFlags.watch is on (loaded by path, AD-12). Presentation only (AD-05): reads
## the skill's held state and the boss's def, state, current attack and weak window, never writes
## them, draws no RNG and reads no decoy getter (AC 11, D-S54-1: decoys stay hidden in Watch).
## INK on a BG plate, so it stays legible over the arena glyphs.

const SCALE := 1
const NEXT_PREFIX := "NEXT: "
const UNKNOWN := "?"
## Gap in px between the body circle's top and the lower line, and between the two lines.
const GAP_PX := 4.0
const PLATE_PAD_PX := 1.0

## Injected by Main (read only). Null = nothing is drawn.
var skill: FightSkill
var boss: BossController

## The lines drawn last, so redraws happen only on a change.
var _shown: PackedStringArray = PackedStringArray()


func _process(_delta: float) -> void:
	var lines: PackedStringArray = current_lines()
	if lines != _shown:
		_shown = lines
		queue_redraw()


## The lines to draw now (top first); empty while Watch is not held or there is no boss.
func current_lines() -> PackedStringArray:
	if skill == null or not skill.is_active():
		return PackedStringArray()
	return lines_for(boss)


## Pure: the read-out lines for a boss (top first): the next-attack line (when there is one) and the
## bit line. Empty for no boss, no def, or a defeated boss.
static func lines_for(p_boss: BossController) -> PackedStringArray:
	var out := PackedStringArray()
	if p_boss == null or p_boss.def == null or p_boss.state == BossController.BossState.DEFEATED:
		return out
	var next: String = next_attack_label(p_boss)
	if next != "":
		out.append(next)
	out.append(bit_label(p_boss))
	return out


## Pure (D-S54-7): `NEXT: <id>` for the attack being telegraphed or running (TELL or ACTIVE);
## `NEXT: ?` in any other live state of a phase that has attacks (GAP, RECOVERY, ROAR: the next pick
## is not drawn yet, and Watch never draws the RNG early); "" when no attack is planned (an empty
## phase pool, no def, or DEFEATED).
static func next_attack_label(p_boss: BossController) -> String:
	if p_boss == null or p_boss.def == null or p_boss.state == BossController.BossState.DEFEATED:
		return ""
	var s: BossController.BossState = p_boss.state
	if (s == BossController.BossState.TELL or s == BossController.BossState.ACTIVE) and p_boss.current != null:
		return NEXT_PREFIX + String(p_boss.current.id)
	var phase: int = p_boss.phase_index
	if phase < 0 or phase >= p_boss.def.phases.size() or p_boss.def.phases[phase].attack_pool.is_empty():
		return ""
	return NEXT_PREFIX + UNKNOWN


## Pure (D-S54-8): the boss's bits: its drop bit and the current phase's weak window as glyphs.
static func bit_label(p_boss: BossController) -> String:
	if p_boss == null or p_boss.def == null:
		return ""
	var weak: Vector2i = p_boss.current_weak_window()
	return "drop %s  weak %s %s" % [
		Register.glyph_of(p_boss.def.drop_bit), Register.glyph_of(weak.x), Register.glyph_of(weak.y)]


func _draw() -> void:
	var lines: PackedStringArray = current_lines()
	if lines.is_empty() or boss == null:
		return
	var line_h: float = float(GlyphFont.CELL * SCALE)
	var area: Rect2 = Arena.play_area()
	var bottom: float = boss.body_center_px.y - boss.body_radius_px() - GAP_PX
	var top: float = bottom - lines.size() * line_h - (lines.size() - 1) * GAP_PX
	top = clampf(top, area.position.y, area.end.y - lines.size() * line_h)
	for i: int in lines.size():
		var text: String = lines[i]
		var w: float = float(GlyphFont.text_width(text, SCALE))
		var x: float = clampf(boss.body_center_px.x - w / 2.0, area.position.x, area.end.x - w)
		var y: float = top + i * (line_h + GAP_PX)
		draw_rect(Rect2(x - PLATE_PAD_PX, y - PLATE_PAD_PX, w + 2.0 * PLATE_PAD_PX, line_h + 2.0 * PLATE_PAD_PX), Palette.BG)
		GlyphFont.draw_at(self, Vector2(x, y), text, Palette.INK, SCALE)
