class_name DuckHint
extends RefCounted
## The duck's hint template (Story 4.4, FR46, GDD "Duck (hint system)", D-S44-7, D-S44-8):
## "Quack. Weak window: X→Y." with the weak window's two bit glyphs from Register.glyph_of. One
## template; the catalogue holds one entry per window that occurs in the boss data (generated from
## this template, checked by tests) so the pre-render fallback has a clip for each. Pure, no tree.

const PREFIX := "Quack. Weak window: "
## U+2192: the font draws it (RegisterPanel.JK_LABEL uses it too); DuckLineDef allows it.
const ARROW := "→"
const ID_PREFIX := "hint_"


## The hint text for weak window `w` (first, second), e.g. "Quack. Weak window: D→A.". Pure.
static func window_text(w: Vector2i) -> String:
	return "%s%s%s%s." % [PREFIX, Register.glyph_of(w.x), ARROW, Register.glyph_of(w.y)]


## The catalogue id of the hint for `w`, e.g. &"hint_d_a". Pure.
static func line_id_for(w: Vector2i) -> StringName:
	return StringName("%s%s_%s" % [ID_PREFIX, Register.glyph_of(w.x).to_lower(), Register.glyph_of(w.y).to_lower()])


## True when `id` names a hint entry (the template counts once in the line budget, D-039). Pure.
static func is_hint_id(id: StringName) -> bool:
	return String(id).begins_with(ID_PREFIX)


## Every weak window a boss can show in `def`: each phase's data window, plus its reverse for the
## Infinite Loop's phase 3 (the inner ring, InfiniteLoopBody.current_weak_window). Sorted, unique. Pure.
static func windows_of(def: BossDef) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if def == null:
		return out
	for i: int in def.phases.size():
		var w: Vector2i = def.phases[i].weak_window
		if not out.has(w):
			out.append(w)
		if def.boss_id == DuckDirector.INFINITE_LOOP_ID and i == InfiniteLoopBody.PHASE_3:
			var r := Vector2i(w.y, w.x)
			if not out.has(r):
				out.append(r)
	out.sort()
	return out
