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
## Practice target centre (Story 2.7, D-S27-2): 4 tiles right of spawn.
const PRACTICE_TARGET_PX := SPAWN_PX + Vector2(4 * TILE_PX, 0)
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
## The bit register (Story 2.3, D-S23-4). Owned here, reads SimClock's shared buffer; ticked by
## SimClock in the SHIFTS phase while in the tree. Drawn by the HUD's RegisterPanel (Main injects).
var register: Register = Register.new(SimClock.buffer)
## The player's action state machine (Story 2.5). Declared after player and register, so both
## exist when it is built (members initialise in declaration order). Ticked in the ACTIONS phase.
var actions: ActionStateMachine = ActionStateMachine.new(SimClock.buffer, player, register)
## Hit resolution (Story 2.7, AD-04): shape math in the COMBAT phase, after ACTIONS and PLAYER.
var combat: CombatResolver = CombatResolver.new(actions, player)
## The `/* test */` dummy (Story 2.7): null unless a fight was entered with_practice (debug only).
var practice_target: PracticeTarget = null


func _enter_tree() -> void:
	SimClock.register_system(register)
	SimClock.register_system(actions)
	SimClock.register_system(player)
	SimClock.register_system(combat)


## Detach from the autoload clock so re-instancing Main (tests) never double-ticks (D-S22-10).
func _exit_tree() -> void:
	SimClock.unregister_system(register)
	SimClock.unregister_system(actions)
	SimClock.unregister_system(player)
	SimClock.unregister_system(combat)


## Every route into FIGHT (D-S22-5, Story 2.3 AC9): reset the player to spawn and the register to
## `fight_start`, then start ticking both. `with_practice` (Story 2.7, debug Shift+F2 only) places
## the practice target, reset; without it the fight has no target.
func enter_fight(fight_start: PackedInt32Array, with_practice: bool = false) -> void:
	player.reset_for_fight(SPAWN_PX)
	player.set_active(true)
	if not register.set_fight_start(fight_start):
		register.set_fight_start(Register.fight_start_for_boss(0))
	SimClock.buffer.clear() # stale Q/E presses never carry into a fight (D-S23-11 belt and braces)
	register.set_active(true)
	actions.reset_for_fight()
	actions.set_active(true)
	_set_practice(with_practice)
	_redraw_player_view()


## Places (reset) or removes the practice target and hands the resolver its target list.
func _set_practice(on: bool) -> void:
	if on:
		if practice_target == null:
			practice_target = PracticeTarget.new()
		practice_target.position_px = PRACTICE_TARGET_PX
		practice_target.reset()
		combat.targets = [practice_target]
	else:
		practice_target = null
		combat.targets = []


func leave_fight() -> void:
	player.set_active(false)
	register.set_active(false)
	actions.set_active(false)
	_set_practice(false) # a stale target never outlives its fight (review 2.7)


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
