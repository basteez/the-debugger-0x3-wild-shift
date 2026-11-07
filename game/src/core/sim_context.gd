class_name SimContext
extends RefCounted
## Shared simulation context passed to every SimSystem.tick (AD-01).
## Holds the one seeded RNG: all simulation randomness comes from `rng`, never the global RNG.

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Reseeds the RNG (fight start, retry). The same seed always gives the same sequence.
func reseed(seed_value: int) -> void:
	rng.seed = seed_value
