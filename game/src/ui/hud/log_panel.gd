class_name LogPanel
extends Node2D
## The HUD console log (Story 2.8 AC3, FR57): a fixed ring of Hud.LOG_LINES lines drawn at 1x in
## HUD rows 39-44, under the `── console ──` header that HudFrame draws on row 38. Oldest first,
## newest at the bottom; the panel fills top-down like a console, then scrolls. Gameplay
## presentation driven by EventBus (not the Log autoload): it reads only signal arguments (AD-05).
## Story 2.9: EventBus.player_damaged appends `WARN: hp--` (D-S29-9).
## Story 3.2 (FR27, D-S32-18): the line depends on the damage state; resisted lines are dithered.
## Story 5.3 (D-S53-6): EventBus.player_stunned appends its reason (`NullPointerException`).
## Story 8.1 (D-E8-3, D-S81-2): EventBus.hit_missed appends a dithered `// miss` line.

const SCALE := 1
## Story 9.7 (D-S97-4): the block the lines are drawn in. Full width by default (column 0, from
## console line 0, every line); the tutorial console moves them to its right block, under its prompt.
var block_col: int = 0
var block_first_line: int = 0
var block_max_lines: int = Hud.LOG_LINES

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
	if not EventBus.player_stunned.is_connected(_on_player_stunned):
		EventBus.player_stunned.connect(_on_player_stunned)
	if not EventBus.hit_missed.is_connected(_on_hit_missed):
		EventBus.hit_missed.connect(_on_hit_missed)


func _exit_tree() -> void:
	if EventBus.hit_landed.is_connected(_on_hit_landed):
		EventBus.hit_landed.disconnect(_on_hit_landed)
	if EventBus.player_damaged.is_connected(_on_player_damaged):
		EventBus.player_damaged.disconnect(_on_player_damaged)
	if EventBus.player_stunned.is_connected(_on_player_stunned):
		EventBus.player_stunned.disconnect(_on_player_stunned)
	if EventBus.hit_missed.is_connected(_on_hit_missed):
		EventBus.hit_missed.disconnect(_on_hit_missed)


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


## Story 8.1 (D-S81-2): the log line for a miss on the boss's body. ASCII only. Pure.
static func line_for_miss(closed: bool) -> String:
	return "// miss: \";\" is closed" if closed else "// miss: aim for the \";\""


## HUD cell of log line `index` (0 = top line, row 39). Pure.
static func line_cell(index: int) -> Vector2i:
	return Vector2i(Hud.LOG.position.x, Hud.LOG.position.y + 1 + index)


## Story 9.7 (D-S97-4): draw the lines in a block from column `col`, console line `first_line`, at
## most `max_lines` of them (the newest; newest at the bottom). Lines are cut at the last column.
func set_block(col: int, first_line: int, max_lines: int) -> void:
	var c: int = clampi(col, 0, Hud.COLS - 1)
	var f: int = clampi(first_line, 0, Hud.LOG_LINES)
	var m: int = clampi(max_lines, 0, Hud.LOG_LINES - f)
	if c == block_col and f == block_first_line and m == block_max_lines:
		return
	block_col = c
	block_first_line = f
	block_max_lines = m
	queue_redraw()


## Story 9.7: the plain full-width console again.
func reset_block() -> void:
	set_block(0, 0, Hud.LOG_LINES)


## Story 9.7 (D-S97-4): what _draw shows in the current block, oldest first: {cell, text, dithered}.
## The newest block_max_lines lines, each cut to the columns left of the block's origin.
func block_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var shown: PackedStringArray = lines()
	var dithered: Array[bool] = dithered_lines()
	var skip: int = maxi(shown.size() - block_max_lines, 0)
	var width: int = Hud.COLS - block_col
	for i: int in range(skip, shown.size()):
		var cell := Vector2i(block_col, Hud.LOG.position.y + 1 + block_first_line + i - skip)
		out.append({"cell": cell, "text": shown[i].left(width), "dithered": dithered[i]})
	return out


func _draw() -> void:
	for r: Dictionary in block_rows():
		var text: String = r["text"]
		GlyphFont.draw_cell(self, r["cell"], text, Palette.INK, SCALE)
		if r["dithered"]:
			var rect := Rect2(GlyphFont.cell_to_px(r["cell"], SCALE), Vector2(text.length(), 1) * GlyphFont.CELL * SCALE)
			draw_texture_rect(Dither.checker(), rect, true)


func _on_hit_landed(_target: StringName, damage: int, state: int, _is_combo: bool, _pos: Vector2) -> void:
	append_line(line_for_damage(damage, state), state == DamageState.Kind.UNPATCHED)


func _on_player_damaged(_hp: int) -> void:
	append_line(line_for_player_hit())


## Story 5.3 (D-S53-6): the stun's reason, as is (`NullPointerException`).
func _on_player_stunned(reason: StringName) -> void:
	append_line(String(reason))


## Story 8.1 (D-E8-3): one dithered line per miss, like a resisted hit.
func _on_hit_missed(_target: StringName, closed: bool, _pos: Vector2) -> void:
	append_line(line_for_miss(closed), true)
