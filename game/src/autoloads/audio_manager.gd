extends Node
## Audio playback gate (AD-09). Nothing plays before the first user input: the title screen
## calls unlock() on that input. Buses come from res://default_bus_layout.tres, not from code.
## Music crossfade and pooled SFX arrive with the real assets (7.1, 7.2).

const SFX_BUS := &"SFX"
const BLIP_HZ := 880.0
const BLIP_SECONDS := 0.15
const BLIP_MIX_RATE := 22050
const BLIP_AMPLITUDE := 0.4

## Number of "play ignored before unlock" warnings written this session (0 or 1).
var locked_warn_count: int = 0

var _unlocked: bool = false
var _warned_locked: bool = false
var _sfx_player: AudioStreamPlayer = null


func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	Log.info(&"audio", "unlocked")


func is_unlocked() -> bool:
	return _unlocked


## Story 1.4 test SFX (DC4): a generated blip on the SFX bus. Ignored before unlock.
func play_test_sfx() -> void:
	if not _unlocked:
		_warn_locked_once()
		return
	if _sfx_player == null:
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.name = &"TestSfx"
		_sfx_player.bus = SFX_BUS
		_sfx_player.stream = make_blip()
		add_child(_sfx_player)
	_sfx_player.play()


## 16-bit mono sine blip, no loop, short linear fade-out to avoid a click.
static func make_blip() -> AudioStreamWAV:
	var frames: int = int(BLIP_SECONDS * BLIP_MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i: int in frames:
		var fade: float = 1.0 - float(i) / float(frames)
		var sample: float = sin(TAU * BLIP_HZ * float(i) / float(BLIP_MIX_RATE)) * BLIP_AMPLITUDE * fade
		data.encode_s16(i * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = BLIP_MIX_RATE
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	wav.data = data
	return wav


func _warn_locked_once() -> void:
	if _warned_locked:
		return
	_warned_locked = true
	locked_warn_count += 1
	Log.warn(&"audio", "play ignored before unlock")
