# Farlanding — Game Design & Phased Build Plan

Status: **approved 2026-11-12.** Implementation in progress.
Toolchain found on this machine: Godot 4.7.2 stable, Blender 5.3.0, ffmpeg, Python 3.15, uv.

Section 9 records the decisions taken with the project owner.

---

## 1. The game in one page

**Farlanding** is a single-player RTS about a survey expedition following a trail of dormant beacons left by a vanished civilisation, the Antecedents. You command the expedition carrier *Meridian*. Each beacon leads to a planet; each planet is a landing; each landing is a mission.

**The loop**

1. **Aboard the Meridian (star map).** Pick the next planet from a branching route. Read the orbital scan: coarse terrain, a mission brief, and unresolved signal blips marked `?`. Spend Intel on the tech web. Choose a loadout.
2. **Landing.** Your dropship, the Lander, sets down and *becomes your HQ*. Build a base, harvest, produce units.
3. **Explore.** The map is full of things the orbital scan could not resolve. Scanning them earns **Intel** and often changes the mission: a shortcut, a resource bonus, a dormant machine, a weakness in the enemy base.
4. **Resolve the objective** — which is not always "destroy the enemy".
5. **Return to orbit** with Intel, artefacts and codex entries. New route options open.

**What makes it its own game: Intel is the third resource, and you can only get it by looking.**
Alloy and Flux come from harvesting. Intel comes only from discovery. It is spent two ways:

| Where | What it buys | Lifetime |
|---|---|---|
| Survey Lab, during a mission | *Field options*: reveal patrol routes, unlock a planet-specific unit variant, call an orbital scan or supply drop | This mission |
| Tech web, aboard the Meridian | New units, buildings, upgrades, ship abilities | Permanent |

This puts the classic RTS tension (economy vs. army) next to a second one (fight now vs. find out more), and it makes the scout a first-class unit instead of a throwaway.

**Why this design**

- *Curiosity needs a visible promise.* The orbital scan shows that something is there before you know what. A `?` on the map is a stronger pull than black fog.
- *Discoveries must change play, not just fill a log.* Every discovery type has a mechanical payoff (section 2.4).
- *Each planet has one rule that bends the standard game* (section 2.5), so landing somewhere new means learning something new.

**Non-goals for 1.0:** multiplayer, a second playable faction, naval units, procedural map generation, mod tools. The architecture does not block them, but nothing is built for them.

---

## 2. Design

### 2.1 Factions

| Faction | Role | Character | Look |
|---|---|---|---|
| **The Concord Survey** | Player | Scientists with guns. Fewer, sturdier, versatile units; strong sensors | Off-white ceramic panels, safety-orange accents, rounded hard-surface |
| **The Halcyon Combine** | Enemy, builds bases | A salvage conglomerate strip-mining the same trail. Cheap, numerous, drone-heavy | Graphite hulls, acid-teal lights, angular industrial |
| **Custodians** | Neutral, no base | Antecedent machines guarding sites. Dormant until disturbed | Pale stone and brass, geometric, glowing seams |

The Combine uses exactly the same systems as the player (same definitions, same commands, same economy). That halves the engineering and means the enemy AI plays by the rules. Custodians exist so that exploration has stakes even far from the enemy.

### 2.2 Economy

- **Alloy** — mined from deposits by Haulers, returned to a Refinery. Finite per deposit.
- **Flux** — tapped from vents by a building. Infinite but slow, and vents are contested map positions.
- **Power** — a capacity, not a stockpile. Low power slows production and switches off sensors.
- **Intel** — discovery only.

### 2.3 Starting roster (Concord)

Units: **Fabricator** (builder drone), **Hauler** (harvester), **Surveyor** (fast scout, scanner, unarmed), **Ranger** (light infantry walker), **Lancer** (anti-armour), **Bulwark** (heavy tank), **Kite** (fast skimmer), **Arc** (artillery), **Wisp** (stealth infiltrator). Air units arrive after the vertical slice.

Buildings: **Lander** (HQ), **Reactor**, **Refinery**, **Flux Tap**, **Muster Bay** (infantry), **Foundry** (vehicles), **Survey Lab**, **Sensor Mast**, **Sentry** (turret).

Combat uses a small armour-type × damage-type table (light / heavy / structure) held in data. The Combine roster mirrors these roles with different stats and silhouettes.

### 2.4 Exploration and Intel

Three knowledge states per map cell: **charted** (orbital scan: terrain shape only), **explored** (seen once, shown as last known), **visible** (in sight now).

