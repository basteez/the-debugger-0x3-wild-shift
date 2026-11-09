extends GutTest
## Story 2.8 AC1, D-S28-1: hit-stop precedence (Crit 8 > combo value > normal 3; crit is Epic 3).


func test_solo_hit_is_normal_3() -> void:
	assert_eq(HitFeedback.NORMAL_HITSTOP, 3)
	assert_eq(HitFeedback.hitstop_for(false, 0), 3)
	assert_eq(HitFeedback.hitstop_for(false, 6), 3, "a solo hit never uses the action's combo value")


func test_combo_hit_uses_the_action_value() -> void:
	assert_eq(HitFeedback.hitstop_for(true, Defs.DASH_STRIKE.hitstop_frames), 6)
	assert_eq(HitFeedback.hitstop_for(true, 8), 8, "Dereference-style value (Epic 6)")


func test_combo_hit_never_below_normal() -> void:
	assert_eq(HitFeedback.hitstop_for(true, 0), 3)
	assert_eq(HitFeedback.hitstop_for(true, 2), 3)


func test_max_of_a_tick_wins_over_solo_and_combo() -> void:
	var frames: int = maxi(HitFeedback.hitstop_for(false, 0), HitFeedback.hitstop_for(true, 6))
	assert_eq(frames, 6)


func test_action_defaults_and_data() -> void:
	assert_eq(ActionDef.new().hitstop_frames, 3, "default is the normal value")
	assert_eq(Defs.DASH_STRIKE.hitstop_frames, 6)
	for def: ActionDef in [Defs.SLASH_1, Defs.SLASH_2, Defs.SLASH_3, Defs.DASH]:
		assert_eq(def.hitstop_frames, 3, "%s keeps the default" % def.id)


func test_validate_rejects_negative_hitstop() -> void:
	var def := ActionDef.new()
	def.id = &"x"
	assert_true(def.validate().is_empty())
	def.hitstop_frames = -1
	assert_eq(def.validate().size(), 1)
