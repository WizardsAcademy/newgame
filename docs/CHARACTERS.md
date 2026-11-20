# Characters and Skill Trees

> Rule: every character owns 3 exclusive things — a **base kit** (normal
> attack + 2 abilities), a **signature mechanic** (something only they
> have), and **their own skill tree**. Imbalance in early versions is
> expected; we patch it later.

## Overview Table

| Character | Role | Reach | Speed | Learning curve | Implementation status |
|-----------|------|-------|-------|----------------|-----------------------|
| **Borzo** | Melee brawler, soft tank | Short | Heavy/slow | Easy | ✅ Phases 1–5 |
| **Bahman** | Greatsword knight, "aura farmer" | Medium–long | Very heavy | Medium | ❌ |
| **Shabnam** | Vampire, ranged (blood blades) | Long | Agile | Medium | ❌ |
| **Pari** | Elf, bow, mobile kiter | Very long | Fast/fragile | Hard | ❌ |

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
- (Empty for now — starts with the first two-character balance test)
