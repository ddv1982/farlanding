# 0019. Desktop Web runtime and its verification

## Decision

Export with Godot 4.7.2, WebGL2 Compatibility, threads, and Stream audio. Keep
Forward Plus and the existing audio behavior on native platforms. The Web override
lives in project settings; the release and diagnostic presets share the runtime. The project-level Stream value is `0`;
player-node playback enums use a different numbering.

Serve on loopback for development. Threaded exports need a secure context and
`Cross-Origin-Opener-Policy: same-origin` plus
`Cross-Origin-Embedder-Policy: require-corp`. Localhost qualifies. Future hosting
must supply these headers and the WebAssembly MIME type. No hosting is configured.

## Reasons

The existing sound design uses bus compressors, a limiter, and storm filters.
Godot's default Web Sample playback omits AudioEffects. Stream preserves the mixer;
threads avoid the documented single-thread Stream latency penalty. Sample is
rejected on that functional constraint. A single-thread Stream prototype showed no material frame-time benefit and similar
captured cue timing on the reference M4. Threaded Stream passed the full mixer
suite; the single-thread prototype was not promoted.

A real Kessel browser launch exceeded WebGL's per-instance uniform buffer.
Compatibility shaders therefore use ordinary uniforms on private mesh materials;
Forward Plus keeps instance uniforms. Water depth reconstruction maps WebGL depth
to its -1..1 clip range. Both paths use the same shader bodies and visual callers. Web movement and combat
particles use CPU equivalents of the same settings to reduce many small GPU
emitter costs; native particles remain unchanged.

The editor MCP runtime probe remains packaged with its autoload and dependencies.
It registers only when EngineDebugger is active, so release exports have no MCP
command channel. Excluding its script alone would create a dangling autoload.

## Graphics defaults

Fresh Web profiles start with low quality and 50% 3D render scale. Native defaults
remain high/100%, and saved graphics choices take precedence on either platform.
This trades scene sharpness and shadows for responsiveness; UI resolution is
unchanged. Hosted software WebGL at the original high defaults starved simulation
ticks and delayed IndexedDB acknowledgement beyond its deadline even when the
correct file eventually persisted.

## Preserve authored export data

Keep `editor/export/convert_text_resources_to_binary=false`. Godot 4.7.2's binary
conversion discarded the music's packed layer-name and volume arrays. The defect
was reproduced in both Web and Linux packs. Changing default initializers did not
preserve the arrays; retaining text resources did. The browser smoke suite checks
those arrays, and the diagnostic audio suite validates the resulting mix.

Model imports are invalidated when the post-import material mapper changes.
Previously cached scenes kept placeholder materials even after the mapper gained
new planets. The shared import preparation step fingerprints that mapper, and a
native regression checks each planet's mapped runtime material.

## Browser boundary

A click starts the engine. Native Quit is absent. Quicksave and quickload default
to K and L on Web, preserving native F5/F9 and saved user overrides. Fullscreen
starts off and follows actual browser state. Focus loss clears gestures and pauses
play until the player resumes.

Saves use the existing files and formats in Godot's IndexedDB-backed user folder.
A save notice waits for the exact file's SHA-256 to appear in the pinned engine's
Emscripten IDBFS `FILE_DATA` store. The shell warns on denied storage, failed writes,
or a 30-second acknowledgement timeout, and requests confirmation before leaving
while writes are pending. This adapter is version-specific and must be revalidated
on engine upgrades. Storage eviction and a changed origin remain browser limits.
`campaign_saved` announces the local file write and starts synchronization. Web
save audio listens to `campaign_save_confirmed`, emitted only after the persistent
store acknowledges that file; failed writes cannot play the success chime.

One-shot synthesized WAV assets become MP3 through the existing reproducible audio
pipeline. Sample-exact WAV loops and Ogg music retain their formats. Recipes remain
the original sources. Codec analysis and hashes are regenerated for encoded output.

## CI and diagnostics

`check` retains native checks. `web` depends on it, installs verified templates,
builds both presets, verifies manifests, uploads the release, and runs real browser
input against those bundles. Hosted CI may use software WebGL2 for correctness.
Hardware performance acceptance remains separate.

`WebDiagnostics` adds read-only state and coordinates plus seeded test scenarios.
Its tests exercise gameplay using actual pointer and keyboard events. The
optional audio QA route includes GUT and the existing real-mixer audio tests. Release
exports exclude the fixtures. There is no production gameplay command endpoint.

## Evidence and limits

See [WEB_CI_RESULTS.md](../WEB_CI_RESULTS.md) for observed commands, runtime results,
and open acceptance gates. A successful export or native headless benchmark alone
does not establish browser playability or audio quality.

[Godot Web export documentation](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html)
describes the renderer, audio, thread, and hosting constraints.
