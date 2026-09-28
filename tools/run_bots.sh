#!/bin/sh
# Runs the play-through bot on every level plus the enemy arena, at real speed.
# A run fails if the bot fails OR if any script error was logged along the way.
# Usage: tools/run_bots.sh [map ...]
cd "$(dirname "$0")/.." || exit 1
maps=${*:-"arena testbed proving_grounds dry_gulch rattler_mesa bandit_mine canopy_run sunken_temple idol_chamber"}
fail=0
for m in $maps; do
	out=$(godot --headless --path . -- --bot --map "$m" 2>&1)
	echo "$out" | grep -E "^(PASS|FAIL|BOT)" | grep -E "FAIL|BOT"
	errs=$(echo "$out" | grep -E "SCRIPT ERROR|^ERROR: (Invalid|Condition)" | sort | uniq -c | sort -rn)
	if [ -n "$errs" ]; then
		echo "  errors in $m:"
		echo "$errs" | head -8 | sed 's/^/    /'
		fail=1
	fi
	echo "$out" | grep -q "BOT $m OK" || fail=1
done
exit $fail
