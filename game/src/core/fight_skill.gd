class_name FightSkill
extends SimSystem
## Generic face of a cuttable per-fight skill module (Story 4.3, AD-12, D-S43-2). The wiring code
## (Arena, Main) and the HUD hold a module only through this type, loaded by path, so nothing outside
## the module's leaf folder names its class. Every method has a safe default.


## Every FIGHT entry (intro, harvest, retry, debug jump): back to the fight-start state.
## `unlocked` is computed by presentation (e.g. from RunState) and passed in as a plain bool.
func reset_for_fight(_unlocked: bool) -> void:
	pass


## The fight was left (flow change, debug jump): stop ticking, release anything the skill holds.
func end_fight() -> void:
	pass


## True while the skill's effect is running.
func is_active() -> bool:
	return false


## True when the skill may be used in this fight.
func is_unlocked() -> bool:
	return false


## Sim frames left before the skill can be used again (0 = ready).
func cooldown_left_frames() -> int:
	return 0
