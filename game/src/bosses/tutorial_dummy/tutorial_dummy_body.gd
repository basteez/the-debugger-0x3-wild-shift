class_name TutorialDummyBody
extends BossController
## Story 8.2 (D-E8-5, D-S82-2, D-S82-4): the tutorial dummy, the boss of the TUTORIAL state. A
## BossController in the arena's boss slot, so damage states and Patched come from the resolver's
## existing boss path (UNPATCHED x0.5, PATCHED x1.5). It never attacks (no tell, no pick, no RNG
## draw), never hurts the player on contact and never dies (HP floors at 1). Its `;` opens on a fixed
## sim-frame timer: closed CLOSED_FRAMES ticks, then open OPEN_FRAMES ticks, and again. The whole
## body is the hurtbox (so a Dash Strike lands at any time), but the weak window exists only while the
## `;` is open (current_weak_window is ZERO while closed), so only an open `;` applies Patched. A
## Patched state then lasts its full WeakWindowTracker.PATCHED_FRAMES, even after the `;` closes.
## No miss line (body_touch_px keeps the default INF): a closed hit is an ordinary resisted hit.

## [design call] D-S82-4: the `;` timer in sim frames (closed first).
const CLOSED_FRAMES := 180
const OPEN_FRAMES := 120

## Ticks the `;` stays open; open while > 0.
var open_left: int = 0
## Ticks until the `;` opens; counts only while closed.
var closed_left: int = CLOSED_FRAMES


## Fight start (TUTORIAL entry): the `;` closed for a full CLOSED_FRAMES.
func reset_for_fight() -> void:
	open_left = 0
	closed_left = CLOSED_FRAMES
	super()


## Never attacks: the FSM stays in GAP with no pick and no RNG draw.
func _attacks_allowed() -> bool:
	return false


## The fixed `;` timer, one step per live tick (no RNG, no wall clock).
func _tick_body(_ctx: SimContext) -> void:
	if open_left > 0:
		open_left -= 1
		if open_left == 0:
			closed_left = CLOSED_FRAMES
		return
	closed_left -= 1
	if closed_left <= 0:
		closed_left = 0
		open_left = OPEN_FRAMES


## True while the `;` is open.
func is_semicolon_open() -> bool:
	return open_left > 0


## The weak window only while the `;` is open (D-S82-4); ZERO (never completed) while closed.
func current_weak_window() -> Vector2i:
	if not is_semicolon_open():
		return Vector2i.ZERO
	return super()


## Story 8.1 hook: the weak point is the `;`, open while hittable.
func weak_point_open() -> bool:
	return is_semicolon_open() and is_hittable()


## A practice body: contact never hurts the player.
func touches_player(_p: Vector2) -> bool:
	return false


## Never defeated in the tutorial: HP floors at 1.
func take_hit(damage: int) -> void:
	super(mini(damage, hp - 1))
