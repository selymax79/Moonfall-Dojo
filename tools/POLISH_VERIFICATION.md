# Milestone 35: presentation polish verification

Implemented against clean committed baseline `c01f22d` on 16 October 2026.
**Milestone 35 is complete and manually accepted by the owner.** The current graphical/audio
polish is accepted for the present release; further refinement is optional future work.

## Changes and preserved boundaries

- [build_combat_art.gd](build_combat_art.gd) authors tapered cloth masses, shaped waists,
  connected joints, planted shoes, chest-led punches and hip-led high kicks. Ready, turn,
  jump, crouch, approach, attack and collapse poses share the same palette and 32-cell atlas.
- [combat_art.gd](../scripts/combat_art.gd) retracts Punch/Kick through intermediate poses
  within the existing recovery clocks. Red's weapon arm and Blue's low arm connect to their
  existing weapon/fist transforms; their moving hands are not duplicated in the atlas.
- [generate_audio.gd](generate_audio.gd) retains the motif, tempos and durations, adding
  synthetic plucked-string harmonics, filtered echoes, quiet held fifths and sparse replies.
  Three short original formant-synthesised vocal effects accompany defeat/death. No recordings
  or external assets were used. Title source gain compensates for added sustained energy.
- [control_bindings.gd](../scripts/control_bindings.gd) displays Face Up/Down/Left/Right.
  Only its display-name dictionary changes; button numbers, InputMap and saved bindings do not.

Only three PNGs and five WAVs change. Environment, HUD, Barrel and Shuriken assets remain
byte-identical. Player/threat logic, Main, scenes, collision geometry, timing, speeds,
scheduler, scoring, progression, input handling, audio architecture, project settings and
Web/PWA preset remain byte-identical to the baseline. No platform-specific copy was added.

## Native verification actually run

Godot 4.7.2 stable official, isolated `Moonfall Dojo Input Verification` project/save.

| Suite | Passing checks |
| --- | ---: |
| Combat/scoring, correct responses and same-tick Player-hit priority | 621 |
| Menus, persistence and feature flow | 172 |
| Scheduler: 384 pairs, 9,000 encounters, deterministic traces | 2,411,086 |
| Late encounters | 185,873 |
| F4 progression/fairness | 280,196 |
| Pause/determinism | 105,078 |
| Pattern/menu/input-option determinism | 92,017 |
| Audio triggering, bounded voices, pause and settings | 3,497 |
| Keyboard/controller/remapping/touch | 136 |
| Separate-process persisted remap reload | 1 |
| Browser lifecycle/pointer adapters | 49 |
| Existing art read-only state, 60 defeats and corpse cleanup | 15,784 |
| New atlas footprint, active frames and read-only presentation | 7,483 |

The new [verify_polish.gd](verify_polish.gd) checks 768x224 atlas dimensions, every pose's
bounded footprint, active fist/shoe pixels and display labels. It samples four Player
actions every millisecond in both directions and checks presentation does not mutate actor
position, hurtbox/attack transforms, hurtbox size, action clocks, encounter RNG or score.
Existing regression suites verify actual collision outcomes, including Jump/Barrel,
Duck/Shuriken, correct/incorrect Assassin responses and same-tick resolution priority.

Use the isolated-copy setup in [INPUT_VERIFICATION.md](INPUT_VERIFICATION.md), then run:

```text
godot --headless --path <isolated-copy> --script res://tools/verify_polish.gd
```

The existing historical regression harnesses remain in `.godot/input-verification` locally;
they were run against current scripts/assets. Logs are in `.godot/polish-verification`.
The input harness deliberately tests malformed saves/failed writes and emits their expected
diagnostics. Production import/export and render logs had no introduced warnings/errors.

## Visual and audio evidence

Native Compatibility renders on NVIDIA RTX 3080 covered ready, turn, Punch/Kick active and
recovery, Jump apex, Duck, Red/Blue wind-up/strike/recovery from both sides, and Controls.
Representative 640x360 captures were visually inspected. The Controls display fits its columns;
the active attacks stay at the established reach. Atlas contact sheets were also inspected.
Screenshots are in `.godot/input-verification/polish_renders` (local ignored evidence).

