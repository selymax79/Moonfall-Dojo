# Milestone 34 verification

Status: **IMPLEMENTED / DEVICE ACCEPTANCE PENDING**. This evidence is from 15 October 2026.
No real phone, Safari, physical gamepad or PWA installation UI was tested. Milestone 35
has not begun. Earlier subjective gameplay/art/input acceptance remains outstanding.

## Architecture and scope

One Godot project, one main scene, one Player, one scheduler, one record format and one asset
set serve both exports. No gameplay or presentation system was copied for Web/mobile.
[web_platform.gd](../scripts/web_platform.gd) is a small browser lifecycle/orientation shim;
[menu_pointer.gd](../scripts/menu_pointer.gd) invokes the existing shared menu handlers.
The standing shared-codebase rule is in [AGENTS.md](../AGENTS.md).

The Compatibility preset uses single-threaded WebAssembly/WebGL 2 and excludes verification
tools. [web/README.md](../web/README.md) contains export, local-server, HTTPS/MIME, save-storage,
PWA cache and update instructions. Native Android/iOS apps were not added.

## Native regression evidence

Godot 4.7.2 stable official, Windows; isolated application identity and save directory.
All suites below finished without assertion failures:

| Coverage | Checks |
| --- | ---: |
| Combat/scoring regression | 621 |
| Menus, persistence and feature flow | 172 |
| Audio, bounded voices and pause | 3,497 |
| Pause determinism, including a ten-second pause | 105,078 |
| F4 progression and fairness | 280,196 |
| Scheduler, 384 pairs and 9,000 encounters | 2,411,086 |
| Late encounters, 320 pairs | 185,873 |
| Pattern/menu/touch-option determinism | 92,017 |
| Shared keyboard/gamepad/touch input | 136 |
| Persisted remap reload | 1 |
| New pointer menus and browser adapters | 49 |

The rendered input harness also passed 136 checks using Compatibility/OpenGL on the RTX 3080.
Its 640x360 captures were inspected. Deliberately malformed save and failed-write fixtures
produce expected diagnostics; these are not successful-save failures. VS Code has no registered
GDScript test provider, so the CLI harness results above are the actual test evidence.

Follow [INPUT_VERIFICATION.md](INPUT_VERIFICATION.md) to create the isolated copy named
`Moonfall Dojo Input Verification`. Then additionally run:

```text
godot --headless --path <isolated-copy> --script res://tools/verify_web.gd
```

The new adapter harness checks direct title/options/scores/Controls/initials navigation,
gesture cancellation, unchanged menu RNG, normal scene replacement, pause/release/resume,
Game Over restart, first-gesture audio gating, background audio and bounded voices.
It cannot verify browser policies or hardware usability by itself.

## Served desktop browsers

Standalone **Firefox 142.0.1** (Playwright browser build) and installed **Microsoft Edge
155.0.4283.45**, both automated headlessly: **44 checks passed in total**. These used an
isolated export/origin of the current shared scripts with the test-only probe below.

- Silent initial title; a real automation key gesture starts one AudioContext with measurable
  nonzero waveform output. This verifies signal output, not human listening quality.
- Keyboard menu navigation, direct click menus, volume adjustment, Punch remapping to C,
  Punch/Kick/Jump/Duck and rejection of Duck during committed Jump.
- Pause freezes the shared simulation clock and music; direct Resume works.
- A qualifying test score, initials, highest level, audio settings and binding survive reload.
- Browser Gamepad API connection, remapping, gameplay and Start/Pause using a **simulated pad**.
- Thirty F2 restarts per browser retain bounded scene nodes and nine shared audio voices.
- Final fifteen-second frame/physics sampling: Firefox 238.5 render FPS / 59.98 Hz physics;
  Edge 239.7 render FPS / 60.00 Hz physics on this 240 Hz display.
- An online worker-controlled reload populates the PWA cache. Both browsers then reload the
  title and start gameplay with the browser context offline.

No online runtime errors were observed. Edge's offline run reports its optional `index.png`
boot-splash request as disconnected; the cached game still loads and plays. That image is
not in Godot's generated worker cache. Firefox reported no offline errors.

