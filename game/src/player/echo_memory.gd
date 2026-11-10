class_name EchoMemory
extends RefCounted
## Echo's memory (Story 4.1, NP-5): the exact ActionDef of the last solo bit action that started
## (D-S41-1). Owned and written only by the ActionStateMachine's start path; cleared on every fight
## start and retry through ActionStateMachine.reset_for_fight (D-S41-8). Holds a reference to a
## read-only def, never a copy. Pure, no node.
## Storage happens when an action starts, so an action cancelled during its startup would never be
## stored; startup cancels do not exist today (cancel is RECOVERY-only), so the rule is vacuous.

## The remembered def, or null (empty memory: Echo is not startable, D-S41-3).
var last: ActionDef = null


func has_last() -> bool:
	return last != null


## Stores `def` unless it is null, not echoable (NOP, Echo itself) or an Echo def.
func remember(def: ActionDef) -> void:
	if def == null or not def.echoable or def.echo_action:
		return
	last = def


func clear() -> void:
	last = null
