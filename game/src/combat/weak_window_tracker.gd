class_name WeakWindowTracker
extends RefCounted
## The boss's Patched state (Story 3.2, FR21, GDD D-017, NP-4, D-S32-3). The only writer of
## Patched: owned by BossController as `weak_window`, ticked by it in BOSS_HAZARDS (sim frames
## only), applied by CombatResolver in COMBAT through process() + apply_patched(), before the
## hit's damage is computed. Re-applying refreshes to PATCHED_FRAMES, never stacks (D-S32-4).

## Patched length in sim frames (FR21).
const PATCHED_FRAMES := 180

## Frames of Patched left; 0 = not Patched.
var frames_left: int = 0


## Sets Patched to `frames` (refresh, not add).
func apply_patched(frames: int = PATCHED_FRAMES) -> void:
	frames_left = maxi(frames, 0)


func is_patched() -> bool:
	return frames_left > 0


## One sim frame: counts down to 0 and stays there.
func tick() -> void:
	if frames_left > 0:
		frames_left -= 1


func clear() -> void:
	frames_left = 0


## True when any interaction completes the weak window `weak`. Pure: the caller applies Patched
## and emits EventBus.patched_applied.
static func process(interactions: Array[BossInteraction], weak: Vector2i) -> bool:
	for i: BossInteraction in interactions:
		if BossInteraction.completes_weak_window(i, weak):
			return true
	return false