| Discovery type | Found by | Payoff |
|---|---|---|
| Geological | Scanning formations | Rich deposits, hidden vents, passable routes |
| Biological | Observing flora/fauna | Counters to the planet's hazard; sometimes a hazard you can aim at the enemy |
| Antecedent | Scanning ruins, recovering caches | Tech-web branches that cannot be bought any other way |
| Enemy | Observing Combine structures unseen | Their build state, patrol routes, a weak point |

Every discovery writes a short **codex** entry. Larger finds are multi-step: a ruin points to a second site, which needs a unit you may not have yet. Some cannot be completed on the first visit, which is a reason to return to a planet.

### 2.5 Planets

Each planet = a biome, a palette, an ambience, and **one rule**. Launch set of five:

| Planet | Rule |
|---|---|
| **Kessel Reach** (dust basin) | Periodic dust storms cut vision and ground speed for everyone |
| **Thalassa Low** (tidal flats) | The tide floods lowlands on a timer, opening and closing routes |
| **Emberfall** (volcanic) | Flux vents are rich but erupt; buildings near them take damage |
| **Verdance** (overgrown) | Canopy hides ground units from air and long-range sight |
| **Hollow Meridian** (Antecedent megastructure) | Custodians everywhere; power comes from reactivating old machinery |

### 2.6 Mission types

All built from one objective framework (section 3.6), so new types are data and small scripts, not engine work.

- **Conquest** — destroy the Combine base.
- **Survey** — bank a target amount of Intel before the Combine does, or before the storm arrives.
- **Infiltration** — no base. A small squad, patrol routes, sight cones, and an alert meter (Unaware → Suspicious → Alerted). Being seen is not instant failure; it changes what the mission becomes.
- **Recovery** — reach an artefact, then get it back to the Lander.
- **Holdout** — keep a site alive until extraction.

### 2.7 Visual style

Stylised and readable rather than realistic: chunky mid-poly hard-surface, strong silhouettes, restrained detail, one bold palette per planet. The UI reads like survey instruments and charts. Reasons: units must be identifiable from high zoom, the style is achievable by a small team in Blender, and it stays cheap to render with a couple of hundred units on screen.

---

## 3. Architecture

### 3.1 Technology choices

| Choice | Decision | Reason |
|---|---|---|
| Engine | Godot 4.7.2, Forward+ renderer | Installed; current stable |
| Language | Statically typed GDScript | Fastest iteration, no build step, best editor and tooling support. Hot paths sit behind interfaces so one can move to C# or GDExtension if measurement demands it |
| Scale target | 150–250 units on a map | Classic base-builder scale. Thousands of units is a different engine problem and not this game |
| Unit movement | Plain `Node3D` units moved by our own locomotion code; **no** physics body per unit | Forum reports consistently name `CharacterBody3D` per unit and per-frame path requests as the scaling killers |
| Pathfinding | `NavigationServer3D` navmesh paths, requested per group and on a timer, plus server-side RVO avoidance | Built in, threaded. Verified by a benchmark spike in Phase 0; a flow-field backend is the fallback and fits behind the same interface |
| Models | Blender → `.glb` via an export script | Reproducible; keeps `.blend` files out of the Godot project |

### 3.2 Repository layout

```
farlanding/
  game/                 Godot project root (res://)
    core/               Foundations: event bus, commands, state machine, save, utilities
    sim/                Gameplay simulation — knows nothing about UI, audio or VFX
      entities/         Unit, building, resource node, projectile scenes
      components/       Health, locomotion, weapon, vision, harvester, producer, scanner, stealth…
      systems/          Vision/fog, economy, combat, navigation, production, discovery
    ai/                 Enemy commander, unit behaviours
    missions/           Objective framework, triggers, per-mission scripts
    campaign/           Star map, ship, tech web, persistent state
    presentation/       Camera, selection visuals, VFX, fog rendering
    audio/              Audio service, music director, sound-event map
    ui/                 HUD, menus, codex
    data/               .tres definitions: units, weapons, techs, discoveries, planets, missions, sounds
    assets/             Exported models, textures, audio (generated — never hand-edited)
    maps/
    tests/
  art/                  Blender sources and pipeline scripts
  audio_src/            Sound recipes, raw sources, provenance manifest
  tools/                Export, validation and CI scripts
  docs/                 This plan, design docs, style guides, decision records
```

Sources (`art/`, `audio_src/`) live outside `game/` so Godot never imports them; only pipeline output lands in `game/assets/`.

