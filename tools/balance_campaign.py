#!/usr/bin/env python3
"""Campaign economy model (ADR 0018): Intel earned along the route against the tech
web's costs. For each landing on the main route it takes the Intel a player banks
(the sites on that landing's map times an exploration share for the mission type, or
the median the reference player banked in balance runs, `-r runs.jsonl`), then buys
techs at the Meridian the way a reasonable player would (the cheapest one it can
afford whose requirements are met, repeatedly). Prints Intel per landing, what is
owned when each landing starts (the "typical techs" the balance harness assumes) and
the share of the web owned at the finale. Reads game/data directly.

    python3 tools/balance_campaign.py [-r out/balance/runs.jsonl] [-x 0.7] [--gdscript]

Sites pay on every landing on their map (ADR 0012 keeps no per-site memory across
landings), so a planet with two landings pays twice.
"""
import argparse
import json
import os
import re
import statistics

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
# The main route as played (the Kessel branch takes the storm survey).
ROUTE = [
    "kessel_proving",
    "kessel_storm",
    "thalassa_shallows",
    "thalassa_recovery",
    "emberfall_conquest",
    "emberfall_holdout",
    "verdance_conquest",
    "verdance_infiltration",
    "hollow_power",
    "hollow_finale",
]
# Share of a map's site Intel a reasonable (not completionist) player banks, by
# mission type. Survey: Intel is the objective. Holdout and infiltration leave little
# room to wander; an infiltration's own objective sites are counted separately.
EXPLORE = {
    "conquest": 0.7,
    "survey": 0.85,
    "recovery": 0.5,
    "holdout": 0.25,
    "infiltration": 0.0,
    "power": 0.5,
    "finale": 0.3,
}


def read(path):
    with open(os.path.join(ROOT, path)) as handle:
        return handle.read()


def ext_paths(text):
    return {m.group(2): m.group(1) for m in re.finditer(
        r'\[ext_resource [^\]]*path="res://([^"]+)"[^\]]*id="([^"]+)"', text)}


def resource_block(text):
    return text[text.index("[resource]"):]


def field(block, name, default=None):
    found = re.search(r"^%s = (.+)$" % name, block, re.M)
    return found.group(1).strip() if found else default


def mission_of(node_id):
    text = read("data/campaign/route/%s.tres" % node_id)
    exts = ext_paths(text)
    ref = re.search(r'^mission = ExtResource\("([^"]+)"\)', text, re.M).group(1)
    return exts[ref]


def map_sites(mission_path):
    """Intel of every discovery on the mission's map, and the infiltration's own
    objective sites."""
    text = read(mission_path)
    block = resource_block(text)
    kind = field(block, "mission_type", '&"conquest"').split('"')[1]
    exts = ext_paths(text)
    scene = exts[re.search(r'ExtResource\("([^"]+)"\)', field(block, "map_scene")).group(1)]
    name = os.path.basename(os.path.dirname(scene))
    rewards = {}
    map_path = "data/maps/%s_map.tres" % name
    if os.path.exists(os.path.join(ROOT, map_path)):
        map_text = read(map_path)
        map_exts = ext_paths(map_text)
        refs = re.search(r"^discoveries = .*$", map_text, re.M)
        if refs:
            for ref in re.findall(r'ExtResource\("([^"]+)"\)', refs.group(0)):
                path = map_exts.get(ref, "")
                if "discoveries/" in path:
                    disc = read(path)
                    rewards[os.path.basename(path)[:-5]] = int(field(resource_block(disc), "intel_reward", "0"))
    objective_sites = re.findall(r'site_ids = Array\[StringName\]\(\[([^\]]*)\]\)', text)
    wanted = set()
    for group in objective_sites:
        wanted.update(re.findall(r'&"(\w+)"', group))
    return kind, rewards, wanted


def techs():
    result = {}
    folder = os.path.join(ROOT, "data/campaign/techs")
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".tres"):
            continue
        block = resource_block(read("data/campaign/techs/" + name))
        result[field(block, "id").split('"')[1]] = {
            "cost": int(field(block, "intel_cost", "0")),
            "requires": re.findall(r'&"(\w+)"', field(block, "requires", "")),
            "discovery": (field(block, "requires_discovery", '&""').split('"') + [""])[1],
        }
    return result


def measured(path):
    by_mission = {}
    with open(path) as handle:
        for line in handle:
            if line.strip():
                run = json.loads(line)
                if run.get("difficulty") == "normal":
                    by_mission.setdefault(run["mission"], []).append(run["intel"])
    return {k: statistics.median(v) for k, v in by_mission.items()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-r", "--runs", help="runs.jsonl of balance runs (measured Intel)")
    parser.add_argument("-x", "--explore", type=float, default=1.0,
                        help="scale on the exploration shares (0.7 = a lazier player)")
    parser.add_argument("-c", "--cost-scale", type=float, default=1.0,
                        help="preview tech costs multiplied by this")
    parser.add_argument("--gdscript", action="store_true",
                        help="print the typical-techs table for balance_run.gd")
    args = parser.parse_args()
    runs = measured(args.runs) if args.runs else {}
    web = techs()
    for tech in web.values():
        tech["cost"] = round(tech["cost"] * args.cost_scale / 5) * 5
    total = sum(t["cost"] for t in web.values())
    owned, found, bank, typical = [], set(), 0, {}
    print("| Landing | Type | Sites on map | Intel banked | Bank after buying | Owned at start |")
    print("|---|---|---|---|---|---|")
    for node in ROUTE:
        mission_path = mission_of(node)
        kind, rewards, wanted = map_sites(mission_path)
        typical[node] = list(owned)
        mission_id = field(resource_block(read(mission_path)), "id").split('"')[1]
        site_total = sum(rewards.values())
        if mission_id in runs:
            earned = round(runs[mission_id] * args.explore)
        else:
            earned = round(site_total * EXPLORE[kind] * args.explore)
            earned += sum(rewards.get(w, 0) for w in wanted if kind == "infiltration")
        if node == ROUTE[-1]:
            print("| %s | %s | %d | (finale) | %d | %d techs, %d%% of the web |" % (
                node, kind, site_total, bank, len(owned),
                100 * sum(web[t]["cost"] for t in owned) // total))
            break
        # A reasonable player finds the sites it scanned: the larger ones first.
        share = EXPLORE[kind] * args.explore
        for disc, _ in sorted(rewards.items(), key=lambda kv: -kv[1])[: round(len(rewards) * share)]:
            found.add(disc)
        found.update(w for w in wanted if kind == "infiltration")
        bank += earned
        while True:
            ready = [t for t, d in web.items() if t not in owned
                     and all(r in owned for r in d["requires"])
                     and (d["discovery"] == "" or d["discovery"] in found)
                     and d["cost"] <= bank]
            if not ready:
                break
            pick = min(ready, key=lambda t: web[t]["cost"])
            owned.append(pick)
            bank -= web[pick]["cost"]
        print("| %s | %s | %d | %d | %d | %d |" % (
            node, kind, site_total, earned, bank, len(typical[node])))
    spent = sum(web[t]["cost"] for t in owned)
    print("\nWeb: %d techs, %d Intel. Owned at the finale: %d techs, %d Intel (%d%%)." % (
        len(web), total, len(owned), spent, 100 * spent // total))
    if args.gdscript:
        print("\nconst TYPICAL_TECHS: Dictionary[String, PackedStringArray] = {")
        for node in ROUTE:
            print('\t"%s": PackedStringArray(%s),' % (node, json.dumps(typical[node])))
        print("}")


if __name__ == "__main__":
    main()
