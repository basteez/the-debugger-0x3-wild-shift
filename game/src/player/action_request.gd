class_name ActionRequest
extends RefCounted
## The ActionResolver's answer (Story 2.5): which action starts this tick, from which slot.

var def: ActionDef
## The Register.Bit in the pressed slot.
var bit: int = 0
## 0 = J (action_1), 1 = K (action_2).
var slot: int = 0
var key: StringName = &""
## True when this continues an ATTACK chain (FR10).
var chain: bool = false
## True when this cancels the running action's RECOVERY (FR14).
var cancel: bool = false


func _init(p_def: ActionDef = null, p_bit: int = 0, p_slot: int = 0, p_chain: bool = false, p_cancel: bool = false) -> void:
	def = p_def
	bit = p_bit
	slot = p_slot
	key = ActionResolver.KEYS[p_slot] if p_slot >= 0 and p_slot < ActionResolver.KEYS.size() else &""
	chain = p_chain
	cancel = p_cancel
