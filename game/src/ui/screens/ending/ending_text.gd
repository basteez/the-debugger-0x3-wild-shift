class_name EndingText
extends Def
## Every piece of game text the Ending draws (Story 6.8, AC 18, D-S68-8): the caption, the desk art
## rows, the register cells and the `0xFF` caption, the commit row, the stretch summary labels, the
## credit lines and the prompt. Lives in data/ending/ending_text.tres so the 6.9 text audit reads it
## without reading scripts; ending_screen.gd holds no game text literal.
## ASCII only (the glyph font covers printable ASCII; test_font_coverage checks every field).

## Credit lines are drawn at 1x, centred, right of the HUD duck region (cols 0-11): at most
## (640 - 2 * 96) / 8 = 56 columns.
const MAX_CREDIT_CHARS := 56
## The commit row is drawn at 2x on the 640-px base: at most 40 columns, hash and message together.
const MAX_COMMIT_ROW_CHARS := 40

## Top caption, from the first frame (GDD Ending: the developer is back at the desk).
@export var caption: String = "the next morning"
## Desk panel art rows (2x): the developer and the duck on the desk.
@export var desk_rows: PackedStringArray = PackedStringArray()
## The register cells: a set bit and a clear bit (the reserved nibble lights to `1111`).
@export var cell_on: String = "1"
@export var cell_off: String = "0"
## Shown once the reserved nibble is full (GDD: `0xFF` at the ending).
@export var full_caption: String = "0xFF"
## The commit beat: a git-log row, the hash shown at once, the message typed (D-S68-2).
@export var commit_hash: String = ""
@export var commit_message: String = "fix: wild shift"
## The typing cursor after the commit message (blinks; presentation only).
@export var cursor: String = "_"
## [STRETCH] Summary card labels (FeatureFlags.ending_summary, AC 14).
@export var clear_label: String = "CLEAR"
@export var hits_label: String = "HITS"
## The credits block (AC 13, D-S68-10): one static block. The audio line is a placeholder until
## Stories 7.1 / 7.2 choose the final sources (7.9 replaces it before submission).
@export var credit_lines: PackedStringArray = PackedStringArray()
@export var prompt: String = "press any key"


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if commit_message.is_empty():
		out.append("commit_message must not be empty")
	if credit_lines.is_empty():
		out.append("credit_lines must have at least one line")
	for line: String in credit_lines:
		if line.length() > MAX_CREDIT_CHARS:
			out.append("credit line wider than %d columns: %s" % [MAX_CREDIT_CHARS, line])
	if commit_row(commit_hash, commit_message).length() > MAX_COMMIT_ROW_CHARS:
		out.append("commit row wider than %d columns" % MAX_COMMIT_ROW_CHARS)
	if cell_on.length() != 1 or cell_off.length() != 1:
		out.append("cell_on and cell_off must be one glyph each")
	for text: String in all_text():
		if not DuckLineDef.is_ascii(text):
			out.append("text must be printable ASCII: %s" % text)
	return out


## Pure: the full git-log row (`<hash> <message>`); the message alone when there is no hash.
static func commit_row(hash: String, message: String) -> String:
	return message if hash.is_empty() else hash + " " + message


## Every string this resource holds (font coverage, the 6.9 audit, validate()).
func all_text() -> PackedStringArray:
	var out := PackedStringArray([caption, cell_on, cell_off, full_caption, commit_hash, commit_message,
			cursor, clear_label, hits_label, prompt])
	out.append_array(desk_rows)
	out.append_array(credit_lines)
	return out
