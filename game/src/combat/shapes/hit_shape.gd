class_name HitShape
extends Resource
## Base of the action hit shapes (Story 2.5, D-S25-10). Geometry only: knows nothing about damage
## or targets. All arguments are arena-local pixels; `facing` is a unit vector. Pure, no node.


## True when `point` lies inside the shape placed at `origin` and turned to `facing`.
func contains(_origin: Vector2, _facing: Vector2, _point: Vector2) -> bool:
	return false


## True when a circular hurtbox (`centre`, `radius_px`) touches the shape placed at `origin` and
## turned to `facing` (Story 2.7, D-S27-1): any shared point counts, the tangent case included.
## A zero facing means "no direction" (circle-like shapes collapse to a full circle).
func overlaps(_origin: Vector2, _facing: Vector2, _centre: Vector2, _radius_px: float) -> bool:
	return false


## Tiles to pixels (Const.TILE_PX), for subclasses.
static func tiles_to_px(tiles: float) -> float:
	return tiles * Const.TILE_PX
