#!/usr/bin/env bash
# Static guards (AC5). Run from the repo root: bash game/tools/check_guards.sh
# Prints file:line: message for each violation and exits 1 if any are found.
set -u

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
		< <(grep -rnE --include='*.gd' '\bTimer\.new\b|\bawait\b' "${sim_paths[@]}" || true)
	report "create_tween in simulation code (presentation only)" \
		< <(grep -rnE --include='*.gd' '\bcreate_tween\b' "${sim_paths[@]}" || true)
	report "Engine.time_scale in simulation code (use SimClock)" \
		< <(grep -rnE --include='*.gd' '\bEngine\.time_scale\b' "${sim_paths[@]}" || true)
fi

report "bare print( outside Log (use Log.info/debug/warn/error)" \
	< <(grep -rnE --include='*.gd' '\bprint\(' game/src | grep -v '^game/src/autoloads/log\.gd:' || true)

if [ "$violations" -gt 0 ]; then
	echo "check_guards: $violations violation(s)" >&2
	exit 1
fi
echo "check_guards: OK"
