class_name DamageState
extends RefCounted
## The damage state of a landed hit (Story 3.2, FR22, NP-4, D-S32-7). Pure static. The int value
## is what EventBus.hit_landed carries in `state`. Multipliers are whole percent so DamageCalc's
## percent math stays exact.

## BASE = practice target (x1, never a boss); UNPATCHED = boss not Patched (x0.5); PATCHED = x1.5.
enum Kind { BASE = 0, UNPATCHED = 1, PATCHED = 2 }

const BASE_PCT := 100
const UNPATCHED_PCT := 50
const PATCHED_PCT := 150


## The multiplier of a state (1.0 / 0.5 / 1.5). An unknown state is x1. Pure.
static func multiplier(kind: int) -> float:
	return float(multiplier_pct(kind)) / 100.0


## The multiplier of a state as whole percent (100 / 50 / 150). Pure.
static func multiplier_pct(kind: int) -> int:
	match kind:
		Kind.UNPATCHED:
			return UNPATCHED_PCT
		Kind.PATCHED:
			return PATCHED_PCT
	return BASE_PCT