### 3.3 Rules that keep it extensible

1. **Definitions are data.** `UnitDef`, `BuildingDef`, `WeaponDef`, `AbilityDef`, `TechDef`, `DiscoveryDef`, `PlanetDef`, `MissionDef`, `SoundEvent` are custom Resources. Adding a unit means a new `.tres`, a scene and a model — no code change.
2. **Composition over inheritance.** An entity is a scene: a thin root plus component nodes. A Hauler is locomotion + health + harvester; a Sentry is health + weapon + vision. No deep class trees.
3. **One command path.** Every order — from the player, the enemy AI or a mission script — is a `Command` object pushed through the same queue. The AI cannot cheat, tests can drive the game without input, and replays or multiplayer are not ruled out later.
4. **Dependencies point one way.** `core ← sim ← ai / missions ← presentation / ui / audio`. The simulation raises typed events; presentation, UI and audio listen. Nothing in `sim/` may reference a UI node, a sound or a particle.
5. **Fixed simulation tick.** Gameplay advances at 10 Hz with expensive systems staggered across ticks; visuals interpolate every frame. This is the main performance lever and makes behaviour repeatable.
6. **Few globals.** Autoloads only for truly global services (`Game`, `Events`, `Audio`, `Save`, `Settings`). Everything mission-scoped hangs off a `MissionContext` that is created and freed with the mission, so nothing leaks between landings.
7. **Saveable from day one.** Every component implements `to_dict()` / `from_dict()` with a version number, even though mid-mission saving ships late.

### 3.4 Vision, fog and stealth share one system

A per-faction visibility grid (about 2 m cells) is computed on the CPU on a staggered tick and uploaded as a texture. The terrain and entity shaders sample it for the fog look; the simulation reads the same grid to decide what each faction knows. Stealth is then just a `signature` value against a viewer's `sensor` value on that grid, and the enemy AI only acts on what its grid has seen.

### 3.5 Enemy AI

Two layers: a **commander** (goal scoring over economy, defence, scouting and attack, with openings loaded from data) and per-unit **behaviours** (small typed state machines). Difficulty changes decision speed and mistakes, not resource cheats.

### 3.6 Missions

A mission is a `MissionDef` (map, planet, starting forces, objectives) plus an optional script. Objectives are small reusable classes (`DestroyAll`, `ReachArea`, `GatherIntel`, `Survive`, `StayUndetected`, `Escort`) composed with primary/secondary/hidden flags. Triggers are area, timer and event based. New mission types are assembled, not engineered.

### 3.7 Conventions

- Official GDScript style guide; static types required everywhere (untyped-declaration warnings promoted to errors); `class_name` on every script.
- `snake_case` files, scene and script side by side, signals named in the past tense (`unit_died`).
- No string node paths across scene boundaries — exported references or groups only.
- Units: 1 unit = 1 metre. Asset names: `<faction>_<kind>_<name>` (`concord_unit_ranger.glb`).
- Formatter and linter (gdtoolkit) plus a unit-test addon (GUT or gdUnit4 — whichever supports 4.7 best is chosen in Phase 0), all run headless in CI on every push.
- Git LFS for binaries. Short decision records in `docs/adr/` for any choice that would be expensive to reverse.
- A data validator in `tools/` fails CI on a definition with a missing model, icon or sound.

---

## 4. Art and texture pipeline


- **Models:** authored in Blender (by hand or scripted through the Blender connection), exported with one script that applies transforms, checks scale and naming, and writes `.glb`.
- **Faction trim sheet.** Each faction gets one shared texture set (base colour, normal, and a packed occlusion/roughness/metallic map). Nearly every unit and building maps onto it. This keeps the look consistent, memory low and new units cheap.
- **Team colour** is a mask channel, tinted in one shared Godot shader that also handles damage state and fog.
- **Unique bakes** only for hero pieces (the Lander, Antecedent ruins).
- **Terrain:** tileable material sets per planet, blended by a painted splat map in a terrain shader that also carries the fog.
- **Collision and navigation** helpers use Godot's import name suffixes (`-colonly`, `-navmesh`); exact behaviour is checked against the 4.7 docs in Phase 0 because it has varied between versions.

---

## 5. Sound design

Sound gets its own track in every phase rather than a pass at the end, because in an RTS it is half of the feedback.

### 5.1 Principles

