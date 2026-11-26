# Forge quality pass — root-cause fix for "low-quality" hero sprites (2026-11-26)

## Symptom
In-game (Godot 4.7, NEAREST, 0.5x), the reskinned Noa and Sylvara looked mushy /
ragged; Knight partially; Behemoth fine. HUD portraits crisp for everyone.

## Root cause (measured, not guessed)
The AI-generated masters shade with 1-texel dither and scattered single-texel
colour islands. Evidence on the shipped sheets vs the old hand-drawn ones:
- 1-texel horizontal runs: NEW ~70-85% vs OLD ~45-52% of all runs
- cross-ramp small-component analysis (sylvara f00): 234 cross-ramp vs 137
  same-ramp islands <= 2 texels -> most speckle is wrong-material mottle,
  not tonal dither
- rendering path ruled out: all four .tscn use identical filter=1, scale 0.5
- Behemoth looked fine because fur-covered, silhouette-heavy designs read
  1-texel texture as fur; long smooth hair masses read it as noise

## Fix (tools/forge_quality/clean_cells.py)
Structural despeckle on placed frames (only recolours, never moves):
- 4-conn components of size <= 2 absorbed into dominant boundary colour when
  same palette ramp (tonal dither) with >= 2 dominant neighbours
- cross-ramp absorption only for SYSTEMATIC pairs (>= 5 occurrences/frame):
  kills mottle, preserves one-off details (eye glints, rivets, flowers)
- size-1 comps in mixed zones adopt majority same-ramp neighbour
- 2-3 iterations + palette re-snap + full per-frame QA gate re-run

## Result
47/47 affected frames + 15 portrait cells PASS; 1px-run noise roughly halved
(e.g. noa f00 78% -> 52%, knight charge 68% -> 34%); strict contract passes
for all four heroes; Behemoth untouched (already clean).
