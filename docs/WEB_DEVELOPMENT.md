# Browser builds, testing and deployment

Use Godot **4.7.2.stable**, Python **3.11+**, WebAssembly and WebGL2. Install the
matching templates in the editor, or install just the verified Web templates:

```sh
tools/install_godot_templates.sh
tools/export.sh Web
python3 tools/web_manifest.py build/web --verify
python3 tools/serve_web.py build/web
```

Open **http://127.0.0.1:8060** and click **Play Farlanding**. Keep the terminal
running; Ctrl-C stops the server. Opening `index.html` as a local file will not work.
The server binds only to this computer and supplies the headers needed by threads.

Web uses threaded Stream audio to preserve mixer effects. The local server supplies
the isolation headers that this requires.

Fresh profiles start at **High**, 100% 3D resolution and 2× MSAA. The launcher
offers High, Balanced and Performance before loading the game; Saved keeps your
preferences. Performance uses 50% 3D resolution with shadows, SSAO and glow off;
the UI stays at full resolution. Existing Web players with the old Low/50%
settings get a one-time choice to keep them or use High. Audio, controls and
progress are retained. Settings also lets you customize resolution and MSAA.
See [graphics qualification](WEB_GRAPHICS.md) for renderer differences,
hardware measurements and reproducible comparisons.

Web uses **K/L** for quicksave/quickload. Settings and landings stay in this browser
at this origin. Wait for the saved confirmation before reloading. Denied storage
or failed persistence produces a warning. Clearing site data or changing the port
or origin can make existing progress unavailable. Fullscreen requires a user
click. Leaving the tab pauses the mission; resume explicitly when returning.
Keyboard and mouse are required. Mobile controls remain outside this milestone.

Every successful CI `web` job publishes `farlanding-web-<commit>` in the run's
Artifacts section. Download and extract it, then run the same manifest verification
and serving commands from the extracted root. The artifact includes `build/web/`
and the two Python tools. `manifest.json` identifies the commit, engine, headers,
and every bundle file's hash. It describes required HTTP headers; a ZIP has none.

### Browser checks

Node **26.x** is needed only for testing and deployment. Export diagnostics separately:

```sh
tools/export.sh Web WebDiagnostics
cd tools/web_tests
npm ci
npx playwright install chromium
npm test
WEB_BROAD=1 npm test
WEB_UI_QUALIFY=1 npm test -- ui_style.spec.cjs
WEB_AUDIO_QA=1 npm test -- --grep real-mixer
WEB_PERFORMANCE=1 npm test -- --grep 233-unit
WEB_BROWSER=firefox npm test
```

Install Firefox or WebKit with `npx playwright install firefox webkit` before using
those browser names. The suite starts loopback servers on 8070/8071, uses fresh
profiles, and has no automatic retries. It retains console/network logs, state,
screenshots and traces on failures; `WEB_RECORD=1` enables video capture. Video is
opt-in to avoid competing with software WebGL on CI runners. The broad mission
matrix also runs from CI's manual **Run workflow** action. `WebDiagnostics` is for
testing only; play the release under `build/web`. Browser versions and acceptance
evidence are tracked in [the Web results](WEB_CI_RESULTS.md).

### Production deployment

Successful pushes to `main` deploy to [Farlanding](https://farlanding.vercel.app)
after native checks and browser gameplay pass. Pull requests and manual test runs
do not deploy. Both the CI Node steps and the Vercel project use Node 26.x.

The Vercel Hobby project uses the same team and CI-controlled deployment policy as
Space Explorer. Its Git auto-deploys are disabled. Because the exported game exceeds
Hobby's 100 MB CLI source-upload limit, CI uploads a small build script referring
to that run's tested GitHub artifact by ID and digest. Vercel resolves a fresh
download URL when its build starts, using that CI job's short-lived GitHub token
as a build-only secret with repository contents/Actions read permissions. It is
never stored in source files or public assets and is not forwarded to artifact
storage. The build verifies GitHub's archive digest and the release's complete
file inventory and commit. Godot is not rebuilt on Vercel.

CI first creates an unaliased production deployment and runs real browser input
against it, including the isolation headers and WebAssembly MIME type. Only a
passing staged game is promoted. CI then checks the public production domain
without authentication. Use that stable domain for play so browser saves stay at
the same origin across deployments.

Repository secrets: `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`, and
`VERCEL_AUTOMATION_BYPASS_SECRET`. The last one lets the staged browser check pass
Vercel's preview protection; traces are disabled when it is used so request
credentials are not recorded. `VERCEL_PRODUCTION_URL` is a repository variable.
The deployment uses the GitHub `production` environment and Vercel CLI 65.16.0.

Deploy through CI rather than rebuilding an old deployment in the Vercel dashboard:
the job's GitHub token expires when that job finishes. Rerun the deployment job in
a push-to-`main` workflow while its tested artifact is retained, or rerun that entire push workflow
to create a fresh artifact. Manual **Run workflow** runs remain test-only.
Existing ready deployments can still be promoted or rolled back without
downloading the source artifact again.
