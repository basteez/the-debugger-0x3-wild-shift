class_name PlayerView
extends Node2D
## Draws the player `@` and its `>o` duck companion (Story 2.2, NFR8) at 2x on the 16-px grid.
## Presentation only (AD-05): reads Player state, never writes it. A child of the Arena so its
## coordinates are arena-local; added by Main so the arena/ sim folder never references this file.

const GLYPH_SCALE := 2
const PLAYER_GLYPH := "@"
const DUCK_GLYPH := ">o"
## Half a 2x glyph cell: the `@` is drawn centred on Player.position_px.
const HALF_TILE := Vector2(Const.TILE_PX / 2.0, Const.TILE_PX / 2.0)
## Offset of the duck's centre from the player's, per unit of -facing (D-S22-8): 1.5 tiles across
## so the two-glyph duck sits right next to the `@` cell, one tile up or down.
const DUCK_STEP := Vector2(Const.TILE_PX * 1.5, Const.TILE_PX)

var player: Player
## Story 2.9 (D-S29-6): the `@` blinks while this health is invulnerable; the duck never blinks.
## Injected by Main; null = no blink.
var health: PlayerHealth
## Story 2.4 shift juice (D-S24-4): the `@` draws as an INK cell with a BG glyph while true. Set by
## JuiceDirector for 4 frames per shift; the duck `>o` is never inverted.
var inverted: bool = false


func _init(p_player: Player = null) -> void:
	player = p_player


func _process(_delta: float) -> void:
	if player != null and player.active:
		queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var top_left: Vector2 = player_top_left(player.position_px)
	if health != null and PlayerHealth.blink_hidden(health.invuln_left):
		pass # blink-off frame: the `@` is not drawn
	elif inverted:
		draw_rect(Rect2(top_left, Vector2(GlyphFont.text_width(PLAYER_GLYPH, GLYPH_SCALE), Const.TILE_PX)), Palette.INK)
		GlyphFont.draw_at(self, top_left, PLAYER_GLYPH, Palette.BG, GLYPH_SCALE)
	else:
		GlyphFont.draw_at(self, top_left, PLAYER_GLYPH, Palette.INK, GLYPH_SCALE)
	GlyphFont.draw_at(self, duck_top_left(player.position_px, player.facing), DUCK_GLYPH, Palette.INK, GLYPH_SCALE)


## Top-left pixel of the `@` for a sim centre, rounded onto the pixel grid. Pure.
static func player_top_left(centre: Vector2) -> Vector2:
	return (centre - HALF_TILE).round()


## Top-left pixel of the `>o` duck: behind the player (opposite to facing), kept inside the play
## area so it never draws over the HUD frame. Pure.
static func duck_top_left(centre: Vector2, facing: Vector2i) -> Vector2:
	var size := Vector2(GlyphFont.text_width(DUCK_GLYPH, GLYPH_SCALE), Const.TILE_PX)
	var duck_centre: Vector2 = centre - Vector2(facing) * DUCK_STEP
	var top_left: Vector2 = (duck_centre - size / 2.0).round()
	var area: Rect2 = Arena.play_area()
	return top_left.clamp(area.position, area.end - size)
