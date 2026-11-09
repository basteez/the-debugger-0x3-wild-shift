class_name AttackDef
extends Def
## One boss attack's data (Story 3.1, AD-06, FR30, FR31): timings in sim frames, the tell cue id
## and the BossAttack script that runs it. Balance numbers live in data/bosses/<boss>/*.tres.
## `exclusive` and `recovery_if_no_breakpoint` are stored but have no behaviour until 6.5 / 4.3.

## Pillar 2 / FR31: every tell lasts at least this many frames.
const MIN_TELL_FRAMES := 20

## Unique within its boss (e.g. &"test_pulse").
@export var id: StringName = &""
## Telegraph frames (>= MIN_TELL_FRAMES).
@export var tell: int = MIN_TELL_FRAMES
## Frames the attack is live (>= 1).
@export var active: int = 1
## Frames of recovery after the active window (>= 0).
@export var recovery: int = 0
## Story 6.5: the attack cannot overlap another exclusive one. No behaviour in 3.1.
@export var exclusive: bool = false
## Story 4.3: recovery used when the player had no Breakpoint. Stored only in 3.1.
@export var recovery_if_no_breakpoint: int = 0
## The BossAttack subclass that runs the hooks ([design call] D-S31-20: named `attack_script`,
## because `script` is the built-in Object property and cannot be redeclared).
@export var attack_script: Script = null
## Audible tell cue id (D-049, D-S31-7); non-empty. 7.2 maps it to a stream.
@export var tell_sfx: StringName = &""


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	var label: String = String(id) if id != &"" else "<no id>"
	if id == &"":
		out.append("attack id must not be empty")
	if tell < MIN_TELL_FRAMES:
		out.append("attack %s: tell must be >= %d frames (got %d)" % [label, MIN_TELL_FRAMES, tell])
	if active < 1:
		out.append("attack %s: active must be >= 1 (got %d)" % [label, active])
	if recovery < 0:
		out.append("attack %s: recovery must be >= 0 (got %d)" % [label, recovery])
	if recovery_if_no_breakpoint < 0:
		out.append("attack %s: recovery_if_no_breakpoint must be >= 0 (got %d)" % [label, recovery_if_no_breakpoint])
	if tell_sfx == &"":
		out.append("attack %s: tell_sfx must not be empty" % label)
	if not is_boss_attack_script(attack_script):
		out.append("attack %s: attack_script must be a BossAttack subclass" % label)
	return out


## True when `s` is BossAttack or extends it (walks the base-script chain). Pure.
static func is_boss_attack_script(s: Script) -> bool:
	var current: Script = s
	while current != null:
		if current == BossAttack:
			return true
		current = current.get_base_script()
	return false
