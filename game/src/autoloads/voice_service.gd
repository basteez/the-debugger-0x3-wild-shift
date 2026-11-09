extends Node
## Duck voice entry point (AD-14, ADR-05, Stories 3.6 and 3.7). say() is the only way any duck
## speech starts: it resolves a DuckLinesDef id (or passes raw text through) and emits
## EventBus.duck_line_requested once. DuckBubble shows the line and, after the squeak lead
## (D-S37-6), calls speak_pending() for the line it shows; the voice then reports each spoken
## character and the line's end through EventBus.duck_character_spoken / duck_line_finished.
## Backends (D-S37-2): MUMBLE (the mumble-speech GDExtension, one MumbleSpeaker child), PRERENDER
## (clips from data/duck/duck_clips.tres, AD-14 contingency) and TEXT (silent, the 3.6 behaviour).
## The addon's classes are reached only through ClassDB and call() (D-S37-3), so this script parses
## when the addon is absent. Presentation only: no sim state, no RNG (AD-05, D-S37-10). Declares no
## signal (signals live in event_bus.gd only).

enum Backend { TEXT, MUMBLE, PRERENDER, AUTO }

## The one backend switch (D-S37-2, D-S37-8, D-S37-9): AUTO picks MUMBLE, else PRERENDER, else TEXT.
const BACKEND := Backend.AUTO
const LINES: DuckLinesDef = preload("res://data/duck/duck_lines.tres")
const CLIPS: DuckClipsDef = preload("res://data/duck/duck_clips.tres")
## A MumbleVoice resource: loaded at runtime, and only when the addon class exists (D-S37-3).
const VOICE_PATH := "res://data/duck/duck_voice.tres"
const SPEAKER_CLASS := &"MumbleSpeaker"
const VOICE_BUS := &"Voice"
## Watchdog (D-S37-5, D-S37-13): a spoken line that has not ended after its length at the voice's
## speed plus this slack is cut by stop(), so the bubble never waits on a voice that will not finish.
const WATCHDOG_SLACK_S := 3.0
## Characters per second used for the watchdog when the voice gives none (the 3.6 typewriter rate).
const DEFAULT_CPS := 30.0

## The backend in use, resolved once in _ready() (TEXT until then).
var backend: Backend = Backend.TEXT
## Voice failures warned this run (0 or 1, D-S37-12).
var warn_count: int = 0
## Audio lock gate (D-S37-11): true once AudioManager is unlocked. A seam for tests.
var audio_unlocked: Callable = func() -> bool: return AudioManager.is_unlocked()

## The mumble speaker (a MumbleSpeaker child, or a test fake); null unless MUMBLE.
var _speaker: Object = null
var _voice_cps: float = DEFAULT_CPS
## The pre-render player (an AudioStreamPlayer child on the Voice bus); null unless PRERENDER.
var _prerender_player: AudioStreamPlayer = null
var _clip: DuckClipDef = null
var _clip_elapsed_s: float = 0.0
var _clip_next_char: int = 0
## The line being spoken. A late speaker event for a line that was stopped is ignored.
var _active_id: StringName = &""
var _speaking: bool = false
var _watchdog_s: float = 0.0


func _ready() -> void:
	var class_ok: bool = ClassDB.class_exists(SPEAKER_CLASS)
	var speaker: Node = null
	if BACKEND in [Backend.MUMBLE, Backend.AUTO] and class_ok:
		speaker = _make_speaker()
	var clips_ok: bool = CLIPS != null and not CLIPS.entries.is_empty()
	var resolved: Backend = resolve_backend(BACKEND, class_ok, speaker != null, clips_ok)
	match resolved:
		Backend.MUMBLE:
			use_speaker(speaker)
		Backend.PRERENDER:
			use_prerender()
		_:
			backend = Backend.TEXT
	if speaker != null and resolved != Backend.MUMBLE:
		speaker.free()
	if is_downgrade(BACKEND, resolved):
		warn_once("voice backend %s (requested %s)" % [Backend.find_key(resolved), Backend.find_key(BACKEND)])
	Log.debug(&"voice", "backend %s" % Backend.find_key(backend))


