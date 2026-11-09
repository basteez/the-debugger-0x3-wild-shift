#!/usr/bin/env bash
# Static guards (AC5). Run from the repo root: bash game/tools/check_guards.sh
# Prints file:line: message for each violation and exits 1 if any are found.
set -u
cd "$(dirname "$0")/../.." || exit 2

SIM_DIRS=(input register player combat bosses skills arena)
violations=0

report() { # $1 = message, stdin = grep -n output (file:line:text)
	local msg="$1" line
	while IFS= read -r line; do
		[ -z "$line" ] && continue
		# keep "file:line", drop the matched text
		echo "$(echo "$line" | cut -d: -f1,2): $msg"
		violations=$((violations + 1))
	done
}

sim_paths=()
for d in "${SIM_DIRS[@]}"; do
	[ -d "game/src/$d" ] && sim_paths+=("game/src/$d")
done

if [ ! -d game/src ]; then
	echo "check_guards: run from the repo root (game/src not found)" >&2
	exit 2
fi

if [ ${#sim_paths[@]} -gt 0 ]; then
	report "Timer.new or await in simulation code (use SimClock frames)" \
		< <(grep -rnE --include='*.gd' '\bTimer\.new\b|\bawait\b|\bcreate_timer\b|\bget_ticks_(msec|usec)\b' "${sim_paths[@]}" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
	report "create_tween in simulation code (presentation only)" \
		< <(grep -rnE --include='*.gd' '\bcreate_tween\b' "${sim_paths[@]}" || true)
	report "Engine.time_scale in simulation code (use SimClock)" \
		< <(grep -rnE --include='*.gd' '\bEngine\.time_scale\b' "${sim_paths[@]}" || true)
	report "global RNG in simulation code (use SimContext.rng)" \
		< <(grep -rnE --include='*.gd' '(^|[^.[:alnum:]_])(randi|randf|randi_range|randf_range|randfn|randomize)[[:space:]]*\(' "${sim_paths[@]}" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
	# LiveInput is the one sim file allowed to read the Input singleton (Story 2.1, excluded by name).
	report "Input singleton in simulation code (read input through InputSource)" \
		< <(grep -rnE --include='*.gd' '(^|[^.[:alnum:]_])Input\.' "${sim_paths[@]}" | grep -v '^game/src/input/live_input\.gd:' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
fi

# Story 2.8 (AD-01, D-S28-12): hit-stop is simulation state; presentation never requests or writes it.
PRESENTATION_DIRS=(presentation ui debug)
pres_paths=()
for d in "${PRESENTATION_DIRS[@]}"; do
	[ -d "game/src/$d" ] && pres_paths+=("game/src/$d")
done
if [ ${#pres_paths[@]} -gt 0 ]; then
	report "hit-stop requested or written from presentation (sim systems only, AD-01)" \
		< <(grep -rnE --include='*.gd' '\brequest_hitstop[[:space:]]*\(|\bhitstop_frames[[:space:]]*([-+*/]?=[^=])' "${pres_paths[@]}" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
fi

report "direct output call outside Log (use Log.info/debug/warn/error)" \
	< <(grep -rnE --include='*.gd' '(^|[^.[:alnum:]_])(print|prints|printt|printraw|printerr|print_rich|print_debug|print_verbose|push_error|push_warning)[[:space:]]*\(' game/src | grep -v '^game/src/autoloads/log\.gd:' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)

if [ "$violations" -gt 0 ]; then
	echo "check_guards: $violations violation(s)" >&2
	exit 1
fi
echo "check_guards: OK"
