class_name DuckLinesDef
extends Def
## The duck's line catalogue (Story 3.6, D-S36-3): data/duck/duck_lines.tres. It grows by entries
## as later stories add their lines (ten in total, D-039). Read-only at runtime.

@export var entries: Array[DuckLineDef] = []


## The entry with `id`, or null when absent.
func find(id: StringName) -> DuckLineDef:
	for entry: DuckLineDef in entries:
		if entry != null and entry.id == id:
			return entry
	return null


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	var seen: Dictionary[StringName, bool] = {}
	for i: int in entries.size():
		var entry: DuckLineDef = entries[i]
		if entry == null:
			out.append("entries[%d] is null" % i)
			continue
		for message: String in entry.validate():
			out.append("entries[%d]: %s" % [i, message])
		if seen.has(entry.id):
			out.append("entries[%d]: duplicate id %s" % [i, entry.id])
		seen[entry.id] = true
	return out
