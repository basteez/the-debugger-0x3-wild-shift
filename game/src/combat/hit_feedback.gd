class_name HitFeedback
extends RefCounted
## Hit-stop precedence (Story 2.8, FR26, GDD "Hit-stop precedence", D-S28-1). Pure and static: no
## node, no SimClock. The ladder is Crit 8 > the combo's own value > normal (unpatched) 3. Crit is
## Epic 3 and not a parameter yet; Patched 4 and boss defeated 20 (3.8) come with their stories.
## SimClock keeps the maximum request within a tick.

## Hit-stop of a normal (unpatched) hit, and the floor of a combo hit.
const NORMAL_HITSTOP := 3
## Hit-stop when the player is hit (Story 2.9, GDD "Player hit": 4 frames).
const PLAYER_HITSTOP := 4


## Hit-stop frames for one landed hit: NORMAL_HITSTOP for a solo hit, the combo action's own
## value (never below NORMAL_HITSTOP) for a combo hit.
static func hitstop_for(is_combo: bool, action_hitstop: int) -> int:
	if not is_combo:
		return NORMAL_HITSTOP
	return maxi(NORMAL_HITSTOP, action_hitstop)
