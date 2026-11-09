class_name HitArc
extends HitShape
## A circular sector centred on the origin and turned to facing (Story 2.5, the slash).
## `angle_deg` is the full angle (120 = 60 to each side). The origin point counts as inside.

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
		return false
	var between: float = absf(rad_to_deg(facing.angle_to(offset)))
	return between <= angle_deg / 2.0 + ANGLE_EPS_DEG
