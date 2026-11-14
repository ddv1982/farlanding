# 0020. Publish the tested Web artifact through Vercel CI

Deploy production only after the native and browser jobs succeed on a push to
`main`. Disable Vercel Git auto-deploys, use a GitHub production environment,
and serialize main runs so older production deployments cannot overtake newer
ones. Node 26.x and Vercel CLI 65.16.0 are pinned for the deployment tooling.

Use the existing Vercel Hobby team, matching Space Explorer's CI ownership of
production. The Web release is about 168 MB, above Hobby's 100 MB CLI source-upload
limit. A small source upload therefore contains only the static hosting config,
a Python build script, and the current CI run's artifact identity and digest.
Resolve GitHub's one-minute download redirect inside the build, immediately before
fetching it. Pass only the deployment job's temporary, repository-scoped GitHub
token as a build-only secret, with contents/Actions read permissions. Never put it
in source files, public assets, or requests to redirected artifact storage.
The build checks GitHub's immutable artifact archive SHA-256, the expected source
commit, clean release preset, and the complete
exported file inventory. Only `build/web` becomes public. Godot is not rebuilt.

Serve COOP `same-origin`, COEP `require-corp`, and `application/wasm` on the engine
binary. Revalidate stable filenames rather than caching them immutably across
production releases. Missing paths remain missing; there is no SPA fallback.

Create a production deployment with `--skip-domain`, exercise the actual hosted
game, then promote only after that check passes. The staged check uses an
automation bypass header and cookie so audio worklets can load on a protected
deployment. Do not record traces containing the bypass credential. After
promotion, check the production domain without authentication. Keep play and
saves on the stable production origin.

The GitHub job token expires after the job. CI supplies a fresh token for each
deployment; dashboard source rebuilds of old deployments are not supported.
Existing ready deployments can be promoted or rolled back. Do not upgrade the Vercel plan or add an asset
hosting service for this workflow.
