"""Renders every sound recipe into game/assets/audio, analyses the result and
writes audio_src/manifest.json.

    uv run --python 3.12 --with numpy --with scipy audio_src/build.py [--only SUBSTRING]

Exits non-zero if any file clips, misses its loudness target, has DC offset,
breaks its duration bounds, or (for loops) has an audible seam. The analysis
runs on the files as written (Ogg files are decoded again first), so it judges
what the game will actually load.

Also maintains the Godot side: writes the import settings each file needs
(looping, tempo for bar-synced music) into its `.import` file, keeping any uid
Godot assigned, and scaffolds a SoundEvent `.tres` in game/data/sounds for any
event that does not have one yet (existing ones are never overwritten: they hold
hand-tuned mix settings).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
from pathlib import Path

import numpy as np

from recipes import Sound, load_all
from synth import io, measure
from synth.dsp import SR

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
OUT = GAME / "assets" / "audio"
EVENTS = GAME / "data" / "sounds"
MANIFEST = Path(__file__).resolve().parent / "manifest.json"

CEILING_DBTP = -1.0  # normalisation ceiling
MAX_DBTP = -0.5  # hard fail after encoding
LUFS_TOL = {"wav": 0.5, "ogg": 1.0}
MAX_DC = 0.002
MAX_SUB = 0.03  # share of energy below 25 Hz
SEAM_JUMP = 1.5
SEAM_CURVE = 1.5
SEAM_LEVEL_DB = 1.0
OGG_MIN_SEG_SNR_DB = 18.0  # median segmental SNR of decoded vs. source

# Defaults for scaffolded SoundEvents, per group (see docs/AUDIO_STYLE.md).
EVENT_DEFAULTS = {
    "ui": dict(bus="UI", priority=90, max_instances=2, cooldown=0.03, positional=False, max_distance=0.0),
    "unit": dict(bus="Barks", priority=70, max_instances=1, cooldown=0.25, positional=False, max_distance=0.0),
    "movement": dict(bus="Units", priority=30, max_instances=3, cooldown=0.0, positional=True, max_distance=45.0),
    "world": dict(bus="UI", priority=60, max_instances=2, cooldown=0.08, positional=True, max_distance=90.0),
    "building": dict(bus="Buildings", priority=70, max_instances=1, cooldown=0.25, positional=False, max_distance=0.0),
    "base": dict(bus="Buildings", priority=60, max_instances=2, cooldown=0.1, positional=True, max_distance=90.0),
    "baseloop": dict(bus="Buildings", priority=30, max_instances=2, cooldown=0.0, positional=True, max_distance=40.0),
    "advisor": dict(bus="Advisor", priority=100, max_instances=1, cooldown=1.0, positional=False, max_distance=0.0),
    "ambience": dict(bus="Ambience", priority=100, max_instances=1, cooldown=0.0, positional=False, max_distance=0.0),
    # Combat. Priority doubles as "heaviness": the combat mixer keeps the
    # heaviest and nearest when a fight asks for more than the budget.
    "weapon": dict(bus="Weapons", priority=40, max_instances=3, cooldown=0.05, positional=True, max_distance=70.0),
    "impact": dict(bus="Weapons", priority=36, max_instances=3, cooldown=0.04, positional=True, max_distance=55.0,
                   pitch_variation=1.0),
    "explosion": dict(bus="Explosions", priority=64, max_instances=2, cooldown=0.08, positional=True,
                      max_distance=120.0, pitch_variation=0.8),
    "sting": dict(bus="Music", priority=100, max_instances=1, cooldown=1.0, positional=False, max_distance=0.0),
    # Discovery (Phase 4). Signal loops are driven by SignalPulses, which sets
    # their level from camera distance and zoom itself; max_distance is only a
    # fallback for one-shots such as scan_interrupted.
    "signal": dict(bus="Discovery", priority=55, max_instances=3, cooldown=0.0, positional=True, max_distance=120.0),
    "discovery": dict(bus="Discovery", priority=95, max_instances=1, cooldown=0.5, positional=False, max_distance=0.0),
    "field": dict(bus="SFX", priority=90, max_instances=1, cooldown=0.5, positional=False, max_distance=0.0),
    "antecedent": dict(bus="Units", priority=68, max_instances=2, cooldown=0.3, positional=True, max_distance=110.0),
    # Stealth (Phase 5): flat alert stingers on their own bus, which the
    # discovery duck leaves alone so a spotted sting always reads.
    # Beds loop under the briefing and debrief panels on their own player
    # (MissionSoundRouter -> MusicDirector.play_bed); the event only names the stream.
    "bed": dict(bus="Music", priority=100, max_instances=1, cooldown=0.0, positional=False, max_distance=0.0),
    "stealth": dict(bus="Stealth", priority=96, max_instances=1, cooldown=0.4, positional=False, max_distance=0.0),
    # Phase 6. The storm is on its own Weather bus (the muffle it puts on SFX and
    # Ambience must not muffle the storm itself). Its beds loop on the
    # StormSound's own players; gusts are flat one-shots, debris positional.
    "weather": dict(bus="Weather", priority=30, max_instances=2, cooldown=0.4, positional=False, max_distance=0.0),
    # Ambience details: quiet positional one-shots around the listener; lowest
    # priority of all, so a fight steals their voices first.
    "ambdetail": dict(bus="Ambience", priority=10, max_instances=2, cooldown=1.0, positional=True,
                      max_distance=160.0),
    # Phase 7. Ship details aboard the Meridian: flat stereo one-shots (the pan
    # is in the file), played by the AmbienceDirector in ship mode; as low a
    # priority as the planet's details.
    "shipdetail": dict(bus="Ambience", priority=10, max_instances=2, cooldown=1.0, positional=False,
                       max_distance=0.0),
    # Phase 8c. Canopy rustles: the player's units going under a crown or out
    # (CanopySound, which also rate-limits them into one gesture per group).
    "canopy": dict(bus="Units", priority=42, max_instances=2, cooldown=0.15, positional=True,
                   max_distance=70.0),
}
EVENT_OVERRIDES = {
    "ui_hover": dict(priority=20, max_instances=1, cooldown=0.06),
    "ui_invalid": dict(cooldown=0.15, max_instances=1),
    "ui_select": dict(cooldown=0.08),
    "ui_invalid_placement": dict(cooldown=0.25, max_instances=1),
    "ui_not_enough_resources": dict(cooldown=0.3, max_instances=1),
    "loop_mine": dict(max_instances=3),
    "loop_hum": dict(max_instances=3, max_distance=30.0),
    "loop_construct": dict(max_distance=50.0),
    "base_place": dict(max_distance=150.0, priority=80),
    "base_complete": dict(max_distance=120.0, priority=75, cooldown=0.4),
    "base_unload": dict(max_distance=60.0, cooldown=0.3),
    "base_turret_traverse": dict(max_distance=60.0, cooldown=0.2, priority=45),
    "advisor_under_attack": dict(cooldown=5.0),
    # Concord weapons are tonal and in key: no detune. Combine ones may wander.
    "weapon_repeater_fire": dict(priority=40, max_instances=3, cooldown=0.06),
    "weapon_light_gun_fire": dict(priority=40, max_instances=3, cooldown=0.06),
    "weapon_sentry_fire": dict(priority=46, max_instances=2, cooldown=0.1),
    "weapon_cannon_fire": dict(priority=58, max_instances=2, cooldown=0.15, max_distance=90.0),
    "weapon_skitter_gun_fire": dict(priority=38, max_instances=3, cooldown=0.06, pitch_variation=1.0),
    "weapon_lance_fire": dict(priority=50, max_instances=2, cooldown=0.1, pitch_variation=0.7),
    "weapon_siege_fire": dict(priority=58, max_instances=2, cooldown=0.2, max_distance=90.0, pitch_variation=0.7),
    "impact_spark": dict(priority=34),
    "impact_armour": dict(priority=40, max_instances=2),
    "impact_ground": dict(priority=36, max_instances=2),
    "explosion_small": dict(priority=62, max_instances=3, cooldown=0.06),
    "explosion_medium": dict(priority=66),
    "explosion_large": dict(priority=70, max_instances=2, cooldown=0.15, max_distance=150.0),
    "death_light": dict(priority=66, max_instances=2, cooldown=0.1),
    "death_heavy": dict(priority=72, max_instances=2, cooldown=0.15, max_distance=140.0),
    "death_building": dict(priority=78, max_instances=1, cooldown=0.3, max_distance=160.0),
    "scan_interrupted": dict(max_instances=2, cooldown=0.2, priority=70),
    "ui_intel_tick": dict(cooldown=0.08, max_instances=1),
    "ui_codex_entry": dict(cooldown=0.3, max_instances=1),
    "advisor_discovery": dict(cooldown=2.0),
    # The Warden is a third sound world: it never wanders out of tune.
    "weapon_warden_fire": dict(priority=52, max_instances=2, cooldown=0.1, max_distance=90.0),
    "death_warden": dict(priority=74, max_instances=1, cooldown=0.2, max_distance=140.0),
    "loop_hum_warden": dict(max_instances=2, max_distance=45.0),
    "loop_hum_hub": dict(max_instances=1, max_distance=50.0),
    "loop_hum_forge": dict(max_instances=1, max_distance=50.0),
    "loop_hum_spire": dict(max_instances=1, max_distance=55.0),
    "loop_hum_survey_lab": dict(max_instances=1, max_distance=40.0),
    # Faint and close: a pulse is a clue for a camera that is nearby.
    "signal_pulse": dict(max_distance=80.0, priority=45),
    # Played with the antecedent resolve phrase, which ducks the Music bus.
    "mus_swell_antecedent": dict(bus="Discovery"),
    # Phase 5. Suspicion tones are driven by SuspicionTones (level and pitch
    # follow suspicion); cloak sounds sit on the Wisp.
    "stealth_suspicion": dict(positional=True, max_distance=70.0, priority=50, max_instances=2, cooldown=0.0),
    "stealth_cloak_engage": dict(positional=True, max_distance=60.0, priority=65, max_instances=2, cooldown=0.1),
    "stealth_cloak_disengage": dict(positional=True, max_distance=60.0, priority=65, max_instances=2, cooldown=0.1),
    "stealth_spotted": dict(priority=110, cooldown=0.6),
    "stealth_alert_alarm": dict(priority=105, cooldown=2.0),
    "stealth_alert_suspicious": dict(cooldown=1.5),
    "stealth_all_clear": dict(cooldown=1.5),
    "ui_briefing_tick": dict(priority=15, max_instances=1, cooldown=0.03),
    "ui_objective_tick": dict(cooldown=0.25, max_instances=1),
    "advisor_objective_done_secondary": dict(cooldown=0.5),
    "weapon_wisp_fire": dict(priority=38, max_instances=2, cooldown=0.08, max_distance=50.0),
    "weapon_lancer_fire": dict(priority=54, max_instances=2, cooldown=0.12, max_distance=85.0),
    "weapon_arc_fire": dict(priority=58, max_instances=2, cooldown=0.2, max_distance=110.0),
    "death_wisp": dict(priority=66, max_instances=2, cooldown=0.1),
    "death_lancer": dict(priority=66, max_instances=2, cooldown=0.1),
    "death_arc": dict(priority=72, max_instances=2, cooldown=0.15, max_distance=140.0),
    "move_wisp": dict(max_instances=2, max_distance=30.0),
    # Phase 6.
    "storm_debris": dict(positional=True, max_distance=70.0, priority=25, max_instances=3, cooldown=0.3,
                         pitch_variation=1.5),
    "storm_gust": dict(priority=35, max_instances=2, cooldown=1.5),
    "storm_front_rumble": dict(priority=60, max_instances=1, cooldown=10.0),
    "storm_passed": dict(priority=60, max_instances=1, cooldown=10.0),
    "ui_slider_tick": dict(priority=40, max_instances=1, cooldown=0.04),
    "ui_toggle": dict(cooldown=0.06),
    "ui_hint_show": dict(cooldown=0.3, max_instances=1),
    "ui_hint_dismiss": dict(cooldown=0.2, max_instances=1),
    "death_prop_crates": dict(priority=60, max_instances=2, cooldown=0.1),
    "death_prop_tank": dict(priority=66, max_instances=1, cooldown=0.2, max_distance=140.0),
    "death_prop_barrier": dict(priority=58, max_instances=2, cooldown=0.1),
    "death_prop_boulder": dict(priority=60, max_instances=2, cooldown=0.15),
    "discovery_enemy_intel": dict(priority=80, cooldown=4.0),
    "advisor_enemy_intel": dict(cooldown=2.0),
    "mus_hit_combat": dict(cooldown=6.0),
    "mus_hit_aftermath": dict(cooldown=6.0),
    # Phase 7. Hovers are also rate-limited by the CampaignSoundRouter.
    "ui_map_node_hover": dict(priority=20, max_instances=1, cooldown=0.05),
    "ui_tech_hover": dict(priority=20, max_instances=1, cooldown=0.05),
    "ui_tech_buy": dict(cooldown=0.15, max_instances=1),
    "ui_tech_unlocked": dict(cooldown=0.3, max_instances=1),
    "ui_tech_denied": dict(cooldown=0.15, max_instances=1),
    "ui_map_launch": dict(cooldown=1.0, max_instances=1),
    "ui_campaign_saved": dict(priority=40, cooldown=1.0, max_instances=1),
    "ui_loadout_change": dict(cooldown=0.06),
    # Phase 8a, Thalassa Low. The tide's warnings are flat on the Weather bus,
    # like the storm front; its beds loop on the TideSound's own players.
    "tide_turn_rising": dict(priority=70, max_instances=1, cooldown=5.0),
    "tide_turn_falling": dict(priority=70, max_instances=1, cooldown=5.0),
    "amb_shore_call": dict(max_instances=1, cooldown=4.0),
    "amb_buoy_bell": dict(max_instances=1, cooldown=6.0, max_distance=200.0),
    "amb_drip": dict(max_distance=90.0),
    "ui_artefact_pickup": dict(cooldown=0.3, max_instances=1),
    "ui_artefact_drop": dict(cooldown=0.3, max_instances=1),
    "loop_hum_artefact": dict(max_instances=1, max_distance=50.0, priority=40),
    # Phase 8b, Emberfall. Eruption sounds play on the EruptionSound's own
    # positional players (Weather bus); these settings document them and serve
    # anything that plays them through the pool.
    "eruption_build_low": dict(positional=True, max_distance=220.0, priority=60, max_instances=2, cooldown=0.0),
    "eruption_build_high": dict(positional=True, max_distance=220.0, priority=60, max_instances=2, cooldown=0.0),
    "eruption_knock": dict(positional=True, max_distance=180.0, priority=55, max_instances=2, cooldown=0.08,
                           pitch_variation=0.6),
    "eruption_blast": dict(positional=True, max_distance=320.0, priority=85, max_instances=2, cooldown=0.3),
    "amb_distant_collapse": dict(max_instances=1, cooldown=8.0, max_distance=220.0),
    "amb_gas_hiss": dict(max_distance=120.0),
    "amb_ember_tick": dict(max_distance=70.0),
    "mus_holdout_minute": dict(cooldown=10.0),
    "mus_holdout_engine": dict(cooldown=0.0),
    "mus_holdout_arrived": dict(cooldown=5.0),
    "ui_vent_release": dict(cooldown=0.12, max_instances=1),
    "ui_vent_denied": dict(cooldown=0.2, max_instances=1),
    # Phase 8c, Verdance. Calls are rare and never overlap; wing flurries and
    # creaks are heard from further than drips.
    "amb_canopy_call": dict(max_instances=1, cooldown=5.0, max_distance=180.0),
    "amb_wing_flurry": dict(max_instances=1, cooldown=3.0, max_distance=120.0),
    "amb_branch_creak": dict(max_distance=120.0),
    "amb_leaf_drip": dict(max_distance=60.0),
    # Air units (Phase 8c). Engines are heard further than ground chassis: the
    # sky carries. Concord weapons stay in tune, the Hornet's may wander.
    "move_talon": dict(max_instances=2, max_distance=75.0, priority=34),
    "move_hornet": dict(max_instances=2, max_distance=75.0, priority=34),
    "weapon_talon_fire": dict(priority=44, max_instances=3, cooldown=0.08, max_distance=85.0),
    "weapon_hornet_fire": dict(priority=40, max_instances=3, cooldown=0.06, max_distance=80.0, pitch_variation=1.0),
    "death_talon": dict(priority=72, max_instances=2, cooldown=0.15, max_distance=150.0),
    "death_hornet": dict(priority=72, max_instances=2, cooldown=0.15, max_distance=150.0, pitch_variation=0.6),
}


# --------------------------------------------------------------------------- render


def render(s: Sound) -> np.ndarray:
    x = s.fn(np.random.default_rng(s.seed))
    x = np.asarray(x, dtype=np.float64)
    if s.channels == 1 and x.ndim != 1:
        raise ValueError(f"{s.id}: recipe returned {x.shape}, expected mono")
    if s.channels == 2 and (x.ndim != 2 or x.shape[0] != 2):
        raise ValueError(f"{s.id}: recipe returned {x.shape}, expected stereo (2, n)")
    if not np.all(np.isfinite(x)):
        raise ValueError(f"{s.id}: recipe produced NaN/inf")
    return measure.normalize(x, s.target_lufs, CEILING_DBTP, circular=s.loop)


def import_params(s: Sound) -> tuple[str, str, dict]:
    if s.fmt == "wav":
        return "wav", "AudioStreamWAV", {
            "force/8_bit": "false", "force/mono": "false", "force/max_rate": "false",
            "force/max_rate_hz": "44100", "edit/trim": "false", "edit/normalize": "false",
            "edit/loop_mode": "2" if s.loop else "1", "edit/loop_begin": "0", "edit/loop_end": "-1",
            "compress/mode": "2",
        }
    return "oggvorbisstr", "AudioStreamOggVorbis", {
        "loop": "true" if s.loop else "false", "loop_offset": "0",
        "bpm": f"{s.bpm:g}" if s.bpm else "0", "beat_count": str(s.beats), "bar_beats": str(s.bar_beats),
    }


def write_import(path: Path, s: Sound) -> None:
    """Writes the import settings Godot should use, unless the existing .import
    already has exactly these values. Keeps a previously assigned uid."""
    importer, rtype, params = import_params(s)
    imp = path.with_name(path.name + ".import")
    uid = ""
    if imp.exists():
        text = imp.read_text()
        current = dict(re.findall(r"^([\w/]+)=(.*)$", text.split("[params]")[-1], re.M))
        if all(current.get(k) == v for k, v in params.items()) and f'importer="{importer}"' in text:
            return
        m = re.search(r'^uid="([^"]+)"', text, re.M)
        uid = m.group(1) if m else ""
    lines = ["[remap]", "", f'importer="{importer}"', f'type="{rtype}"']
    if uid:
        lines.append(f'uid="{uid}"')
    lines += ["", "[params]", ""] + [f"{k}={v}" for k, v in params.items()]
    imp.write_text("\n".join(lines) + "\n")


def event_id(s: Sound) -> str:
    """Variations share an event: unit_ranger_select_2 -> unit_ranger_select.
    A recipe can instead name its events in params["events"] (movement loops
    are shared by chassis: move_rover serves the event move_surveyor)."""
    return re.sub(r"_\d+$", "", s.id)


def scaffold_events(sounds: list[Sound]) -> list[str]:
    """Creates game/data/sounds/<group>/<event>.tres for new events only."""
    groups: dict[str, list[Sound]] = {}
    for s in sounds:
        if s.group in EVENT_DEFAULTS:
            for eid in s.params.get("events", [event_id(s)]):
                groups.setdefault(eid, []).append(s)
    created = []
    for eid, members in sorted(groups.items()):
        s0 = members[0]
        path = EVENTS / s0.group / f"{eid}.tres"
        if path.exists():
            continue
        cfg = dict(EVENT_DEFAULTS[s0.group], **EVENT_OVERRIDES.get(eid, {}))
        ext = ['[ext_resource type="Script" path="res://audio/sound_event.gd" id="1_script"]']
        refs = []
        for i, m in enumerate(sorted(members, key=lambda x: x.id), start=2):
            ext.append(f'[ext_resource type="AudioStream" path="res://assets/audio/{m.path}" id="{i}_stream"]')
            refs.append(f'ExtResource("{i}_stream")')
        body = [
            "[resource]",
            'script = ExtResource("1_script")',
            f'id = &"{eid}"',
            f"streams = Array[AudioStream]([{', '.join(refs)}])",
            f'bus = &"{cfg["bus"]}"',
            f"priority = {cfg['priority']}",
            f"max_instances = {cfg['max_instances']}",
            f"cooldown = {cfg['cooldown']}",
            f"positional = {'true' if cfg['positional'] else 'false'}",
            f"max_distance = {cfg['max_distance']}",
        ]
        for key in ("volume_db", "pitch_variation"):
            if cfg.get(key):
                body.append(f"{key} = {cfg[key]}")
        text = '[gd_resource type="Resource" script_class="SoundEvent" format=3]\n\n'
        text += "\n".join(ext) + "\n\n" + "\n".join(body) + "\n"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        created.append(str(path.relative_to(ROOT)))
    return created


# --------------------------------------------------------------------------- analysis


def analyse(s: Sound, src: np.ndarray, path: Path) -> dict:
    y = io.read_wav(path) if s.fmt == "wav" else io.read_any(path, s.channels)
    a = {
        "seconds": y.shape[-1] / SR,
        "lufs": measure.lufs(y),
        "dbtp": measure.true_peak(y),
        "peak": measure.sample_peak(y),
        "dc": measure.dc_offset(y),
        **measure.spectrum(y),
    }
    if s.loop:
        a.update(measure.seam(y))
    if s.fmt == "ogg":
        n = min(y.shape[-1], src.shape[-1])
        win = int(0.1 * SR)
        e = np.atleast_2d(y)[:, :n] - np.atleast_2d(src)[:, :n]
        snrs = []
        for i in range(0, n - win, win):
            p = np.sum(np.atleast_2d(src)[:, i:i + win] ** 2)
            if p > 1e-4:
                snrs.append(10 * np.log10(p / (np.sum(e[:, i:i + win] ** 2) + 1e-20)))
        a["codec_snr"] = float(np.median(snrs)) if snrs else 99.0
        a["length_delta"] = int(y.shape[-1] - src.shape[-1])
    problems = []
    if a["dbtp"] > MAX_DBTP or a["peak"] >= -0.01:
        problems.append(f"clips ({a['dbtp']:.2f} dBTP)")
    if abs(a["lufs"] - s.target_lufs) > LUFS_TOL[s.fmt]:
        problems.append(f"loudness {a['lufs']:.1f} vs target {s.target_lufs:.1f}")
    if a["dc"] > MAX_DC:
        problems.append(f"DC offset {a['dc']:.4f}")
    if a["sub_ratio"] > MAX_SUB:
        problems.append(f"subsonic energy {a['sub_ratio']:.1%}")
    if not (s.min_seconds <= a["seconds"] <= s.max_seconds):
        problems.append(f"duration {a['seconds']:.3f}s outside [{s.min_seconds}, {s.max_seconds}]")
    if s.loop:
        if a["jump"] > SEAM_JUMP or a["curve"] > SEAM_CURVE:
            problems.append(f"loop seam click (jump {a['jump']:.2f}, curve {a['curve']:.2f})")
        if a["level_db"] > SEAM_LEVEL_DB:
            problems.append(f"loop seam level step {a['level_db']:.1f} dB")
        if s.fmt == "ogg" and a["length_delta"] != 0:
            problems.append(f"encoded length differs by {a['length_delta']} samples")
    if s.fmt == "ogg" and a["codec_snr"] < OGG_MIN_SEG_SNR_DB:
        problems.append(f"codec fidelity {a['codec_snr']:.1f} dB")
    a["problems"] = problems
    return a


def table(rows: list[tuple[Sound, dict]]) -> str:
    head = f"{'file':52} {'dur s':>6} {'LUFS':>6} {'tgt':>5} {'dBTP':>6} {'DC':>6} {'cent Hz':>7} {'seam j/c/dB':>15} {'codec':>6}  result"
    out = [head, "-" * len(head)]
    for s, a in rows:
        seam = f"{a['jump']:.2f}/{a['curve']:.2f}/{a['level_db']:+.1f}" if s.loop else "-"
        codec = f"{a['codec_snr']:.0f}dB" if "codec_snr" in a else "-"
        res = "ok" if not a["problems"] else "FAIL: " + "; ".join(a["problems"])
        out.append(
            f"{s.path:52} {a['seconds']:6.2f} {a['lufs']:6.1f} {s.target_lufs:5.0f} {a['dbtp']:6.1f} "
            f"{a['dc']:6.4f} {a['centroid_hz']:7.0f} {seam:>15} {codec:>6}  {res}"
        )
    return "\n".join(out)


# --------------------------------------------------------------------------- main


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="render only sounds whose id contains this")
    args = ap.parse_args()

    sounds = load_all()
    ids = [s.id for s in sounds]
    if len(ids) != len(set(ids)):
        raise SystemExit("duplicate sound ids")
    chosen = [s for s in sounds if args.only in s.id]
    manifest = {}
    if MANIFEST.exists() and args.only:
        manifest = {e["id"]: e for e in json.loads(MANIFEST.read_text())["sounds"]}

    rows = []
    t0 = time.time()
    for s in chosen:
        x = render(s)
        path = OUT / s.path
        path.parent.mkdir(parents=True, exist_ok=True)
        write_import(path, s)
        (io.write_wav if s.fmt == "wav" else io.write_ogg)(path, x, s.seed)
        a = analyse(s, x, path)
        rows.append((s, a))
        manifest[s.id] = {
            "id": s.id,
            "file": f"game/assets/audio/{s.path}",
            "recipe": f"{s.fn.__module__}." + s.params.get("recipe", s.fn.__name__),
            "seed": s.seed,
            "group": s.group,
            "format": s.fmt,
            "channels": s.channels,
            "loop": s.loop,
            "seconds": round(a["seconds"], 4),
            "peak_dbtp": round(a["dbtp"], 2),
            "lufs": round(a["lufs"], 2),
            "target_lufs": s.target_lufs,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "source": "synthesised (audio_src recipes); no recordings, samples or external services",
        }
        print(f"  rendered {s.path}", file=sys.stderr)

    if not args.only:
        # Remove outputs that no recipe produces any more.
        known = {str(OUT / s.path) for s in sounds}
        for f in OUT.rglob("*"):
            if f.suffix in (".wav", ".ogg") and str(f) not in known:
                f.unlink()
                f.with_name(f.name + ".import").unlink(missing_ok=True)
                print(f"  removed stale {f.relative_to(ROOT)}", file=sys.stderr)

    MANIFEST.write_text(json.dumps({
        "generator": "audio_src/build.py",
        "sample_rate": SR,
        "sounds": [manifest[k] for k in sorted(manifest)],
    }, indent=1) + "\n")
    created = scaffold_events(sounds)

    print(table(rows))
    failed = [s.id for s, a in rows if a["problems"]]
    print(f"\n{len(rows)} files rendered in {time.time() - t0:.1f}s, {len(failed)} failed.")
    for c in created:
        print(f"scaffolded {c}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
