extends GutTest
## Story 2.5 AC1: HitCircle, HitArc and HitCapsule geometry (D-S25-10). Pure.

const O := Vector2(100, 100)
const RIGHT := Vector2(1, 0)
const EPS := 0.001


func _arc() -> HitArc:
	var arc := HitArc.new()
	arc.radius_tiles = 1.5
	arc.angle_deg = 120.0
	return arc


func _at_angle(deg: float, dist: float) -> Vector2:
	return O + Vector2.from_angle(deg_to_rad(deg)) * dist


func test_base_shape_contains_nothing() -> void:
	assert_false(HitShape.new().contains(O, RIGHT, O))


func test_circle_inside_outside_and_origin() -> void:
	var c := HitCircle.new()
	c.radius_tiles = 1.0
	assert_true(c.contains(O, RIGHT, O))
	assert_true(c.contains(O, RIGHT, O + Vector2(0, 16)))
	assert_true(c.contains(O, RIGHT, O + Vector2(-15.9, 0)))
	assert_false(c.contains(O, RIGHT, O + Vector2(16.1, 0)))


func test_arc_angles() -> void:
	var arc: HitArc = _arc()
	assert_true(arc.contains(O, RIGHT, _at_angle(0.0, 20.0)), "0 deg")
	assert_true(arc.contains(O, RIGHT, _at_angle(59.0, 20.0)), "+59 deg")
	assert_false(arc.contains(O, RIGHT, _at_angle(61.0, 20.0)), "+61 deg")
	assert_true(arc.contains(O, RIGHT, _at_angle(-59.0, 20.0)), "-59 deg")
	assert_false(arc.contains(O, RIGHT, _at_angle(-61.0, 20.0)), "-61 deg")
	assert_false(arc.contains(O, RIGHT, _at_angle(180.0, 20.0)), "180 deg")


func test_arc_range_boundary() -> void:
	var arc: HitArc = _arc()
	assert_true(arc.contains(O, RIGHT, O + Vector2(24.0 - EPS, 0)))
	assert_true(arc.contains(O, RIGHT, O + Vector2(24.0, 0)))
	assert_false(arc.contains(O, RIGHT, O + Vector2(24.0 + 0.01, 0)))


func test_arc_follows_facing_and_contains_origin() -> void:
	var arc: HitArc = _arc()
	var up := Vector2(0, -1)
	assert_true(arc.contains(O, up, O + Vector2(0, -20)))
	assert_false(arc.contains(O, up, O + Vector2(20, 0)))
	assert_true(arc.contains(O, up, O))
	var diag := Vector2(1, 1).normalized()
	assert_true(arc.contains(O, diag, O + Vector2(10, 10)))


func test_capsule_along_facing_with_round_ends() -> void:
	var cap := HitCapsule.new()
	cap.length_tiles = 2.0
	cap.radius_tiles = 0.5
	assert_true(cap.contains(O, RIGHT, O + Vector2(16, 7)), "side of the segment")
	assert_false(cap.contains(O, RIGHT, O + Vector2(16, 9)), "outside the side")
	assert_true(cap.contains(O, RIGHT, O + Vector2(39, 0)), "round tip")
	assert_false(cap.contains(O, RIGHT, O + Vector2(32 + 6, 6)), "tip corner is round")
	assert_true(cap.contains(O, RIGHT, O + Vector2(-7, 0)), "round base")
	assert_false(cap.contains(O, RIGHT, O + Vector2(-9, 0)))
	assert_true(cap.contains(O, Vector2(0, 1), O + Vector2(0, 30)), "turns with facing")


# --- Story 2.7: circle overlap (D-S27-1) ---

func test_base_shape_overlaps_nothing() -> void:
	assert_false(HitShape.new().overlaps(O, RIGHT, O, 100.0))


