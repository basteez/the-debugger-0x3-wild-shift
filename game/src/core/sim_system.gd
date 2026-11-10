class_name SimSystem
extends RefCounted
## Base of every simulation system ticked by SimClock (AD-01, D-S21-4).
## The built-in input poll runs before all phases; systems run by phase, then registration order.
## Story 4.3 (D-S43-3): every registered system also gets poll() once per polled frame, before the
## Breakpoint and hit-stop gates, so a system can react to presses while the world is frozen.

enum SimPhase { SHIFTS, ACTIONS, PLAYER, BOSS_HAZARDS, PLAYER_EFFECTS, COMBAT, TIMERS }

## The phase this system ticks in. Set it before SimClock.register_system.
var phase: SimPhase = SimPhase.TIMERS


## Advances the system by one world frame. Override in subclasses.
func tick(_ctx: SimContext) -> void:
	pass


## Called by SimClock once per polled (non-paused) frame, after the frame's presses are pushed to the
## buffer and before the gates (Story 4.3, D-S43-3), so it runs during Breakpoint and hit-stop too.
## `presses` are this frame's raw presses (read only). Default: nothing.
func poll(_presses: Array[StringName], _ctx: SimContext) -> void:
	pass
