extends Node
## Audio playback gate (AD-09). Nothing plays before the first user input: the title screen
## calls unlock() on that input. Buses come from res://default_bus_layout.tres, not from code.
## Music crossfade and pooled SFX arrive with the real assets (7.1, 7.2).

const SFX_BUS := &"SFX"
const MASTER_BUS := &"Master"
const BLIP_HZ := 880.0
const BLIP_SECONDS := 0.15
const BLIP_MIX_RATE := 22050
const BLIP_AMPLITUDE := 0.4

## Number of "play ignored before unlock" warnings written this session (0 or 1).
var locked_warn_count: int = 0

var _unlocked: bool = false
var _warned_locked: bool = false
var _sfx_player: AudioStreamPlayer = null
## The one player for gameplay SFX (Story 2.4 shift clicks); a new play cuts the previous one.
var _shift_player: AudioStreamPlayer = null
## Placeholder boss tell cue (Story 3.1, D-S31-16), built in _ready so no tell hitches the sim tick. 7.2 maps tell_sfx ids
## to real streams.
var _tell_blip: AudioStreamWAV = null


func _ready() -> void:
	_tell_blip = make_blip()
	EventBus.boss_tell_started.connect(_on_boss_tell_started)


## Story 3.1 (AC 4): every boss tell plays its cue on the SFX bus. Presentation only.
func _on_boss_tell_started(_attack_id: StringName, _tell_sfx: StringName) -> void:
	play_sfx(_tell_blip)


func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	Log.info(&"audio", "unlocked")


func is_unlocked() -> bool:
	return _unlocked


## Master bus mute for the session (Story 1.7 AC3, DC8). AudioServer holds the value, so the
## save service (7.3) can read it back; nothing is written to disk here. Logs once per change.
func set_master_muted(muted: bool) -> void:
	var bus: int = AudioServer.get_bus_index(MASTER_BUS)
	if bus < 0 or AudioServer.is_bus_mute(bus) == muted:
		return
	AudioServer.set_bus_mute(bus, muted)
	Log.info(&"audio", "master %s" % ("muted" if muted else "unmuted"))


func is_master_muted() -> bool:
	var bus: int = AudioServer.get_bus_index(MASTER_BUS)
	return bus >= 0 and AudioServer.is_bus_mute(bus)


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


## Plays `stream` on the SFX bus (Story 2.4 shift click, D-S24-8). Ignored before unlock. One
## lazily created player: a rapid second call restarts it (pooling is Story 7.2).
func play_sfx(stream: AudioStream) -> void:
	if not _unlocked:
		_warn_locked_once()
		return
	if stream == null:
		return
	if _shift_player == null:
		_shift_player = AudioStreamPlayer.new()
		_shift_player.name = &"ShiftSfx"
		_shift_player.bus = SFX_BUS
		add_child(_shift_player)
	_shift_player.stream = stream
	_shift_player.play()


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
