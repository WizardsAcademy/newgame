# Hero Skeleton Spec (the body, not the costume)

> **Why this file exists.** Three art passes in a row produced four heroes whose
> silhouettes are near-identical (pairwise IoU up to **0.80**). The generators
> were drawing correct *costumes* on one shared *body*. This file pins the
> **body** down with absolute pixel numbers. The generators may draw however
> they like — they must land inside these proportions.
>
> Verified by `python3 tools/hero_skeleton_check.py --strict`.
> No PR merges while that command fails.

---

## 1. The cast, in absolute numbers

All numbers are pixels inside the **96×96 cell**, `GROUND_Y = 80`.
"Body height" = crown → ground line.

| | **Behemoth** | **Knight** | **Sylvara** | **Noa** |
|---|---|---|---|---|
| role | hulking brawler | ordinary human | tall lithe elf | short, lithe vampire |
| **body height** | **68** | **76** | **80** | **64** |
| **head ratio** | 30% | 26% | 25% | 33% |
| crown y | 12 | 4 | 0 | 16 |
| chin y | 32 | 24 | 20 | 37 |
| shoulder y / **width** | 40 / **48** | 30 / **30** | 26 / **24** | 42 / **22** |
| waist y / width | 52 / 30 | 44 / 20 | 42 / 16 | 50 / 16 |
| hip y / width | 58 / 28 | 52 / 22 | 50 / 18 | 55 / 17 |
| knee y | 68 | 66 | 70 | 56 |
| ground y | 80 | 80 | 80 | 80 |
| **leg mass** (px below 70%) | **470** | **300** | **200** | **200** |
| **stance width** (feet span) | **26** | **16** | **12** | **12** |
| max silhouette width | 60 | 40 | 38 | 46 |
| build | hunched, head **forward** | upright | upright, narrowest | upright, hair mass |

**Relationships that must hold** (this is what the user asked for):

- Behemoth is **overall the thickest**: widest shoulders (48 vs ≤30), widest
  hips, heaviest legs, widest stance. He is *not* the tallest.
- Knight is the **human baseline**: 76 tall, 30 shoulders — nothing extreme.
- Sylvara is **taller than the Knight but clearly thinner**: 80 tall, 24
  shoulders, 200 leg mass.
- Noa is **the shortest of all**: 65 tall (`[62, 68]`), imported from
  hand-drawn `art_src/noa/*.png` via `tools/import_pose_sheet.py` with a
  narrow `12–13 px` boot stance inside her floor-length crimson-lined overcoat
  and sweeping ankle-length silver haircape.

---

## 2. Silhouette identities (non-negotiable)

Each hero must be identifiable from a **pure black shape at 96×96**.
Pairwise IoU must be **≤ 0.45** (currently 0.80 for Sylvara/Noa).

| Hero | What breaks the outline |
|---|---|
| **Behemoth** | Shoulders wider than hips by 20px; head sunk between them and pushed 3px **forward**; both fists hang below the hip line. |
| **Knight** | Straight vertical spine; sword breaks the right edge from shoulder height upward; cape wedge visible on the left hip. |
| **Sylvara** | A closed **bow hoop** that extends 10px past the body on one side; quiver breaking the back line at 45°. Nothing else is wide. |
| **Noa** | A **hair mass 40px wide** — the widest part of her is hair, not shoulders; one asymmetric fall reaching below the knee on her left only; skirt hem flares to 34px. |

**Anti-pattern to avoid:** four bodies at ~30px shoulders with a different
colour on top. That is what produced the "Roblox" read.

---

## 3. Rendering rules (shared)

| Rule | Value |
|---|---|
| cell | 96×96, `GROUND_Y = 80` for every frame |
| in-game scale | `Visuals.scale = 0.5` (all four, identical) |
| palette | ≤ 24 colours, shared master ramp (`tools/hero_art_lib.py`) |
| shading | 4 steps per material: shadow / base / light / highlight |
| light | top-left only, `(-0.68, -0.73)` |
| outline | selective selout, **never** `#000000` |
| alpha | binary (0 or 255), ≤ 2% semi-transparent |
| legs | must be **visibly narrower than the torso** — this is the #1 "action figure" tell |

---

## 4. How to verify

```bash
python3 tools/hero_skeleton_check.py            # human-readable table
python3 tools/hero_skeleton_check.py --strict    # exit 1 on any violation
python3 tools/hero_skeleton_check.py --iou       # silhouette overlap table
python3 tools/hero_skeleton_check.py --json      # for CI
```

The checker measures the **real pixels** of the standing frame: body height,
head ratio (crown → chin pinch), shoulder/hip width, leg mass below 70% of the
body, stance width, colour count, semi-alpha ratio and pairwise silhouette IoU.

**Definition of done for any art pass:**

```
hero_skeleton_check.py --strict   → exit 0
measure_hero_sheets.py --strict   → exit 0
tests/sprite_contract_test.tscn   → exit 0
tests/heroes_and_dash_test.tscn   → exit 0
```

No exceptions. If a hero "looks better" but the checker fails, the pass is not
done — it just moved the problem somewhere the eye stops noticing.
