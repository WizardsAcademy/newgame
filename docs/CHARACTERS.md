# Characters and Skill Trees

> Rule: every character owns 3 exclusive things — a **base kit** (normal
> attack + Shift skill + signature mechanic), a **signature mechanic**
> (something only they have), and **their own skill tree**.

## Overview Table

| Character | HP | Speed | `Shift` Skill | Signature Mechanic | Status |
|-----------|----|-------|---------------|--------------------|--------|
| **Behemoth** | **120 HP** | `92 px/s` | **18 DMG + 1.1s Stun** Shoulder Charge | 3-Hit Iron-Cestus Combo (`18 → 21 → 29 DMG`); **every punch STUNS** (`0.45s / 0.90s`) | ✅ Playable |
| **Knight** | **150 HP** | `68 px/s` *(Slowest)* | **16 DMG** Shield-Wall Charge | **Fallen Plate Armor (`-3` flat)** + **Tower Shield (`RMB / E`)**: **100% HP Block** powered by **Green Energy** (breaks at `0` until `100%` recovered) + **Spinning Greatsword (`26 DMG`)** | ✅ Playable |
| **Sylvara** | **100 HP** | `124 px/s` *(Fastest)* | **0 DMG** Sylvan Gale Vault *(Phases, Slows, +28% Tailwind)* | **Held Elven Recurve Bow**: `15 DMG` quick shots, 3-arrow 4th fan, & visible charged **Piercing Great-Arrow (`30 DMG`)** | ✅ Playable |
| **Velmira** | **75 HP** | `104 px/s` | **0 DMG** Bat-Swarm Vanish *(5 crimson bats)* | **Returning Liquid Blood Whip** (`6%` HP cost locked at `1 HP` floor; returns healing `cost + 1 HP/hit`) + **2-Fang Filling Circle (`30%` Max HP Burst)** | ✅ Playable |

---

## 1. Behemoth — Medieval Pit-Champion (`120 HP`)

- **Scene & Script**: `scenes/player/Behemoth.tscn`, `scripts/player/behemoth.gd`
- **Sprite Sheet (`96×96` × 16 frames = `1536×96`)**: `assets/textures/player_behemoth.png` (`tools/make_behemoth_sprites.py` — riveted brigandine vest, iron shoulder pauldron, crimson headband, scarred beard, spiked iron cestus gauntlets with dedicated `jab`, `cross`, `uppercut`, `charge`, and `hurt` frames) + circular `64×64` face portrait strip `assets/textures/portrait_behemoth.png`.
- **Signature Mechanic**: **Concussive Iron-Cestus Combo** — 3-hit melee combo (`18` → `21` → `29 DMG`); hits 1–2 stun for `0.45s` and the 3rd-hit Shockwave Uppercut stuns for `0.90s`.
- **`Shift` Skill**: **Shoulder Charge** — drops his spiked pauldron forward and rams enemies for **`18 DMG` + `1.10s` Stun**.

## 2. Knight — Fallen Knight (`150 HP`, Slowest `68 px/s`)

- **Scene & Script**: `scenes/player/Knight.tscn`, `scripts/player/knight.gd`
- **Sprite Sheet (`96×96` × 16 frames = `1536×96`)**: `assets/textures/player_knight.png` (`tools/make_knight_sprites.py` — cracked visor greathelm, tattered crimson betrayal cloak, dark steel plate, oversized **Zweihander Greatsword** with full swing/spin arc, Tower Shield `guard`, `charge`, and `hurt` frames) + `assets/textures/portrait_knight.png`.
- **Signature Mechanic**:
  - **Passive Fallen Plate Armor**: Reduces unshielded hits by `-3` flat damage (minimum `1`).
  - **Tower Shield (`Right-Click` / `E`)**: Blocks **100% of HP damage** (`0 HP` lost!) by consuming **Green Energy** instead (`14 + 1.5 × DMG`, plus `14/s` hold upkeep). If Green Energy hits `0`, the Shield **breaks (`shield_exhausted`)** and cannot be raised again until Green Energy regenerates back to `100%`.
- **`Shift` Skill**: **Shield-Wall Charge** — braces his Tower Shield in front (`charge` pose) and rams enemies for **`16 DMG`**.

## 3. Sylvara — Blonde Elven Ranger (`100 HP`, Fastest `124 px/s`)

