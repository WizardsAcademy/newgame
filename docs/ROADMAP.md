# Roadmap

> Every phase has a "Definition of Done" (DoD) — once every DoD item is
> tested and correct, commit and move to the next phase. The order of
> phases is fixed: single-player → local co-op → online.

## Current status

| Phase | Content | Status |
|-------|---------|--------|
| 1 | Movement + basic attack (brawler) | ✅ |
| 2 | First enemy (slime: chase/lunge) | ✅ |
| 3 | Juice: screen shake, hit-stop, procedural SFX | ✅ |
| 4 | Player health, game over, Borzo sprite | ✅ |
| 5 | Endless wave system with scaling | ✅ |
| 6 | Polish: death particles, shadows, footstep dust, hurt flash, wave banner | ✅ |

## Phase 7 — Enemy variety and between-wave upgrades (in progress)

- [x] Second enemy: "skeleton archer" — keeps distance, red telegraph,
  dodgeable arrows; joins from wave 3 (`archer_start_wave`)
- [x] Third enemy: "stone golem" — slow, 90 HP, long telegraph (0.8s),
  AOE slam with heavy screen shake + a punish window after the hit;
  joins from wave 5 (`golem_start_wave`)
- [x] Wave composition: waves 1–2 slimes only; from wave 3 a 30% archer
  chance; from wave 5 a 15% golem chance — scaling is an "added bonus"
  on each type's base stats (per-type speed cap: `max_move_speed`)
- [x] Between waves: pick 1 of 3 upgrades (in-run roguelike layer) —
  starts with generic upgrades (+HP, attack speed, dash); each character
  later gets their own exclusive pool (`UpgradePool` + the 1/2/3 menu,
  tested: menu opens, stats apply, next wave unlocks)
- [x] Arrows draw a risk line on the ground (linear telegraph, polish pass)
- [ ] Elites (hero versions of enemies): golden aura, 3× HP, one extra ability
- DoD: a 10-minute run should feel varied; death around waves 7–10 should
  feel natural; zero log errors

## Phase 8 — First boss

- [ ] Wave-5 boss: "Forest Colossus" — 3 attack phases, clear telegraphs,
  enrage phase
- DoD: beating the boss should feel like "I learned it", not like luck

## Phase 9 — Meta progression and second character

- [ ] Death currency + hub/menu scene (character select + skill tree)
- [ ] Borzo's skill tree — data in one file (JSON/Dictionary), not hardcoded
- [ ] Second character: Bahman — built on a shared `PlayerBase`, not a copy
  of player.gd
- DoD: repeated deaths should convey real growth; Bahman must feel clearly
  mechanically different from Borzo

## Phase 10 — Local co-op (2 players)

- [ ] Input refactor: every Player binds to an "input profile" (device),
  not global actions; player 2: second keyboard or gamepad
- [ ] Shared camera: both players in frame + dynamic zoom
- [ ] Teammate revive (hold a button near the body for 3 seconds)
- [ ] Two-column HUD; friendly fire off
- DoD: two people on keyboard + gamepad reach wave 10

## Phase 11 — Online (host/join)

- [ ] Authoritative server architecture (host = authority; clients send
  inputs and render)
- [ ] State sync (position/health/wave) via RPC; 2 players only at first
- [ ] LAN test first, then public deployment (distribution method decided later)
- DoD: 2 people on 2 separate machines complete a healthy run

> Golden rule for Phase 11: write nothing "single-player-only" even now —
> keep logic separate from rendering, route inputs through the player
> instead of global Input, and publish important decisions with signals
> (the current main.gd pattern). These three habits turn Phase 11 from a
> nightmare into an ordinary phase.
