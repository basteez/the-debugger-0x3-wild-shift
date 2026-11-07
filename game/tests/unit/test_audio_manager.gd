extends GutTest
## Story 1.4 AC4: bus layout and the AudioManager unlock gate.

const AudioManagerScript := preload("res://src/autoloads/audio_manager.gd")


func _playing_players(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		var player := child as AudioStreamPlayer
		if player != null and player.playing:
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
	var player := am.get_child(0) as AudioStreamPlayer
	assert_eq(player.bus, &"SFX")
	am.play_test_sfx()
	assert_eq(am.get_child_count(), 1, "the test SFX player is reused")
	assert_eq(am.get("locked_warn_count"), 0)


func test_blip_is_short_16bit_mono() -> void:
	var blip: AudioStreamWAV = AudioManagerScript.make_blip()
	assert_eq(blip.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_false(blip.stereo)
	assert_eq(blip.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_almost_eq(float(blip.data.size()) / 2.0 / float(blip.mix_rate), 0.15, 0.01)
