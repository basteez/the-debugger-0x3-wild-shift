class_name Register
extends SimSystem
## The player's bit register (Story 2.3, FR4-FR9, GDD "The Register"). A ring of owned bits only
## (D-S23-1): rotation can never bring an unowned slot into the active window. The active window
## is ring[0], ring[1] (J, K). Ticked by SimClock in the SHIFTS phase: applies buffered Q/E
## presses oldest first (D-S23-3, D-S23-4). Register methods are the only writers of `ring`.

## Story 6.6 (D-S66-3): the ring may also hold one temporary slot written by a boss effect
## (Reserved Write's garbage bit `?`), never owned: harvest and the fight-start set reject it.

enum Bit { ATTACK = 1, DASH = 2, LOOP = 3, NULL_BIT = 4, GARBAGE = 5 }

const MIN_BITS := 2
## Four owned bits fill the low nibble (0x0F); the high nibble is reserved.
const MAX_BITS := 4
## Story 6.6 (D-S66-3): owned bits plus at most one temporary slot.
const MAX_SLOTS := MAX_BITS + 1
const LEFT := -1
const RIGHT := 1
const SHIFT_ACTIONS: Array[StringName] = [&"shift_left", &"shift_right"]
const GLYPHS: Dictionary[int, String] = {
	Bit.ATTACK: "A",
	Bit.DASH: "D",
	Bit.LOOP: "L",
	Bit.NULL_BIT: "N",
	Bit.GARBAGE: "?",
}

## Owned bits in ring order, length MIN_BITS..MAX_BITS. Read through the getters; write only
## through Register methods.
var ring: PackedInt32Array = PackedInt32Array([Bit.DASH, Bit.ATTACK])
## Only an active register applies shifts (D-S23-11): on in FIGHT, off elsewhere.
var active: bool = false
## Count of applied shifts (Story 2.5, D-S25-2): a changed serial resets the ATTACK chain. Written
## only in shift(); read-only for other systems.
var shift_serial: int = 0
## Story 6.6 (D-S66-3): the bit id of the temporary slot in the ring, 0 = none. Written only by
## insert_temporary / remove_temporary / set_fight_start.
var temporary: int = 0

var _buffer: InputBuffer


func _init(p_buffer: InputBuffer = null) -> void:
	phase = SimPhase.SHIFTS
	_buffer = p_buffer


## One world frame (only SimClock calls this): applies every live buffered shift, in press order.
func tick(ctx: SimContext) -> void:
	if not active or _buffer == null:
		return
	var action: StringName = _buffer.consume_oldest(SHIFT_ACTIONS, ctx.poll_frame)
	while active and action != &"":
		shift(LEFT if action == &"shift_left" else RIGHT)
		action = _buffer.consume_oldest(SHIFT_ACTIONS, ctx.poll_frame)


func set_active(on: bool) -> void:
	active = on


## Rotates the ring one slot: -1 `<<` moves the leftmost bit to the right end, +1 `>>` moves the
## rightmost bit to the left end. Emits EventBus.register_shifted once.
func shift(direction: int) -> void:
	if direction != LEFT and direction != RIGHT:
		Log.error(&"register", "shift direction %d (expected -1 or +1)" % direction)
		return
	if ring.size() < MIN_BITS:
		Log.error(&"register", "shift on a ring of %d bits" % ring.size())
		return
	ring = rotated(ring, direction)
	shift_serial += 1
	EventBus.register_shifted.emit(direction, active_window(), ring.duplicate(), &"player")


## Story 6.5 (NP-3, D-S65-4, D-S65-5): a boss effect's rotation (SIGSEGV +2), applied only through
## the PlayerEffects queue. Rotates |n| slots in the direction of n's sign (+ = `>>`), reduced modulo
## the ring size (+2 on a 2-bit ring leaves it unchanged), and emits register_shifted once with
## `source`. Not a player shift: shift_serial is untouched, so an ATTACK chain survives (it still
## needs its slot to hold A); the PlayerEffects command closes the link itself (NP-1).
func rotate(n: int, source: StringName = &"sigsegv") -> void:
	if n == 0:
		Log.error(&"register", "rotate by 0 slots")
		return
	if ring.size() < MIN_BITS:
		Log.error(&"register", "rotate on a ring of %d bits" % ring.size())
		return
	var direction: int = RIGHT if n > 0 else LEFT
	for i: int in absi(n) % ring.size():
		ring = rotated(ring, direction)
	EventBus.register_shifted.emit(direction, active_window(), ring.duplicate(), source)


## The two leftmost owned bits (J, K).
func active_window() -> Vector2i:
	return window_of(ring)


## The window a shift in `direction` would produce. Never changes the register.
func preview(direction: int) -> Vector2i:
	return window_of(rotated(ring, direction))


## Owned bits only (a temporary slot is not owned, Story 6.6).
func owned_count() -> int:
	return ring.size() - (1 if temporary != 0 else 0)


## Story 6.6: true while a temporary slot (the garbage bit) is in the ring.
func has_temporary() -> bool:
	return temporary != 0


## 0x03, 0x07, 0x0F for 2, 3, 4 owned bits (FR8).
func byte_value() -> int:
	return (1 << owned_count()) - 1


