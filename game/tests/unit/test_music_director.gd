extends GutTest
## Story 7.1: music tracks per context, two crossfaded players on the Music bus, phase-3 glitch,
## Breakpoint muffled loop, HARVEST silence, ENDING title, and the placeholder assets.

const AudioManagerScript := preload("res://src/autoloads/audio_manager.gd")
const GameFlow := preload("res://src/autoloads/game.gd")

const TITLE := GameFlow.FlowState.TITLE
const INTRO := GameFlow.FlowState.INTRO
const FIGHT := GameFlow.FlowState.FIGHT
const DEAD := GameFlow.FlowState.DEAD
const HARVEST := GameFlow.FlowState.HARVEST
const ENDING := GameFlow.FlowState.ENDING

const MUSIC_DIR := "res://assets/audio/music/"
const BASE_NAMES: Array[String] = ["boss_1.ogg", "boss_2.ogg", "boss_3.ogg"]
const GLITCH_NAMES: Array[String] = ["boss_1_glitch.ogg", "boss_2_glitch.ogg", "boss_3_glitch.ogg"]
const ALL_NAMES: Array[String] = [
	"title.ogg", "boss_1.ogg", "boss_2.ogg", "boss_3.ogg",
	"boss_1_glitch.ogg", "boss_2_glitch.ogg", "boss_3_glitch.ogg", "breakpoint_muffled.ogg",
]


func _track(file: String) -> AudioStream:
	return load(MUSIC_DIR + file) as AudioStream


func _music_players(am: Node) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for child: Node in am.get_children():
		var player := child as AudioStreamPlayer
		if player != null and player.bus == &"Music":
			players.append(player)
	return players


func _playing_music(am: Node) -> int:
	var count: int = 0
	for player: AudioStreamPlayer in _music_players(am):
		if player.playing:
			count += 1
	return count


## A bare AudioManager, unlocked (title playing) and moved into FIGHT for `boss`.
func _in_fight(boss: int) -> Node:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.unlock()
	am.on_music_flow_changed(TITLE, INTRO, 0)
	am.on_music_flow_changed(INTRO, FIGHT, boss)
	return am


# --- AC 11: desired_track is a pure table -------------------------------------------------------

func test_desired_track_title_intro_ending_play_the_title() -> void:
	for flow: int in [TITLE, INTRO, ENDING]:
		for bp: bool in [false, true]:
			assert_eq(AudioManagerScript.desired_track(flow, 1, true, bp), _track("title.ogg"), str(flow))


func test_desired_track_fight_base_and_glitch_per_boss() -> void:
	for boss: int in 3:
		assert_eq(AudioManagerScript.desired_track(FIGHT, boss, false, false), _track(BASE_NAMES[boss]))
		assert_eq(AudioManagerScript.desired_track(FIGHT, boss, true, false), _track(GLITCH_NAMES[boss]))


func test_desired_track_breakpoint_overrides_any_fight_track() -> void:
	for boss: int in 3:
		for glitch: bool in [false, true]:
			assert_eq(AudioManagerScript.desired_track(FIGHT, boss, glitch, true), _track("breakpoint_muffled.ogg"))


func test_desired_track_dead_keeps_the_fight_track_and_harvest_is_silent() -> void:
	for boss: int in 3:
		assert_eq(AudioManagerScript.desired_track(DEAD, boss, false, false), _track(BASE_NAMES[boss]))
		assert_eq(AudioManagerScript.desired_track(DEAD, boss, true, true), _track(GLITCH_NAMES[boss]))
		assert_null(AudioManagerScript.desired_track(HARVEST, boss, false, false))
		assert_null(AudioManagerScript.desired_track(HARVEST, boss, true, true))


func test_desired_track_out_of_range_boss_is_silent() -> void:
	assert_null(AudioManagerScript.desired_track(FIGHT, -1, false, false))
	assert_null(AudioManagerScript.desired_track(FIGHT, 3, true, false))


# --- AC 1, 2, 13: unlock, two players, Music bus ---------------------------------------------------

func test_no_music_before_unlock_and_requests_warn_once() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.on_music_flow_changed(TITLE, INTRO, 0)
	am.on_music_flow_changed(INTRO, FIGHT, 0)
	am.on_boss_phase_changed(2)
	am.on_breakpoint_started()
	assert_eq(_music_players(am).size(), 0, "no music player before unlock")
	assert_eq(am.get("locked_warn_count"), 0, "context changes alone are silent")
	am.crossfade_to(_track("title.ogg"), 0)
	am.crossfade_to(_track("boss_1.ogg"), 0)
	assert_eq(_music_players(am).size(), 0)
	assert_eq(am.get("locked_warn_count"), 1, "exactly one warn per session")


