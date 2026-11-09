class_name LinkState
extends RefCounted
## The combo link (Story 2.6, NP-1): opened when a J action's first ACTIVE frame executes, open
## through J's ACTIVE frames and for LINK_FRAMES ticks after its last one. While open, a K press on
## the same window fires the combo (or K's solo action flagged link_second). Plain data, owned and
## written only by the ActionStateMachine (D-S26-4); holds no node or FSM reference.

## GDD "Combos": K within 18 frames after J's ACTIVE frames end.
const LINK_FRAMES := 18

## The window (J, K bits) the link was opened on.
var pair: Vector2i = Vector2i.ZERO
## Register.shift_serial when the link opened; a different serial means a shift closed it.
var serial: int = -1
## Ticks left once counting: LINK_FRAMES on the tick J's last ACTIVE frame executes (k = 0), one
## less per later tick; the link closes below 0 (k = 19).
var frames_left: int = 0
## False while J's ACTIVE frames still run (the count has not started).
var counting: bool = false
## The held K press (D-S26-5): consumed from the InputBuffer, waiting until the target can start.
var held: bool = false
var held_key: StringName = &""
var held_slot: int = -1
## The poll frame the held press was pushed on (the 8-frame cooldown drop counts from it).
var held_frame: int = -1

var _open: bool = false


func is_open() -> bool:
	return _open


## Opens (or reopens, D-S26-9) the link on `p_pair` at shift serial `p_serial`. A held press stays.
func open(p_pair: Vector2i, p_serial: int) -> void:
	_open = true
	pair = p_pair
	serial = p_serial
	frames_left = LINK_FRAMES
	counting = false


## J's last ACTIVE frame executed: the 18-tick count starts (this tick is k = 0).
func start_count() -> void:
	if _open:
		counting = true
		frames_left = LINK_FRAMES


## One sim tick, before resolution: counts down; true when the count ran out and closed the link.
func tick() -> bool:
	if not _open or not counting:
		return false
	frames_left -= 1
	if frames_left < 0:
		close()
		return true
	return false


func hold(key: StringName, slot: int, pushed_frame: int) -> void:
	held = true
	held_key = key
	held_slot = slot
	held_frame = pushed_frame


func clear_hold() -> void:
	held = false
	held_key = &""
	held_slot = -1
	held_frame = -1


## Closes the link and discards a held press (D-S26-7).
func close() -> void:
	_open = false
	counting = false
	frames_left = 0
	clear_hold()
