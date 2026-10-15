# Web export and local hosting

Web/mobile is another export of the same project, **not a fork**. The `Web` preset uses
Godot 4.7.2, Compatibility/WebGL 2, single-threaded WebAssembly and the shared main scene.
Runtime resources are included; tools, Markdown, Web source files and build output are excluded.
There are no native Android/iOS projects or mobile-specific gameplay values.

## Export

Install the matching Godot 4.7.2 export templates. From the project directory:

```powershell
New-Item -ItemType Directory -Force build/web | Out-Null
New-Item -ItemType File -Force build/.gdignore | Out-Null
& 'C:/Users/myles/OneDrive/Desktop/GODOT/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --export-release Web
```

Alternatively use Project → Export → Web. The output is `build/web/index.html` plus its
adjacent engine, pack, icons, manifest, worklets, offline page and service worker. Deploy the
whole exported directory together; do not rename individual files. Do not serve `.import`
sidecars left by an older editor scan. The `.gdignore` prevents new build-folder imports.

## Run locally

Godot's one-click **Run in Browser** button uses the runnable Web preset and starts its own
local HTTP server (normally port 8060). Keep the editor open while using that preview.
For the exported release directory, an optional dependency-free Node.js server is included:

```text
node tools/serve_web.cjs
```

Open **http://127.0.0.1:8064/**. Add `8066` to the command if the default port is occupied.
Ctrl+C stops it. This small server binds localhost only; it is not a production host.
Node is optional development tooling, not a game dependency. Opening the HTML directly as
a `file:` URL is not supported. No PowerShell execution-policy change is needed.

## Hosting requirements

Use an HTTPS static host for remote/phone access. Localhost is a secure-context exception.
Serve `.wasm` as `application/wasm`, `.js` as JavaScript, `.json` as JSON, and `.pck` as binary.
No COOP/COEP headers are required because this preset disables threads and GDExtensions.
Keep the app at a stable origin/path, with all assets same-origin. Embedding in another site
can introduce additional storage, audio and gamepad permissions; test the actual embed.

Enable gzip or Brotli on the host. The measured release engine is approximately 39.5 MB raw
or 10.2 MB gzip; the game pack is 2.4 MB raw or 2.2 MB gzip. JavaScript adds about 69 KB gzip.
These are measured compressed sizes, not a promise about a host's transfer settings. The
local test server deliberately serves uncompressed files.

Avoid long-lived HTTP caching of the HTML, manifest and service worker. Godot versions its
PWA cache on export; upload a complete new build together. Close old app tabs/windows and
reopen after an update so the waiting worker can activate. Never force a reload mid-run.

## Browser behaviour and limits

- The same 640×360 scene scales with nearest-neighbour filtering into a centred 16:9 area.
  Rendering follows the browser/display refresh rate; shared physics remains at 60 Hz.
  An engine FPS cap was rejected after it increased CPU use in a controlled comparison.
- Touch browsers enable the shared overlay automatically. Native desktop and non-touch
  desktop browsers default to no overlay. Controls retains a session-only toggle.
- Direct taps operate existing menu handlers. Touch positions are fixed semantic actions;
  keyboard/gamepad remapping does not change which action a touch button represents.
- Touch portrait displays a readable rotate notice outside the letterboxed canvas. Rotation
  or browser focus/visibility loss pauses a run and releases touches. Returning requires
  Resume. The PWA requests landscape, but browsers may ignore orientation locking.
- Title playback waits for the first key, button, tap or click. Godot handles browser audio
  permission; the shared audio controller starts its one requested music voice once.
- The unchanged `user://high_score.cfg` uses Godot's IndexedDB filesystem. Scores, legitimate
  level unlocks, volumes and bindings share the same save model as native. Clearing site data
  removes saves; private browsing, storage denial/eviction and abrupt termination can prevent
  durability. Native and browser storage are separate. A new origin/port is a different save.
- Press a controller button after connecting so the browser exposes the device. Browser/OS
  mapping and reserved shortcuts vary. Physical controller acceptance is still required.

## PWA / Add to Home Screen

Godot generates the manifest, landscape/standalone request, three app icons from
[icon.svg](icon.svg), service worker and offline fallback. Use the browser's install/Add to
Home Screen command where available. The built-in cache stores engine/game files as they are
requested under service-worker control; revisit once online before relying on offline use.
The export's tiny head script normalises a directory URL to `index.html` without reloading;
Godot's cache needs that exact page URL for subsequent offline navigation.
An incomplete cache shows the offline fallback. Installation UI, storage eviction and iOS
standalone audio/orientation behaviour still need real-device acceptance.
Godot's generated worker does not cache its optional `index.png` boot splash; Edge can report
that image request as offline while the cached game still loads and plays normally.

See [verification evidence and remaining acceptance](../tools/WEB_VERIFICATION.md).

Engine requirements are documented in [Godot's Web export guide](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html).
