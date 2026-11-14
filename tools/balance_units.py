#!/usr/bin/env python3
"""Unit efficiency table (ADR 0018): for every armed unit, damage per second against
each armour type (damage table applied, salvo counted) per 100 Alloy-equivalent of
cost (Flux counts double, as the AI's strength measure does), plus effective health
per cost. A unit beaten on every column by another of its faction at a similar role
is dominated. Reads game/data directly.

    python3 tools/balance_units.py
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
FIELD = re.compile(r"^(\w+) = (.+)$")
WEAPON_DEFAULTS = {"damage": 10.0, "damage_type": "light", "splash_radius": 0.0,
                   "hits_air": False, "hits_ground": True, "max_range": 15.0,
                   "cooldown": 1.0, "salvo": 1}


def parse(path):
    fields, ext = {}, {}
    in_resource = False
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            match = re.match(r'\[ext_resource .*path="res://([^"]+)".*id="([^"]+)"', line)
            if match:
                ext[match.group(2)] = match.group(1)
                continue
            if line.startswith("[resource]"):
                in_resource = True
                continue
            if line.startswith("["):
                in_resource = False
                continue
            found = FIELD.match(line)
            if in_resource and found:
                fields[found.group(1)] = found.group(2)
    return fields, ext


def value(text):
    text = text.strip()
    if text in ("true", "false"):
        return text == "true"
    if text.startswith('&"') or text.startswith('"'):
        return text.split('"')[1]
    try:
        return float(text)
    except ValueError:
        return text


def damage_table():
    multipliers = {}
    with open(os.path.join(ROOT, "data/combat/damage_table.tres")) as handle:
        for found in re.finditer(r'&"(\w+)/(\w+)": ([\d.]+)', handle.read()):
            multipliers[(found.group(1), found.group(2))] = float(found.group(3))
    return multipliers


def main():
    table = damage_table()
    armours = ["light", "heavy", "air", "structure"]
    rows = []
    units_dir = os.path.join(ROOT, "data/units")
    for name in sorted(os.listdir(units_dir)):
        if not name.endswith(".tres"):
            continue
        fields, ext = parse(os.path.join(units_dir, name))
        unit = {k: value(v) for k, v in fields.items()}
        weapon_ref = fields.get("weapon", "")
        found = re.search(r'ExtResource\("([^"]+)"\)', weapon_ref)
        if not found:
            continue
        weapon = dict(WEAPON_DEFAULTS)
        weapon_fields, _ = parse(os.path.join(ROOT, ext[found.group(1)]))
        weapon.update({k: value(v) for k, v in weapon_fields.items()})
        cost = float(unit.get("cost_alloy", 0)) + 2.0 * float(unit.get("cost_flux", 0))
        per_shot = float(weapon["damage"]) * float(weapon["salvo"])
        dps = per_shot / float(weapon["cooldown"])
        cells = []
        for armour in armours:
            hits = weapon["hits_air"] if armour == "air" else weapon["hits_ground"]
            mult = table.get((weapon["damage_type"], armour), 1.0) if hits else 0.0
            cells.append(100.0 * dps * mult / max(cost, 1.0))
        hp = float(unit.get("max_health", 100))
        rows.append((str(unit.get("id", name)), cost, hp, dps, float(weapon["max_range"]),
                     float(weapon["splash_radius"]), str(unit.get("armour_type", "")), cells,
                     100.0 * hp / max(cost, 1.0)))
    print("| Unit | Cost | HP | Armour | DPS | Range | Splash | DPS/100 vs light | heavy | air | structure | HP/100 |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for row in rows:
        print("| %s | %d | %d | %s | %.1f | %.0f | %.1f | %s | %.0f |" % (
            row[0], row[1], row[2], row[6], row[3], row[4], row[5],
            " | ".join("%.1f" % c for c in row[7]), row[8]))


if __name__ == "__main__":
    sys.exit(main())
