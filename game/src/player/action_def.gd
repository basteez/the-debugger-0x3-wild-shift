class_name ActionDef
extends Def
## One player action's frame data (Story 2.5, AD-02): startup / active / recovery frames,
## invulnerability, hit shape, damage, cooldown, movement, cancels and the chain. Read-only at
## runtime; the ActionStateMachine owns the mutable state. Action frames are 1-based.

@export var id: StringName = &""
@export var startup_frames: int = 0
@export var active_frames: int = 1
@export var recovery_frames: int = 0
## Invulnerable action frames, 1-based inclusive; both 0 = none.
@export var invuln_from: int = 0
@export var invuln_to: int = 0
## Null for actions that hit nothing (DASH).
@export var hit_shape: HitShape
@export var base_damage: int = 0
## Cooldown of the bit that started this action, in sim frames (0 = none).
@export var cooldown_frames: int = 0
## Distance moved along the captured facing across the ACTIVE frames (0 = stationary).
@export var move_tiles: float = 0.0
## Bit ids this action may be cancelled into during RECOVERY (FR14, D-S25-5).
@export var cancel_into: PackedInt32Array = PackedInt32Array([Register.Bit.DASH])
## The next hit of an ATTACK chain; null = end of chain (D-S25-14).
@export var chain_next: ActionDef
## Hit-stop in sim frames when this action lands as a combo hit (Story 2.8, FR26, D-S28-1). The
## default 3 is the normal (unpatched) value; Dash Strike is 6. A solo hit always uses
## HitFeedback.NORMAL_HITSTOP; the precedence rule lives in HitFeedback.
@export var hitstop_frames: int = 3


func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames


## True when action frame `frame` (1-based) is inside the invulnerable range.
func is_invulnerable_frame(frame: int) -> bool:
	return invuln_from > 0 and frame >= invuln_from and frame <= invuln_to


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if startup_frames < 0:
		out.append("startup_frames must be >= 0 (got %d)" % startup_frames)
	if active_frames < 1:
		out.append("active_frames must be >= 1 (got %d)" % active_frames)
	if recovery_frames < 0:
		out.append("recovery_frames must be >= 0 (got %d)" % recovery_frames)
	if base_damage < 0:
		out.append("base_damage must be >= 0 (got %d)" % base_damage)
	if cooldown_frames < 0:
		out.append("cooldown_frames must be >= 0 (got %d)" % cooldown_frames)
	if hitstop_frames < 0:
		out.append("hitstop_frames must be >= 0 (got %d)" % hitstop_frames)
	if hitstop_frames > 8:
		out.append("hitstop_frames must be <= 8, the InputBuffer window (got %d)" % hitstop_frames)
	var no_invuln: bool = invuln_from == 0 and invuln_to == 0
	if not no_invuln and not (1 <= invuln_from and invuln_from <= invuln_to and invuln_to <= total_frames()):
		out.append("invuln range %d-%d must be 0-0 or within 1..%d" % [invuln_from, invuln_to, total_frames()])
	if not is_finite(move_tiles) or move_tiles < 0.0:
		out.append("move_tiles must be >= 0 (got %s)" % move_tiles)
	if hit_shape != null and active_frames < 1:
		out.append("a hit_shape needs active_frames >= 1")
	for bit: int in cancel_into:
		if not Register.is_bit(bit):
			out.append("cancel_into has unknown bit %d" % bit)
	var seen: Array[ActionDef] = [self]
	var next: ActionDef = chain_next
	while next != null:
		if seen.has(next):
			out.append("chain_next forms a cycle")
			break
		seen.append(next)
		next = next.chain_next
	return out