func test_unlock_starts_the_title_on_music_a() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.unlock()
	var players: Array[AudioStreamPlayer] = _music_players(am)
	assert_eq(players.size(), 2)
	assert_eq(players[0].name, &"MusicA")
	assert_eq(players[1].name, &"MusicB")
	assert_eq(am.active_music_player(), players[0])
	assert_eq(players[0].stream, _track("title.ogg"))
	assert_true(players[0].playing)
	assert_false(players[1].playing)
	assert_almost_eq(players[0].volume_linear, 1.0, 0.001)
	am.unlock()
	assert_eq(am.get("music_switch_count"), 1, "a second unlock does not restart the title")


func test_intro_keeps_the_title_without_a_switch() -> void:
	var am: Node = add_child_autofree(AudioManagerScript.new())
	am.unlock()
	am.on_music_flow_changed(TITLE, INTRO, 0)
	assert_eq(am.get("music_switch_count"), 1)
	assert_eq(am.current_track(), _track("title.ogg"))


func test_fight_crossfades_the_title_into_the_boss_track() -> void:
	var am: Node = _in_fight(0)
	var players: Array[AudioStreamPlayer] = _music_players(am)
	assert_eq(am.current_track(), _track("boss_1.ogg"))
	assert_eq(am.active_music_player(), players[1], "the players alternate")
	assert_eq(_playing_music(am), 2, "both play during the crossfade")
	assert_lt(players[1].volume_linear, 0.5, "the incoming player fades in")
	await wait_seconds(float(AudioManagerScript.FLOW_FADE_FRAMES) / 60.0 + 0.2)
	assert_false(players[0].playing, "the outgoing player stops after the fade")
	assert_true(players[1].playing)
	assert_almost_eq(players[1].volume_linear, 1.0, 0.001)


func test_each_boss_index_maps_to_its_track() -> void:
	for boss: int in 3:
		var am: Node = _in_fight(boss)
		assert_eq(am.current_track(), _track(BASE_NAMES[boss]))


func test_never_more_than_two_music_players() -> void:
	var am: Node = _in_fight(0)
	for i: int in 10:
		am.on_breakpoint_started()
		am.on_breakpoint_ended()
	am.on_boss_phase_changed(2)
	am.on_music_flow_changed(FIGHT, HARVEST, 0)
	am.on_music_flow_changed(HARVEST, FIGHT, 1)
	assert_eq(_music_players(am).size(), 2)
	assert_lte(_playing_music(am), 2)


func test_incoming_track_starts_at_the_outgoing_position() -> void:
	var am: Node = _in_fight(0)
	var base: AudioStreamPlayer = am.active_music_player()
	base.play(3.0)
	var at: float = base.get_playback_position()
	assert_gt(at, 2.5, "the base track is mid-loop")
	am.on_boss_phase_changed(2)
	var glitch: AudioStreamPlayer = am.active_music_player()
	assert_ne(glitch, base)
	assert_eq(glitch.stream, _track("boss_1_glitch.ogg"))
	assert_almost_eq(glitch.get_playback_position(), at, 0.25, "the variant keeps the bar position")


# --- AC 5, 6, 7: phase-3 glitch -------------------------------------------------------------------

func test_only_phase_index_two_switches_to_the_glitch_variant() -> void:
	var am: Node = _in_fight(1)
	var switches: int = am.get("music_switch_count")
	am.on_boss_phase_changed(1)
	assert_eq(am.current_track(), _track("boss_2.ogg"), "phase index 1 keeps the base track")
	assert_eq(am.get("music_switch_count"), switches)
	am.on_boss_phase_changed(2)
	assert_eq(am.current_track(), _track("boss_2_glitch.ogg"))
	assert_eq(am.get("music_switch_count"), switches + 1)


func test_retry_restarts_the_base_track_with_a_cut() -> void:
	var am: Node = _in_fight(2)
	am.on_boss_phase_changed(2)
	am.on_music_flow_changed(FIGHT, DEAD, 2)
	assert_eq(am.current_track(), _track("boss_3_glitch.ogg"), "DEAD keeps the fight track")
	var switches: int = am.get("music_switch_count")
	am.on_music_flow_changed(DEAD, FIGHT, 2)
	assert_eq(am.get("music_switch_count"), switches + 1)
	assert_eq(am.current_track(), _track("boss_3.ogg"), "the glitch is not carried over")
	assert_false(am.get("music_glitch"))
	assert_eq(_playing_music(am), 1, "a retry is a cut: the old player stops at once")
	assert_almost_eq(am.active_music_player().volume_linear, 1.0, 0.001)


func test_same_boss_fight_entry_restarts_even_with_the_same_track() -> void:
	var am: Node = _in_fight(0)
	am.on_music_flow_changed(FIGHT, DEAD, 0)
	var switches: int = am.get("music_switch_count")
	am.on_music_flow_changed(DEAD, FIGHT, 0)
	assert_eq(am.get("music_switch_count"), switches + 1)
	assert_eq(am.current_track(), _track("boss_1.ogg"))


