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
- [x] Elites (hero versions of enemies): golden ring at the feet, 3x HP,
  one exclusive ability per type — slime RAGE (60% telegraph, +15% lunge),
  archer VOLLEY (3-arrow fan), golem UPRISING (+50% slam radius, +5 dmg);
  chance grows with the wave (8% from wave 6, +2%/wave, 25% cap)
  (`Elite` helper + `become_elite()` per enemy)
- [x] Golem art pass: the 24×24 grey blob became a 40×40, 12-pose brute
  (stomp, roar, fists-overhead telegraph, fists-in-the-floor slam, stuck
  recovery, elite flare, crumble → rubble) with footstep dust and camera
  nudge, and the same HP/damage/radius — `docs/GOLEM_REDESIGN.md`,
  generator in `tools/make_golem_sprites.py`
- [x] Velmira art pass (gothic): the lilac redesign became a near-black
  purple, six-frame vampire from the reference sheet — huge hair mass with a
  crimson rose and two falls to her ankles, pale face with crimson eyes and
  fangs, black bodice with crimson collar/cape/brooch and silver belt,
  thigh-high boots with a crimson cross-band, blood orb + droplet cast
  frames, and the same 85 HP / 104 speed / 17 DMG Blood Splash —
  `docs/VELMIRA_REDESIGN.md`, generator in `tools/make_velmira_sprites.py`
- [x] Archer art pass: the 16×16 placeholder became a 32×32, 12-pose
  hooded skeleton (shamble, bone rattle, bow draw → release, mocking head
  tilt, white hit flash, collapse into a bone heap) with the same HP,
  speed, damage and hitboxes — `docs/ARCHER_REDESIGN.md`, generator in
  `tools/make_archer_sprites.py`
- [x] Slime art pass: the green placeholder square became a rounded,
  hand-generated 12-pose jelly (breath, blink, hop, splat, wind-up, lunge,
  flinch, puddle) with a real white hit flash and goo death decal —
  `docs/SLIME_REDESIGN.md`, generator in `tools/make_slime_sprites.py`
- [x] Slime family (Phase V1): grass / acid / ember / basalt share one 12-pose
  rig and escalate with the wave — acid unlocks at 3 (dies into a damaging
  pool), ember at 6 (fuses then explodes behind a painted danger circle),
  basalt at 9 (spiked shell, contact damage, tanky) — registry in
  `scripts/enemies/slime_variant.gd`, FX in `scenes/fx/`, design and the
  remaining variants (frost / splitter / void / king) in
  `docs/SLIME_VARIANTS.md`
- DoD: a 10-minute run should feel varied; death around waves 7–10 should
  feel natural; zero log errors

## Phase 8 — First boss

- [x] Wave-5 boss: "Forest Colossus" — 3 attack phases (SLAM 70px/18 dmg,
  SWEEP 52px/14 dmg alternating close-range, ROOTS ring burst 12 dmg at
  range up to 340px), 1.0s clear telegraphs, ENRAGE below 30% HP
  (speed ×1.4, telegraphs ×0.6, red tint). Spawns as a boss-only wave
  every 5th wave. 17/17 automated boss checks pass.
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
