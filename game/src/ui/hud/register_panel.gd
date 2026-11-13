class_name RegisterPanel
extends Node2D
## The REGISTER box content (Story 2.3, FR9, GFR5-GFR10, D-S23-8): hex byte value, the 8 bit cells,
## the faded `<<` / `>>` previews around the inverted active window, and `J→K`. Presentation only
## (AD-05, D-S23-9): reads the injected Register, never writes it. HUD text at 1x on the 8-px grid.
## The pure `plan()` decides every cell; `_draw_content()` only executes it.
## Story 2.4 (D-S24-3): the cells are drawn by a child `Content` node shifted by `slide_px`, and this
## node is its clip mask (CLIP_CHILDREN_ONLY: the opaque interior rect is not drawn, it only keeps
## the slid cells inside the REGISTER box, off the border and the col-12 gap).
## Story 2.6 (FR7, D-S26-10, D-S26-14): the active window and each preview show their combo name
## (word-wrapped on two rows of 10 cells) where a combo exists, and only the bit glyphs where none.
## Story 5.4 (AC 10, D-S54-8): while Watch is held, the byte-row cells of the boss's current weak
## window bits get an INK frame. Reads the injected FightSkill (is_active) and the weak-window source
## only; the Register is never changed. Released Watch draws no frame.

## One run of text to draw: top-left HUD cell, text (one glyph per cell) and style.
class Cell:
	extends RefCounted
	var cell: Vector2i
	var text: String
	var style: StringName

	func _init(p_cell: Vector2i, p_text: String, p_style: StringName) -> void:
		cell = p_cell
		text = p_text
		style = p_style


const SCALE := 1
## Styles (D-S23-7): INK glyph; greyed and faded = glyph under a 50% BG checker; inverted = INK cell
## with a BG glyph. Greyed and faded draw the same; the names keep their meaning for 2.4 / 2.6.
const INK := &"ink"
const GREYED := &"greyed"
const FADED := &"faded"
const INVERTED := &"inverted"
## Layout (D-S23-8, re-spaced in 2.6 by D-S26-14), HUD cells inside the REGISTER box interior
## (cols 1-10, rows 3-20). Each combo name takes NAME_ROWS rows under its glyph row.
const LEFT_COL := 1
const HEX_ROW := 3
const BYTE_ROW := 5
const LABEL_ROW := 6
const PREVIEW_LEFT_ROW := 8
const PREVIEW_LEFT_NAME_ROW := 9
const WINDOW_ROW := 12
const JK_ROW := 13
const WINDOW_NAME_ROW := 14
const PREVIEW_RIGHT_ROW := 17
const PREVIEW_RIGHT_NAME_ROW := 18
const NAME_ROWS := 2
## The J and K glyph columns, shared by both previews, the window and `J→K`.
const J_COL := 4
const K_COL := 6
const WINDOW_COLS := 10
const BYTE_BITS := 8
const NIBBLE_BITS := 4
const RESERVED_LABEL := "reserved"
const JK_LABEL := "J→K"
const UNOWNED := "0"
## REGISTER box interior in px at 1x, relative to the panel origin: cols 1-10, rows 3-20 (D-S24-3).
const CLIP_RECT := Rect2(8, 24, 80, 144)

## The register to show. Injected by Main (null-safe: nothing is drawn without one).
var register: Register

## Story 5.4: the Watch module (null = Watch is cut, never marks) and the boss's current weak window
## (a Callable returning Vector2i; ZERO = no boss). Injected by Main; read only.
var watch_skill: FightSkill
var weak_window_source: Callable
## True when the last draw framed weak-window cells (so a release outside a fight still clears).
var _marks_shown: bool = false

## Horizontal slide of the cells in px (Story 2.4 shift juice). Set by JuiceDirector; 0 = rest,
## which draws exactly as Story 2.3.
var slide_px: int = 0:
	set(value):
		slide_px = value
		content.position = Vector2(value, 0)
		content.queue_redraw()

## The child that draws the cells; clipped to CLIP_RECT by this node.
var content: Node2D

## 8x8 50% checker of BG pixels (transparent elsewhere), built once on first draw.
static var _checker: ImageTexture


func _init() -> void:
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	content = Node2D.new()
	content.name = &"Content"
	content.draw.connect(_draw_content)
	add_child(content)