1. **Sound is information.** Every gameplay event has a distinct, learnable sound. A player should know "Refinery finished", "Hauler under fire" and "something unscanned is nearby" without looking.
2. **Discovery has a voice.** Unresolved signals emit a faint tonal pulse, audible when the camera is near. Scanning resolves the pulse into a short phrase that differs by discovery type. Curiosity is pulled by the ears as well as the map. This phrase, the *Trail motif*, also seeds the music.
3. **Every planet sounds like itself:** its own ambience bed, weather, and musical mode.
4. **Restraint.** Forty units firing must not be forty times louder. Clarity beats density.

### 5.2 What gets made

| Group | Contents |
|---|---|
| Interface | Clicks, placement valid/invalid, queue, cancel, insufficient resources |
| Unit voices | Select, move, attack, ability, under fire — 3 to 5 variations each, per unit type |
| Advisor | *Meridian*'s own tone family plus on-screen text: base alerts, objectives, discoveries |
| Weapons | Fire, travel, impact per weapon and surface; explosions in three sizes |
| Movement | Engine/servo loops per chassis, footfalls for walkers |
| Buildings | Placement, construction loop, completion, idle hum, production, destruction |
| World | Planet ambience bed, positional spot sounds, weather, hazard warnings |
| Discovery | Signal pulse, scan loop, resolve stingers per type, codex entry |
| Stealth | Suspicion rising, alert, all-clear |
| Music | Adaptive score per planet (below), ship theme, victory and defeat |

### 5.3 Runtime design

- **Game code never plays a sound.** It raises gameplay events; `audio/` maps events to `SoundEvent` resources. A `SoundEvent` holds its variations, bus, priority, maximum simultaneous instances, cooldown and distance settings — all tunable without code.
- **Voice budget.** A pooled set of players with priority stealing, per-event instance caps and cooldowns. This is what keeps mass combat clean.
- **RTS listener.** The listener sits at the camera's ground focus point, not at the camera, with zoom shaping the mix: close in you hear servos and footsteps; zoomed out you hear the battle as a whole and the music.
- **Alert discipline.** One RTS lesson from the research: an "under attack" alert that fires for every scratch teaches players to ignore it. Alerts are throttled per map region and scaled by severity.
- **Bus layout:** `Master` ← `Music`, `Ambience`, `SFX` (Weapons, Explosions, Units, Buildings), `Voice` (Barks, Advisor), `UI`. The Advisor ducks Music and Ambience through a sidechain compressor; a limiter protects Master. Both effects are confirmed present in 4.7.2.
- **Adaptive music.** Godot's built-in interactive music streams (confirmed present in 4.7.2): each planet has clips for *explore*, *tension*, *combat* and *aftermath*, with transitions on the bar. Inside a clip, synchronised layers fade in and out. A music director drives it from game state — nearby threat, alert level, a discovery just made — with slow smoothing so the score does not flap.

### 5.4 How the sounds are produced

A scripted pipeline, the same shape as the art pipeline:

1. **Synthesis recipes** (Python scripts → WAV) for every sound and all music. Fully original, reproducible, and tweakable by editing numbers. No recordings, no generation services, no spoken voices (see section 9).
2. **Processing**: trim, fade, loudness-normalise, export. Short sounds as WAV, music and ambience as Ogg Vorbis.
3. **Automated analysis** on every build (clipping, loop seams, loudness targets), because the pipeline is scripted end to end.

Every file is listed in `audio_src/manifest` with its source, licence and recipe, so the game's audio is auditable and rebuildable. An audio style guide in `docs/` fixes loudness targets per group and the naming scheme before production starts.

---

## 6. Phases

Each phase ends in something playable and has all three tracks. A phase is done only when its "Done when" line is true in a build.

### Phase 0 — Foundations and proof
- **Code:** project skeleton, conventions, lint/format/tests in CI, event bus, command queue, data-definition base classes, debug overlay.
- **Art:** one unit modelled, textured and exported end to end through the scripted pipeline.
- **Audio:** bus layout, audio service, one synthesised and one recorded sound through the full pipeline.
- **Spikes (throwaway):** 200 units pathing across a navmesh with frame-time measurements; a fog-grid prototype.
- **Done when:** a fresh clone builds and passes CI; one textured model and one sound appear in-engine purely from pipeline output; the navigation decision is recorded with numbers.

### Phase 1 — Command feel
- **Code:** RTS camera, selection (click, box, double-click, control groups), move/stop/attack-move orders, formations, greybox map.
- **Art:** greybox unit and terrain kit; selection rings, order markers.
- **Audio:** interface sounds, first select/move barks, movement loops, the zoom-aware listener.
- **Done when:** moving thirty units around a map feels good with sound on. This is the gate for everything after it.

