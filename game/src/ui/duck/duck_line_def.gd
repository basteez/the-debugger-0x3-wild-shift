class_name DuckLineDef
extends Def
## One duck line (Story 3.6, D-S36-3): a stable snake_case id and its ASCII text. The text must
## fit the bubble: no word wider than DuckBubble.WRAP_WIDTH, at most DuckBubble.MAX_LINES lines.
## Story 4.4 (D-S44-10): EXTRA_GLYPHS lists the non-ASCII glyphs a line may use (the hint's arrow;
## the font draws it, test_font_coverage checks every line).

const EXTRA_GLYPHS := "→"

@export var id: StringName = &""
@export var text: String = ""


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if id == &"":
		out.append("id must not be empty")
	if text.is_empty():
		out.append("text must not be empty")
		return out
	if not is_drawable(text):
		out.append("text must be ASCII or EXTRA_GLYPHS only (%s)" % id)
	for word: String in text.split(" ", false):
		if word.length() > DuckBubble.WRAP_WIDTH:
			out.append("word '%s' is wider than %d columns" % [word, DuckBubble.WRAP_WIDTH])
	var lines: int = DuckBubble.wrap(text, DuckBubble.WRAP_WIDTH).size()
	if lines > DuckBubble.MAX_LINES:
		out.append("text wraps to %d lines (max %d)" % [lines, DuckBubble.MAX_LINES])
	return out


## True when every character of `s` is printable ASCII (0x20..0x7E). Pure.
static func is_ascii(s: String) -> bool:
	for i: int in s.length():
		var c: int = s.unicode_at(i)
		if c < 0x20 or c > 0x7E:
			return false
	return true


## True when every character of `s` is printable ASCII or one of EXTRA_GLYPHS. Pure.
static func is_drawable(s: String) -> bool:
	for i: int in s.length():
		var c: int = s.unicode_at(i)
		if (c < 0x20 or c > 0x7E) and not EXTRA_GLYPHS.contains(s[i]):
			return false
	return true
