class_name TextFixedLines
extends Def
## The audited list of the three bosses' fixed lines (Story 6.9, AC 6, 9, D-S69-2, D-S69-7; GDD Boss
## Design "Fixed line on defeat"). BossDef.fixed_line stays the runtime source the boss wiring and
## HarvestScreen.setup read; test_text_audit.gd asserts the two agree. `fallback` is the HARVEST
## row shown only when a boss has no fixed line (a debug fight); it is not one of the 3 GDD lines.
## Lives in data/text/fixed_lines.tres. ASCII only.

const BOSS_COUNT := 3
const BOSS_IDS: Array[StringName] = [&"infinite_loop", &"null_pointer", &"segfault"]

## Boss id -> fixed line, one per boss.
@export var entries: Dictionary[StringName, String] = {}
@export var fallback: String = ""


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if entries.size() != BOSS_COUNT:
		out.append("entries must hold exactly %d fixed lines, has %d" % [BOSS_COUNT, entries.size()])
	for boss_id: StringName in BOSS_IDS:
		if not entries.has(boss_id):
			out.append("no fixed line for boss %s" % boss_id)
	for id: StringName in entries:
		if not BOSS_IDS.has(id):
			out.append("unknown boss id %s" % id)
		if entries[id].is_empty():
			out.append("fixed line for %s must not be empty" % id)
	if fallback.is_empty():
		out.append("fallback must not be empty")
	for text: String in all_text():
		if not DuckLineDef.is_ascii(text):
			out.append("text must be printable ASCII: %s" % text)
	return out


## The fixed line of `boss_id`, "" when the boss has none.
func line_for(boss_id: StringName) -> String:
	return entries.get(boss_id, "")


## Every string this resource holds (font coverage, the audit).
func all_text() -> PackedStringArray:
	var out := PackedStringArray(entries.values())
	out.append(fallback)
	return out
