class_name PerfOverlay
extends Node2D
## F10 perf overlay (Story 2.8 AC6, architecture "Debug tools"): FPS, frame time, live particles
## and 2D draw calls, drawn at 1x in INK on a BG box at the top-right of the play area. Added by
## Main only when Debug.enabled; hidden by default. Read-only: never writes sim state.
## [design call] Draw calls come from the root viewport's canvas render info
## (Viewport.RENDER_INFO_TYPE_CANVAS): in Godot 4.7 RenderingServer.get_rendering_info counts only
## 3D for draw calls (class docs), so it would always read 0 in this 2D game. When the info is not
## available (0 before 2 rendered frames, or a renderer that does not report it) the value shows
## as `-` (D-S28-7); a missing number is never a crash.

const TEXT_INSET := Vector2(4, 4)
const LINE_STEP := GlyphFont.CELL + 1
## Widest line, in characters, for the background box ("particles 300/300", "frame 999.9 ms").
const BOX_CHARS := 17
## Refresh every N process frames: the numbers are readable and the overlay costs little.
const REFRESH_FRAMES := 15
## Shown for a value that is not available.
const MISSING := "-"

## The pool whose live_count is shown, set by Main. Null = 0 particles.
var particle_pool: ParticlePool

var _lines: PackedStringArray = PackedStringArray()
var _since_refresh: int = 0
var _warned_draw_calls: bool = false


func _init() -> void:
	visible = false
	z_index = 10  # above the Particles layer (z 0)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_since_refresh += 1
	if _since_refresh >= REFRESH_FRAMES:
		refresh()


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


## Reads the current numbers and redraws.
func refresh() -> void:
	_since_refresh = 0
	var live: int = particle_pool.live_count() if is_instance_valid(particle_pool) else 0
	var draw_calls: int = -1
	var vp: Viewport = get_viewport()
	if vp != null:
		draw_calls = vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		if draw_calls <= 0 and not _warned_draw_calls and Engine.get_process_frames() > 120:
			_warned_draw_calls = true
			Log.warn(&"debug", "perf overlay: draw calls unavailable, showing %s" % MISSING)
	_lines = lines(Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, live, draw_calls)
	queue_redraw()


func shown_lines() -> PackedStringArray:
	return _lines


## The overlay lines (ASCII only). A negative or zero draw-call count shows as MISSING. Pure.
static func lines(fps: float, frame_ms: float, live_particles: int, draw_calls: int) -> PackedStringArray:
	return PackedStringArray([
		"fps %d" % roundi(fps),
		"frame %.1f ms" % frame_ms,
		"particles %d/%d" % [live_particles, ParticlePool.CAPACITY],
		"draw calls %s" % (str(draw_calls) if draw_calls > 0 else MISSING),
	])


## Top-left of the box, inside the top-right corner of the play area (arena-local px). Pure.
static func box_top_left(line_count: int) -> Vector2:
	var area: Rect2 = Arena.play_area()
	var size: Vector2 = box_size(line_count)
	return Vector2(area.end.x - TEXT_INSET.x - size.x, area.position.y + TEXT_INSET.y)


static func box_size(line_count: int) -> Vector2:
	return Vector2(BOX_CHARS * GlyphFont.CELL + 4, line_count * LINE_STEP + 3)


func _draw() -> void:
	if _lines.is_empty():
		return
	var top_left: Vector2 = box_top_left(_lines.size())
	draw_rect(Rect2(top_left, box_size(_lines.size())), Palette.BG)
	for i: int in _lines.size():
		GlyphFont.draw_at(self, top_left + Vector2(2, 2 + i * LINE_STEP), _lines[i], Palette.INK, 1)
