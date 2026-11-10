class_name ComboDef
extends Def
## One ordered combo (Story 2.6, AD-02): the window (first, second) that fires it, the ActionDef
## that replaces K's solo action, and the HUD name. Read-only at runtime. The cooldown is not stored
## here: the second bit's solo cooldown applies (D-S26-3).

## GDD: combo names are at most 11 characters.
const NAME_MAX_CHARS := 11
const DEFS_PATH := "res://src/core/defs.gd"

## Register.Bit of J (ring[0]).
@export var first: int = 0
## Register.Bit of K (ring[1]).
@export var second: int = 0
@export var action: ActionDef
@export var display_name: String = ""
## Story 4.2 (D-S42-4 resolved by the coordinator, D-S42-11): the combo starts only on a tick where the
## running action's last executed frame is invulnerable, and replaces that action at once (even
## during its ACTIVE frames). So no executed frame between the first action and the combo is
## vulnerable. A K press on the window outside that rule is consumed and dropped (no hold, no
## link_second fallback). Echo Dash (D->L) sets it; Dash Strike does not.
@export var gap_free: bool = false


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
	# Story 4.2 (D-S42-8, the 2.6 deferred checks): K's bit has a solo action to replace, the combo
	# action carries no cooldown of its own (D-S26-3), and a K buffered with J stays live until the
	# link opens (J's solo startup + 1 <= the 8-frame press lifetime).
	if Register.is_bit(second) and _solo_action(second) == null:
		out.append("second bit %d has no solo action to replace" % second)
	if action != null and action.cooldown_frames != 0:
		out.append("action cooldown_frames must be 0, the replaced solo's cooldown applies (got %d)" % action.cooldown_frames)
	var first_solo: ActionDef = _solo_action(first) if Register.is_bit(first) else null
	if first_solo != null and first_solo.startup_frames + 1 > InputBuffer.PRESS_LIFETIME_FRAMES:
		out.append("first bit's solo startup %d + 1 exceeds the %d-frame press lifetime" % [first_solo.startup_frames, InputBuffer.PRESS_LIFETIME_FRAMES])
	if gap_free and (action == null or action.invuln_from != 1):
		out.append("a gap_free combo's action must be invulnerable from its frame 1")
	if display_name.length() < 1 or display_name.length() > NAME_MAX_CHARS:
		out.append("display_name must be 1-%d characters (got '%s')" % [NAME_MAX_CHARS, display_name])
	return out


## Defs.solo_action(bit), looked up at call time: Defs preloads the combo table, which uses this
## script, so a parse-time reference to Defs here would be a preload cycle (Story 4.2).
static func _solo_action(bit: int) -> ActionDef:
	var defs: GDScript = load(DEFS_PATH) as GDScript
	return defs.call(&"solo_action", bit) as ActionDef if defs != null else null
