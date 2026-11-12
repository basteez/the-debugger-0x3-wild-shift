extends GutTest
## Story 6.5 (AC 3, 4, D-S65-8): the SIGSEGV tell's red border is a separate WARN node, the HUD
## sources stay INK/BG only, and the node reads the warning by method.


class WarnAttack:
	extends BossAttack
	var on: bool = false

	func warning_tell() -> bool:
		return on


class FakeBoss:
	extends BossController
	var atk: BossAttack

	func current_attack() -> BossAttack:
		return atk


func test_border_is_warn_and_covers_the_hud() -> void:
	assert_eq(WarningBorder.BORDER_RECT.size, Vector2(Hud.COLS * 8 - 2, Hud.ROWS * 8 - 2))
	var code: String = FileAccess.get_file_as_string("res://src/presentation/warning_border.gd")
	assert_true(code.contains("Palette.WARN"), "the border is the reserved red")


func test_hud_sources_draw_no_red_border() -> void:
	for path: String in ["res://src/ui/hud/hud.gd", "res://src/ui/hud/hud_frame.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("Palette.WARN"), path)


func test_border_follows_the_warning_tell() -> void:
	var hud: Hud = autofree(Hud.new())
	var boss := FakeBoss.new()
	var atk := WarnAttack.new()
	boss.atk = atk
	hud.boss = boss
	var border := WarningBorder.new()
	add_child_autofree(border)
	assert_false(border.is_on(), "no hud, nothing drawn")
	border.hud = hud
	assert_false(border.is_on())
	atk.on = true
	assert_true(border.is_on())
	atk.on = false
	assert_false(border.is_on())
	hud.boss = null


func test_sky_text_is_the_inverted_tell_line_during_a_warning() -> void:
	var hud: Hud = autofree(Hud.new())
	var boss := FakeBoss.new()
	var atk := WarnAttack.new()
	boss.atk = atk
	hud.boss = boss
	assert_ne(hud.sky_text(), Hud.WARNING_TELL_TEXT)
	atk.on = true
	assert_eq(hud.sky_text(), Hud.WARNING_TELL_TEXT)
	hud.boss = null


func test_warning_border_is_the_only_warn_user_of_the_warning() -> void:
	var main: String = FileAccess.get_file_as_string("res://src/main/main.gd")
	assert_true(main.contains("WarningBorder.new()"), "Main builds the border")
	assert_false(FileAccess.get_file_as_string("res://src/bosses/segfault/attacks/sigsegv.gd").contains("WARN"))
