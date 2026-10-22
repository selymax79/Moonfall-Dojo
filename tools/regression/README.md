# Regression suites

These headless suites produced the scheduler, fairness, combat, pause, pattern, audio and
persistence check counts recorded in [Roadmap.md](../../Roadmap.md) and
[DESIGN_NOTES.md](../../DESIGN_NOTES.md). Before they were placed here, they existed only in the
gitignored `.godot/input-verification/` folder. The files are kept verbatim from that copy.

Run them after any change to Player timings, threat geometry, speeds, the scheduler, scoring,
pause, persistence or menu flow. Automated survival checks do not replace playtesting.

## Why they live in an isolated copy

- Each suite `extends` another suite through a **root-level** path such as
  `extends "res://scheduler_verify.gd"`, so the files must sit at the root of the project they run in.
- Some suites read or write `user://high_score.cfg`. Godot derives `user://` from the project
  name, so a copy named `Moonfall Dojo Input Verification` keeps your real scores and bindings safe.
- `.gdignore` stops the main project's editor from importing this folder, and the export
  `exclude_filter` (`tools/*`) keeps it out of builds.

## Setup

1. Copy `project.godot`, `default_bus_layout.tres`, `scenes/`, `scripts/`, `art/` and `audio/`
   into a disposable folder (the existing one is `.godot/input-verification/`).
2. In the copy only, set `application/config/name="Moonfall Dojo Input Verification"`.
   Never rename the working game.
3. Copy every `*.gd` and `*.gd.uid` from this folder to the root of the copy (not the `.gdignore`).
4. Import once: `godot --headless --path <copy> --editor --import --quit`.

Refresh the copy's `scripts/` and `scenes/` from the working game before each run, otherwise
the suites test stale code.

## Running

Use the console build of Godot 4.7.2, for example:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path <copy> --script res://scheduler_verify.gd
```

Each suite prints a result line. Look for `failures=0` or `failures=[]` and review any other errors.

| Suite | Covers | Extends | Last recorded result |
| --- | --- | --- | --- |
| `scheduler_verify` | 1,024 ordered pair cases (8 Levels, pressed at the planned press and at the latest tolerated moment), 9,000 progressing encounters, seeded determinism, targeted fairness/pacing/death | `SceneTree` | `RESULT checks=2381910 failures=0` |
| `press_window_verify` | ThreatTiming geometry matches the scenes; every tick inside every press window wins (1,936 presses, Levels 1–1000); Blue crouches before Kick range | scheduler | `PRESS_WINDOWS presses=1936 checks=2249 failures=[]` |
| `pacing_measure` | Measurement: threats per second and overlap at fixed Levels 1–60 (compare before/after difficulty changes) | scheduler | `PACING_RESULT checks=1177652 failures=[]` |
| `regression_verify` | Combat outcomes, scoring, progression and multiplier boundaries | scheduler | `REGRESSION RESULT checks=708 failures=0` |
| `pause_verify` | Pause freezes Player, threats, cosmetics and scheduler time | scheduler | `PAUSE RESULT checks=98084 failures=0` |
| `features_verify` | Title, menus, Game Over, initials, high scores, unlocks, persistence; former F2/F4 keys inert | pause | `FEATURES checks=171 failures=[]` |
| `run_menus_verify` | Pause menu (Resume/Restart/Quit by key, Enter, tap and click), Game Over Try Again / Return to Menu, initials typing and on-screen key grid; Esc pause; zero scores void | features | `RUN_MENUS checks=109 failures=[]` |
| `late_verify` | Late speed curve, gap bands and wind-up schedule (Levels 14–1000) and 320 late-tier pairs at Levels 15–50 | scheduler | `LATE pairs=320 checks=167691 failures=[] minimum_margin=0.1` |
| `pattern_verify` | Curated two-step patterns, draw order, pattern share | scheduler | `PATTERNS_RESULT checks=9167023 failures=[] minimum_margin=0.09999999999982` (0.1 within float rounding) |
| `pattern_controls` | Pattern state across pause, Level-up, death and restart; identical traces after different menu waits | features | `PATTERN_CONTROLS checks=77402 failures=[] menu_encounters=200` |
| `audio_verify` | Cue counts, routing, volumes, death and pause audio | features | `AUDIO checks=3524 failures=[]` |
| `barrel_verify` | Barrel/Jump input windows | scheduler | `BARREL TARGETED checks=429 failures=[]` |
| `combat_verify` | Combat art reads state without changing hurtboxes or RNG | features | `COMBAT ART checks=15314 failures=[]` |
| `presentation_verify` | Cosmetic seeds/rates leave gameplay traces unchanged | features | `PRESENTATION RESULT checks=82459 failures=[]` |
| `orientation_verify`, `window_verify` | Web orientation and window scaling checks | `SceneTree` | — |
| `pattern_render`, `polish_render` | Capture PNGs for visual inspection (run without `--headless`) | pattern / features | — |

Results recorded on 22 October 2026, after the F2/F4 development controls were removed. That
change deleted the F4-only `f4_verify` suite and moved the other suites' restarts onto the real
Game Over path. The same day added `run_menus_verify` for the pause menu, Game Over menu and
initials key grid. Later that day the difficulty extension (new fairness model, late speed
curve, shorter late wind-ups) added `press_window_verify` and `pacing_measure`; many counts
changed because the autopilot now presses at each threat's planned moment. Investigate any later difference in counts rather than assuming a regression.

Injected pointer events use window coordinates. Headless windows are tiny (64×64), so convert a
640×360 viewport point with `root.get_final_transform() * point` before dispatching it, as
`run_menus_verify` does; otherwise taps and clicks silently miss.

Helpers that are not suites:

- `fixed_main.gd` is a test-only Main that locks the Level, so a single difficulty tier can be measured.
- `pattern_oracle.gd` independently recomputes the expected encounter RNG sequence.
- `audio_spy.gd` and `records_spy.gd` record audio and save calls for assertions.

Input, Web and polish verifiers are documented separately in [INPUT_VERIFICATION.md](../INPUT_VERIFICATION.md),
[WEB_VERIFICATION.md](../WEB_VERIFICATION.md) and [POLISH_VERIFICATION.md](../POLISH_VERIFICATION.md).
