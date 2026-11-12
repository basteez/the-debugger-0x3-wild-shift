class_name PlayerCommand
extends RefCounted
## Base of every PlayerEffects command (Story 6.6, D-S66-4, the 6.5 deferred refactor): plain data
## that a boss pushes and the PlayerEffects queue applies at the PLAYER_EFFECTS tick point against
## the fight's Register and LinkState (NP-3). Holds no node or system.


## Applies the command. True when the register changed (a refused change returns false). The
## base does nothing.
func apply(_register: Register, _link: LinkState) -> bool:
	return false
