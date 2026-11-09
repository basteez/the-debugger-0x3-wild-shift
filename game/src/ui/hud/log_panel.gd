class_name LogPanel
extends Node2D
## The HUD console log (Story 2.8 AC3, FR57): a fixed ring of Hud.LOG_LINES lines drawn at 1x in
## HUD rows 39-44, under the `── console ──` header that HudFrame draws on row 38. Oldest first,
## newest at the bottom; the panel fills top-down like a console, then scrolls. Gameplay
## presentation driven by EventBus (not the Log autoload): it reads only signal arguments (AD-05).

const SCALE := 1

var _ring: PackedStringArray = PackedStringArray()
## Index of the oldest line in the ring.
var _head: int = 0
var _count: int = 0


func _init() -> void:
	_ring.resize(Hud.LOG_LINES)


func _enter_tree() -> void:
	if not EventBus.hit_landed.is_connected(_on_hit_landed):
		EventBus.hit_landed.connect(_on_hit_landed)


func _exit_tree() -> void:
	if EventBus.hit_landed.is_connected(_on_hit_landed):
		EventBus.hit_landed.disconnect(_on_hit_landed)


## Appends a line; once the ring is full the oldest line scrolls off.
func append_line(text: String) -> void:
	var cap: int = _ring.size()
	if _count < cap:
		_ring[(_head + _count) % cap] = text
		_count += 1
	else:
		_ring[_head] = text
		_head = (_head + 1) % cap
	queue_redraw()


## The current lines, oldest first, newest last.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for i: int in _count:
		out.append(_ring[(_head + i) % _ring.size()])
	return out


func clear() -> void:
	_head = 0
	_count = 0
	queue_redraw()


## The log line for a landed hit (D-S28-4). ASCII only. Pure.
static func line_for_damage(damage: int) -> String:
	return "console.log(\"-%d\")" % maxi(damage, 0)


## HUD cell of log line `index` (0 = top line, row 39). Pure.
static func line_cell(index: int) -> Vector2i:
	return Vector2i(Hud.LOG.position.x, Hud.LOG.position.y + 1 + index)


func _draw() -> void:
	var shown: PackedStringArray = lines()
	for i: int in shown.size():
		GlyphFont.draw_cell(self, line_cell(i), shown[i], Palette.INK, SCALE)


func _on_hit_landed(_target: StringName, damage: int, _state: int, _is_combo: bool, _pos: Vector2) -> void:
	append_line(line_for_damage(damage))
