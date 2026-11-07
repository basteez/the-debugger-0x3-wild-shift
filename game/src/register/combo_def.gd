class_name ComboDef
extends Def
## One ordered combo (Story 2.6, AD-02): the window (first, second) that fires it, the ActionDef
## that replaces K's solo action, and the HUD name. Read-only at runtime. The cooldown is not stored
## here: the second bit's solo cooldown applies (D-S26-3).

## GDD: combo names are at most 11 characters.
const NAME_MAX_CHARS := 11

## Register.Bit of J (ring[0]).
@export var first: int = 0
## Register.Bit of K (ring[1]).
@export var second: int = 0
@export var action: ActionDef
@export var display_name: String = ""


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if not Register.is_bit(first):
		out.append("first must be a Register.Bit (got %d)" % first)
	if not Register.is_bit(second):
		out.append("second must be a Register.Bit (got %d)" % second)
	if first == second:
		out.append("first and second must differ (got %d)" % first)
	if action == null:
		out.append("action must be set")
	else:
		for message: String in action.validate():
			out.append("action: %s" % message)
	if display_name.length() < 1 or display_name.length() > NAME_MAX_CHARS:
		out.append("display_name must be 1-%d characters (got '%s')" % [NAME_MAX_CHARS, display_name])
	return out
