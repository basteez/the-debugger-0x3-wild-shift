extends Node
## Global signal hub. Every cross-system signal is declared here and only here.

@warning_ignore("unused_signal")
signal flow_state_changed(from: int, to: int)
@warning_ignore("unused_signal")
signal pause_toggled(paused: bool)
