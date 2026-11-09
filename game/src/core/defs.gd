class_name Defs
extends RefCounted
## Global catalogue of the bit and action defs, preloaded once (architecture, Story 2.5).
## Read-only at runtime.

const BIT_ATTACK: BitDef = preload("res://data/bits/bit_attack.tres")
const BIT_DASH: BitDef = preload("res://data/bits/bit_dash.tres")
const SLASH_1: ActionDef = preload("res://data/actions/slash_1.tres")
const SLASH_2: ActionDef = preload("res://data/actions/slash_2.tres")
const SLASH_3: ActionDef = preload("res://data/actions/slash_3.tres")
const DASH: ActionDef = preload("res://data/actions/dash.tres")


## The def of a bit id; null for a bit with no def yet (LOOP and NULL_BIT in Story 2.5, D-S25-8).
static func bit(id: int) -> BitDef:
	match id:
		Register.Bit.ATTACK:
			return BIT_ATTACK
		Register.Bit.DASH:
			return BIT_DASH
	return null


## The solo action of a bit id, or null.
static func solo_action(id: int) -> ActionDef:
	var def: BitDef = bit(id)
	return def.solo_action if def != null else null
