class_name FeatureFlags
extends Def
## Cut-ladder switches (AD-12, Story 4.3 D-S43-1). One bool per cuttable module; the shipped
## data/config/feature_flags.tres turns all of them on. Read once at startup by the wiring code
## (Defs.FEATURE_FLAGS), never inside the simulation. A module that is off is never constructed,
## and the GDD fallback for its cut reads the flag (e.g. SIGSEGV recovery 150 frames).
## Must not reference Defs (preload cycle, 4.2 lesson).

## Cut #4: reserved-nibble write (Epic 5).
@export var reserved_write: bool = true
## Cut #2: Watch (Epic 6).
@export var watch: bool = true
## Cut #3: Breakpoint (Story 4.3; `breakpoint` is a GDScript keyword, D-S43-17). Off: no skill, no HUD readout, SIGSEGV recovery 150.
@export var breakpoint_enabled: bool = true
## Cut #1: Segfault boss (Epic 6).
@export var segfault: bool = true


## Plain bools have no invalid values; kept so test_data_validation covers the resource.
func validate() -> PackedStringArray:
	return PackedStringArray()
