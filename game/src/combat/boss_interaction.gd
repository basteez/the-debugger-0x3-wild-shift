class_name BossInteraction
extends RefCounted
## One way the player affected the boss in a tick (Story 3.2, GDD D-017, NP-4). CombatResolver
## produces HIT and (Story 4.2, Echo Dash) PASS_THROUGH; DECOY_STRUCK (Ghost Echo, 6.1) has no
## producer yet and exists only for the completion rule and its tests (D-S32-19).

enum Kind { HIT, PASS_THROUGH, DECOY_STRUCK }

var kind: Kind = Kind.HIT
## The register window (first, second) the affecting action started on (D-S32-5).
var window_pair: Vector2i = Vector2i.ZERO
## The hitting action is a combo (HIT only).
var is_combo: bool = false
## The hitting action is a link follow-up (HIT only, FR20).
var is_link_second: bool = false


func _init(p_kind: Kind = Kind.HIT, p_window_pair: Vector2i = Vector2i.ZERO, p_is_combo: bool = false, p_is_link_second: bool = false) -> void:
	kind = p_kind
	window_pair = p_window_pair
	is_combo = p_is_combo
	is_link_second = p_is_link_second


## True when `i` completes the weak window `weak` (D-S32-6): the window matches, and the
## interaction is a combo or link_second HIT, a PASS_THROUGH or a DECOY_STRUCK. A plain solo hit
## never completes it, even on the right bits. Pure.
static func completes_weak_window(i: BossInteraction, weak: Vector2i) -> bool:
	if i == null or weak == Vector2i.ZERO or i.window_pair != weak:
		return false
	match i.kind:
		Kind.HIT:
			return i.is_combo or i.is_link_second
		Kind.PASS_THROUGH, Kind.DECOY_STRUCK:
			return true
	return false
