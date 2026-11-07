extends Node
## Debug tooling switch. The ?debug URL check arrives in Story 1.6.

var enabled: bool = OS.is_debug_build()
