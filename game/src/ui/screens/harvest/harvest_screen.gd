class_name HarvestScreen
extends Node2D
## The HARVEST screen (Story 3.8, FR8, FR50, GDD "Level Types (Harvest)"): the defeated bug's fixed
## line at the top, the register below it with the dropped bit flying into its new slot
## (BIT_FLIGHT_FRAMES, D-S38-9), the byte value, the new active windows with their combo names, and
## a `press any key` prompt once the skip opens. On entry it requests the shared harvest duck line
## (VoiceService.say, deferred so the bubble's flow-change clear runs first, D-S38-11). It ends at
## Game.HARVEST_MAX_FRAMES sim frames or on any non-modifier key / left click after
## Game.HARVEST_SKIP_FRAMES (D-S38-10), through Game.finish_harvest.
## Presentation only: it reads Game.run and Defs and builds a COPY of the register for display
## (D-S38-5); it never writes flow state, the arena or the run.

const GameFlow := preload("res://src/autoloads/game.gd")
## The shared harvest line id in data/duck/duck_lines.tres (FR45 line 8).
const LINE_ID := &"harvest_shared"
const TEXT_SCALE := 2
const SMALL_SCALE := 1
## Rows on the 8-px grid (640x360 base). Everything stays right of the HUD duck region (cols 0-11)
## on rows 22-37, where the duck bubble shows the harvest line.
const FIXED_TOP_Y := 64
const REGISTER_TOP_Y := 128
const WINDOWS_TOP_Y := 176
const WINDOW_ROW_STEP := 16
const PROMPT_TOP_Y := 304
const PROMPT_TEXT := "press any key"
const FIXED_FALLBACK := "// bug fixed"
## The dropped bit's flight from the fixed line to its register slot, in presentation (physics)
## frames of this screen (D-S38-9). Never sim state.
const BIT_FLIGHT_FRAMES := 30

var boss_index: int = 0
## The defeated bug's fixed line ("" = the fallback, e.g. a debug fight without a boss body).
var fixed_line: String = ""
## The dropped bit (Register.Bit), 0 = none (the test boss).
var bit: int = 0
## The ring the player had at the start of the defeated fight (the snapshot), and the ring shown.
var previous_ring: PackedInt32Array = PackedInt32Array()
var shown_ring: PackedInt32Array = PackedInt32Array()
## Presentation frames since the screen opened (drives the flight only).
var frames_open: int = 0

var _line_requested: bool = false
## The prompt was drawn on the last redraw (the screen stops redrawing once it shows and the flight ended).
var _prompt_drawn: bool = false


## Main calls this before adding the screen. `p_bit` is the boss's drop_bit; `p_previous` the
## defeated fight's start ring.
func setup(p_boss_index: int, p_fixed_line: String, p_bit: int, p_previous: PackedInt32Array) -> void:
	boss_index = p_boss_index
	fixed_line = p_fixed_line
	bit = p_bit
	previous_ring = p_previous.duplicate()
	shown_ring = display_ring(previous_ring, bit, boss_index)
	name = &"HarvestScreen"
	queue_redraw()


func _ready() -> void:
	Log.info(&"flow", "harvest opened boss=%d bit=%s ring=%s" % [boss_index, Register.glyph_of(bit), Register.to_text(shown_ring)])
	request_line.call_deferred()


## Requests the shared harvest line once (E4). Deferred from _ready so the duck bubble has
## already cleared the previous fight's line on this flow change.
func request_line() -> void:
	if _line_requested or not is_inside_tree() or Game.flow_state != GameFlow.FlowState.HARVEST:
		return
	_line_requested = true
	VoiceService.say(String(LINE_ID))


## The ring a harvest gives (C4, D-S38-5): a fresh Register COPY set to `previous` with `p_bit`
## inserted (the arena's register is never touched). Returns `previous` unchanged when there is
## no bit or the insert is rejected (Register logs the error). Pure apart from the copy.
static func harvest_ring(previous: PackedInt32Array, p_bit: int) -> PackedInt32Array:
	var copy := Register.new()
	if not copy.set_fight_start(previous):
		return previous.duplicate()
	if p_bit != 0:
		copy.insert(p_bit)
	return copy.ring.duplicate()


## The ring the screen shows (D-S38-17): the next fight's fight-start set when it holds exactly the
## harvested bits (the order the player will get), else the harvested ring itself. Pure.
static func display_ring(previous: PackedInt32Array, p_bit: int, p_boss_index: int) -> PackedInt32Array:
	var harvested: PackedInt32Array = harvest_ring(previous, p_bit)
	if p_boss_index + 1 > GameFlow.LAST_BOSS_INDEX:
		return harvested
	var next: PackedInt32Array = Register.fight_start_for_boss(p_boss_index + 1)
	return next if same_bits(next, harvested) else harvested