# --- AC 8, 9: Breakpoint ---------------------------------------------------------------------------

func test_breakpoint_round_trip_returns_to_the_base_track() -> void:
	var am: Node = _in_fight(0)
	var events: int = am.get("breakpoint_music_events")
	am.on_breakpoint_started()
	assert_eq(am.current_track(), _track("breakpoint_muffled.ogg"))
	am.on_breakpoint_ended()
	assert_eq(am.current_track(), _track("boss_1.ogg"))
	assert_eq(am.get("breakpoint_music_events"), events + 2)


func test_phase_three_during_breakpoint_waits_for_the_end() -> void:
	var am: Node = _in_fight(1)
	am.on_breakpoint_started()
	var switches: int = am.get("music_switch_count")
	am.on_boss_phase_changed(2)
	assert_eq(am.current_track(), _track("breakpoint_muffled.ogg"), "no switch during Breakpoint")
	assert_eq(am.get("music_switch_count"), switches)
	am.on_breakpoint_ended()
	assert_eq(am.current_track(), _track("boss_2_glitch.ogg"), "the glitch applies when Breakpoint ends")
	assert_eq(am.get("music_switch_count"), switches + 1)


func test_breakpoint_events_reach_the_handlers_through_the_event_bus() -> void:
	var am: Node = _in_fight(0)
	EventBus.breakpoint_started.emit()
	assert_eq(am.current_track(), _track("breakpoint_muffled.ogg"))
	EventBus.breakpoint_ended.emit()
	EventBus.boss_phase_changed.emit(2)
	assert_eq(am.current_track(), _track("boss_1_glitch.ogg"))


# --- AC 10: HARVEST and ENDING ---------------------------------------------------------------------

func test_harvest_fades_to_silence() -> void:
	var am: Node = _in_fight(0)
	await wait_seconds(float(AudioManagerScript.FLOW_FADE_FRAMES) / 60.0 + 0.2)
	am.on_music_flow_changed(FIGHT, HARVEST, 0)
	assert_null(am.current_track())
	await wait_seconds(float(AudioManagerScript.HARVEST_FADE_FRAMES) / 60.0 + 0.2)
	assert_eq(_playing_music(am), 0, "silence after the HARVEST fade")


func test_harvest_to_next_fight_starts_the_next_boss() -> void:
	var am: Node = _in_fight(0)
	am.on_music_flow_changed(FIGHT, HARVEST, 0)
	am.on_music_flow_changed(HARVEST, FIGHT, 1)
	assert_eq(am.current_track(), _track("boss_2.ogg"))


func test_ending_plays_the_title_from_the_start() -> void:
	var am: Node = _in_fight(2)
	am.on_music_flow_changed(FIGHT, ENDING, 2)
	assert_eq(am.current_track(), _track("title.ogg"))
	assert_almost_eq(am.active_music_player().get_playback_position(), 0.0, 0.25)


# --- AC 3, 15, 17: the eight files -----------------------------------------------------------------

func test_eight_music_files_load_as_looping_ogg_vorbis() -> void:
	for file: String in ALL_NAMES:
		var path: String = MUSIC_DIR + file
		assert_true(ResourceLoader.exists(path), "missing %s" % path)
		var stream := load(path) as AudioStreamOggVorbis
		assert_not_null(stream, "%s is not AudioStreamOggVorbis" % path)
		if stream != null:
			assert_true(stream.loop, "%s must import with loop on" % path)


func test_variants_share_the_length_of_their_family() -> void:
	var muffled: float = _track("breakpoint_muffled.ogg").get_length()
	assert_gt(muffled, 0.0)
	for boss: int in 3:
		var base: float = _track(BASE_NAMES[boss]).get_length()
		assert_almost_eq(_track(GLITCH_NAMES[boss]).get_length(), base, 0.01, GLITCH_NAMES[boss])
		assert_almost_eq(muffled, base, 0.01, "the muffled loop keeps the bar for %s" % BASE_NAMES[boss])


func test_preloaded_constants_point_at_the_final_paths() -> void:
	assert_eq(AudioManagerScript.TITLE_TRACK.resource_path, MUSIC_DIR + "title.ogg")
	assert_eq(AudioManagerScript.BREAKPOINT_TRACK.resource_path, MUSIC_DIR + "breakpoint_muffled.ogg")
	for boss: int in 3:
		assert_eq(AudioManagerScript.BOSS_TRACKS[boss].resource_path, MUSIC_DIR + BASE_NAMES[boss])
		assert_eq(AudioManagerScript.BOSS_GLITCH_TRACKS[boss].resource_path, MUSIC_DIR + GLITCH_NAMES[boss])
