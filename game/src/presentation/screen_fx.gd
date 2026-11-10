class_name ScreenFX
extends ColorRect
## Full-screen effect rect in the ScreenFX CanvasLayer (Story 2.8 AC5, AD-07): the `invert` and
## `dither` uniforms of screen_fx.gdshader. Only JuiceDirector calls set_invert and set_dither.
## Hidden while no effect is on, so the screen copy costs nothing in normal play.
## Story 4.3 (AC 11): the shader leaves the warning red unchanged; ScreenFxRule mirrors it on the CPU.

const SHADER: Shader = preload("res://src/presentation/screen_fx.gdshader")

var shader_material: ShaderMaterial = ShaderMaterial.new()


func _init() -> void:
	shader_material.shader = SHADER
	shader_material.set_shader_parameter(&"ink_colour", Palette.INK)
	shader_material.set_shader_parameter(&"bg_colour", Palette.BG)
	shader_material.set_shader_parameter(&"base_size", Vector2(Const.BASE_RES))
	material = shader_material
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func set_invert(on: bool) -> void:
	shader_material.set_shader_parameter(&"invert", on)
	_update_visible()


## Dither level 0..1 (clamped); the shader dithers at 0.5 and above.
func set_dither(level: float) -> void:
	shader_material.set_shader_parameter(&"dither", clampf(level, 0.0, 1.0))
	_update_visible()


func is_inverted() -> bool:
	return shader_material.get_shader_parameter(&"invert") == true


func dither_level() -> float:
	var v: Variant = shader_material.get_shader_parameter(&"dither")
	return 0.0 if v == null else float(v)


func _update_visible() -> void:
	# The shader only dithers at 0.5 and above; below that the screen copy would be wasted.
	visible = is_inverted() or dither_level() >= 0.5

