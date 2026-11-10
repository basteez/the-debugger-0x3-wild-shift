class_name Hud
extends CanvasLayer
## IDE HUD frame (Story 1.5, FR57 shell, D-047): 80x45 cells of 8 px at 1x on the 640x360 base.
## Static placeholder text (DC10) plus the RegisterPanel (Story 2.3) and the LogPanel (Story 2.8);
## Story 3.6: the DuckBubble draws the duck and its text in the DUCK region.

const COLS := 80
const ROWS := 45
## Region rectangles in cells (inclusive corners as Rect2i position + size), per the GDD wireframe.
const REGISTER := Rect2i(0, 2, 12, 20) # cols 0-11, rows 2-21
const DUCK := Rect2i(0, 22, 12, 16) # cols 0-11, rows 22-37
const LINE_NUMBERS := Rect2i(13, 2, 3, 36) # cols 13-15, rows 2-37
const ARENA := Rect2i(16, 2, 64, 36) # cols 16-79, rows 2-37
const LOG := Rect2i(0, 38, 80, 7) # rows 38-44: header + 6 lines
const LOG_LINES := 6

## Top bar fallback while no boss is in the fight (D-S31-14); boss_header() replaces it otherwise.
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
## Register content of the REGISTER box (Story 2.3). Main injects the arena's Register.
@onready var register_panel: RegisterPanel = $RegisterPanel
## Console log lines under the LOG header (Story 2.8). Listens to EventBus.hit_landed itself.
@onready var log_panel: LogPanel = $LogPanel
@onready var frame: Node2D = $Frame
## The duck text bubble in the DUCK region (Story 3.6). Listens to EventBus.duck_line_requested.
@onready var duck_bubble: DuckBubble = $DuckBubble

## The fight's boss (Story 3.1), set by Main on every flow change; null = placeholder top bar.
## Read only: the header shows its live HP (AD-05).
var boss: BossController = null


func _ready() -> void:
	EventBus.boss_hp_changed.connect(_on_boss_hp_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)


## Story 3.8 (D-S38-16): HARVEST shows only the duck bubble of the HUD (the harvest line), with the
## frame (top bar and boss header, D-S38-13), the register panel, the log and the HP readout hidden.
## Off in every other state. Main calls it on every flow change.
func set_duck_only(on: bool) -> void:
	for child: Node in get_children():
		if child == duck_bubble or child == grid_overlay:
			continue
		if child is CanvasItem:
			(child as CanvasItem).visible = not on


## True while only the duck bubble shows (HARVEST).
func is_duck_only() -> bool:
	return not frame.visible


## Main hands the arena's boss (or null) on every flow change.
func set_boss(p_boss: BossController) -> void:
	boss = p_boss
	frame.queue_redraw()


## The top bar text: the boss header while a boss is in the fight, the placeholder otherwise.
func top_bar_text() -> String:
	if boss == null or boss.def == null:
		return TOP_BAR
	return boss_header(boss.def.name_signature, boss.hp)


## FR32 signature header (D-S31-14): `void <signature>() // hp <hp>`. Pure.
static func boss_header(signature: String, p_hp: int) -> String:
	return "void %s() // hp %d" % [signature, p_hp]


func _on_boss_hp_changed(_hp: int, _max_hp: int) -> void:
	frame.queue_redraw()


func _on_boss_defeated(_boss: StringName) -> void:
	frame.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if visible and Debug.enabled and event.is_action_pressed(&"debug_grid") and not event.is_echo():
		grid_overlay.visible = not grid_overlay.visible
		get_viewport().set_input_as_handled()


## Debug rule (project-context): debug builds, or any build whose URL has `?debug`.
## The live gate is Debug.enabled (Story 1.6 DC3); this pure form stays for its tests.
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
