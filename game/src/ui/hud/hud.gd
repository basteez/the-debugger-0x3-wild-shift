class_name Hud
extends CanvasLayer
## IDE HUD frame (Story 1.5, FR57 shell, D-047): 80x45 cells of 8 px at 1x on the 640x360 base.
## Static placeholder text only (DC10); register bits, duck text, log lines and HP come later.

const COLS := 80
const ROWS := 45
## Region rectangles in cells (inclusive corners as Rect2i position + size), per the GDD wireframe.
const REGISTER := Rect2i(0, 2, 12, 20) # cols 0-11, rows 2-21
const DUCK := Rect2i(0, 22, 12, 16) # cols 0-11, rows 22-37
const LINE_NUMBERS := Rect2i(13, 2, 3, 36) # cols 13-15, rows 2-37
const ARENA := Rect2i(16, 2, 64, 36) # cols 16-79, rows 2-37
const LOG := Rect2i(0, 38, 80, 7) # rows 38-44: header + 6 lines
const LOG_LINES := 6

const TOP_BAR := "void fightPlaceholder() // hp ---"
const SKY := "// TODO: this should terminate"
const REG_TITLE := "reg"
const LOG_HEADER := "── console ─────────────────────────────────────────────────────────────────────"
## One per arena tile row (DC6): drawn at cols 13-14 on HUD row 2 + 2 * index.
const LINE_NO: PackedStringArray = [
	"01", "02", "03", "04", "05", "06", "07", "08", "09",
	"10", "11", "12", "13", "14", "15", "16", "17", "18",
]
const LINE_NO_COL := 13
const SEPARATOR_COL := 15

@onready var grid_overlay: Node2D = $GridOverlay


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"debug_grid") and not event.is_echo() \
			and (OS.is_debug_build() or grid_toggle_allowed(false, UrlQuery.web_search())):
		grid_overlay.visible = not grid_overlay.visible
		get_viewport().set_input_as_handled()


## Debug rule (project-context): debug builds, or any build whose URL has `?debug`.
static func grid_toggle_allowed(is_debug_build: bool, search: String) -> bool:
	return is_debug_build or UrlQuery.has_debug(search)


## HUD region of a cell; &"gap" for col 12 and anything outside the listed regions.
static func region_of(cell: Vector2i) -> StringName:
	if cell.x < 0 or cell.x >= COLS or cell.y < 0 or cell.y >= ROWS:
		return &"gap"
	if cell.y == 0:
		return &"top_bar"
	if cell.y == 1:
		return &"sky"
	if REGISTER.has_point(cell):
		return &"register"
	if DUCK.has_point(cell):
		return &"duck"
	if LINE_NUMBERS.has_point(cell):
		return &"line_numbers"
	if ARENA.has_point(cell):
		return &"arena"
	if LOG.has_point(cell):
		return &"log"
	return &"gap"


## HUD row of the line number for arena tile row `index` (0-based).
static func line_no_row(index: int) -> int:
	return ARENA.position.y + 2 * index


## The box-drawing border strings for a panel rect: top, middle, bottom rows.
static func box_rows(rect: Rect2i, title: String = "") -> PackedStringArray:
	assert(rect.size.x >= 2 and rect.size.y >= 2, "Hud.box_rows: rect too small")
	var inner: int = maxi(rect.size.x - 2, 0)
	title = title.substr(0, maxi(inner - 2, 0))
	var top: String = "┌" + ("─" + title + "─".repeat(maxi(inner - 1 - title.length(), 0)) if title != "" else "─".repeat(inner)) + "┐"
	var mid: String = "│" + " ".repeat(inner) + "│"
	var bottom: String = "└" + "─".repeat(inner) + "┘"
	return PackedStringArray([top, mid, bottom])
