class_name HitArc
extends HitShape
## A circular sector centred on the origin and turned to facing (Story 2.5, the slash).
## `angle_deg` is the full angle (120 = 60 to each side). The origin point counts as inside.
## A zero facing tests as a full circle (Story 2.7, D-S27-1).

## Tolerance on the half-angle test, so a point exactly on the edge counts as inside.
const ANGLE_EPS_DEG := 0.0001

@export var radius_tiles: float = 1.5
@export var angle_deg: float = 120.0


func contains(origin: Vector2, facing: Vector2, point: Vector2) -> bool:
	var offset: Vector2 = point - origin
	if offset.length() > tiles_to_px(radius_tiles):
		return false
	if offset.is_zero_approx():
		return true
	if facing.is_zero_approx():
		return true # Story 2.7, D-S27-1: no direction = full circle, like the capsule
	var between: float = absf(rad_to_deg(facing.angle_to(offset)))
	return between <= angle_deg / 2.0 + ANGLE_EPS_DEG


## Exact circle-vs-sector test (Story 2.7, D-S27-1): the hurtbox touches the sector when its centre
## is inside the sector's angle and within radius + radius_px, or when it is within radius_px of
## one of the two straight edges (which also covers a centre within radius_px of the origin).
## A zero facing is a full circle.
func overlaps(origin: Vector2, facing: Vector2, centre: Vector2, radius_px: float) -> bool:
	var r: float = tiles_to_px(radius_tiles)
	var offset: Vector2 = centre - origin
	var dist: float = offset.length()
	if dist > r + radius_px:
		return false
	if facing.is_zero_approx() or dist <= radius_px:
		return true
	var half: float = deg_to_rad(angle_deg / 2.0)
	if absf(facing.angle_to(offset)) <= half + deg_to_rad(ANGLE_EPS_DEG):
		return true
	var dir: Vector2 = facing.normalized()
	for side: float in [-half, half]:
		var edge_tip: Vector2 = origin + dir.rotated(side) * r
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(centre, origin, edge_tip)
		if nearest.distance_to(centre) <= radius_px:
			return true
	return false
