class_name HitCapsule
extends HitShape
## A capsule: the segment from the origin along facing (`length_tiles`), swept by `radius_tiles`,
## round at both ends (Story 2.5). Not used by any action yet.

@export var length_tiles: float = 1.0
@export var radius_tiles: float = 0.5


func contains(origin: Vector2, facing: Vector2, point: Vector2) -> bool:
	var tip: Vector2 = origin + facing.normalized() * tiles_to_px(length_tiles)
	var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(point, origin, tip)
	return nearest.distance_to(point) <= tiles_to_px(radius_tiles)
