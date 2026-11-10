// Full-screen effects (Story 2.8 AC5, AD-07). Uniforms are written only by ScreenFX, driven only by
// JuiceDirector. Compatibility renderer. Output stays inside the 1-bit palette (NFR8, D-S28-6).
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// Swap INK and BG by luminance threshold (not 1 - colour), so the output stays two-colour.
uniform bool invert = false;
// 0..1. At >= 0.5, BG on the checkerboard pixels where (x + y) is even (the RegisterPanel dither).
uniform float dither = 0.0;
// Set from Palette by ScreenFX; the defaults match Palette.INK and Palette.BG.
uniform vec4 ink_colour = vec4(0.9098, 0.9098, 0.9098, 1.0);
uniform vec4 bg_colour = vec4(0.0627, 0.0627, 0.0784, 1.0);
// Story 4.3 (AC 11, D-S43-10): pixels of exactly this colour (Palette.WARN, the Breakpoint dot and
// line, later SIGSEGV) pass through dither and invert unchanged. Mirrored by ScreenFxRule.shade().
uniform vec4 warn_colour = vec4(1.0, 0.25098, 0.25098, 1.0);
// Per-channel tolerance of the exact-match test (half an 8-bit step).
const float WARN_EPSILON = 0.002;
// The game's base resolution, so the checker follows game pixels, not window pixels.
uniform vec2 base_size = vec2(640.0, 360.0);

void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	vec3 d = abs(c.rgb - warn_colour.rgb);
	if (max(d.r, max(d.g, d.b)) <= WARN_EPSILON) {
		COLOR = vec4(c.rgb, 1.0);
		return;
	}
	if (invert) {
		float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		float mid = dot((ink_colour.rgb + bg_colour.rgb) * 0.5, vec3(0.299, 0.587, 0.114));
		c = lum > mid ? bg_colour : ink_colour;
	}
	if (dither >= 0.5) {
		ivec2 p = ivec2(floor(SCREEN_UV * base_size));
		if ((p.x + p.y) % 2 == 0) {
			c = bg_colour;
		}
	}
	COLOR = vec4(c.rgb, 1.0);
}
