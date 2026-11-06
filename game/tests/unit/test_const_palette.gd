extends GutTest
## Ports the Story 1.1 Const and Palette checks.


func test_const_tile_px_is_16() -> void:
	assert_eq(Const.TILE_PX, 16)


func test_const_sim_hz_is_60() -> void:
	assert_eq(Const.SIM_HZ, 60)


func test_const_base_res_is_640x360() -> void:
	assert_eq(Const.BASE_RES, Vector2i(640, 360))


func test_const_arena_tiles_is_32x18() -> void:
	assert_eq(Const.ARENA_TILES, Vector2i(32, 18))


func test_tiles_per_s_to_px_per_frame_3_75_is_1() -> void:
	assert_almost_eq(Const.tiles_per_s_to_px_per_frame(3.75), 1.0, 0.0001)


func test_tiles_per_s_to_px_per_frame_0_is_0() -> void:
	assert_eq(Const.tiles_per_s_to_px_per_frame(0.0), 0.0)


func test_palette_ink_is_e8e8e8() -> void:
	assert_eq(Palette.INK, Color("#E8E8E8"))


func test_palette_bg_is_101014() -> void:
	assert_eq(Palette.BG, Color("#101014"))


func test_palette_warn_is_ff4040() -> void:
	assert_eq(Palette.WARN, Color("#FF4040"))