## True when both rings hold the same bits, in any order. Pure.
static func same_bits(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	if a.size() != b.size():
		return false
	for x: int in a:
		if not b.has(x):
			return false
	return true


## Every window a ring can bring into J/K by shifting: (ring[i], ring[i + 1]) cyclic. Pure.
static func windows_of(ring: PackedInt32Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if ring.size() < 2:
		return out
	for i: int in ring.size():
		var w := Vector2i(ring[i], ring[(i + 1) % ring.size()])
		if not out.has(w):
			out.append(w)
	return out


## The windows of `now` that `before` could not reach (the "new windows" of the harvest). Pure.
static func new_windows(before: PackedInt32Array, now: PackedInt32Array) -> Array[Vector2i]:
	var old: Array[Vector2i] = windows_of(before)
	var out: Array[Vector2i] = []
	for w: Vector2i in windows_of(now):
		if not old.has(w):
			out.append(w)
	return out


## `D>L  --` / `A>D  Dash Strike`: a window and its combo name from Defs.COMBOS. Pure.
static func window_text(w: Vector2i) -> String:
	var combo: ComboDef = Defs.COMBOS.get_combo(w.x, w.y)
	return "%s>%s  %s" % [Register.glyph_of(w.x), Register.glyph_of(w.y), combo.display_name if combo != null else "--"]


## `[A, D, L] = 0x07`. Pure.
static func register_text(ring: PackedInt32Array) -> String:
	return "%s = 0x%02X" % [Register.to_text(ring), (1 << ring.size()) - 1]


## Character index of ring slot `slot` inside register_text (`[` then `X, ` per slot). Pure.
static func slot_char_index(slot: int) -> int:
	return 1 + slot * 3


## Every text row the screen can draw for this harvest (font coverage, tests).
func text_rows() -> PackedStringArray:
	var rows := PackedStringArray([fixed_text(), register_text(shown_ring), PROMPT_TEXT])
	for w: Vector2i in new_windows(previous_ring, shown_ring):
		rows.append(window_text(w))
	return rows


func fixed_text() -> String:
	return fixed_line if fixed_line != "" else FIXED_FALLBACK


## Pure: 0..1 progress of the bit flight after `frames` presentation frames.
static func flight_progress(frames: int) -> float:
	return clampf(float(frames) / float(BIT_FLIGHT_FRAMES), 0.0, 1.0)


## Pure: the left x that centres `text` at `scale` on the base width, on the 8-px grid.
static func centred_x_at(text: String, scale: int) -> int:
	var x: int = maxi((Const.BASE_RES.x - GlyphFont.text_width(text, scale)) / 2, 0)
	return x - x % GlyphFont.CELL


func _unhandled_input(event: InputEvent) -> void:
	if Game.flow_state != GameFlow.FlowState.HARVEST:
		return
	if not PlaceholderScreen.is_advance(event):
		return
	get_viewport().set_input_as_handled() # an early press is consumed and does nothing
	try_skip(SimClock.sim_frame)


## A skip press at sim frame `frame`: ends HARVEST once the skip is open. True if it moved.
func try_skip(frame: int) -> bool:
	if not Game.harvest_skip_open(frame):
		return false
	return Game.finish_harvest(frame)


func _physics_process(_delta: float) -> void:
	if frames_open < BIT_FLIGHT_FRAMES or not _prompt_drawn:
		queue_redraw()
	frames_open += 1
	if Game.flow_state == GameFlow.FlowState.HARVEST and Game.harvest_timed_out(SimClock.sim_frame):
		Game.finish_harvest(SimClock.sim_frame)


func _draw() -> void:
	var fixed: String = fixed_text()
	var fixed_left := Vector2(centred_x_at(fixed, TEXT_SCALE), FIXED_TOP_Y)
	GlyphFont.draw_at(self, fixed_left, fixed, Palette.INK, TEXT_SCALE)
	var reg: String = register_text(shown_ring)
	var reg_left := Vector2(centred_x_at(reg, TEXT_SCALE), REGISTER_TOP_Y)
	var slot: int = shown_ring.find(bit) if bit != 0 else -1
	var cell: int = GlyphFont.size_for(TEXT_SCALE)
	if slot < 0:
		GlyphFont.draw_at(self, reg_left, reg, Palette.INK, TEXT_SCALE)
	else:
		# The register text without the new glyph, then the glyph on its flight path.
		var at: int = slot_char_index(slot)
		var without: String = reg.substr(0, at) + " " + reg.substr(at + 1)
		GlyphFont.draw_at(self, reg_left, without, Palette.INK, TEXT_SCALE)
		var to := reg_left + Vector2(at * cell, 0)
		var from := Vector2(Const.BASE_RES.x / 2.0 - cell / 2.0, FIXED_TOP_Y)
		var p: Vector2 = from.lerp(to, flight_progress(frames_open)).round()
		GlyphFont.draw_at(self, p, Register.glyph_of(bit), Palette.INK, TEXT_SCALE)
	var row: int = 0
	for w: Vector2i in new_windows(previous_ring, shown_ring):
		var text: String = window_text(w)
		GlyphFont.draw_at(self, Vector2(centred_x_at(text, SMALL_SCALE), WINDOWS_TOP_Y + row * WINDOW_ROW_STEP), text, Palette.INK, SMALL_SCALE)
		row += 1
	_prompt_drawn = Game.harvest_skip_open(SimClock.sim_frame)
	if _prompt_drawn:
		GlyphFont.draw_at(self, Vector2(centred_x_at(PROMPT_TEXT, SMALL_SCALE), PROMPT_TOP_Y), PROMPT_TEXT, Palette.INK, SMALL_SCALE)
