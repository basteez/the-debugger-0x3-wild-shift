class_name NullPointerHum
extends AudioStreamPlayer2D
## The Null Pointer's looping hum (Story 5.1, AC 1, AC 11, AC 13, AD-09): a child of the BossView
## (arena-local px), so its position is the boss's body_center_px and the 2D panning follows the
## ghost's x. Presentation only: sync_to() reads the boss after SimClock's tick of the same physics
## frame and never writes it. Plays while the fight is live (the boss is a live NullPointerBody,
## audio unlocked, not paused); stops on leave (the view's boss becomes null), defeat and pause.
## D-S51-3: the stream is generated in code at load (a low drone with a slow beat), no asset; the
## music pass (Epic 7) replaces it. Story 5.1: this node alone uses Stream playback (AD-09 fallback,
## see the story's Completion Notes); everything else keeps the project's Sample default on web.

const HUM_HZ := 110.0
## A second partial 1 Hz higher: the slow beat that makes the drone wobble.
const BEAT_HZ := 111.0
## A slow tremolo, in Hz. Every frequency is a whole number of cycles in the loop: seamless.
const TREMOLO_HZ := 2.0
const LOOP_SECONDS := 1
const MIX_RATE := 22050
const AMPLITUDE := 0.35
const SFX_BUS := &"SFX"

## The generated loop, built once per session (never in a sim tick).
static var _stream: AudioStreamWAV = null


func _init() -> void:
	name = &"NullPointerHum"
	if _stream == null:
		_stream = make_hum()
	stream = _stream
	playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	bus = SFX_BUS


func _ready() -> void:
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		bus = &"Master"


## Follows `p_boss` (any BossController or null): position on its body, and the hum on while it is a
## live Null Pointer. Called once per physics frame by the BossView, and by tests per tick.
func sync_to(p_boss: BossController) -> void:
	var body := p_boss as NullPointerBody
	if body != null:
		position = body.body_center_px
	var on: bool = should_play(body, AudioManager.is_unlocked(), SimClock.paused)
	if on and not playing:
		play()
	elif not on and playing:
		stop()


## True when the hum should sound (AC 13). Pure.
static func should_play(body: NullPointerBody, unlocked: bool, paused: bool) -> bool:
	return body != null and body.alive() and unlocked and not paused


## 16-bit mono loop of LOOP_SECONDS: two close sines (HUM_HZ, BEAT_HZ) under a slow tremolo,
## looping forward over the whole buffer (D-S51-3).
static func make_hum() -> AudioStreamWAV:
	var frames: int = LOOP_SECONDS * MIX_RATE
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i: int in frames:
		var t: float = float(i) / float(MIX_RATE)
		var tremolo: float = 0.75 + 0.25 * sin(TAU * TREMOLO_HZ * t)
		var sample: float = (sin(TAU * HUM_HZ * t) + sin(TAU * BEAT_HZ * t)) * 0.5 * AMPLITUDE * tremolo
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = MIX_RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	return wav
