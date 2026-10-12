# Presentation assets

These presentation assets do not define collision, movement, scoring or scheduling.
The logical viewport is 640×360; Player feet remain at y=300 and the HUD starts at y=308.

## Asset inventory and provenance

- [background/dojo_source.png](background/dojo_source.png): original image generated with
  the built-in image generation tool, then edited to align the wall/floor composition.
- [background/dojo.png](background/dojo.png): nearest-neighbour 640×318 runtime plate.
  Static sky, moon, trees, layered roofs, wall, two shoji panels, lamps and plank floor.
- [background/sky_mask.png](background/sky_mask.png): derived sky/moon mask for clouds.
- [background/cloud_0.png](background/cloud_0.png), [cloud_1.png](background/cloud_1.png):
  original code-authored stepped pixel banks, 192×32 each.
- [background/person_0.png](background/person_0.png), [person_1.png](background/person_1.png):
  original two-frame 16×30 silhouette; retained builder source output, superseded at runtime below.
- [background/dog_0.png](background/dog_0.png), [dog_1.png](background/dog_1.png):
  original two-frame 23×14 silhouette; retained builder source output, superseded at runtime below.
- [background/cloud_mask.gdshader](background/cloud_mask.gdshader): applies the sky mask
  in world coordinates, keeping moving cloud sprites behind static architecture.
- [ui/dojo_font.png](ui/dojo_font.png), [dojo_font.fnt](ui/dojo_font.fnt),
  [dojo_font.tres](ui/dojo_font.tres): original project-owned 5×7 bitmap glyphs, atlas,
  BMFont descriptor and embedded Godot FontFile. No external font assets were used.

The generated plate is a single composed image, not independently scrolling roof textures.
Only the two cloud depths drift. Lamps and silhouettes are drawn locally over the plate;
the shoji-cell mask preserves foreground wooden rails. Dark navy and muted blue dominate;
cream paper and small amber lamp pools provide restrained warmth. No real-time lighting.

## Image-generation direction

Generation used the built-in tool, not the CLI/API fallback. The initial prompt requested
an original, polished early-1990s Mega Drive/arcade-style side-on moonlit Japanese dojo,
with a central textured pale moon, dark irregular trees, distant and foreground tiled roofs,
two warm shoji doors, two amber wall lanterns, a calm central combat wall and wooden floor.
It specified a 640:308 landscape composition, restrained navy/blue-black/grey and amber
palette, hard pixel edges, no characters, no HUD/text, no bloom and no modern soft gradients.
The subsequent edit preserved the upper composition while extending the wall and doors
downward and narrowing the visible floor so it could align with the existing y=300 feet.
The retained source is that edited version; the earlier draft is not a runtime asset.

## Rebuilding the derived assets

Run from the project with Godot 4.7:

```text
godot --headless --path . --script res://tools/build_presentation.gd
```

[build_presentation.gd](../tools/build_presentation.gd) deterministically resizes the retained
source with nearest filtering and generates the mask, clouds, silhouette frames and font.
It does not call an image service or rebuild audio. Import the PNGs in Godot after rebuilding.
The font resource embeds its atlas and uses integer-only fixed-size scaling: 8, 16 and 24 px.

The plate's last ten rows lie beneath the status strip. Door-paper coordinates are
Rect2(116, 204, 88, 66) and Rect2(436, 204, 88, 66). These are visual authoring coordinates,
not hurtboxes; changing artwork requires checking masks and render alignment, not moving actors.

## Runtime ownership and learning points

[dojo_environment.gd](../scripts/dojo_environment.gd) owns a separate cosmetic RNG and
Pausable clock. Independent random-number streams keep decorative events from changing
gameplay choices; native scene pause freezes their elapsed time without wall-clock catch-up.
[run_hud.gd](../scripts/run_hud.gd) owns drawing/text fitting while Main owns the values:
presentation changes therefore leave scoring and progression rules in one place.

Milestone 27 is **COMPLETE** following automated verification and user manual acceptance of the environment and HUD presentation.

## Combined character/effects pass (Milestones 28 + 29)

All new sprites are original, code-authored native pixel images. Offline raster helpers fill
hand-placed polygons, strokes and colour clusters into fixed poses; they are not a runtime
skeleton or procedural animation system. No existing game sprites were copied and no image
service is required to regenerate these assets. The accepted dojo plate and HUD are unchanged.

Run `godot --headless --path . --script res://tools/build_combat_art.gd` to rebuild:

| Asset under `combat/` | Contents |
| --- | --- |
| [player.png](combat/player.png) | Navy/slate ninja, muted gold accent. |
| [red.png](combat/red.png) | Crimson sword ninja; blade rendered separately from its collision transform. |
| [blue.png](combat/blue.png) | Blue low-striking ninja; fist rendered from its collision transform. |
| [barrel.png](combat/barrel.png) | Eight 20×20 end-face roll cells spanning a full clockwise revolution; each contains an 18×18 circle matching radius 9. Reverse sequence for leftward travel. |
| [shuriken.png](combat/shuriken.png) | Four 8×8 steel spin cells. |
| [adult_0.png](combat/adult_0.png), [adult_1.png](combat/adult_1.png), [adult_2.png](combat/adult_2.png), [adult_3.png](combat/adult_3.png), [adult_4.png](combat/adult_4.png) | Four 24×32 walk poses plus a stationary pause pose. |
| [dog_0.png](combat/dog_0.png), [dog_1.png](combat/dog_1.png), [dog_2.png](combat/dog_2.png), [dog_3.png](combat/dog_3.png) | Four 28×18 trot poses. |
| [lamp_shadow_0.png](combat/lamp_shadow_0.png), [lamp_shadow_1.png](combat/lamp_shadow_1.png), [lamp_shadow_2.png](combat/lamp_shadow_2.png) | Three 64×84 lantern-cage/timber cast-shadow accents. |

The three ninja atlases use eight columns of 96×56 cells, with feet at cell coordinate (40,48).
The shared 32-pose catalogue is: idle 0–1; turn 2; punch 3–6; kick 7–10; jump 11–14;
crouch/rise 15–17; run 18–21; Red wind-up/strike/recovery 22–24; Blue low guard/strike 25–26;
collapse 27–31. Actors select relevant frames from their current clocks, not animation callbacks.
Cell padding reserves space for attacks and grounded collapse without changing collision bounds.

[combat_art.gd](../scripts/combat_art.gd) draws sprites/contact shadows and local hazard/dust
effects. [combat_aftermath.gd](../scripts/combat_aftermath.gd) draws harmless Assassin corpses
for 0.48 s. These effects use no RNG and cannot award rewards or block admissions. The updated
shoji silhouettes retain the existing separate cosmetic RNG and intervals; their feet step in
two-pixel increments. Three lamp intensity/shadow states keep illumination deliberately stepped.

Milestones 28 and 29 are **COMPLETE for functional development** following user manual review.
Current character sprites are accepted first-pass 16-bit placeholders, not final artwork.
Substantial Player punch/kick anatomy and pose polish, plus the same Red/Blue quality review,
is required before release; see the
[Roadmap art debt](../Roadmap.md#required-pre-release-character-art-polish).
Preserve current gameplay timings, hitboxes and animation-state alignment when polishing the art.
