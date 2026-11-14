extends GutTest
## Story 1.4 AC4: bus layout and the AudioManager unlock gate.

const AudioManagerScript := preload("res://src/autoloads/audio_manager.gd")


## SFX players only: Story 7.1 adds MusicA / MusicB on unlock (the title track).
func _sfx_players(node: Node) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for child: Node in node.get_children():
		var player := child as AudioStreamPlayer
		if player != null and player.bus != &"Music":
			players.append(player)
	return players


func _playing_players(node: Node) -> int:
	var count: int = 0
	for player: AudioStreamPlayer in _sfx_players(node):
		if player.playing:
			count += 1
	return count


func test_buses_exist() -> void:
	for bus: StringName in [&"Master", &"Music", &"SFX", &"Voice"]:
		assert_gte(AudioServer.get_bus_index(bus), 0, "bus %s missing" % bus)
	assert_eq(AudioServer.bus_count, 4)


func test_non_master_buses_send_to_master() -> void:
	for bus: StringName in [&"Music", &"SFX", &"Voice"]:
		assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)), &"Master", bus)


func test_no_bus_effects() -> void:
	for i: int in AudioServer.bus_count:
		assert_eq(AudioServer.get_bus_effect_count(i), 0, AudioServer.get_bus_name(i))


func test_no_player_at_boot() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	assert_false(am.is_unlocked())
	assert_eq(am.get_child_count(), 0)


func test_play_before_unlock_is_ignored_and_warns_once() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.play_test_sfx()
	am.play_test_sfx()
	assert_eq(_playing_players(am), 0)
	assert_eq(am.get_child_count(), 0)
	assert_true(am.get("_warned_locked"))
	assert_eq(am.get("locked_warn_count"), 1, "exactly one warn per session")


func test_unlock_is_idempotent_and_play_uses_sfx() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.unlock()
	am.unlock()
	assert_true(am.is_unlocked())
	am.play_test_sfx()
	assert_eq(_playing_players(am), 1)
	var player := am.get_node(^"TestSfx") as AudioStreamPlayer
	assert_eq(player.bus, &"SFX")
	am.play_test_sfx()
	assert_eq(_sfx_players(am).size(), 1, "the test SFX player is reused")
	assert_eq(am.get("locked_warn_count"), 0)


# Story 2.4: play_sfx for the shift clicks.
func test_play_sfx_before_unlock_is_ignored_and_warns_once() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.play_sfx(AudioManagerScript.make_blip())
	am.play_sfx(AudioManagerScript.make_blip())
	assert_eq(_playing_players(am), 0)
	assert_eq(am.get_child_count(), 0)
	assert_eq(am.get("locked_warn_count"), 1, "exactly one warn per session")


func test_play_sfx_after_unlock_plays_on_sfx_and_reuses_one_player() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.unlock()
	var stream: AudioStreamWAV = AudioManagerScript.make_blip()
	am.play_sfx(stream)
	assert_eq(_playing_players(am), 1)
	var player := am.get_node(^"ShiftSfx") as AudioStreamPlayer
	assert_eq(player.bus, &"SFX")
	assert_eq(player.stream, stream)
	var other: AudioStreamWAV = AudioManagerScript.make_blip()
	am.play_sfx(other)
	assert_eq(_sfx_players(am).size(), 1, "a rapid second click restarts the same player")
	assert_eq(player.stream, other)
	assert_true(player.playing)
	assert_eq(am.get("locked_warn_count"), 0)


func test_blip_is_short_16bit_mono() -> void:
	var blip: AudioStreamWAV = AudioManagerScript.make_blip()
	assert_eq(blip.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_false(blip.stereo)
	assert_eq(blip.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_almost_eq(float(blip.data.size()) / 2.0 / float(blip.mix_rate), 0.15, 0.01)


# Story 1.7 AC3: session mute on the Master bus.
var _master_was_muted: bool = false


func before_each() -> void:
	_master_was_muted = AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master"))


func after_each() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), _master_was_muted)


func test_master_mute_toggles_the_master_bus() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	var master: int = AudioServer.get_bus_index(&"Master")
	am.set_master_muted(true)
	assert_true(AudioServer.is_bus_mute(master))
	assert_true(am.is_master_muted())
	am.set_master_muted(true)
	assert_true(am.is_master_muted(), "muting twice keeps it muted")
	am.set_master_muted(false)
	assert_false(AudioServer.is_bus_mute(master))
	assert_false(am.is_master_muted())
	for bus: StringName in [&"Music", &"SFX", &"Voice"]:
		assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)), "%s untouched" % bus)


# Story 3.2 (AC 3, AC 5, D-S32-17): placeholder thud and chime, built once in _ready.
func test_unpatched_boss_hit_plays_the_thud_and_patched_plays_the_chime() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.unlock()
	var thud: AudioStreamWAV = am.get("_thud")
	var chime: AudioStreamWAV = am.get("_chime")
	assert_not_null(thud)
	assert_not_null(chime)
	assert_gt(thud.data.size(), 0)
	assert_gt(chime.data.size(), 0)
	EventBus.hit_landed.emit(&"practice_target", 10, DamageState.Kind.BASE, false, Vector2.ZERO)
	EventBus.hit_landed.emit(&"boss", 15, DamageState.Kind.PATCHED, false, Vector2.ZERO)
	assert_null(am.get_node_or_null(^"ShiftSfx"), "no thud for practice or Patched hits")
	EventBus.hit_landed.emit(&"boss", 5, DamageState.Kind.UNPATCHED, false, Vector2.ZERO)
	var player := am.get_node(^"ShiftSfx") as AudioStreamPlayer
	assert_eq(player.stream, thud)
	EventBus.patched_applied.emit(&"test_boss", 180)
	assert_eq(player.stream, chime)
	assert_same(am.get("_thud"), thud, "cached, not rebuilt per hit")
