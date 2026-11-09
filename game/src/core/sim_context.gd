class_name SimContext
extends RefCounted
## Shared simulation context passed to every SimSystem.tick (AD-01).
## Holds the one seeded RNG: all simulation randomness comes from `rng`, never the global RNG.

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The held direction for the current polled frame (Story 2.2, D-S22-3), components in {-1, 0, 1}.
## Set by SimClock before the systems tick; read-only for systems.
var move_dir: Vector2i = Vector2i.ZERO


## Reseeds the RNG (fight start, retry). The same seed always gives the same sequence.
func reseed(seed_value: int) -> void:
	rng.seed = seed_value