## Backend resolution (D-S37-2). `class_ok`: the MumbleSpeaker class exists; `speaker_ok`: it
## instantiated with its voice; `clips_ok`: the pre-render clips loaded. Pure.
static func resolve_backend(requested: Backend, class_ok: bool, speaker_ok: bool, clips_ok: bool) -> Backend:
	var mumble_ok: bool = class_ok and speaker_ok
	match requested:
		Backend.TEXT:
			return Backend.TEXT
		Backend.MUMBLE:
			return Backend.MUMBLE if mumble_ok else Backend.TEXT
		Backend.PRERENDER:
			return Backend.PRERENDER if clips_ok else Backend.TEXT
	if mumble_ok:
		return Backend.MUMBLE
	return Backend.PRERENDER if clips_ok else Backend.TEXT


## True when `resolved` is worse than what `requested` asked for (one warning, D-S37-12). Pure.
static func is_downgrade(requested: Backend, resolved: Backend) -> bool:
	if requested == Backend.AUTO:
		return resolved != Backend.MUMBLE
	return resolved != requested


## Resolves `line` (a known id, else raw text), requests it once and returns the resolved text.
## The voice does not start here: DuckBubble calls speak_pending() when the line is on screen.
func say(line: String) -> String:
	var entry: DuckLineDef = LINES.find(StringName(line)) if not line.is_empty() else null
	var line_id: StringName = entry.id if entry != null else &""
	var text: String = entry.text if entry != null else line
	if text.is_empty():
		return text # nothing to show or speak
	Log.debug(&"voice", "say %s" % _label(line_id))
	EventBus.duck_line_requested.emit(line_id, text)
	return text


## True when a line started now would be voiced: a voice backend and the audio lock open (D-S37-11).
func can_speak() -> bool:
	return backend != Backend.TEXT and bool(audio_unlocked.call())


## Starts the voice for the line the bubble shows (`text` is the bubble's revealed text). Returns
## true when the voice started, so its events will drive the reveal; false leaves the bubble on its
## own timer (TEXT, audio locked, empty text, no clip for the line, or a failure).
func speak_pending(line_id: StringName, text: String) -> bool:
	if not can_speak() or text.is_empty():
		return false
	if _speaking:
		stop()
	return _speak(line_id, text)


## Cuts any speech in progress: the speech stops at once and duck_line_finished(id, false) is
## emitted once. Nothing happens when no line is speaking.
func stop() -> void:
	if not _speaking:
		return
	var line_id: StringName = _active_id
	_end_line()
	if _speaker != null and is_instance_valid(_speaker):
		_speaker.call(&"stop")
	if _prerender_player != null:
		_prerender_player.stop()
	Log.debug(&"voice", "stop %s" % _label(line_id))
	EventBus.duck_line_finished.emit(line_id, false)


func is_speaking() -> bool:
	return _speaking


func active_id() -> StringName:
	return _active_id


## Backend seam: starts `text` on the resolved backend.
func _speak(line_id: StringName, text: String) -> bool:
	match backend:
		Backend.MUMBLE:
			if _speaker == null or not is_instance_valid(_speaker) or not _speaker.has_method(&"say"):
				_fail("speaker unavailable")
				return false
			_begin_line(line_id, float(text.length()) / _voice_cps)
			_speaker.call(&"say", text)
			return true
		Backend.PRERENDER:
			var clip: DuckClipDef = CLIPS.find(line_id) if line_id != &"" else null
			if clip == null or clip.stream == null or not clip.matches_text(text):
				Log.debug(&"voice", "no clip for %s, text only" % _label(line_id))
				return false
			_clip = clip
			_clip_elapsed_s = 0.0
			_clip_next_char = 0
			_begin_line(line_id, clip.stream.get_length())
			if _prerender_player != null:
				_prerender_player.stream = clip.stream
				_prerender_player.play()
			return true
	return false