func test_circle_overlap_and_tangent() -> void:
	var c := HitCircle.new()
	c.radius_tiles = 1.0
	assert_true(c.overlaps(O, RIGHT, O + Vector2(30, 0), 14.0), "16 + 14 = 30: tangent counts")
	assert_false(c.overlaps(O, RIGHT, O + Vector2(30.1, 0), 14.0))
	assert_true(c.overlaps(O, Vector2.ZERO, O + Vector2(0, -20), 5.0), "facing ignored")


func test_arc_overlap_in_front_with_edge_reach() -> void:
	var arc: HitArc = _arc() # 24 px, 120 deg
	assert_true(arc.overlaps(O, RIGHT, O + Vector2(48, 0), 24.0), "tangent at the tip")
	assert_false(arc.overlaps(O, RIGHT, O + Vector2(48.1, 0), 24.0))
	assert_false(arc.overlaps(O, RIGHT, O + Vector2(-30, 0), 24.0), "behind, out of reach")


func test_arc_overlap_beside_the_sector_counts_through_the_edge() -> void:
	var arc: HitArc = _arc()
	# Centre at 90 deg (outside the 60-deg half-angle) 20 px away: its distance to the
	# 60-deg edge is 20 * sin(30 deg) = 10 px.
	var centre: Vector2 = _at_angle(90.0, 20.0)
	assert_true(arc.overlaps(O, RIGHT, centre, 10.5))
	assert_false(arc.overlaps(O, RIGHT, centre, 9.5))
	assert_false(arc.contains(O, RIGHT, centre), "the centre itself is outside the sector")


func test_arc_overlap_with_centre_inside_the_hurtbox_origin() -> void:
	var arc: HitArc = _arc()
	assert_true(arc.overlaps(O, RIGHT, O + Vector2(-10, 0), 12.0), "origin inside the hurtbox")
	assert_true(arc.overlaps(O, RIGHT, O + Vector2(-20, 0), 100.0), "huge hurtbox behind")


func test_arc_zero_facing_is_a_full_circle() -> void:
	var arc: HitArc = _arc()
	assert_true(arc.overlaps(O, Vector2.ZERO, O + Vector2(-40, 0), 16.0))
	assert_false(arc.overlaps(O, Vector2.ZERO, O + Vector2(-40.1, 0), 16.0))
	assert_true(arc.contains(O, Vector2.ZERO, O + Vector2(-20, 0)), "contains agrees (2.5 deferral closed)")
	assert_false(arc.contains(O, Vector2.ZERO, O + Vector2(-25, 0)))


func test_capsule_overlap_along_the_segment() -> void:
	var cap := HitCapsule.new()
	cap.length_tiles = 5.0
	cap.radius_tiles = 0.75 # Dash Strike: 80 px, 12 px
	assert_true(cap.overlaps(O, RIGHT, O + Vector2(64, 0), 24.0))
	assert_true(cap.overlaps(O, RIGHT, O + Vector2(40, 36), 24.0), "side tangent: 12 + 24")
	assert_false(cap.overlaps(O, RIGHT, O + Vector2(40, 36.1), 24.0))
	assert_true(cap.overlaps(O, RIGHT, O + Vector2(116, 0), 24.0), "tip tangent: 80 + 36")
	assert_false(cap.overlaps(O, RIGHT, O + Vector2(116.1, 0), 24.0))
	assert_false(cap.overlaps(O, RIGHT, O + Vector2(-37, 0), 24.0), "behind the round base")
	assert_true(cap.overlaps(O, RIGHT, O + Vector2(0, 0), 200.0), "centre on the shape, large radius")


func test_capsule_zero_facing_is_a_circle() -> void:
	var cap := HitCapsule.new()
	cap.length_tiles = 5.0
	cap.radius_tiles = 0.75
	assert_true(cap.overlaps(O, Vector2.ZERO, O + Vector2(0, 36), 24.0))
	assert_false(cap.overlaps(O, Vector2.ZERO, O + Vector2(64, 0), 24.0), "no length without a direction")
