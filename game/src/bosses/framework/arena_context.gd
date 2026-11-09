class_name ArenaContext
extends RefCounted
## What a boss and its attacks may read from the arena (Story 3.1, AD-06, NP-3, D-S31-10): the aim
## point through an injectable source, the player position for body contact, and the
## PlayerEffects queue. No Player or Register reference is held. Story 3.3 (D-S33-6): the
## register's shift count, read-only, through an injectable source.

## Aim-point source. Arena sets it to the player's position_px; Ghost Echo (6.1) swaps in the
## decoy. Default: the play-area centre (headless tests without an arena).
var target_source: Callable = _default_target
## The real player's position for body contact (never the decoy, [design call] D-S31-21).
var player_source: Callable = _default_target
## The NP-3 effect queue (D-S31-11). Empty in 3.1.
var player_effects: PlayerEffects = PlayerEffects.new()
## The register's shift count (Register.shift_serial), set by the Arena. Read-only (NP-3).
## Default: 0 (headless tests without an arena).
var shift_count: Callable = _zero_shifts


## The point attacks aim at (D-S31-10). The only aim read allowed in attack code.
func target_position() -> Vector2:
	return target_source.call()


## The player's own position (body contact only).
func player_position() -> Vector2:
	return player_source.call()


## Shifts applied since the session started (Story 3.3, D-S33-6). Read only.
func read_shift_count() -> int:
	return shift_count.call()


## True when `p` (arena-local px) lies inside the 32x18 play area, edges included. Pure.
static func inside_play_area(p: Vector2) -> bool:
	var area: Rect2 = Arena.play_area()
	return p.x >= area.position.x and p.y >= area.position.y and p.x <= area.end.x and p.y <= area.end.y


static func _zero_shifts() -> int:
	return 0


static func _default_target() -> Vector2:
	return Arena.play_area().get_center()
