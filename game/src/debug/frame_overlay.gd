class_name FrameOverlay
extends Node2D
## F9 frame overlay (Story 2.5 AC7): sim frame, player FSM state, frame in state, J/K cooldowns,
## invulnerability, the player hurtbox and the active hit shape. Story 2.6: the combo link (open or
## closed, window pair, frames left in the 18-tick count, held K press). Story 2.7: the shape at the
## action's start position and the practice target's hurtbox. A child of the Arena (arena-local
## pixels), added by Main only when Debug.enabled; hidden by default. Read-only: never writes sim state.

const TEXT_ORIGIN := Vector2(4, 4)
const LINE_STEP := GlyphFont.CELL + 1
## Widest line, in characters, for the background box ("IDLE_MOVE 999", "frame 9999999").
const BOX_CHARS := 14
## Above the arena's other children and the Particles layer (z 0), so nothing shows through the text.
const OVERLAY_Z := 10
## Segments used to outline circles and arcs.
const SEGMENTS := 24

var player: Player
var actions: ActionStateMachine
var register: Register
## The practice target (Story 2.7), set by Main; null = no target circle.
var practice_target: PracticeTarget


func _init() -> void:
	visible = false
	z_index = OVERLAY_Z


func _process(_delta: float) -> void:
	if visible and player != null and player.active:
		queue_redraw()


func toggle() -> void:
	visible = not visible
	queue_redraw()


func _draw() -> void:
	if player == null or actions == null:
		return
	var centre: Vector2 = player.position_px
	var hurt_r: float = player.def.hurtbox_tiles * Const.TILE_PX / 2.0
	draw_arc(centre, hurt_r, 0.0, TAU, SEGMENTS, Palette.INK, 1.0)
	if actions.state == ActionStateMachine.ActionState.ACTIVE and actions.action != null:
		# Story 2.7, D-S27-13: shapes are anchored at the action's start, not the moving player.
		_draw_shape(actions.action.hit_shape, actions.action_origin_px, Vector2(actions.facing).normalized())
	if practice_target != null:
		draw_arc(practice_target.position_px, practice_target.hurtbox_radius_px, 0.0, TAU, SEGMENTS, Palette.INK, 1.0)
	var window: Vector2i = register.active_window() if register != null else Vector2i.ZERO
	var link: LinkState = actions.link
	var lines: PackedStringArray = format_lines(SimClock.sim_frame, actions.state, actions.frame_in_state(), actions.cooldowns.remaining(window.x), actions.cooldowns.remaining(window.y), actions.invulnerable(), link.is_open(), link.pair, link.frames_left, link.held)
	var box := text_box(lines.size())
	draw_rect(box, Palette.BG)
	draw_rect(box, Palette.INK, false, 1.0)
	for i: int in lines.size():
		GlyphFont.draw_at(self, box.position + Vector2(2, 2 + i * LINE_STEP), lines[i], Palette.INK, 1)


## The opaque box behind the text lines: top-left of the play area (the F10 box is top-right). Pure.
static func text_box(line_count: int) -> Rect2:
	return Rect2(TEXT_ORIGIN, Vector2(BOX_CHARS * GlyphFont.CELL + 4, line_count * LINE_STEP + 3))


func _draw_shape(shape: HitShape, origin: Vector2, dir: Vector2) -> void:
	if shape is HitArc:
		var arc := shape as HitArc
		var r: float = HitShape.tiles_to_px(arc.radius_tiles)
		var half: float = deg_to_rad(arc.angle_deg / 2.0)
		var a: float = dir.angle()
		draw_arc(origin, r, a - half, a + half, SEGMENTS, Palette.INK, 1.0)
		draw_line(origin, origin + Vector2.from_angle(a - half) * r, Palette.INK, 1.0)
		draw_line(origin, origin + Vector2.from_angle(a + half) * r, Palette.INK, 1.0)
	elif shape is HitCircle:
		draw_arc(origin, HitShape.tiles_to_px((shape as HitCircle).radius_tiles), 0.0, TAU, SEGMENTS, Palette.INK, 1.0)
	elif shape is HitCapsule:
		var cap := shape as HitCapsule
		var r: float = HitShape.tiles_to_px(cap.radius_tiles)
		var tip: Vector2 = origin + dir * HitShape.tiles_to_px(cap.length_tiles)
		var side: Vector2 = dir.orthogonal() * r
		draw_line(origin + side, tip + side, Palette.INK, 1.0)
		draw_line(origin - side, tip - side, Palette.INK, 1.0)
		draw_arc(origin, r, 0.0, TAU, SEGMENTS, Palette.INK, 1.0)
		draw_arc(tip, r, 0.0, TAU, SEGMENTS, Palette.INK, 1.0)


## The overlay's text lines (ASCII only, so the 8x8 font covers them). Pure. The link lines show
## the pair and count only while the link is open.
static func format_lines(sim_frame: int, state: ActionStateMachine.ActionState, frame_in_state: int, cooldown_j: int, cooldown_k: int, invulnerable: bool, link_open: bool, link_pair: Vector2i, link_left: int, link_held: bool) -> PackedStringArray:
	return PackedStringArray([
		"frame %d" % sim_frame,
		"%s %d" % [ActionStateMachine.state_name(state), frame_in_state],
		"cd J %d K %d" % [cooldown_j, cooldown_k],
		"invuln %s" % ("yes" if invulnerable else "no"),
		"link %s" % ("open" if link_open else "closed"),
		"pair %s %s" % ([Register.glyph_of(link_pair.x), Register.glyph_of(link_pair.y)] if link_open else ["-", "-"]),
		"left %d" % (link_left if link_open else 0),
		"held %s" % ("K" if link_held else "-"),
	])
