class_name TextSkyComments
extends Def
## The HUD sky row comments (Story 6.9, AC 7, 8; GDD Art Style sky comment list, FR56): the default
## (the Infinite Loop and every fight without its own comment, no boss included), the Null Pointer's
## and the Segfault's. Hud reads them through Hud.SKY / SKY_NULL_POINTER / SKY_SEGFAULT and
## Hud.sky_for. Lives in data/text/sky_comments.tres. ASCII only, at most MAX_CHARS wide (the audit test asserts <= Hud.COLS).

const MAX_CHARS := 80

@export var default_comment: String = ""
@export var null_pointer: String = ""
@export var segfault: String = ""


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	for text: String in all_text():
		if text.is_empty():
			out.append("sky comments must not be empty")
		elif text.length() > MAX_CHARS:
			out.append("sky comment wider than %d columns: %s" % [MAX_CHARS, text])
		if not DuckLineDef.is_ascii(text):
			out.append("text must be printable ASCII: %s" % text)
	return out


## Every comment (font coverage, the audit).
func all_text() -> PackedStringArray:
	return PackedStringArray([default_comment, null_pointer, segfault])
