class_name Arena
extends Node2D
## The Clearing (Story 1.5, FR56): a fixed 32x18 glyph layout drawn at 2x on 16-px tiles,
## plus the bounds clamp (scenery has no collision; walls are a position clamp).
## Placed by Main at HUD cell ORIGIN_CELL, i.e. pixel ORIGIN_CELL * 8 on the 640x360 base.

const TILES := Const.ARENA_TILES
const TILE_PX := Const.TILE_PX
## Top-left HUD cell of the arena: cells (16,2)-(79,37) at 8 px (D-047).
const ORIGIN_CELL := Vector2i(16, 2)
const GLYPH_SCALE := 2
const TREE := "♣"
const GRASS := "\""
const ROCK := "o"
const WATER := "~"
const LABEL := "stack frame 0x03"
const LABEL_COL := 2
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
## Player spawn (D-S22-6): centre of the play area, arena-local pixels.
const SPAWN_PX := Vector2(TILES * TILE_PX) / 2.0
## Inset of the player's glyph centre from the play-area edge: half a tile, so the whole `@` cell
## stays inside the 32x18 play area (D-S22-2). One more tile inward makes the tree ring a wall.
const PLAYER_EDGE_INSET_PX := TILE_PX / 2.0
## 18 rows x 32 glyphs (DC5): tree ring, grass, a connected stream, rocks, the label on row 0.
const LAYOUT: PackedStringArray = [
	'♣♣stack frame 0x03♣♣♣♣♣♣♣♣♣♣♣♣♣♣',
	'♣"    "    "    "    "    "    ♣',
	'♣ "    "    "    "    "    "   ♣',
	'♣  o    "    "    "   o"    "  ♣',
	'♣   "    o    "    "    "    " ♣',
	'♣    "    " o  "    "    o    "♣',
	'♣"    "    "    "    "    "    ♣',
	'♣ "    "    "    "    "   ~~~~~♣',
	'♣~~~~~~ "    "    "   ~~~~~ "  ♣',
	'♣   " ~~~~~~~ "  ~~~~~~ "    " ♣',
	'♣    "    " ~~~~~~  "    "    "♣',
	'♣"    "    "    "    "    "    ♣',
	'♣ "    "    "    "    "    "   ♣',
	'♣  "    "    " o  "    "   o"  ♣',
	'♣   "o   "    "    "    "    " ♣',
	'♣    "    "    "   o"    "    "♣',
	'♣"    "    "    "    "    "    ♣',
	'♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣♣',
]

## The player movement system (Story 2.2). Owned here; ticked by SimClock while in the tree.
var player: Player = Player.new(PLAYER_DEF, player_bounds())


func _enter_tree() -> void:
	SimClock.register_system(player)


## Detach from the autoload clock so re-instancing Main (tests) never double-ticks (D-S22-10).
func _exit_tree() -> void:
	SimClock.unregister_system(player)


## Every route into FIGHT (D-S22-5): reset to spawn, then start ticking.
func enter_fight() -> void:
	player.reset_for_fight(SPAWN_PX)
	player.set_active(true)
	_redraw_player_view()


func leave_fight() -> void:
	player.set_active(false)


## Drops the previous fight's cached frame so the view never shows the old position for a frame.
func _redraw_player_view() -> void:
	var view: Node = get_node_or_null(^"PlayerView")
	if view != null:
		view.queue_redraw()


func _ready() -> void:
	position = Vector2(ORIGIN_CELL * GlyphFont.CELL)
	queue_redraw()


func _draw() -> void:
	for row: int in LAYOUT.size():
		var line: String = LAYOUT[row]
		for col: int in line.length():
			var ch: String = line[col]
			if ch != " ":
				GlyphFont.draw_cell(self, Vector2i(col, row), ch, Palette.INK, GLYPH_SCALE)


## Play area in arena-local pixels: 512x288, max edge inclusive (DC4).
static func play_area() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(TILES * TILE_PX))


## Nearest point inside the play area (DC4). Pure: no node, no scene tree.
static func clamp_to_play_area(p: Vector2) -> Vector2:
	var area: Rect2 = play_area()
	return p.clamp(area.position, area.end)


## Rect the player's glyph centre may occupy (Story 2.2 C3): the play area shrunk by half a tile,
## i.e. centre in [8, 504] x [8, 280]. Handed to Player at construction.
static func player_bounds() -> Rect2:
	return play_area().grow(-PLAYER_EDGE_INSET_PX)
