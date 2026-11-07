class_name HitCircle
extends HitShape
## A circle centred on the origin (Story 2.5). Facing is ignored.

@export var radius_tiles: float = 1.0


func contains(origin: Vector2, _facing: Vector2, point: Vector2) -> bool:
	return origin.distance_to(point) <= tiles_to_px(radius_tiles)
