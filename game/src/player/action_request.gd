class_name ActionRequest
extends RefCounted
## The ActionResolver's answer (Story 2.5): which action starts this tick, from which slot.
## Story 2.6: a combo start carries its ComboDef; a no-combo link follow-up is flagged link_second;
## a request with no def is a link instruction for the FSM (hold or drop a K press, D-S26-5).

enum LinkOp { NONE, HOLD, DROP }

var def: ActionDef
## The Register.Bit in the pressed slot (for a combo: the second bit, whose cooldown applies).
var bit: int = 0
## 0 = J (action_1), 1 = K (action_2).
var slot: int = 0
var key: StringName = &""
## True when this continues an ATTACK chain (FR10).
var chain: bool = false
## True when this cancels the running action's RECOVERY (FR14).
var cancel: bool = false
## The combo that replaces K's solo action (FR15), or null.
var combo: ComboDef = null
## True for K's solo action performed through an open link on a no-combo window (FR20, NP-4).
var link_second: bool = false
## Link instruction when `def` is null: HOLD the K press pushed on `held_frame`, or DROP the held one.
var link_op: LinkOp = LinkOp.NONE
var held_frame: int = -1


func _init(p_def: ActionDef = null, p_bit: int = 0, p_slot: int = 0, p_chain: bool = false, p_cancel: bool = false, p_combo: ComboDef = null, p_link_second: bool = false) -> void:
	def = p_def
	bit = p_bit
	slot = p_slot
	key = ActionResolver.KEYS[p_slot] if p_slot >= 0 and p_slot < ActionResolver.KEYS.size() else &""
	chain = p_chain
	cancel = p_cancel
	combo = p_combo
	link_second = p_link_second


## A link instruction (no action starts this tick).
static func link_instruction(op: LinkOp, slot: int, pushed_frame: int = -1) -> ActionRequest:
	var r := ActionRequest.new(null, 0, slot)
	r.link_op = op
	r.held_frame = pushed_frame
	return r
