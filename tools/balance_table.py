#!/usr/bin/env python3
"""Summarises balance runs (tools/balance.sh, ADR 0018): one row per mission and
difficulty over its seeds. Reads the BALANCE json lines (runs.jsonl)."""
import json
import statistics
import sys
from collections import defaultdict


def clock(seconds):
    if seconds is None or seconds < 0:
        return "-"
    return "%d:%02d" % (seconds // 60, seconds % 60)


def median(values):
    values = [v for v in values if v is not None and v >= 0]
    return round(statistics.median(values)) if values else -1


def main(path):
    groups = defaultdict(list)
    order = []
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            run = json.loads(line)
            key = (run["mission"], run["difficulty"])
            if key not in groups:
                order.append(key)
            groups[key].append(run)
    header = (
        "| Mission | Diff | Level | Runs | Won | Lost | Timeout | Duration (med) | "
        "First hit (med) | First attack | Enemy waves (seed 1) | Units lost | "
        "Bldg lost | Intel | Peak army me/enemy | Alloy float |"
    )
    print(header)
    print("|" + "---|" * (header.count("|") - 1))
    for key in order:
        runs = groups[key]
        won = sum(1 for r in runs if r["over"] and r["won"])
        lost = sum(1 for r in runs if r["over"] and not r["won"])
        timeout = sum(1 for r in runs if not r["over"])
        waves = runs[0].get("enemy_waves", [])
        print(
            "| %s | %s | %s | %d | %d | %d | %d | %s | %s | %s | %s | %d | %d | %d | %d/%d | %d |"
            % (
                key[0],
                key[1],
                runs[0].get("enemy_level", "?"),
                len(runs),
                won,
                lost,
                timeout,
                clock(median([r["seconds"] for r in runs])),
                clock(median([r["first_hit"] for r in runs])),
                clock(median([r["first_attack"] for r in runs])),
                ",".join(str(w) for w in waves[:6]) or "-",
                median([r["units_lost"] for r in runs]),
                median([r["buildings_lost"] for r in runs]),
                median([r["intel"] for r in runs]),
                median([r["peak_army"] for r in runs]),
                median([r["peak_enemy_army"] for r in runs]),
                median([r["mean_alloy_float"] for r in runs]),
            )
        )


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "out/balance/runs.jsonl")