func _process(_delta: float) -> void:
	if register != null and register.active:
		content.queue_redraw()
	elif _marks_shown:
		content.queue_redraw() # Story 5.4: never leave a stale Watch frame



## The clip mask: an opaque rect over the interior. Not shown (CLIP_CHILDREN_ONLY).
func _draw() -> void:
	draw_rect(CLIP_RECT, Palette.INK)


func _draw_content() -> void:
	if register == null:
		return
	for c: Cell in plan(register.ring, Register.MAX_BITS, Defs.COMBOS):
		var rect := Rect2(GlyphFont.cell_to_px(c.cell, SCALE), Vector2(c.text.length(), 1) * GlyphFont.CELL)
		if c.style == INVERTED:
			content.draw_rect(rect, Palette.INK)
			GlyphFont.draw_cell(content, c.cell, c.text, Palette.BG, SCALE)
			continue
		GlyphFont.draw_cell(content, c.cell, c.text, Palette.INK, SCALE)
		if c.style == GREYED or c.style == FADED:
			content.draw_texture_rect(checker_texture(), rect, true)
	var marks: Array[Vector2i] = watch_mark_cells(register.ring, current_weak_window(), Register.MAX_BITS)
	_marks_shown = not marks.is_empty()
	for cell: Vector2i in marks:
		content.draw_rect(Rect2(GlyphFont.cell_to_px(cell, SCALE), Vector2(GlyphFont.CELL, GlyphFont.CELL)), Palette.INK, false, 1.0)


## Story 5.4: the weak window to mark now, or ZERO while Watch is not held (or cut, or no boss).
func current_weak_window() -> Vector2i:
	if watch_skill == null or not watch_skill.is_active() or not weak_window_source.is_valid():
		return Vector2i.ZERO
	var w: Variant = weak_window_source.call()
	return w if w is Vector2i else Vector2i.ZERO


## Story 5.4 (AC 10): the byte-row cells holding a bit of `weak` (x and y), in ring order. Pure:
## `ring` is never modified; ZERO marks nothing. A weak bit the player does not own is not marked.
static func watch_mark_cells(ring: PackedInt32Array, weak: Vector2i, owned_cap: int = Register.MAX_BITS) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if weak == Vector2i.ZERO:
		return out
	var high: int = BYTE_BITS - clampi(owned_cap, 0, BYTE_BITS)
	for slot: int in ring.size():
		if ring[slot] == weak.x or ring[slot] == weak.y:
			out.append(Vector2i(LEFT_COL + high + slot, BYTE_ROW))
	return out


## Every cell of the panel for a ring of owned bits (window first), in draw order. Pure: no node,
## no Register instance; `ring` is never modified. `owned_cap` is the low-nibble width; `combos` is
## the combo table (null = Defs.COMBOS).
static func plan(ring: PackedInt32Array, owned_cap: int = Register.MAX_BITS, combos: ComboTable = null) -> Array[Cell]:
	if combos == null:
		combos = Defs.COMBOS
	var out: Array[Cell] = []
	var byte_value: int = (1 << ring.size()) - 1
	out.append(Cell.new(Vector2i(LEFT_COL, HEX_ROW), "0x%02X" % byte_value, INK))
	# 8 bit cells: the reserved high nibble, then the owned bits window first, then unowned slots.
	var high: int = BYTE_BITS - clampi(owned_cap, 0, BYTE_BITS)
	for i: int in BYTE_BITS:
		var col: int = LEFT_COL + i
		var slot: int = i - high
		if slot >= 0 and slot < ring.size():
			out.append(Cell.new(Vector2i(col, BYTE_ROW), Register.glyph_of(ring[slot]), INK))
		else:
			out.append(Cell.new(Vector2i(col, BYTE_ROW), UNOWNED, GREYED))
	out.append(Cell.new(Vector2i(LEFT_COL, LABEL_ROW), RESERVED_LABEL, GREYED))
	if ring.size() < Register.MIN_BITS:
		return out
	var left: Vector2i = Register.window_of(Register.rotated(ring, Register.LEFT))
	out.append(Cell.new(Vector2i(LEFT_COL, PREVIEW_LEFT_ROW), "<< " + _pair_text(left), FADED))
	_append_name(out, combos.get_combo(left.x, left.y), PREVIEW_LEFT_NAME_ROW, FADED)
	var active: Vector2i = Register.window_of(ring)
	var window: String = " ".repeat(J_COL - LEFT_COL) + _pair_text(active)
	out.append(Cell.new(Vector2i(LEFT_COL, WINDOW_ROW), window + " ".repeat(WINDOW_COLS - window.length()), INVERTED))
	out.append(Cell.new(Vector2i(J_COL, JK_ROW), JK_LABEL, INK))
	_append_name(out, combos.get_combo(active.x, active.y), WINDOW_NAME_ROW, INK)
	var right: Vector2i = Register.window_of(Register.rotated(ring, Register.RIGHT))
	out.append(Cell.new(Vector2i(LEFT_COL, PREVIEW_RIGHT_ROW), ">> " + _pair_text(right), FADED))
	_append_name(out, combos.get_combo(right.x, right.y), PREVIEW_RIGHT_NAME_ROW, FADED)
	return out


