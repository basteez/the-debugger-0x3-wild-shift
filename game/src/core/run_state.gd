class_name RunState
extends RefCounted
## Mutable state of one run (Story 1.6 DC1). Owned by Game as Game.run.
## Story 2.9 adds deaths_on_boss (I-5) and the fight-start snapshot (AD-08) that a retry restores.

## 0, 1, 2 for Fight 1, 2, 3.
var boss_index: int = 0
## Seed of the current fight's SimContext RNG (Story 2.1, D-S21-6). Set by Game on FIGHT entry
## (Story 3.4, D-S34-2: fight_seed_for(run_seed, fight_attempt)); written into every input recording.
var fight_seed: int = 0
## Story 3.4 (D-S34-2): the run's seed, taken once from a presentation-side clock on the run's first
## FIGHT entry (0 = not taken yet). A new run is a new RunState.
var run_seed: int = 0
## Story 3.4 (D-S34-2): FIGHT entries in this run (intro, harvest, retry, debug jump), 1 on the first.
var fight_attempt: int = 0
## Deaths on the current boss (Story 2.9, I-5). Reset by start_boss only; a retry keeps it (the
## 3rd-death hint in Epic 4 reads it).
var deaths_on_boss: int = 0
## Fight-start snapshot (Story 2.9, D-S29-4): the register ring captured on FIGHT enter, restored by
## every retry. Boss state (Epic 3) and Echo memory (Epic 4) join it with their stories.
var fight_start_ring: PackedInt32Array = PackedInt32Array()
## Story 7.4 (AC 9, 12, D-S74-1): the "debug build" assist of the current fight attempt, copied from
## SaveService.assist by Game on every FIGHT entry (retries included). A toggle mid-fight applies
## from the next attempt. Main passes it to Arena.enter_fight.
var assist: bool = false


## Modulus of the seed mix: the Mersenne prime 2^31 - 1 (products stay far below 2^63).
const SEED_MOD := 2147483647
const SEED_MUL_A := 48271
const SEED_MUL_B := 16807
const SEED_ROUNDS := 4


## The seed of FIGHT entry `attempt` in the run seeded `run_seed` (Story 3.4, D-S34-2). A pure
## integer mix (no clock, no RNG, no overflow): positive, nonzero, below 2^62. The same pair always
## gives the same seed; consecutive attempts give different ones (the low 31 bits differ). Pure.
static func fight_seed_for(p_run_seed: int, attempt: int) -> int:
	var parts: Array[int] = [p_run_seed & 0x7FFFFFFF, (p_run_seed >> 31) & 0x7FFFFFFF, (p_run_seed >> 62) & 0x3]
	var hi: int = 1
	for part: int in parts:
		hi = (hi * SEED_MUL_A + part) % SEED_MOD
	var lo: int = (hi * SEED_MUL_B + posmod(attempt, SEED_MOD)) % SEED_MOD
	for i: int in SEED_ROUNDS:
		hi = (hi * SEED_MUL_A + lo) % SEED_MOD
		lo = (lo * SEED_MUL_B + hi) % SEED_MOD
	var out: int = (hi << 31) | lo
	return out if out != 0 else 1


## A new boss becomes current (intro, harvest, debug jump; never a retry): deaths start at 0.
func start_boss(index: int) -> void:
	boss_index = index
	deaths_on_boss = 0
