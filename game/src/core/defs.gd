class_name Defs
extends RefCounted
## Global catalogue of the bit, action and combo defs, preloaded once (architecture, Story 2.5).
## Read-only at runtime.

const BIT_ATTACK: BitDef = preload("res://data/bits/bit_attack.tres")
const BIT_DASH: BitDef = preload("res://data/bits/bit_dash.tres")
## Story 3.8 registered LOOP; Story 4.1: its solo action is Echo.
const BIT_LOOP: BitDef = preload("res://data/bits/bit_loop.tres")
## Story 5.5: the NULL bit (N); its solo action is Null Dodge. Owned from Story 5.6 (Harvest).
const BIT_NULL: BitDef = preload("res://data/bits/bit_null.tres")
## Story 4.1 (NP-5): LOOP's solo action; the FSM runs the remembered def in its place.
const ECHO: ActionDef = preload("res://data/actions/echo.tres")
## The Epic 6 garbage bit's action (NP-3); LOOP's placeholder in Story 3.8.
const NOP: ActionDef = preload("res://data/actions/nop.tres")
const SLASH_1: ActionDef = preload("res://data/actions/slash_1.tres")
const SLASH_2: ActionDef = preload("res://data/actions/slash_2.tres")
const SLASH_3: ActionDef = preload("res://data/actions/slash_3.tres")
const DASH: ActionDef = preload("res://data/actions/dash.tres")
const DASH_STRIKE: ActionDef = preload("res://data/actions/dash_strike.tres")
## Story 4.2: the D->L combo's action (redirectable, pass_through).
const ECHO_DASH: ActionDef = preload("res://data/actions/echo_dash.tres")
## Story 5.5: NULL's solo action (intangible 30 frames, slows_move, arms_clean_catch).
const NULL_DODGE: ActionDef = preload("res://data/actions/null_dodge.tres")
## Story 6.1: the L->N combo's action (intangible 30 frames, leaves a 120-frame decoy).
const GHOST_ECHO: ActionDef = preload("res://data/actions/ghost_echo.tres")
## Ordered combo lookup (Story 2.6, AD-02): COMBOS.get_combo(first, second).
const COMBOS: ComboTable = preload("res://data/combos/combo_table.tres")
## Story 4.3 (AD-12, D-S43-1): the cut-ladder switches, read once by the startup wiring.
const FEATURE_FLAGS: FeatureFlags = preload("res://data/config/feature_flags.tres")


## The def of a bit id; null for an unknown id (LOOP since Story 3.8, NULL_BIT since Story 5.5).
static func bit(id: int) -> BitDef:
	match id:
		Register.Bit.ATTACK:
			return BIT_ATTACK
		Register.Bit.DASH:
			return BIT_DASH
		Register.Bit.LOOP:
			return BIT_LOOP
		Register.Bit.NULL_BIT:
			return BIT_NULL
	return null


## The solo action of a bit id, or null.
static func solo_action(id: int) -> ActionDef:
	var def: BitDef = bit(id)
	return def.solo_action if def != null else null