The shared in-app browser was also exercised: Chromium 150.0.7871.250 / Electron 43.7.7 /
VS Code 1.142. Release export launch, menu clicks, keyboard play, pause, browser storage and
640x360/1280x720 captures were checked. Opening another tab verified real visibility/focus
loss and explicit Resume on return. PWA offline evidence comes from standalone browsers,
not the embedded browser.

## Mobile emulation and visual inspection

Edge 155 mobile/touch emulation, DPR 1, 844x390 landscape and 390x844 portrait: **18 checks
passed**. CDP touch injection exercised automatic overlay enablement, direct touch menus,
volume adjustment, Controls capture cancellation, Start Level, simultaneous direction plus
Punch/Kick, Jump commitment, Duck, Pause, portrait rotation while holding a touch, release
and explicit Resume, qualifying initials and persistence/reload. No runtime exceptions.
Directory URLs were verified to normalise to `index.html` for the generated offline cache.

Inspected native 640x360, desktop 1280x720, mobile landscape and portrait captures. Pixel art
retains nearest-neighbour presentation, the moon/background composition and bottom HUD are
visible, controls sit over outer entry lanes, and central combat remains clear. The portrait
notice uses browser-sized text outside the tiny letterboxed canvas. Physical thumb reach,
device safe areas, high-DPI appearance and touch comfort still require real devices.

## Performance and cleanup

An optional Godot 60 FPS cap was **removed** after an A/B test with the same exported pack.
Only command-line `--max-fps` differed. Five-second Edge samples on this machine measured:

| Engine cap | Render frames | Physics ticks | Main thread CPU time |
| --- | ---: | ---: | ---: |
| Uncapped, display around 240 Hz | 1,206 | 301 | 0.98 s |
| 60 FPS | 303 | 302 | 4.69 s |

The capped profile spent most samples reading the clock. The final project therefore keeps
browser/display-paced rendering and the existing 60 Hz physics. These desktop measurements
do not establish phone battery use or sustained thermal performance. No combat timing or
scheduler optimisation was made.

Repeated restarts retained 102-110 scene nodes in the final desktop suite and nine audio
voices. The final fifteen-second Edge sample used 2.95 seconds of main thread CPU; worklet
processors stayed at four, audio handlers fell from 83 to 77, JS heap rose from 9.29 to
9.74 MB and browser listener count rose from 105 to 119. These short, garbage-collection-
sensitive samples do not prove leak freedom; long mobile sessions remain an acceptance
item. Release payload: approximately 39.5 MB WASM raw / 10.2 MB gzip, 2.4 MB pack raw /
2.2 MB gzip and 69 KB gzip JavaScript. Enable host compression; localhost tests were raw.

## Reproduction and local evidence

[verify_web.gd](verify_web.gd) and [verify_input.gd](verify_input.gd) are checked-in native
harnesses. [web_probe.gd](web_probe.gd) is verification-only instrumentation: in a disposable
copy, rename the application `Moonfall Dojo Web Verification`, add an autoload pointing to
that script, and remove only `tools/*` from the copied preset exclusion. Export the copy and
serve it on a different localhost port. Never add that autoload to the production project.

The probe reads runtime state via `window.moonfallProbe('snapshot')` and
`window.moonfallSnapshot`. `award_four` invokes the normal handled-threat reward path four
times; `qualifying_death` supplies a test score and calls normal death. These are controlled
fixtures, not claims of human survival or legitimate high scores. `reset_metrics` begins
frame/physics counting. The native player's real save was not used by these harnesses.

Ignored local evidence is under `.godot/web-verification`: `browser-tests.cjs`,
`mobile-tests.cjs`, `performance-ab.cjs`, JSON results, export/native logs and screenshots.
These one-off automation scripts use an isolated Node/Playwright installation in that
directory; they are development tooling, not game runtime dependencies. Re-run the browser
scripts only against the isolated probe origin (8065), with its server already running:

```powershell
$env:PLAYWRIGHT_BROWSERS_PATH = Join-Path (Get-Location) '.godot/web-verification/browsers'
& '.godot/web-verification/node-v22.20.0-win-x64/node.exe' '.godot/web-verification/browser-tests.cjs'
& '.godot/web-verification/node-v22.20.0-win-x64/node.exe' '.godot/web-verification/mobile-tests.cjs'
```