## A combo's name on up to NAME_ROWS rows from `row`; nothing for no combo (FR7, D-S26-10).
static func _append_name(out: Array[Cell], combo: ComboDef, row: int, style: StringName) -> void:
	if combo == null:
		return
	var lines: PackedStringArray = wrap_name(combo.display_name)
	for i: int in lines.size():
		out.append(Cell.new(Vector2i(LEFT_COL, row + i), lines[i], style))


## Word-wraps a combo name into at most NAME_ROWS lines of WINDOW_COLS cells (D-S26-14): "Dash
## Strike" (11) becomes "Dash" / "Strike". Story 6.2 (D-S62-5): a single word longer than a row is
## hyphenated across two rows ("Dereference" -> "Derefer-" / "ence", see hyphen_split). Pure.
static func wrap_name(combo_name: String) -> PackedStringArray:
	var lines := PackedStringArray()
	var line: String = ""
	for word: String in combo_name.split(" ", false):
		if line.is_empty():
			line = word
		elif line.length() + 1 + word.length() <= WINDOW_COLS:
			line += " " + word
		else:
			lines.append(line)
			line = word
		while line.length() > WINDOW_COLS:
			var parts: PackedStringArray = hyphen_split(line)
			lines.append(parts[0])
			line = parts[1]
	if not line.is_empty():
		lines.append(line)
	if lines.size() > NAME_ROWS:
		lines.resize(NAME_ROWS)
	return lines


## Story 6.2 (D-S62-5): splits an over-long word into [head + "-", tail] with the head at most
## WINDOW_COLS - 1 characters. The break is the last consonant-to-vowel boundary that fits and
## leaves a tail of at least 2 characters ("Derefer-" / "ence"); without one, a hard cut. Pure.
static func hyphen_split(word: String) -> PackedStringArray:
	var max_head: int = WINDOW_COLS - 1
	var cut: int = -1
	for i: int in range(mini(max_head, word.length() - 2), 1, -1):
		if _is_vowel(word[i]) and not _is_vowel(word[i - 1]):
			cut = i
			break
	if cut < 0:
		cut = max_head
	return PackedStringArray([word.left(cut) + "-", word.substr(cut)])


static func _is_vowel(c: String) -> bool:
	return "aeiouyAEIOUY".contains(c)


## "D A": the J glyph at J_COL, the K glyph at K_COL when the run starts J_COL - LEFT_COL earlier.
static func _pair_text(window: Vector2i) -> String:
	return Register.glyph_of(window.x) + " ".repeat(K_COL - J_COL - 1) + Register.glyph_of(window.y)


## The dither (D-S23-7, NFR8): BG on pixels where x + y is even, transparent elsewhere. Built from
## Palette.BG only, so the panel draws no colour outside INK and BG. Shared with LogPanel (3.2).
static func checker_texture() -> ImageTexture:
	if _checker == null:
		var img: Image = Image.create_empty(GlyphFont.CELL, GlyphFont.CELL, false, Image.FORMAT_RGBA8)
		for y: int in GlyphFont.CELL:
			for x: int in GlyphFont.CELL:
				if (x + y) % 2 == 0:
					img.set_pixel(x, y, Palette.BG)
		_checker = ImageTexture.create_from_image(img)
	return _checker
