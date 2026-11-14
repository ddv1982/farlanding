#!/usr/bin/env bash
# Balance harness (ADR 0018): plays missions headless with the reference player in the
# player's seat, several seeds each, and prints one table row per mission and
# difficulty. Every run's report and its BALANCE json line are kept in the output
# directory (runs.jsonl collects the json lines).
#
#   tools/balance.sh                              # every drivable mission, seeds 1-3, normal
#   tools/balance.sh -m "conquest survey" -s "1 2 3 4" -d "easy normal hard" -j 6
#   tools/balance.sh -p idle -m verdance_conquest  # nobody plays: how fast the enemy kills
#   tools/balance.sh -t all                        # route landings with every tech owned
#   tools/balance.sh -r out/balance/runs.jsonl     # only print the table of earlier runs
#
# Options: -m missions (mission or route node ids), -s seeds, -d difficulties (the
# player's choice; it shifts each mission's own level), -p reference|idle, -j parallel
# runs, -c minutes cap per run, -t techs for route landings (comma list or "all"),
# -o output directory, -r table only.
# Env: GODOT (default: godot), BALANCE_WALL (wall-clock seconds per run, default 1800).
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME="$ROOT/game"
MISSIONS="kessel_proving kessel_storm thalassa_shallows thalassa_recovery emberfall_conquest emberfall_holdout verdance_conquest hollow_power hollow_finale"
SEEDS="1 2 3"
DIFFICULTIES="normal"
PLAYER="reference"
JOBS=4
CAP=45
TECHS=""
OUT="$ROOT/out/balance"
REPORT_ONLY=""
WALL="${BALANCE_WALL:-1800}"

while getopts "m:s:d:p:j:c:t:o:r:" opt; do
	case "$opt" in
	m) MISSIONS="$OPTARG" ;;
	s) SEEDS="$OPTARG" ;;
	d) DIFFICULTIES="$OPTARG" ;;
	p) PLAYER="$OPTARG" ;;
	j) JOBS="$OPTARG" ;;
	c) CAP="$OPTARG" ;;
	t) TECHS="$OPTARG" ;;
	o) OUT="$OPTARG" ;;
	r) REPORT_ONLY="$OPTARG" ;;
	*) exit 2 ;;
	esac
done

if [ -n "$REPORT_ONLY" ]; then
	python3 "$ROOT/tools/balance_table.py" "$REPORT_ONLY"
	exit 0
fi

command -v "$GODOT" >/dev/null || { echo "Godot binary '$GODOT' not found (set GODOT=...)" >&2; exit 1; }
mkdir -p "$OUT/logs"
RUNS="$OUT/runs.jsonl"
: >"$RUNS"

# One line per run: mission seed difficulty.
JOBLIST="$OUT/jobs.txt"
: >"$JOBLIST"
for mission in $MISSIONS; do
	for difficulty in $DIFFICULTIES; do
		for seed in $SEEDS; do
			echo "$mission $seed $difficulty" >>"$JOBLIST"
		done
	done
done

run_one() {
	local mission="$1" seed="$2" difficulty="$3"
	local log="$OUT/logs/${mission}_${difficulty}_${seed}.log"
	local args=(--mission="$mission" --seed="$seed" --difficulty="$difficulty" --player="$PLAYER" --minutes="$CAP")
	if [ -n "$TECHS" ]; then
		args+=(--techs="$TECHS")
	fi
	# A run that fails to load never quits by itself: cap its wall time.
	timeout "$WALL" "$GODOT" --headless --fixed-fps 60 --path "$GAME" res://tests/balance/balance_run.tscn -- "${args[@]}" >"$log" 2>&1 || true
	grep '^balance ' "$log" || echo "balance $mission seed $seed $difficulty: no report (see $log)"
}
export -f run_one
export GODOT GAME OUT PLAYER CAP TECHS WALL

echo "==> $(wc -l <"$JOBLIST" | tr -d ' ') runs, $JOBS at a time, logs in $OUT/logs"
xargs -P "$JOBS" -L 1 bash -c 'run_one "$0" "$1" "$2"' <"$JOBLIST"
while read -r mission seed difficulty; do
	sed -n 's/^BALANCE //p' "$OUT/logs/${mission}_${difficulty}_${seed}.log" >>"$RUNS"
done <"$JOBLIST"
python3 "$ROOT/tools/balance_table.py" "$RUNS"
