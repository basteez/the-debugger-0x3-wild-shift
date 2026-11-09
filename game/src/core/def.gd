class_name Def
extends Resource
## Base of every `*Def` data resource (architecture: typed defs in data/**/*.tres, read-only at
## runtime). Subclasses override validate(); test_data_validation.gd asserts it is empty for
## every shipped .tres.


## Human-readable problems with this def's values; empty when the def is valid.
func validate() -> PackedStringArray:
	return PackedStringArray()