func _begin_line(line_id: StringName, expected_s: float) -> void:
	_active_id = line_id
	_speaking = true
	_watchdog_s = expected_s + WATCHDOG_SLACK_S
	Log.debug(&"voice", "speak %s" % _label(line_id))


func _end_line() -> void:
	_speaking = false
	_active_id = &""
	_clip = null


func _process(delta: float) -> void:
	step(delta)


## One presentation step of `delta` seconds (the _process body, callable from tests): drives the
## pre-render reveal times and the watchdog. Wall time, like the addon's own Sample-mode timing.
func step(delta: float) -> void:
	if not _speaking:
		return
	if backend == Backend.PRERENDER and _clip != null:
		var clip := _clip # a listener may call stop() during an emit, which nulls _clip
		_clip_elapsed_s += delta
		while _speaking and _clip_next_char < clip.char_times.size() and clip.char_times[_clip_next_char] <= _clip_elapsed_s:
			_clip_next_char += 1
			EventBus.duck_character_spoken.emit(_clip_next_char - 1)
		if not _speaking:
			return
		if _clip_elapsed_s >= clip.stream.get_length():
			_on_finished()
			return
	_watchdog_s -= delta
	if _watchdog_s <= 0.0:
		Log.debug(&"voice", "watchdog cut %s" % _label(_active_id))
		stop()


## MUMBLE: uses `speaker` (a MumbleSpeaker node, or a test fake with say / stop that calls the
## two callbacks itself). Connects the speaker's character_spoken / finished signals when it has them.
func use_speaker(speaker: Object) -> void:
	backend = Backend.MUMBLE
	_speaker = speaker
	var voice: Variant = speaker.get(&"voice")
	var cps: float = float((voice as Resource).get(&"speed")) if voice is Resource else 0.0
	_voice_cps = cps if cps > 0.0 else DEFAULT_CPS
	if speaker.has_signal(&"character_spoken") and not speaker.is_connected(&"character_spoken", _on_character_spoken):
		speaker.connect(&"character_spoken", _on_character_spoken)
	if speaker.has_signal(&"finished") and not speaker.is_connected(&"finished", _on_finished):
		speaker.connect(&"finished", _on_finished)
	var node := speaker as Node
	if node != null and node.get_parent() == null:
		add_child(node)


## PRERENDER: plays the clips on a `PrerenderPlayer` child on the Voice bus.
func use_prerender() -> void:
	backend = Backend.PRERENDER
	if _prerender_player == null:
		_prerender_player = AudioStreamPlayer.new()
		_prerender_player.name = &"PrerenderPlayer"
		_prerender_player.bus = VOICE_BUS
		add_child(_prerender_player)


## One Log.warn for the whole run (D-S37-12); later failures go to Log.debug.
func warn_once(message: String) -> void:
	if warn_count > 0:
		Log.debug(&"voice", message)
		return
	warn_count += 1
	Log.warn(&"voice", message)


func _make_speaker() -> Node:
	var voice: Resource = load(VOICE_PATH) if ResourceLoader.exists(VOICE_PATH) else null
	if voice == null:
		return null
	var speaker := ClassDB.instantiate(SPEAKER_CLASS) as Node
	if speaker == null:
		return null
	speaker.name = &"MumbleSpeaker"
	speaker.set(&"voice", voice)
	speaker.set(&"bus", VOICE_BUS)
	speaker.set(&"volume_db", 0.0)
	return speaker


## A runtime failure: the line stays silent (the bubble keeps its timer) and the run falls back to TEXT.
func _fail(reason: String) -> void:
	warn_once("voice failed (%s), text only" % reason)
	backend = Backend.TEXT
	_end_line()


func _on_character_spoken(char_index: int) -> void:
	if not _speaking:
		return
	EventBus.duck_character_spoken.emit(char_index)


func _on_finished() -> void:
	if not _speaking:
		return
	var line_id: StringName = _active_id
	_end_line()
	if _prerender_player != null and backend == Backend.PRERENDER:
		_prerender_player.stop()
	EventBus.duck_line_finished.emit(line_id, true)


static func _label(line_id: StringName) -> String:
	return String(line_id) if line_id != &"" else "<raw>"
