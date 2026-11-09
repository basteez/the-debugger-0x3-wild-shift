class_name DamageCalc
extends RefCounted
## The only producer of damage numbers (single writer, Story 2.7 AC3). Pure static: multiplies the
## base by every factor and rounds half up once (GDD "Weak Window and Patched", Rounding).
## Factors become integer percent first, so float drift never moves a .5 result (D-S27-6).

## Damage state carried by EventBus.hit_landed (D-S27-7): BASE = x1, not a boss (practice target).
## Epic 3 adds UNPATCHED and PATCHED after it; the signal's type stays int.
const STATE_BASE := 0
## Clean Catch bonus, in percent (GDD: x1.5 on top of the damage state).
const CLEAN_CATCH_PCT := 150
## Three percent factors (state, Clean Catch, Echo) multiplied together.
const DEN := 100 * 100 * 100


## base x state_mult x (1.5 if clean_catch) x echo_scale, rounded half up once. Pure.
static func compute(base: int, state_mult: float, clean_catch: bool, echo_scale: float) -> int:
	var num: int = base * to_pct(state_mult) * (CLEAN_CATCH_PCT if clean_catch else 100) * to_pct(echo_scale)
	if num <= 0:
		return 0 # damage is never negative
	# floori(x + 0.5) in integers: x = num / DEN, so the result is (2 num + DEN) div (2 DEN).
	@warning_ignore("integer_division")
	return (num * 2 + DEN) / (DEN * 2)


## A multiplier as whole percent (0.7 -> 70). Pure.
static func to_pct(mult: float) -> int:
	return roundi(mult * 100.0)
