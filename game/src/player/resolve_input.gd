class_name ResolveInput
extends RefCounted
## The inputs of one ActionResolver.resolve call (Story 2.7 AC6), replacing its 11 positional
## arguments. Built once per tick by the ActionStateMachine (and by tests). Plain data, read only by
## the resolver; it holds references, never copies, so the resolver still consumes from `buffer`.

## The shared InputBuffer (presses are consumed from it).
var buffer: InputBuffer = null
## The poll frame being ticked (the buffer's time base).
var frame: int = 0
## The register's active window (J bit, K bit).
var window: Vector2i = Vector2i.ZERO
## The running ActionDef, or null.
var action: ActionDef = null
## The last executed action frame (0 = none).
var action_frame: int = 0
## Chain record (D-S25-2): the key that started the chain and its shift serial (-1 = no chain).
var chain_key: StringName = &""
var chain_serial: int = -1
## Register.shift_serial now.
var shift_serial: int = 0
var cooldowns: Cooldowns = null
## The FSM's combo link (Story 2.6); null = no link.
var link: LinkState = null
## The combo table; null = Defs.COMBOS.
var combos: ComboTable = null
## Story 4.1 (D-S41-3): true when Echo's memory holds a def; an Echo def is not startable without it.
var echo_ready: bool = false
