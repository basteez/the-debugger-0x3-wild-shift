class_name HitFeedback
extends RefCounted
## Hit-stop precedence (Story 2.8, FR26, GDD "Hit-stop precedence", D-S28-1). Pure and static: no
## node, no SimClock. The ladder is Crit 8 > the combo's own value > normal (unpatched) 3.
## Story 3.2 (D-S32-8): boss hits use hitstop_for_boss_hit (the patching hit 4, a Patched hit 8);
## practice-target hits keep hitstop_for. Boss defeated 20 comes with 3.8.
## SimClock keeps the maximum request within a tick.

## Hit-stop of a normal (unpatched) hit, and the floor of a combo hit.
const NORMAL_HITSTOP := 3
## Hit-stop when the player is hit (Story 2.9, GDD "Player hit": 4 frames).
const PLAYER_HITSTOP := 4
## Hit-stop of the boss hit that applies Patched (Story 3.2, D-S32-8).
const PATCHED_APPLIED_HITSTOP := 4
## Hit-stop of a crit: a hit on a boss already Patched (FR26, D-S32-8).
const CRIT_HITSTOP := 8


## Hit-stop frames for one landed hit: NORMAL_HITSTOP for a solo hit, the combo action's own
## value (never below NORMAL_HITSTOP) for a combo hit.
static func hitstop_for(is_combo: bool, action_hitstop: int) -> int:
	if not is_combo:
		return NORMAL_HITSTOP
	return maxi(NORMAL_HITSTOP, action_hitstop)


## Hit-stop frames for one boss hit (Story 3.2, D-S32-8). `state` is the DamageState.Kind the hit's
## damage used, `applied` true when this tick's interactions applied Patched. Precedence: the
## patching hit takes PATCHED_APPLIED_HITSTOP; a Patched hit that did not apply it takes
## CRIT_HITSTOP; an unpatched hit follows hitstop_for (combo value, never below 3; solo 3). Pure.
static func hitstop_for_boss_hit(state: int, is_combo: bool, action_hitstop: int, applied: bool) -> int:
	if applied:
		return PATCHED_APPLIED_HITSTOP
	if state == DamageState.Kind.PATCHED:
		return CRIT_HITSTOP
	return hitstop_for(is_combo, action_hitstop)
