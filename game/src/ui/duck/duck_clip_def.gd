class_name DuckClipDef
extends Def
## One pre-rendered duck line (Story 3.7, AD-14 pre-render contingency, F2): the DuckLinesDef id,
## its clip (rendered by tools/render_duck_lines.gd) and, for each character of the spoken text
## (the line's joined wrapped text, D-S36-16), the clip time in seconds at which the bubble shows it.

@export var id: StringName = &""
@export var stream: AudioStreamWAV = null
@export var char_times: PackedFloat32Array = PackedFloat32Array()


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if id == &"":
		out.append("id must not be empty")
	if stream == null:
		out.append("stream must not be empty (%s)" % id)
	elif stream.get_length() <= 0.0:
		out.append("stream is an empty clip (%s)" % id)
	if char_times.is_empty():
		out.append("char_times must not be empty (%s)" % id)
	for i: int in range(1, char_times.size()):
		if char_times[i] < char_times[i - 1]:
			out.append("char_times must not decrease (%s, index %d)" % [id, i])
			break
	return out


## True when char_times has one entry per character of `text` (the line text it was rendered from).
func matches_text(text: String) -> bool:
	return char_times.size() == text.length()


## The reveal time of every character of `text` from a mumble render's events (each event:
## char_index and start, letters only; spaces and punctuation have no event). A character shows
## when the first spoken character at or after it starts, which is what the live backend does
## (set_revealed(char_index + 1) reveals everything up to the spoken letter); characters after the
## last event show at `duration`. Pure.
static func char_times_from_events(text_length: int, events: Array, duration: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(text_length, 0))
	var next_time: float = duration
	var starts: Dictionary[int, float] = {}
	for e: Variant in events:
		var event := e as Dictionary
		if event == null or not event.has("char_index") or not event.has("start"):
			continue
		starts[int(event["char_index"])] = float(event["start"])
	for i: int in range(text_length - 1, -1, -1):
		if starts.has(i):
			next_time = starts[i]
		out[i] = next_time
	return out