This local evidence is intentionally excluded from Git and the shipping pack. The test
probe is also excluded from shipping. Standard local hosting uses [serve_web.cjs](serve_web.cjs).

## Outstanding device acceptance

- Real Android browser and iPhone/Safari, plus installed/Add to Home Screen mode.
- Physical controller discovery, browser mapping, disconnects and remapping.
- Real simultaneous thumbs, touch cancellation, device safe areas and high-DPI readability.
- Mobile OS background/foreground, audio interruption and human listening.
- Device-specific orientation enforcement, PWA install/update UI, offline relaunch, private
  storage/eviction, and longer sessions for battery/thermal/memory behaviour.

Saves are origin-local IndexedDB through unchanged `user://high_score.cfg`. Clearing site
data removes them; private mode, denied storage, eviction and abrupt process termination
can prevent durability. Native and browser saves do not automatically synchronise.

## Exact change inventory and final Git state

The starting checkout was clean at `32c7751`. No pre-existing project-setting edit needed
preservation. Final state: **12 tracked files modified, 18 new files untracked, nothing
staged, no commit**. Build output and local verification evidence remain ignored.

Modified tracked files:

- [.gitignore](../.gitignore): ignore exported builds.
- [AGENTS.md](../AGENTS.md): shared-codebase rule and authorised browser-mobile scope.
- [DESIGN_NOTES.md](../DESIGN_NOTES.md): current Web, input, audio and storage behaviour.
- [Roadmap.md](../Roadmap.md): Milestone 34 status and Milestone 35 next.
- [project.godot](../project.godot): explicit aspect preservation and fractional scaling only.
- [scenes/main.tscn](../scenes/main.tscn): two small helper nodes and script references.
- [scripts/main.gd](../scripts/main.gd): platform/touch/audio startup, shared pointer dispatch,
  lifecycle pause and state carried across existing scene replacement.
- [scripts/controls_menu.gd](../scripts/controls_menu.gd): touch-option label and pointer footer.
- [scripts/game_audio.gd](../scripts/game_audio.gd): first-gesture activation/background pause.
- [scripts/touch_overlay.gd](../scripts/touch_overlay.gd): larger translucent targets and labels.
- [tools/verify_input.gd](verify_input.gd): derive test touch positions from current target rectangles.
- [tools/INPUT_VERIFICATION.md](INPUT_VERIFICATION.md): link Web evidence and retain hardware caveats.

New authored files:

- [export_presets.cfg](../export_presets.cfg)
- [scripts/menu_pointer.gd](../scripts/menu_pointer.gd)
- [scripts/web_platform.gd](../scripts/web_platform.gd)
- [tools/serve_web.cjs](serve_web.cjs)
- [tools/verify_web.gd](verify_web.gd)
- [tools/web_probe.gd](web_probe.gd)
- [tools/WEB_VERIFICATION.md](WEB_VERIFICATION.md)
- [web/README.md](../web/README.md)
- [web/icon.svg](../web/icon.svg)

Godot-generated identity/import metadata (retained for stable resource references):

- [scripts/control_bindings.gd.uid](../scripts/control_bindings.gd.uid)
- [scripts/controls_menu.gd.uid](../scripts/controls_menu.gd.uid)
- [scripts/menu_pointer.gd.uid](../scripts/menu_pointer.gd.uid)
- [scripts/touch_overlay.gd.uid](../scripts/touch_overlay.gd.uid)
- [scripts/web_platform.gd.uid](../scripts/web_platform.gd.uid)
- [tools/verify_input.gd.uid](verify_input.gd.uid)
- [tools/verify_web.gd.uid](verify_web.gd.uid)
- [tools/web_probe.gd.uid](web_probe.gd.uid)
- [web/icon.svg.import](../web/icon.svg.import)

Learning points: the pointer adapter translates gestures into existing semantic menu actions,
so menu state stays in one place. The platform adapter uses signals and removes browser
listeners on scene exit, making lifecycle ownership explicit across restarts.
