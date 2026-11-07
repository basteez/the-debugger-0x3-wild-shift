class_name HitCapsule
extends HitShape
## A capsule: the segment from the origin along facing (`length_tiles`), swept by `radius_tiles`,
## round at both ends (Story 2.5). Dash Strike's shape (Story 2.6). A zero facing collapses it to a
## circle of `radius_tiles` on the origin.

@export var length_tiles: float = 1.0
@export var radius_tiles: float = 0.5


func _tip(origin: Vector2, facing: Vector2) -> Vector2:
	if facing.is_zero_approx():
		return origin # no direction: a circle on the origin
	return origin + facing.normalized() * tiles_to_px(length_tiles)


func contains(origin: Vector2, facing: Vector2, point: Vector2) -> bool:
	var tip: Vector2 = _tip(origin, facing)
	var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(point, origin, tip)
	return nearest.distance_to(point) <= tiles_to_px(radius_tiles)


func overlaps(origin: Vector2, facing: Vector2, centre: Vector2, radius_px: float) -> bool:
	var tip: Vector2 = _tip(origin, facing)
	var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(centre, origin, tip)
	return nearest.distance_to(centre) <= tiles_to_px(radius_tiles) + radius_px