## Replaces the ring with a fight-start set (FR7). Rejects a size outside 2..4, a duplicate or an
## unknown bit id with Log.error and leaves the ring unchanged.
func set_fight_start(bits: PackedInt32Array) -> bool:
	if bits.size() < MIN_BITS or bits.size() > MAX_BITS:
		Log.error(&"register", "fight-start set of %d bits rejected" % bits.size())
		return false
	var seen: PackedInt32Array = PackedInt32Array()
	for bit: int in bits:
		if not is_bit(bit):
			Log.error(&"register", "fight-start set has unknown bit %d" % bit)
			return false
		if not is_ownable(bit):
			Log.error(&"register", "fight-start set has unownable bit %s" % glyph_of(bit))
			return false
		if seen.has(bit):
			Log.error(&"register", "fight-start set has duplicate bit %s" % glyph_of(bit))
			return false
		seen.append(bit)
	ring = bits.duplicate()
	temporary = 0 # Story 6.6 (AC 15): the retry restore never keeps a temporary slot
	Log.debug(&"register", "fight start %s" % to_text(ring))
	return true


## Appends a bit to the right of the last owned slot (harvest, Story 3.8). Rejects an unknown id, a
## duplicate or a full register with Log.error. Story 6.6 (AC 9): also the garbage bit, and any
## insert while a temporary slot is in the ring.
func insert(bit: int) -> bool:
	if not is_bit(bit):
		Log.error(&"register", "insert of unknown bit %d" % bit)
		return false
	if not is_ownable(bit):
		Log.error(&"register", "insert of unownable bit %s" % glyph_of(bit))
		return false
	if temporary != 0:
		Log.error(&"register", "insert while a temporary slot is in the ring")
		return false
	if ring.size() >= MAX_BITS:
		Log.error(&"register", "insert into a full register")
		return false
	if ring.has(bit):
		Log.error(&"register", "insert of owned bit %s" % glyph_of(bit))
		return false
	ring.append(bit)
	Log.debug(&"register", "inserted %s" % glyph_of(bit))
	return true


## Story 6.6 (NP-3, D-S66-3, AC 7): a boss effect writes `bit` into the ring as its one temporary
## slot, appended to the right end (the ring grows to at most MAX_SLOTS). Rejects an unknown bit,
## a bit already in the ring, a second temporary slot or a ring of fewer than MIN_BITS / more than
## MAX_BITS owned bits. Emits register_changed once with `cause`. Not a player shift: shift_serial
## is untouched; the PlayerEffects command closes the link (NP-1).
func insert_temporary(bit: int, cause: StringName = &"garbage_in") -> bool:
	if not is_bit(bit):
		Log.error(&"register", "temporary insert of unknown bit %d" % bit)
		return false
	if temporary != 0:
		Log.error(&"register", "temporary insert while %s is present" % glyph_of(temporary))
		return false
	if ring.has(bit):
		Log.error(&"register", "temporary insert of %s already in the ring" % glyph_of(bit))
		return false
	if ring.size() < MIN_BITS or ring.size() > MAX_BITS:
		Log.error(&"register", "temporary insert on a ring of %d bits" % ring.size())
		return false
	ring.append(bit)
	temporary = bit
	EventBus.register_changed.emit(active_window(), ring.duplicate(), cause)
	return true


## Story 6.6 (AC 12): removes the temporary slot wherever rotation moved it (the owned bits keep
## their order), recomputes the window and emits register_changed once with `cause`. False (no
## signal) when there is none.
func remove_temporary(cause: StringName = &"garbage_out") -> bool:
	if temporary == 0:
		return false
	var at: int = ring.find(temporary)
	if at >= 0:
		ring.remove_at(at)
	temporary = 0
	EventBus.register_changed.emit(active_window(), ring.duplicate(), cause)
	return true


## GDD fight-start sets (D-S23-6): Boss 1 [D, A], Boss 2 [A, D, L], Boss 3 [A, D, L, N]. Unknown
## indices fall back to Boss 1 with Log.warn.
static func fight_start_for_boss(boss_index: int) -> PackedInt32Array:
	match boss_index:
		0:
			return PackedInt32Array([Bit.DASH, Bit.ATTACK])
		1:
			return PackedInt32Array([Bit.ATTACK, Bit.DASH, Bit.LOOP])
		2:
			return PackedInt32Array([Bit.ATTACK, Bit.DASH, Bit.LOOP, Bit.NULL_BIT])
	Log.warn(&"register", "no fight-start set for boss %d, using Boss 1" % boss_index)
	return PackedInt32Array([Bit.DASH, Bit.ATTACK])


## The ring rotated one slot (-1 left, +1 right); a copy, `bits` is untouched. Pure.
static func rotated(bits: PackedInt32Array, direction: int) -> PackedInt32Array:
	var out: PackedInt32Array = bits.duplicate()
	if out.size() < 2:
		return out
	if direction < 0:
		out.append(out[0])
		out.remove_at(0)
	else:
		var last: int = out[out.size() - 1]
		out.remove_at(out.size() - 1)
		out.insert(0, last)
	return out


## (ring[0], ring[1]); Vector2i.ZERO for a ring shorter than 2. Pure.
static func window_of(bits: PackedInt32Array) -> Vector2i:
	if bits.size() < 2:
		return Vector2i.ZERO
	return Vector2i(bits[0], bits[1])


static func is_bit(bit: int) -> bool:
	return GLYPHS.has(bit)


## Story 6.6 (AC 9): a bit the player can own (harvest, fight-start set): any bit but GARBAGE.
static func is_ownable(bit: int) -> bool:
	return is_bit(bit) and bit != Bit.GARBAGE


## One-glyph name of a bit id; "?" for an unknown id.
static func glyph_of(bit: int) -> String:
	return GLYPHS.get(bit, "?")


## "[D, A]" style text of a ring, for logs.
static func to_text(bits: PackedInt32Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for bit: int in bits:
		parts.append(glyph_of(bit))
	return "[" + ", ".join(parts) + "]"
