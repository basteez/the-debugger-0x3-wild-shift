class_name ScreenFxRule
extends RefCounted
## CPU mirror of screen_fx.gdshader's fragment (Story 4.3, AC 11, D-S43-10), so the colour rules are
## testable headless: Palette.WARN (the Breakpoint dot and line, later SIGSEGV) passes through
## invert and dither unchanged; every other pixel follows the 2.8 rules. Keep in step with the shader.

## Per-channel tolerance of the red exemption (half an 8-bit step), as WARN_EPSILON in the shader.
const WARN_EPSILON := 0.002


## The output colour of screen pixel `c` at game pixel `p`. Pure.
static func shade(c: Color, p: Vector2i, invert: bool, dither: float) -> Color:
	if is_warn(c):
		return Color(c.r, c.g, c.b, 1.0)
	var out: Color = c
	if invert:
		var mid_c: Color = (Palette.INK + Palette.BG) * 0.5
		out = Palette.BG if luminance(c) > luminance(mid_c) else Palette.INK
	if dither >= 0.5 and (p.x + p.y) % 2 == 0:
		out = Palette.BG
	return Color(out.r, out.g, out.b, 1.0)


## True when `c` is the reserved warning red (exact match within WARN_EPSILON per channel). Pure.
static func is_warn(c: Color) -> bool:
	return absf(c.r - Palette.WARN.r) <= WARN_EPSILON and absf(c.g - Palette.WARN.g) <= WARN_EPSILON \
			and absf(c.b - Palette.WARN.b) <= WARN_EPSILON


## Rec. 601 luma, as the shader's dot(rgb, vec3(0.299, 0.587, 0.114)). Pure.
static func luminance(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114