- **Scene & Script**: `scenes/player/Sylvara.tscn`, `scripts/player/sylvara.gd`
- **Sprite Sheet (`96×96` × 15 frames = `1440×96`)**: `assets/textures/player_sylvara.png` (`tools/make_sylvara_sprites.py` — flowing golden hair, emerald elven tiara, forest tunic, feathered quiver, and **golden-yew Recurve Bow held visibly in hand** with `bow_draw`, `bow_charge`, `bow_release`, `charge`, and `hurt` frames) + `assets/textures/portrait_sylvara.png`.
- **Signature Mechanic**: **Elven Recurve Bow** — swift `15 DMG` arrows (every 4th quick shot looses a 3-arrow fan); holding Attack visibly draws and charges a **`30 DMG` Piercing Great-Arrow**.
- **`Shift` Skill**: **Sylvan Gale Vault** — leaps in a swirl of emerald leaves (`0 DMG`), phases cleanly through enemies, slows nearby foes (`×0.55` speed for `1.8s`), and grants `+28%` Tailwind movement haste.

## 4. Velmira — Silver-Haired Hemomancer (`75 HP`)

- **Scene & Script**: `scenes/player/Velmira.tscn`, `scripts/player/velmira.gd`
- **Sprite Sheet (`96×96` × 16 frames = `1536×96`)**: `assets/textures/player_velmira.png` (`tools/make_velmira_sprites.py` — moonlit **white/silver hair** with crimson temple rose, gothic crimson-collared bodice, smooth normal `idle`, 4-directional `walk`, `attack`, `charge`, `hurt`, and `die` blood-pool frames) + `320×64` portrait `assets/textures/portrait_velmira.png`.
- **Signature Mechanic**:
  - **Returning Liquid Blood Whip**: Lashing out sacrifices `6%` Max HP (`5 HP`), **strictly locked at a `1 HP` floor** (Velmira can NEVER kill herself by attacking; only enemy damage can kill her). A sinuous crimson blood orb (`128 px` reach) whips outward and curves back into Velmira: if it hit `N >= 1` enemies (`13 DMG` each), it heals **`spent_hp + 1 × N`** on return (`+1 HP` net per enemy hit; `0` heal on miss).
  - **2-Fang + Filling Crimson Circle Curse**: Each Blood Whip hit builds `1/4` of a circular crimson gauge topped with two vampire fangs on the target. On the **4th hit (`4/4`)**, the circle explodes for **30% of the enemy's Max HP** (capped at `55` on bosses) and heals Velmira `+4 HP`.
- **`Shift` Skill**: **Bat-Swarm Vanish** — Velmira vanishes into **5 flapping crimson bats** (`assets/textures/crimson_bat.png`, `0` Shift damage, phases through enemies) and re-materializes at the destination.

---

## Balance Log

- 2026-11-16 — **Medieval Guild Hub Lobby, `96×96` Hero Overhaul, Circular Face-Only `HeroHUD` + Green Energy, & Combat/Shift Rework**:
  - **Hub Lobby (`LobbyHub`)**: Game boots into a playable Medieval Guild Hall with a **Hero Wardrobe (`Komod`)**, a North **`STAGES`** Dungeon Gate (room-by-room stage progression with `NEXT STAGE` / `LOBBY` doors), an attached East Training Room with an immovable `100 HP` **`TrainingDummy`**, and a corner **`SANDBOX`** Door leading to the `1280×720` Arena Sandbox Map.
  - **HUD & Mini-Map**: Removed all top-left control/stat clutter; faded `MiniMap` (`alpha = 0.42`, hidden in Lobby); added bottom-left **`HeroHUD`** with a circular animated `64×64` **Face-Only Portrait** (`idle_a`, `idle_b`, `blink`, `<=35%` `low_hp` face, and hit-reaction `hurt` `"AKH!"` face) + Crimson HP Bar + Emerald Green Energy Bar.
  - **Stats & Speeds**: Knight `150 HP / 68 px/s` (slowest) | Behemoth `120 HP / 92 px/s` | Velmira `75 HP / 104 px/s` (lowest HP, white hair) | Sylvara `100 HP / 124 px/s` (fastest).
  - **Combat & Shift Rework**: Behemoth punches & Shoulder Charge stun foes; Knight gains `-3` passive Plate Armor + 100%-HP-block Energy Shield (`0 → 100%` exhaustion lockout) + spinning `26 DMG` Greatsword; Sylvara visibly draws/charges her held Recurve Bow + Sylvan Gale Vault slow/tailwind; Velmira uses a `1 HP`-locked returning Liquid Blood Whip (`+1 HP/hit` net on return) + 4-stack 2-Fang `30%` Max HP burst + 5-bat Bat-Swarm Vanish `Shift`.
