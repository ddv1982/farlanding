# Field kit, Survey Log and control-group verification

The interface now uses shared steel-blue plates with cut corners, cyan instrument
lamps and Chakra Petch. `HudStyle` and `HudTheme` define the look; `UiTheme` applies
it to stock controls. The font's OFL notice is included in every export and Credits.

The player-facing discovery journal is the **Survey Log**. Discovery save keys and
the saved `codex` key-binding action remain unchanged so existing progress and
custom keys load. Resource paths for discovery definitions also stay the same.

## Numbered groups

- Ctrl/Cmd + 1–9 stores; the plain number recalls; a quick second press centres the camera.
- Alt/Option + number also stores when the browser reserves Ctrl/Cmd for its tabs.
- Shift + number adds the selection, or starts an empty group.
- A badge shows the group number and living count. Click recalls; right-click replaces it.

Observed in the running Godot game through real mouse/key input: select unit 43,
Ctrl+1 stores it, click unit 44, plain 1 selects 43 again. The browser test stores
multiple units with Alt+1, adds another with Shift+1, deselects and recalls the
same members with plain 1 and the badge. Unit tests also cover Ctrl/Cmd, macOS
Option characters, dead members, saved groups and sticky Shift.

## Checks observed locally

| Check | Result |
| --- | --- |
| `tools/check.sh` | Format/lint, 746 gameplay tests (7997 assertions), 416 real-time audio tests (6372 assertions), boot and all 11 mission smoke tests passed |
| Python build/deployment tools | 13 tests passed |
| Chromium hardware gameplay | 24 cases passed |
| Chromium software WebGL, explicit Performance profile | 23 cases passed |
| Screen qualification at 2000×754 | 100% and 130% UI scale passed through title, settings, help, controls, credits, missions, briefing, campaign, star map, Meridian, tech web, loadout, HUD, Survey Log and pause screens |
| Campaign browser route | Launch, save, reload and Continue passed |
| Overlay layering | Tutorial cards hide under pause and Survey Log, retain their state and return afterward; both native checks and real browser input passed |
| Exports | Web, WebDiagnostics and macOS release exports succeeded |

The hardware/software full browser suites preceded the final modal and narrow-strip
fixes; focused screen/campaign qualification and native geometry checks cover them.
After review, a blocked-segment regression failed before the guard and passed
after it (41 focused native tests, 209 assertions). Three repetitions each of
construction/save recovery and legacy graphics retention passed after their
layout/fixture timing fixes. CI gates the combined release on the latest commit.
At narrow sizes the command strip stays between selection and minimap panels;
its horizontal scrollbar keeps later commands reachable. A real browser check
selects a Fabricator at 1152×648 / 130% UI, stores all nine groups, drags the scrollbar to
Survey Lab and enters placement. Native geometry checks cover the same layout.

No game balance statistics were changed. One commander test previously required
both retrieval members to die along a particular route through gunfire. A member
can now escape, so that test forms the squad and applies losses explicitly before
checking larger squads, delay, surviving reserves and persistence.

## Movement measurements and limits

[ADR 0022](adr/0022-traffic.md) records the traffic rules, reproducible benchmark
and measurements. Contacts use the next integration positions, slow queues still
look for close blockers, idle friends make room, and route shortcuts require a
clear segment. No frame-dependent RVO callback drives ground movement.

The final stress run settled 202/202 units near their reachable endpoints in
147.6 simulation seconds; 201 were within one body radius and all were within one
body width plus clearance. Its sim tick measured mean 4.50 ms, p95 6.24 ms on M4.
This is a dense-queue stress result, not a browser FPS or exact formation-lock
promise. The old idle-only arrival counter could count a unit waiting to return
to its post, or one that had given up far away; the new report distinguishes them.

Run the optional browser screen matrix with:

```sh
WEB_UI_QUALIFY=1 WEB_CAMPAIGN=1 npm test -- ui_style.spec.cjs campaign.spec.cjs
```

Run it from `tools/web_tests` after `tools/export.sh Web WebDiagnostics`.
Evidence is retained locally under `build/evidence/field-kit/` and in CI artifacts.
