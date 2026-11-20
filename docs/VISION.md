# Game Vision — Roguelike Brawler

> This document is the single source of truth for every design decision.
> When in doubt during development — "which choice is right?" — the answer
> lives in the **four pillars**.

## The game in one sentence

A 2D roguelike brawler you play locally with a friend, with four distinct
characters each having their own skill tree, pushing through ever-harder
waves until death — and every death makes you come back stronger.

## Four Pillars

| # | Pillar | Practical meaning |
|---|--------|-------------------|
| 1 | **Every hit must be felt** (Impact) | Hit-stop, screen shake, flash, particles, sound — no hit is ever "silent". A new mechanic without these effects is half-finished. |
| 2 | **Character = Gameplay** | The 4 characters must not differ only in looks; each should make you feel within the first 10 minutes that "this one plays unlike the others". |
| 3 | **Death = Progress** | Every death grants resources spent in the skill tree. The player should never feel "that was wasted" — they should feel "I moved one step forward". |
| 4 | **Hard but fair** | Enemies telegraph clearly, then strike. Death is always preventable. Unfair randomness is forbidden. |

## Core Loop

```
enemy wave → combat (urgent, high-tension) → reward between waves
   ↑                                              |
   |                                              ↓
death → character skill tree ← collected resources → next wave / next run
```

Run structure (current and near-term):
- Fixed arena, endless waves with scaling difficulty
- Every 5 waves: a **boss** / special event
- Between waves: pick one upgrade (in-run roguelike layer)

Long-term structure (after co-op):
- Rooms → biomes (à la Dead Cells) with exit doors and route choice
- Optional extraction: at any moment you may **bank** your resources and
  leave, or get greedy and risk losing them all

## Game Modes

| Mode | Version | Notes |
|------|---------|-------|
| Single-player arena | ✅ now | Done |
| Local co-op, 2 players | Phase A | Two gamepads/keyboards, shared camera |
| Local co-op, up to 4 players | Phase B | Same architecture, just more inputs |
| Online (host/join) | Phase C | One player hosts, others join; the same local gameplay loop over the network |

## Tone and Look

- 24×24 pixel art, limited palette, simple dark background
- Persian-flavored names and fantasy: Borzo, Bahman, Shabnam, Pari —
  the rest of the content (enemies, places, upgrade names) draws from
  the same space
- Audio: procedural SFX via `SFXGenerator` — no music files or external
  audio assets
