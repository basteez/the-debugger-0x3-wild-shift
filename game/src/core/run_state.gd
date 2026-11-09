class_name RunState
extends RefCounted
## Mutable state of one run (Story 1.6 DC1). Owned by Game as Game.run.
## Story 2.9 adds deaths_on_boss (I-5) and the fight-start snapshot (AD-08) that a retry restores.

## 0, 1, 2 for Fight 1, 2, 3.
var boss_index: int = 0
## Seed of the current fight's SimContext RNG (Story 2.1, D-S21-6). Set by Game on FIGHT entry
## from a presentation-side clock; written into every input recording.
var fight_seed: int = 0
## Deaths on the current boss (Story 2.9, I-5). Reset by start_boss only; a retry keeps it (the
## 3rd-death hint in Epic 4 reads it).
var deaths_on_boss: int = 0
## Fight-start snapshot (Story 2.9, D-S29-4): the register ring captured on FIGHT enter, restored by
## every retry. Boss state (Epic 3) and Echo memory (Epic 4) join it with their stories.
var fight_start_ring: PackedInt32Array = PackedInt32Array()


## A new boss becomes current (intro, harvest, debug jump; never a retry): deaths start at 0.
func start_boss(index: int) -> void:
	boss_index = index
	deaths_on_boss = 0
