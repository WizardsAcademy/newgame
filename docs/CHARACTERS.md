# Characters and Skill Trees

> Rule: every character owns 3 exclusive things — a **base kit** (normal
> attack + 2 abilities), a **signature mechanic** (something only they
> have), and **their own skill tree**. Imbalance in early versions is
> expected; we patch it later.

## Overview Table

| Character | Role | Reach | Speed | Learning curve | Implementation status |
|-----------|------|-------|-------|----------------|-----------------------|
| **Borzo** | Melee brawler, soft tank | Short | Heavy/slow | Easy | ✅ Playable |
| **Bahman** | Greatsword knight, "aura farmer" | Medium–long | Very heavy | Medium | ✅ Playable |
| **Shabnam** | Vampire, ranged (blood blades) | Long | Agile | Medium | ✅ Playable |
| **Pari** | Elf, bow, mobile kiter | Very long | Fast/fragile | Hard | ✅ Playable |

---

## 1. Borzo — Brawler

- Look: muscular mustached man, navy work clothes, red scarf (current spritesheet)
- Base HP: 100 (second tank after Bahman)
- Signature mechanic: **3-hit combo** (left–right–uppercut) where the
  third hit launches the enemy into the air
- Base kit: punch combo / shoulder dash (breaks enemy telegraphs) / ground
  slam (radial shockwave)
- Skill tree direction: durability + crowd control (more knockback, small
  HP-on-hit leech, wider shockwave)

## 2. Bahman — Knight

- Look: steel armor, greatsword, an "aura" = cold frost field around his body
- Base HP: 120 (main tank) — slowest mover
- Signature mechanic: **Winter Aura** — enemies inside a short radius are
  slowed; the longer Bahman stands still, the stronger the aura (aura farmer!)
- Base kit: whiplike sword sweep (wide and slow, hits several enemies) /
  shield wall (full frontal block + slight reflect) / charge attack
  (1-second windup, linear cleave)
- Skill tree direction: zone control + survival (wider aura, damage
  reflection, resilience)

## 3. Shabnam — Vampire

- Look: woman with short black hair, red eyes, a blood trail on her clothes
- Base HP: 80 — but has **life leech**: every hit returns a little HP
- Signature mechanic: **Blood Pool** — damage you deal accumulates in a
  pool, spent on her special ability
- Base kit: blood blade (a curving boomerang-like throw) / bat dash (quick
  reposition toward a marker) / blood gulp: spend the pool for a radial
  burst + the biggest heal in the game
- Skill tree direction: risk management (more life steal, blade stickiness,
  second/third bat dash, blood pool capacity)

## 4. Pari — Elf Archer

- Look: attractive elf woman, delicate features, forest-green outfit, bow
- Base HP: 70 (most fragile) — fastest mover + double jump
- Signature mechanic: **Hunter's Charge** — holding the attack builds a
  huge arrow that pierces through enemies
- Base kit: quick arrow (upgrades into a triple shot) / spike trap (roots
  an enemy) / arrow rain (ultimate AOE with a long windup)
- Skill tree direction: mobility (extra jumps, fire rate, more traps,
  critical backstabs)

---

## Skill Tree Principles (shared by all 4 characters)

- Structure: each tree runs from **one root** into 3 branches
  (branch = fantasy role). Example for Borzo → "Iron Fists" (damage) /
  "The Mountain" (survival) / "The Storm" (mobility)
- Every node: a fixed, checkable number (never random); max level of any
  node is 2–3
- Costs are spent after each death and **are never lost** (meta progression)
- Design rule: price "new mechanic" nodes cheap and "numeric" nodes
  expensive — a mechanical node (like Pari's double jump) delivers a
  real sense of progress

## Balance Log

Every meaningful numeric change is logged here so we know what happened:
- 2026-11-20 — Archer anti-kiting (playtest: wave 3 was unwinnable, the
  archer's retreat + arrow knockback made the fight an endless chase).
  Changed: retreat speed 55 → 30 px/s (×0.55 `retreat_speed_factor`);
  NEW panic exhaustion — after 1.5s of fleeing in one stretch the archer
  cannot retreat for 1.2s (grey tint tell). Effect: a persistent player
  always catches the archer and gets a guaranteed hit window.
- 2026-11-20 — Phase 8: first boss "Forest Colossus" (every 5th wave,
  no wave scaling). 400 HP, speed 26 px/s. Attacks: SLAM (close, r=70,
  18 dmg, 1.0s telegraph, 1.2s recover), SWEEP (close, r=52, 14 dmg,
  0.7s telegraph, alternates with SLAM), ROOTS (ranged cast ≤340px,
  red ring grows 0.9s on the player's spot, then 12 dmg burst; 2.5s
  cooldown). ENRAGE once below 30% HP: speed ×1.4, telegraphs ×0.6,
  permanent red tint.
- 2026-11-16 — 4-Hero Roster + Universal Shift-Dash (`PlayerBase` +
  `CharacterSelectMenu`):
  - **Universal Shift-Dash (`KEY_SHIFT`)**: 1.0s cooldown, 0.16s burst,
    phases through enemy bodies while respecting walls, grants dash
    i-frames, and deals `dash_damage` on enemy pass-through (+ `razor_dash`
    +8 dmg upgrade in `UpgradePool`).
  - **Borzo (Brawler)**: 100 HP, 90 px/s, 18 base dmg, 3-hit combo
    (×1.0 / ×1.15 / ×1.60 uppercut shockwave + knockback), 14 dash dmg.
  - **Bahman (Knight)**: 120 HP, 76 px/s, 24 wide greatsword cleave dmg,
    16 dash dmg, **Winter Aura** (r=56→82 px while standing still, slows
    enemies 30%→55% + 5 frost pulse dmg/s at full charge).
  - **Pari (Elf)**: 75 HP, 118 px/s, 14 arrow dmg (3-arrow fan every 4th
    quick shot; hold ≥0.35s for 2× dmg piercing Great-Arrow), 390 dash
    speed / 11 dash dmg.
  - **Shabnam (Vampire)**: 85 HP, 104 px/s, 13×2 boomerang Blood Blade
    dmg (outbound + return), +2 HP leech on hit (+3 HP on Bat-Mist Dash,
    15 dash dmg), 5-orb Blood Pool detonates a 16-dmg AOE Blood Nova (+5 HP).
