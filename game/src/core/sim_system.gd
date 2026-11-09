class_name SimSystem
extends RefCounted
## Base of every simulation system ticked by SimClock (AD-01, D-S21-4).
## The built-in input poll runs before all phases; systems run by phase, then registration order.

enum SimPhase { SHIFTS, ACTIONS, PLAYER, BOSS_HAZARDS, PLAYER_EFFECTS, COMBAT, TIMERS }

## The phase this system ticks in. Set it before SimClock.register_system.
var phase: SimPhase = SimPhase.TIMERS


## Advances the system by one world frame. Override in subclasses.
func tick(_ctx: SimContext) -> void:
	pass
