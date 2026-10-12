# Environment and gameplay HUD assets

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
  original two-frame 16×30 silhouette.
- [background/dog_0.png](background/dog_0.png), [dog_1.png](background/dog_1.png):
  original two-frame 23×14 silhouette.
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
