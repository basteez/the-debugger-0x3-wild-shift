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
