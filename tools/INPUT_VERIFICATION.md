# Input verification (Milestone 32/33)

[verify_input.gd](verify_input.gd) injects real keyboard, joystick and screen-touch events
through Godot's viewport dispatch. It checks all thirteen bindings, remapping/reload,
conflicts/defaults/cancel, controller navigation, initials, action parity, pause/F2/F4,
touch state release, multi-pointer pad ownership and hidden-overlay isolation.

Run it in a disposable **copy** of the project. The harness deliberately removes/replaces
its test save and refuses to run unless the copied project's application name is
`Moonfall Dojo Input Verification`. Never rename the working game's application to run tests.

1. Copy the current project assets/scripts/scenes into an isolated directory.
2. Change only the copied `application/config/name` to the test identity above.
3. Import that copy with Godot 4.7.2 (`--headless --editor --import --quit`), or copy its
   matching imported assets when editor import is unavailable.
4. Run these commands with your Godot console executable:

```text
godot --headless --path <isolated-copy> --script res://tools/verify_input.gd
godot --headless --path <isolated-copy> --script res://tools/verify_input.gd -- --reload
godot --path <isolated-copy> --script res://tools/verify_input.gd -- --renders
```

The main run must precede `--reload`; it leaves Punch bound to C in the isolated save.
The malformed-config fixture intentionally emits one ConfigFile parse diagnostic; a directory
temporarily occupying the test save temporary-file path deliberately produces a save warning.
The test verifies the old file survives and that a later save succeeds.
Assertions report `INPUT checks=... failures=[]`; inspect logs for any other runtime errors.
Rendered mode saves seven 640×360 PNGs to `input_renders` in the copied project.

This implementation was tested in `.godot/input-verification` using a root-level copy of
the harness (`res://verify_input.gd`). Existing regression harnesses were recovered from
the previous local Milestone 31 verification directory and run against the current scenes
and scripts. The old feature-flow assertion that Accept exits Controls was updated for the
new remap screen; production behavior was not changed to satisfy that obsolete assertion. The menu-determinism
fixture also enables the touch overlay in its longer-wait run to compare identical seeded traces.
The roadmap records the observed check counts and remaining hardware acceptance.

## Remaining hands-on acceptance

- Connect a controller: navigate title/options/Controls with D-pad and left stick; verify
  South/Accept, East/Cancel, Start/Pause and all four gameplay face buttons.
- Rebind a key/button/stick direction, reject a conflict, cancel capture using Esc/View,
  restore defaults, then restart/relaunch and check persistence.
- Hold the stick while entering gameplay, pausing, and ending a committed action: there
  should be no repeat or buffered action until a new tilt/press.
- Enable Desktop touch overlay in Controls. Click each pad direction, Punch/Kick and Pause.
  On a touch-capable desktop, use pad plus attack simultaneously and verify that a second
  pad finger cannot add a diagonal; slide off, pause, change focus and restart to check release.
- Complete controller-only initials entry: directions choose, Accept adds, Cancel erases,
  and Accept submits three characters. Confirm non-qualifying Game Over restart too.
- Judge the translucent controls over outer threat-entry lanes at native resolution and
  normal window sizes. Central combat and the bottom HUD should remain clear.

Real controller/multitouch hardware and subjective usability are not verified by the
injected-event suite. Milestone 34 browser/export evidence is in [WEB_VERIFICATION.md](WEB_VERIFICATION.md).
