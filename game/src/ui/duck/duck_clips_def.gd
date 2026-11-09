class_name DuckClipsDef
extends Def
## The pre-rendered duck lines (Story 3.7, AD-14, F2): data/duck/duck_clips.tres, written by
## tools/render_duck_lines.gd from data/duck/duck_lines.tres and data/duck/duck_voice.tres. Read
## only by VoiceService on the PRERENDER backend. Read-only at runtime.

@export var entries: Array[DuckClipDef] = []


## The entry with `id`, or null when absent.
func find(id: StringName) -> DuckClipDef:
	for entry: DuckClipDef in entries:
		if entry != null and entry.id == id:
			return entry
	return null


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	var seen: Dictionary[StringName, bool] = {}
	for i: int in entries.size():
		var entry: DuckClipDef = entries[i]
		if entry == null:
			out.append("entries[%d] is null" % i)
			continue
		for message: String in entry.validate():
			out.append("entries[%d]: %s" % [i, message])
		if seen.has(entry.id):
			out.append("entries[%d]: duplicate id %s" % [i, entry.id])
		seen[entry.id] = true
	return out