### Phase 2 — Base and economy
- **Code:** resources, Haulers, deposits and vents, building placement, construction, power, production queues, rally points, HUD.
- **Art:** Concord base buildings and economy units, first pass; construction effect.
- **Audio:** building lifecycle, harvesting, production, economy alerts from the Advisor.
- **Done when:** you can land, build a full base and field an army from nothing.

### Phase 3 — Combat, fog and the enemy
- **Code:** weapons, projectiles, damage table, death, vision grid and fog, minimap, the Combine commander AI, win/lose.
- **Art:** Combine roster first pass; weapon, impact and destruction effects; fog look.
- **Audio:** weapons, impacts, explosions, combat barks, voice budget tuned under mass combat, first combat music layer.
- **Done when:** a full Conquest match against the AI is winnable, losable and fun. *Milestone: the classic loop works.*

### Phase 4 — Exploration and Intel
- **Code:** orbital-scan layer, signals, Surveyor scanning, discovery definitions and payoffs, Intel, Survey Lab field options, codex, Custodians.
- **Art:** discovery sites, Antecedent ruins kit, scan effects, codex illustrations.
- **Audio:** signal pulse, scan loop, resolve stingers, the Trail motif, explore music.
- **Done when:** playtesters detour to find out what a `?` is without being told to. *Milestone: the game has its identity.*

### Phase 5 — Missions and stealth
- **Code:** objective framework, triggers, briefing/debrief flow, stealth (signature, sight cones, alert meter, patrols), three mission scripts: Conquest, Survey, Infiltration.
- **Art:** objective markers, sight-cone and alert visuals, Wisp.
- **Audio:** objective stingers, stealth state sounds, tension music, briefing voice.
- **Done when:** the three missions play differently enough that each needs a different approach.

### Phase 6 — Vertical slice: Kessel Reach
- **Code:** the planet rule (dust storms), performance pass, settings menu, first-time tutorial prompts.
- **Art:** final-quality pass on one planet, both rosters, UI skin, lighting.
- **Audio:** full adaptive score for the planet, complete ambience, final mix.
- **Done when:** three missions on one planet are at shipping quality. This is the proof that the whole pipeline produces a good game, and the point to re-plan everything after it.

### Phase 7 — Campaign layer
- **Code:** star map, branching route, the Meridian screen, tech web, loadouts, persistent state, campaign save/load, then mid-mission saves.
- **Art:** star map, ship interior screens, tech-web icons.
- **Audio:** ship ambience and theme, map interface, Advisor campaign lines.
- **Mid-mission saves (ADR 0013):** quicksave (F5) / quickload (F9), a landing autosave as a campaign landing starts, three manual slots from the pause menu, Continue on the title picks the newest of the campaign autosave and the saved landings. A load builds the map and restores the whole landing into it (world, orders reconnected to their targets, mission runner, objectives, script, enemy AI, fog, storm, camera, control groups). Not saved: commands younger than one tick, transient AI timers, the shooter of a projectile in flight.
- **Done when:** two planets can be played in sequence with Intel carrying over and changing the second landing.

### Phase 8 — Content
- **Code:** remaining planet rules, air units, Recovery and Holdout types, remaining discoveries and tech.
- **Art / Audio:** the other four planets, each with its kit, palette, ambience and score.
- **Done when:** the full campaign of roughly ten missions is playable start to finish.

### Phase 9 — Polish and release
- Balance, difficulty levels, onboarding, accessibility (rebinding, colour-blind team colours, subtitles, separate volume sliders), performance on a minimum-spec machine, export builds, credits including audio provenance.
- **Done when:** a new player finishes the first planet without help, and the release builds pass a full campaign playthrough.

---

## 7. Main risks

| Risk | Mitigation |
|---|---|
| Unit movement feels bad or does not scale | Measured in Phase 0, felt in Phase 1, isolated behind one interface |
| Enemy AI is weak or needs cheats | Shares the player's command path from Phase 0; commander built in Phase 3, before content depends on it |
| Scope: five planets is a lot of art and audio | Trim sheets and shared kits; the slice in Phase 6 gives a real cost per planet before committing to four more |
| Exploration is a checklist, not curiosity | Phase 4's done-line is a playtest observation, not a feature list |
| Audio turns to mush in big fights | Voice budget and caps exist from Phase 0 and are tuned in Phase 3 |

---

## 8. Research notes

