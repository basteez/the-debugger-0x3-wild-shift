class_name Dither
extends RefCounted
## The BG dither textures (NFR8 extra states), drawn as a tiled texture rect over INK glyphs.
## Transparent pixels keep the glyph's INK, the others paint BG; built from Palette.BG only, so no
## colour outside INK and BG is ever drawn. Static, built once. Lives in src/core/ so the
## simulation folder arena/ can use it without referencing ui/ or presentation/ (DC4a, Story 9.7).
## - checker(): the 50% checker (D-S23-7): BG where x + y is even. Register panel, console log.
## - scenery(): the 75% scenery dither (Story 9.7, D-S97-1): one INK pixel kept per 2x2 block,
##   at x % 2 == 0 and y % 2 == 0, BG elsewhere. Grass, rock and water.

## Texture side in pixels at 1x: one HUD cell. Both patterns repeat every 2 px, so a tiled rect
## anchored on the 8-px grid keeps the pattern aligned to the base pixels.
const SIZE := 8

static var _checker: ImageTexture = null
static var _scenery: ImageTexture = null


## Pure: true where the 50% checker paints BG (local pixel x, y).
static func checker_paints(x: int, y: int) -> bool:
	return (x + y) % 2 == 0


## Pure: true where the 75% scenery dither paints BG (one INK pixel kept per 2x2 block).
static func scenery_paints(x: int, y: int) -> bool:
	return not (x % 2 == 0 and y % 2 == 0)


static func checker() -> ImageTexture:
	if _checker == null:
		_checker = _build(checker_paints)
	return _checker


static func scenery() -> ImageTexture:
	if _scenery == null:
		_scenery = _build(scenery_paints)
	return _scenery


static func _build(paints: Callable) -> ImageTexture:
	var img: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in SIZE:
		for x: int in SIZE:
			if paints.call(x, y):
				img.set_pixel(x, y, Palette.BG)
	return ImageTexture.create_from_image(img)
