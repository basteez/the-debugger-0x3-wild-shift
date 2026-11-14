extends GutTest
## Story 1.4 AC4: bus layout and the AudioManager unlock gate.

const AudioManagerScript := preload("res://src/autoloads/audio_manager.gd")
const GameFlow := preload("res://src/autoloads/game.gd")


## SFX players only: Story 7.1 adds MusicA / MusicB on unlock (the title track).
func _sfx_players(node: Node) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for child: Node in node.get_children():
		var player := child as AudioStreamPlayer
		if player != null and player.bus != &"Music" and not String(player.name).begins_with(AudioManagerScript.SFX_POOL_PREFIX):
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


# Story 7.2 (AC 5, D-S72-6): boss hits by state, the Patched chime, the player hit; all pooled.
func _pool_streams(am: Node) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for player: AudioStreamPlayer in am.pool_players():
		if player.playing:
			out.append(player.stream)
	return out


func test_hit_cues_by_damage_state() -> void:
	assert_eq(AudioManagerScript.hit_cue(&"boss", DamageState.Kind.BASE), &"hit")
	assert_eq(AudioManagerScript.hit_cue(&"boss", DamageState.Kind.UNPATCHED), &"hit_resisted")
	assert_eq(AudioManagerScript.hit_cue(&"boss", DamageState.Kind.PATCHED), &"", "Patched: the chime only")
	assert_eq(AudioManagerScript.hit_cue(&"practice_target", DamageState.Kind.BASE), &"")


func test_boss_hits_patched_chime_and_player_hit_play_on_the_pool() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.unlock()
	EventBus.hit_landed.emit(&"practice_target", 10, DamageState.Kind.BASE, false, Vector2.ZERO)
	EventBus.hit_landed.emit(&"boss", 15, DamageState.Kind.PATCHED, false, Vector2.ZERO)
	assert_eq(_pool_streams(am).size(), 0, "no sound for practice or Patched hits")
	EventBus.hit_landed.emit(&"boss", 5, DamageState.Kind.BASE, false, Vector2.ZERO)
	assert_eq(am.last_cue, &"hit")
	EventBus.hit_landed.emit(&"boss", 5, DamageState.Kind.UNPATCHED, false, Vector2.ZERO)
	assert_eq(am.last_cue, &"hit_resisted")
	EventBus.patched_applied.emit(&"test_boss", 180)
	assert_eq(am.last_cue, &"patched_chime")
	EventBus.player_damaged.emit(2)
	assert_eq(am.last_cue, &"player_hit")
	var playing: Array[AudioStream] = _pool_streams(am)
	for id: StringName in [&"hit", &"hit_resisted", &"patched_chime", &"player_hit"]:
		assert_true(playing.has(AudioManagerScript.CUES[id]), "%s plays, nothing cut" % id)
	assert_null(am.get_node_or_null(^"ShiftSfx"), "the pool never uses ShiftSfx")
	for player: AudioStreamPlayer in am.pool_players():
		assert_eq(player.bus, &"SFX")


# Story 7.2 (AC 3, D-S72-10): tells play their boss cue; an unknown id is silent and warns once.
func test_tell_cue_by_id_and_unknown_id_warns_once() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.unlock()
	for id: StringName in AudioManagerScript.BOSS_TELL_CUES:
		EventBus.boss_tell_started.emit(&"some_attack", id)
		assert_eq(am.last_cue, id)
	am.last_cue = &""
	EventBus.boss_tell_started.emit(&"pulse", &"tell_test")
	EventBus.boss_tell_started.emit(&"pulse", &"tell_test")
	assert_eq(am.last_cue, &"", "no fallback blip")
	assert_eq(am.unknown_cue_warn_count, 1, "one warn per unknown id")
	EventBus.boss_tell_started.emit(&"other", &"tell_other")
	assert_eq(am.unknown_cue_warn_count, 2)


# Story 7.2 (AC 4, D-S72-5): glitch on phase entries 1 and 2 of the current boss, roar, defeat.
func test_phase_glitch_roar_and_defeat() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.unlock()
	am.on_music_flow_changed(GameFlow.FlowState.TITLE, GameFlow.FlowState.FIGHT, 1)
	am.on_boss_phase_changed(0)
	assert_eq(am.last_cue, &"", "phase 0 is the fight start: no glitch")
	am.on_boss_phase_changed(1)
	assert_eq(am.last_cue, &"glitch_null_pointer")
	am.last_cue = &""
	am.on_boss_phase_changed(2)
	assert_eq(am.last_cue, &"glitch_null_pointer")
	EventBus.boss_roar_started.emit(2)
	assert_eq(am.last_cue, &"phase_roar")
	var squeaks: int = am.defeat_squeak_count
	EventBus.boss_defeated.emit(&"null_pointer")
	assert_eq(am.last_cue, &"defeat")
	assert_eq(am.defeat_squeak_count, squeaks + 1, "the once-per-fight squeak is unchanged")
	assert_eq(AudioManagerScript.glitch_cue(0), &"glitch_infinite_loop")
	assert_eq(AudioManagerScript.glitch_cue(2), &"glitch_segfault")
	assert_eq(AudioManagerScript.glitch_cue(3), &"")


# Story 7.2 (AC 6, D-S72-4): the pool never grows past SFX_POOL_SIZE and never touches ShiftSfx.
func test_pool_is_capped_and_steals_the_oldest() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.unlock()
	var click: AudioStream = AudioManagerScript.make_blip()
	am.play_sfx(click)
	var shift := am.get_node(^"ShiftSfx") as AudioStreamPlayer
	am.play_squeak()
	for i: int in AudioManagerScript.SFX_POOL_SIZE + 5:
		am.play_cue(&"phase_roar" if i == 0 else &"defeat") # long cues: none ends mid-test
	assert_eq(am.pool_players().size(), AudioManagerScript.SFX_POOL_SIZE)
	assert_eq(_sfx_players(am).size(), 2, "ShiftSfx + DuckSqueak next to the pool")
	assert_false(_pool_streams(am).has(AudioManagerScript.CUES[&"phase_roar"]), "the oldest one was stolen")
	assert_eq(shift.stream, click, "ShiftSfx untouched")
	assert_true(shift.playing)
	assert_eq((am.get_node(^"DuckSqueak") as AudioStreamPlayer).stream, AudioManagerScript.CUES[&"duck_squeak"])


# Story 7.2 (AC 7, 5.3): every new play path is ignored before unlock and warns once in total.
func test_cues_before_unlock_are_ignored_and_warn_once() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.play_cue(&"hit")
	EventBus.boss_tell_started.emit(&"head_rush", &"tell_infinite_loop")
	EventBus.hit_landed.emit(&"boss", 5, DamageState.Kind.BASE, false, Vector2.ZERO)
	EventBus.player_damaged.emit(2)
	EventBus.boss_roar_started.emit(1)
	am.on_boss_phase_changed(1)
	assert_eq(am.get_child_count(), 0, "no player before unlock")
	assert_eq(am.locked_warn_count, 1)
	assert_eq(am.unknown_cue_warn_count, 0)
