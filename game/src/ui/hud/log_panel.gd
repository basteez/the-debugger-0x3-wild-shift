class_name LogPanel
extends Node2D
## The HUD console log (Story 2.8 AC3, FR57): a fixed ring of Hud.LOG_LINES lines drawn at 1x in
## HUD rows 39-44, under the `── console ──` header that HudFrame draws on row 38. Oldest first,
## newest at the bottom; the panel fills top-down like a console, then scrolls. Gameplay
## presentation driven by EventBus (not the Log autoload): it reads only signal arguments (AD-05).
## Story 2.9: EventBus.player_damaged appends `WARN: hp--` (D-S29-9).
## Story 3.2 (FR27, D-S32-18): the line depends on the damage state; resisted lines are dithered.

const SCALE := 1

var _ring: PackedStringArray = PackedStringArray()
## Index of the oldest line in the ring.
var _head: int = 0
var _count: int = 0
## Parallel to _ring: true for a line drawn under the 50% checker dither (resisted hits).
var _dithered: Array[bool] = []


func _init() -> void:
	_ring.resize(Hud.LOG_LINES)
	_dithered.resize(Hud.LOG_LINES)
	_dithered.fill(false)


func _enter_tree() -> void:
	if not EventBus.hit_landed.is_connected(_on_hit_landed):
		EventBus.hit_landed.connect(_on_hit_landed)
	if not EventBus.player_damaged.is_connected(_on_player_damaged):
		EventBus.player_damaged.connect(_on_player_damaged)


func _exit_tree() -> void:
	if EventBus.hit_landed.is_connected(_on_hit_landed):
		EventBus.hit_landed.disconnect(_on_hit_landed)
	if EventBus.player_damaged.is_connected(_on_player_damaged):
		EventBus.player_damaged.disconnect(_on_player_damaged)


## Appends a line; once the ring is full the oldest line scrolls off.
func append_line(text: String, dithered: bool = false) -> void:
	var cap: int = _ring.size()
	var at: int
	if _count < cap:
		at = (_head + _count) % cap
		_count += 1
	else:
		at = _head
		_head = (_head + 1) % cap
	_ring[at] = text
	_dithered[at] = dithered
	queue_redraw()


## The current lines, oldest first, newest last.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for i: int in _count:
		out.append(_ring[(_head + i) % _ring.size()])
	return out


## Per shown line (oldest first): true when it is drawn dithered.
func dithered_lines() -> Array[bool]:
	var out: Array[bool] = []
	for i: int in _count:
		out.append(_dithered[(_head + i) % _ring.size()])
	return out


func clear() -> void:
	_head = 0
	_count = 0
	queue_redraw()


## The log line for a landed hit (D-S28-4, D-S32-18): BASE `console.log("-N")`, UNPATCHED
## `console.log("-N") // resisted`, PATCHED `CRITICAL: N dmg`. ASCII only. Pure.
static func line_for_damage(damage: int, state: int = DamageState.Kind.BASE) -> String:
	var n: int = maxi(damage, 0)
	match state:
		DamageState.Kind.UNPATCHED:
			return "console.log(\"-%d\") // resisted" % n
		DamageState.Kind.PATCHED:
			return "CRITICAL: %d dmg" % n
	return "console.log(\"-%d\")" % n


## The log line for a hit on the player (D-S29-9): no number, no frame stamp. Pure.
static func line_for_player_hit() -> String:
	return "WARN: hp--"


## HUD cell of log line `index` (0 = top line, row 39). Pure.
static func line_cell(index: int) -> Vector2i:
	return Vector2i(Hud.LOG.position.x, Hud.LOG.position.y + 1 + index)


func _draw() -> void:
	var shown: PackedStringArray = lines()
	var dithered: Array[bool] = dithered_lines()
	for i: int in shown.size():
		GlyphFont.draw_cell(self, line_cell(i), shown[i], Palette.INK, SCALE)
		if dithered[i]:
			var rect := Rect2(GlyphFont.cell_to_px(line_cell(i), SCALE), Vector2(shown[i].length(), 1) * GlyphFont.CELL * SCALE)
			draw_texture_rect(RegisterPanel.checker_texture(), rect, true)


func _on_hit_landed(_target: StringName, damage: int, state: int, _is_combo: bool, _pos: Vector2) -> void:
	append_line(line_for_damage(damage, state), state == DamageState.Kind.UNPATCHED)


func _on_player_damaged(_hp: int) -> void:
	append_line(line_for_player_hit())
