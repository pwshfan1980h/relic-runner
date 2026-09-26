#!/bin/sh
# Runs the play-through bot on every level plus the enemy arena, at real speed.
# Usage: tools/run_bots.sh [map ...]
cd "$(dirname "$0")/.." || exit 1
maps=${*:-"arena proving_grounds dry_gulch rattler_mesa bandit_mine canopy_run sunken_temple idol_chamber"}
fail=0
for m in $maps; do
	out=$(godot --headless --path . -- --bot --map "$m" 2>&1)
	echo "$out" | grep -E "^(PASS|FAIL|BOT)|SCRIPT ERROR" | grep -E "FAIL|BOT|SCRIPT"
	echo "$out" | grep -q "BOT $m OK" || fail=1
done
exit $fail