**Exa returned "invalid API key" and Ref is not authorised**, so neither research server you asked for was usable in this session. I used general web search plus the class reference dumped from your installed Godot 4.7.2, which is the stronger source for anything version-specific. Once Exa and Ref work, the open items below should be re-checked with them.

Confirmed against the local 4.7.2 class reference: `AudioStreamInteractive`, `AudioStreamSynchronized`, `AudioStreamPlaylist`, `AudioStreamRandomizer`, `AudioStreamPolyphonic`, `AudioEffectCompressor.sidechain`, `AudioEffectHardLimiter`, `max_polyphony` on players, the `NavigationServer3D` agent and avoidance API, and the `@abstract` annotation.

From the web:
- Avoidance is separate from pathfinding and can hurt path quality if misused; target updates should be on a timer, not per frame — [Godot navigation docs](https://docs.godotengine.org/en/4.4/tutorials/navigation/navigation_using_navigationservers.html), [agent avoidance](https://docs.godotengine.org/en/4.0/tutorials/navigation/navigation_using_agent_avoidance.html).
- Anecdotal scaling reports: per-unit physics bodies and per-frame path requests collapse at a few hundred agents; plain nodes roughly double that — [forum thread](https://forum.godotengine.org/t/godot-terrible-performance-on-navigationagent3d/64567), [optimising many agents](https://forum.godotengine.org/t/optimizing-large-numbers-of-complex-agents-while-maintaining-perceptible-framerate/109752), [swarm showcase](https://forum.godotengine.org/t/800-unit-autonomous-swarm-engine-in-godot-4-on-a-10-year-old-laptop-intel-hd-520/146287). No shared benchmark exists, which is why Phase 0 measures it.
- Fog of war: no authoritative Godot 4 tutorial found; the common approach is a visibility texture sampled in shaders — [forum thread](https://forum.godotengine.org/t/3d-implementing-fog-of-war-for-rts/23822).
- Import name suffixes — [Godot docs](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html).
- Interactive music classes — [AudioStreamInteractive](https://docs.godotengine.org/en/latest/classes/class_audiostreaminteractive.html), [AudioStreamSynchronized](https://docs.godotengine.org/en/latest/classes/class_audiostreamsynchronized.html).
- Alert fatigue and mix hierarchy — [Disruptive Audio](https://uxdesign.cc/disruptive-audio-when-sound-works-against-the-game-design-goals-e134a9b2a117), [dynamic game audio mix](https://splice.com/blog/?p=14733).
- Generated sound effects: ElevenLabs states paid-plan output is royalty-free for commercial projects and free-plan output is not — [ElevenLabs](https://elevenlabs.io/sound-effects/commercial). Terms for generated *music* in games were unclear in secondary sources and must be read first-hand before use.
- Godot 4.7 headline changes (HDR output, AreaLight3D, new Asset Store) — [GamingOnLinux](https://www.gamingonlinux.com/2026/06/godot-engine-4-7-is-out-bringing-a-new-asset-store-hdr-support-steam-frame-support/).

Not yet researched, scheduled for Phase 0: test-addon and gdtoolkit compatibility with 4.7, RTS-specific audio post-mortems, licence terms of any generated-audio service.

---

## 9. Decisions (answered 2026-11-12)

1. **Textures** — full creative freedom granted; section 4 stands as the method.
2. **Audio** — nothing paid and no external services. Every sound and all music is synthesised by scripts in `audio_src/`. Consequence: there are no spoken voices. Units answer with short tonal signatures unique to each unit type, and the Advisor speaks through text plus a distinct tone family. CC0 recordings are not used either, so the whole soundscape is original and rebuildable.
3. **Research** — general web search is used until Exa and Ref work.
4. **Plan approved.** Implementation proceeds phase by phase, one pull request per milestone.
5. **Mouse controls (2026-11-13)** — the owner asked for Command & Conquer style controls. The default
   scheme is now *classic*: left click does everything by context (select own units and buildings,
   move, attack, harvest, scan, help build, set a rally point), right click deselects and cancels
   placement or aiming. The earlier scheme stays available as *modern* (left selects, right
   commands) through the MOUSE toggle at the top right of the HUD, saved in `settings.cfg`
   (`[controls] control_scheme`). Both schemes share one set of context rules
   (`SelectionRules.command_target()` / `resolve()`); the cursor shows what a command click would do.

**Working arrangement:** visual work and 3D modelling are done by Fable; all other implementation by Opus 5.5 workers.
