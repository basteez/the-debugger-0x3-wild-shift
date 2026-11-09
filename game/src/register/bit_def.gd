class_name BitDef
extends Def
## One register bit's data (Story 2.5, AD-02): its id, glyph and solo action. Read-only at runtime.

## A Register.Bit value.
@export var id: int = 0
@export var glyph: String = ""
## The action started by J/K when this bit sits in the slot (FR10, FR11).
@export var solo_action: ActionDef


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if not Register.is_bit(id):
		out.append("id must be a Register.Bit (got %d)" % id)
	if glyph.length() != 1:
		out.append("glyph must be one character (got '%s')" % glyph)
	if solo_action == null:
		out.append("solo_action must be set")
	return out