PCM analysis verified mono 22,050 Hz/16-bit format and unchanged file durations. Music RMS
relative to baseline: title 1.010x, gameplay 1.003x. Source peaks: title 0.44, gameplay 0.50,
enemy defeats 0.52, Player death 0.55. Music boundary jumps are 0.00348/0.00101 full scale;
one-shot endpoints match. No sample clipping. Runtime routing and gains are unchanged.
The vocal layers increase sustained impact energy, included in the owner's accepted audio polish.
Numerical headroom/seam measurements are not proof of comfortable loudness, a convincing human
grunt, good musical character or an inaudible loop seam. The automated verification did not
perform human listening; the owner subsequently supplied manual acceptance.

## Web verification

The existing release `Web` preset exported successfully, exit code 0, without new warnings or
errors. It still excludes tools/test probes and uses the same project, assets and runtime.
The local release preview is http://127.0.0.1:8066/index.html while the localhost server runs.

The existing isolated browser suite passed **44 checks** in Firefox 142.0.1 and Microsoft
Edge 155.0.4283.45. Coverage includes first-gesture audio with nonzero output waveform,
keyboard/remapping, simulated Gamepad API input, action commitment, pause, menu and settings
persistence, score/unlock fixture reload, 30 restarts, fixed physics cadence and PWA offline
reload/play. An independent release smoke check verified a 1280x720 canvas, title-to-gameplay
input and pause, no runtime errors and no test probe in the shipping pack; captures were inspected.

Edge mobile/touch emulation passed **18 checks** at 844x390 landscape / 390x844 portrait:
automatic overlay, simultaneous touches, direct menus/initials, committed actions, pause,
rotation release/resume, settings and record reload. Representative landscape/portrait captures
were inspected. These are emulated touches and a simulated controller, not physical hardware.
Browser automation/evidence remains locally in `.godot/web-verification`; current run logs
are in `.godot/polish-verification`. No PWA/browser implementation changes were needed.

No online browser runtime errors occurred. As documented in Milestone 34, Edge may report
the optional uncached boot-splash image offline; the cached game still starts and plays.

## Owner acceptance and closeout

The owner confirmed that Milestone 35 passed manual acceptance and that the current
graphical/audio polish is good enough for the present release. Additional sprite, animation,
music and audio refinement is deferred to a possible future milestone, not unfinished work.
Closeout changes acceptance documentation only; no further gameplay, art, animation or audio
changes or subjective polish pass were performed. The accepted work is committed as
`Complete final presentation polish`.

Earlier physical-controller, Android/iPhone/Safari and PWA installation coverage remains as
recorded in the input/Web reports; no additional hardware testing is claimed here. The fuller
pause menu remains outside the explicit presentation-polish ticket and does not block its closeout.

## Exact file inventory

Runtime code: [combat_art.gd](../scripts/combat_art.gd),
[control_bindings.gd](../scripts/control_bindings.gd).

Authored generators: [build_combat_art.gd](build_combat_art.gd),
[generate_audio.gd](generate_audio.gd).

Art: [player.png](../art/combat/player.png), [red.png](../art/combat/red.png),
[blue.png](../art/combat/blue.png).

Audio: [title.wav](../audio/music/title.wav), [gameplay.wav](../audio/music/gameplay.wav),
[player_death.wav](../audio/sfx/player_death.wav), [red_defeated.wav](../audio/sfx/red_defeated.wav),
[blue_defeated.wav](../audio/sfx/blue_defeated.wav).

Documentation: [DESIGN_NOTES.md](../DESIGN_NOTES.md), [Roadmap.md](../Roadmap.md),
[art/README.md](../art/README.md), [audio/README.md](../audio/README.md),
[INPUT_VERIFICATION.md](INPUT_VERIFICATION.md), and this report.

New verification: [verify_polish.gd](verify_polish.gd) and its Godot-generated
[UID metadata](verify_polish.gd.uid).

Repository scope includes the source, authored assets, documentation and verification files
listed above. Generated build output and local test artifacts remain ignored and excluded.

Learning points: visual state can read gameplay clocks without owning them; offline synthesis
can add harmonic/formant layers while leaving runtime audio ownership and bounded voices intact.
