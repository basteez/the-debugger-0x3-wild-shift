extends Node2D
## Story 1.3 day-1 smoke test (AD-09): a generated tone on an AudioStreamPlayer2D, panned
## left and right every 2 s after the first click or key. Opened only by main.gd with
## ?debug&smoke=audio on web. Presentation/debug code, so await and create_timer are allowed.

const TONE_HZ := 440.0
const TONE_SECONDS := 1.0
const MIX_RATE := 22050
const STEP_SECONDS := 2.0
const PAN_OFFSET_PX := 300.0
const AMPLITUDE := 0.5
const SFX_BUS := &"SFX"

var _started: bool = false
var _step: int = 0

@onready var _player: AudioStreamPlayer2D = $Tone
@onready var _label: Label = $Side


## 16-bit mono sine, looping forward over the whole buffer. Not an AudioStreamGenerator (Sample mode).
static func make_tone(hz: float, seconds: float, mix_rate: int) -> AudioStreamWAV:
	var frames: int = int(seconds * mix_rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i: int in frames:
		var sample: float = sin(TAU * hz * float(i) / float(mix_rate)) * AMPLITUDE
		data.encode_s16(i * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = mix_rate
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	return wav


static func side_for_step(step: int) -> String:
	return "L" if step % 2 == 0 else "R"


static func position_for_step(step: int) -> Vector2:
	return Vector2(-PAN_OFFSET_PX if step % 2 == 0 else PAN_OFFSET_PX, 0.0)


func _ready() -> void:
	var view: Vector2 = get_viewport_rect().size
	position = view * 0.5
	_label.text = "click to start the audio pan test"
	Log.info(&"smoke", "audio pan smoke ready, waiting for input")


func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	var mouse := event as InputEventMouseButton
	var key := event as InputEventKey
	if (mouse != null and mouse.pressed) or (key != null and key.pressed):
		_started = true
		get_viewport().set_input_as_handled()
		_start()


func _start() -> void:
	_player.stream = make_tone(TONE_HZ, TONE_SECONDS, MIX_RATE)
	# Use the SFX bus when the layout has one (AudioManager owns the layout); otherwise Master.
	_player.bus = SFX_BUS if AudioServer.get_bus_index(SFX_BUS) != -1 else &"Master"
	_apply_step()
	_player.play()
	Log.info(&"smoke", "audio pan smoke started on bus %s" % _player.bus)
	_run_pan_loop()


func _run_pan_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(STEP_SECONDS).timeout
		if not is_inside_tree():
			return
		_step += 1
		_apply_step()


func _apply_step() -> void:
	_player.position = position_for_step(_step)
	_label.text = side_for_step(_step)
	Log.info(&"smoke", "pan %s" % _label.text)
