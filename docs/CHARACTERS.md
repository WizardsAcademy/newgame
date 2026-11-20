# Characters and Skill Trees

> Rule: every character owns 3 exclusive things — a **base kit** (normal
> attack + Shift-Dash + signature ability), a **signature mechanic**
> (something only they have), and **their own skill tree**. Imbalance in
> early versions is expected; we patch it later.

## Overview Table

| Character | Role | Reach | Speed | Learning curve | Implementation status |
|-----------|------|-------|-------|----------------|-----------------------|
| **Behemoth** | Melee brawler, soft tank | Short | Heavy | Easy | ✅ Playable |
| **Knight** | Frost greatsword knight, "aura farmer" | Medium–long | Heavy tank | Medium | ✅ Playable |
| **Sylvara** | Elf ranger, bow, mobile kiter | Very long | Fast/fragile | Hard | ✅ Playable |
| **Velmira** | Crimson vampire, ranged blood blades | Long | Agile | Medium | ✅ Playable |

---

## 1. Behemoth — Iron-Fist Brawler

- Look: muscular brawler, navy tunic, crimson headband (`assets/textures/player_borzo.png`)
- Base HP: 100 (second tank after Knight)
- Signature mechanic: **3-hit combo** (Jab → Cross → Shockwave Uppercut)
- Base kit: escalating punch combo / 14-damage **Shoulder Dash** (`Shift`, 1.0s CD, phases through enemies) / shockwave uppercut
- Skill tree direction: durability + crowd control (more knockback, small HP-on-hit leech, wider shockwave)

## 2. Knight — Frost Greatsword

- Look: steel armor, frost greatsword, glowing **Winter Aura** frost ring (`assets/textures/player_bahman.png`)
- Base HP: 120 (main tank) — heaviest mover
- Signature mechanic: **Winter Aura** — enemies inside a short radius are slowed; standing firm charges the aura wider (`56 → 82 px`), up to `55%` chill slow + frost pulse damage/sec!
- Base kit: wide frost greatsword cleave (`24 DMG`) / 16-damage **Shield-Bash Dash** (`Shift`, 1.0s CD) / Winter Aura zone control
- Skill tree direction: zone control + survival (wider aura, damage reflection, resilience)

## 3. Sylvara — Elven Ranger

- Look: agile elven archer in forest-emerald cloak with longbow (`assets/textures/player_pari.png`)
- Base HP: 75 (most fragile) — fastest mover (`118 px/s`)
- Signature mechanic: **Hunter's Charge** — holding Attack (`≥0.35s`) unleashes a 2× damage **Piercing Great-Arrow** that slices through all lined-up enemies; every 4th quick shot fires a 3-arrow Emerald Fan!
- Base kit: quick arrow + 3-arrow fan / charged piercing Great-Arrow / 390-speed **Windstep Dash** (`Shift`, 1.0s CD, 11 DMG)
- Skill tree direction: mobility (fire rate, piercing multishot, dash distance, critical backstabs)

## 4. Velmira — Crimson Vampire

- Look: crimson-cloaked vampire with glowing eyes & blood blades (`assets/textures/player_shabnam.png`)
- Base HP: 85 — **Vampire Life Leech** restores HP on every hit
- Signature mechanic: **Blood Pool & Crimson Nova** — every hit grants +2 HP and 1 Blood Orb; at 5 orbs Velmira erupts in a radial **Blood Nova** (`16 AOE DMG + 5 HP`)
- Base kit: boomerang **Blood Blade** (`13 DMG × 2`, hits going out & returning) / **Bat-Mist Dash** (`Shift`, 1.0s CD, `15 DMG + 3 HP` per enemy phased) / Crimson Nova
- Skill tree direction: risk management (more life steal, blade range, bat dash potency, blood pool capacity)

---

## Skill Tree Principles (shared by all 4 characters)

- Structure: each tree runs from **one root** into 3 branches (branch = fantasy role). Example for Behemoth → "Iron Fists" (damage) / "The Mountain" (survival) / "The Storm" (mobility)
- Every node: a fixed, checkable number (never random); max level of any node is 2–3
- Costs are spent after each death and **are never lost** (meta progression)
- Design rule: price "new mechanic" nodes cheap and "numeric" nodes expensive — a mechanical node delivers a real sense of progress

## Balance Log

Every meaningful numeric change is logged here so we know what happened:
- 2026-11-20 — Archer anti-kiting: retreat speed 55 → 30 px/s (`×0.55`); panic exhaustion after 1.5s fleeing locks retreat for 1.2s (grey tint tell).
- 2026-11-20 — Phase 8: first boss "Forest Colossus" (every 5th wave, 400 HP, speed 26 px/s; SLAM / SWEEP / ROOTS telegraphs + `<30% HP` Enrage).
- 2026-11-16 — 4-Hero Roster (`Behemoth`, `Knight`, `Sylvara`, `Velmira`) + Universal Shift-Dash + Top-Right Mini-Map:
  - **Universal Shift-Dash (`KEY_SHIFT`)**: 1.0s cooldown, 0.16s burst, phases through enemy bodies while respecting walls, grants dash i-frames, and deals `dash_damage` on enemy pass-through (+ `razor_dash` +8 dmg upgrade in `UpgradePool`).
  - **Behemoth (Brawler)**: 100 HP, 90 px/s, 18 base dmg, 3-hit combo (×1.0 / ×1.15 / ×1.60 uppercut shockwave + knockback), 14 dash dmg.
  - **Knight (Frost Greatsword)**: 120 HP, 76 px/s, 24 wide greatsword cleave dmg, 16 dash dmg, **Winter Aura** (`r = 56→82 px` while standing still, slows enemies `30%→55%` + 5 frost pulse dmg/s at full charge).
  - **Sylvara (Elf Ranger)**: 75 HP, 118 px/s, 14 arrow dmg (3-arrow fan every 4th quick shot; hold `≥0.35s` for 2× dmg piercing Great-Arrow), 390 dash speed / 11 dash dmg.
  - **Velmira (Crimson Vampire)**: 85 HP, 104 px/s, `13×2` boomerang Blood Blade dmg (outbound + return), +2 HP leech on hit (+3 HP on Bat-Mist Dash, 15 dash dmg), 5-orb Blood Pool detonates a 16-dmg AOE Blood Nova (+5 HP).
