class_name TextScreenText
extends Def
## The narrative text of the screens (Story 6.9, AC 10, D-S69-1, D-S69-6): the title line, the
## `press any key` prompt (title and harvest), the three Intro caption panels (2 + 2 + 1 rows) and
## the DEAD line. One shared resource so the audit reads one file; the Ending keeps its own
## data/ending/ending_text.tres (6.8, D-S68-8). Lives in data/text/screen_text.tres. ASCII only.

const PANEL_COUNT := 3

@export var title: String = ""
@export var prompt: String = ""
## One PackedStringArray of caption rows per Intro panel.
@export var intro_captions: Array[PackedStringArray] = []
@export var dead_line: String = ""
## Story 7.3 (D-S73-5): the title's new-run option label, shown only with a save past Boss 1.
@export var new_run_label: String = ""
## Story 7.4 (AC 4, D-S74-8): the title's "debug build" assist label, one per state. Neutral wording.
@export var debug_build_on_label: String = ""
@export var debug_build_off_label: String = ""


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if title.is_empty():
		out.append("title must not be empty")
	if prompt.is_empty():
		out.append("prompt must not be empty")
	if dead_line.is_empty():
		out.append("dead_line must not be empty")
	if new_run_label.is_empty():
		out.append("new_run_label must not be empty")
	if debug_build_on_label.is_empty():
		out.append("debug_build_on_label must not be empty")
	if debug_build_off_label.is_empty():
		out.append("debug_build_off_label must not be empty")
	if intro_captions.size() != PANEL_COUNT:
		out.append("intro_captions must hold exactly %d panels, has %d" % [PANEL_COUNT, intro_captions.size()])
	for i: int in intro_captions.size():
		if intro_captions[i].is_empty():
			out.append("intro panel %d has no caption row" % i)
		for row: String in intro_captions[i]:
			if row.is_empty():
				out.append("intro panel %d has an empty row" % i)
	for text: String in all_text():
		if not DuckLineDef.is_ascii(text):
			out.append("text must be printable ASCII: %s" % text)
	return out


## The caption rows of Intro panel `panel` (0-2); none for any other index.
func caption_for(panel: int) -> PackedStringArray:
	if panel < 0 or panel >= intro_captions.size():
		return PackedStringArray()
	return intro_captions[panel]


## Every string this resource holds (font coverage, the audit).
func all_text() -> PackedStringArray:
	var out := PackedStringArray([title, prompt, dead_line, new_run_label, debug_build_on_label, debug_build_off_label])
	for panel: PackedStringArray in intro_captions:
		out.append_array(panel)
	return out
