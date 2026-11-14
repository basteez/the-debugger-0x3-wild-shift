#!/usr/bin/env bash
# Web build size check (Story 7.7 AC 8, NFR4). Run from anywhere after a release Web export:
#   bash game/tools/check_build_size.sh [export_dir]        # default build/web (repo root relative)
# Sums the uncompressed byte size of every file under the export directory, lists the files, and
# compares the total with the budget.
# Budget: WEB_SIZE_BUDGET_BYTES (env) or 32000000 bytes, the decimal 32 MB of NFR4 used by CI since
# Story 1.3 DC4 (raised from 30000000 on 2026-11-10, deferred-work.md). [design call] D-S77-5: the
# script defaults to CI's decimal budget, not 33554432 (32 MiB), so local and CI give the same verdict.
# CI runs this script on the build it ships (the stripped custom template); a local export with the
# stock template is ~44 MB over budget (known waiver, deferred-work.md "1.3 H3") and fails here.
# Exit codes: 0 within budget, 1 over budget or empty, 2 export directory missing.
# Not a guard: check_guards.sh does not call it. Installs nothing; works with macOS and GNU tools.
set -euo pipefail

budget="${WEB_SIZE_BUDGET_BYTES:-32000000}"
if [ "$#" -ge 1 ]; then
	dir="$1"
else
	dir="$(cd "$(dirname "$0")/../.." && pwd)/build/web"
fi

if [ ! -d "$dir" ]; then
	echo "check_build_size: export directory not found: $dir" >&2
	exit 2
fi

# One byte count per file (wc -c < file is portable and immune to spaces in names).
listing="$(find "$dir" -type f -exec sh -c 'for f; do printf "%s\t%s\n" "$(wc -c < "$f" | tr -d " ")" "$f"; done' sh {} + | sort -n)"
total="$(printf '%s\n' "$listing" | awk -F '\t' 'NF >= 2 {s += $1} END {printf "%d", s + 0}')"

if [ -n "$listing" ]; then
	printf '%s\n' "$listing"
fi
mb="$(awk -v b="$total" 'BEGIN {printf "%.2f", b / 1000000}')"
echo "check_build_size: ${total} bytes (${mb} MB), budget ${budget} bytes"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	echo "### Web build size: ${total} bytes (budget ${budget})" >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$total" -le 0 ]; then
	echo "check_build_size: the export is empty" >&2
	[ -n "${GITHUB_ACTIONS:-}" ] && echo "::error::Web build is empty"
	exit 1
fi
if [ "$total" -gt "$budget" ]; then
	echo "check_build_size: over budget by $((total - budget)) bytes" >&2
	[ -n "${GITHUB_ACTIONS:-}" ] && echo "::error title=Web build over NFR4 budget::${total} bytes > ${budget} bytes"
	exit 1
fi
echo "check_build_size: OK"
