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

- **Reference-Extracted Sprite Sheet (`224×224` × 32 frames = `1792×896`)**: `assets/textures/player_borzo.png` built from `assets/sprites/behemoth/behemoth_reference.png` (`scale = 0.165`, `LINEAR_WITH_MIPMAPS`, `GROUND_Y = 200`, dark fur-pelt mantle, bare scarred torso, spiked leather-iron bracers, 4-directional idles & walks, `jab` / `cross` / `uppercut` combo, `charge`, `hurt`, and `kneel -> fallen` `die`) + `960×192` (`5 × 192×192`) circular HUD portrait `assets/textures/portrait_borzo.png`.
- **Signature Mechanic**: **Concussive Iron-Cestus Combo** — 3-hit melee combo (`18` → `21` → `29 DMG`); hits 1–2 stun for `0.45s` and the 3rd-hit Shockwave Uppercut stuns for `0.90s`.
- **`Shift` Skill**: **Shoulder Charge** — drops his shoulder forward and rams enemies for **`18 DMG` + `1.10s` Stun**.

## 2. Knight — Golden-Lion Knight (`150 HP`, Slowest `68 px/s`)

- **Reference-Extracted Sprite Sheet (`224×224` × 32 frames = `1792×896`)**: `assets/textures/player_bahman.png` built from `assets/sprites/knight/knight_reference.png` (`scale = 0.165`, `LINEAR_WITH_MIPMAPS`, `GROUND_Y = 200`, crested greathelm, gold-trimmed dark-steel plate, crimson-gold heraldic cloak, Golden-Lion Heater Shield `guard`, silver-crescent Greatsword `attack` combo, speed-streak `charge`, `hurt`, and `die`) + `960×192` (`5 × 192×192`) circular HUD portrait `assets/textures/portrait_bahman.png`.
- **Signature Mechanic**:
  - **Passive Plate Armor**: Reduces unshielded hits by `-3` flat damage (minimum `1`).
  - **Golden-Lion Shield (`Right-Click` / `E`)**: Blocks **100% of HP damage** (`0 HP` lost!) by consuming **Green Energy** on blocked hits (`20 + 1.2 × DMG`, `0` hold drain). If Green Energy hits `0`, the Shield **breaks (`shield_exhausted`)** and cannot be raised again until Green Energy regenerates back to `100%`.
- **`Shift` Skill**: **Shield-Wall Charge** — braces his Lion Shield in front (`charge` pose) and rams enemies for **`16 DMG`**.

## 3. Sylvara — High-Elf Archer (`100 HP`, Fastest `124 px/s`)

- **Reference-Extracted Sprite Sheet (`224×224` × 32 frames = `1792×896`)**: `assets/textures/player_pari.png` built from `assets/sprites/sylvara/sylvara_reference.png` (`scale = 0.165`, `LINEAR_WITH_MIPMAPS`, `GROUND_Y = 200`, blonde braided hair, elven tiara, feathered quiver, emerald-gold ranger armor, 4-directional idles & walks, `bow_draw` / radiant `bow_charge` / `bow_release`, `charge`, `hurt`, and `kneel -> fallen` `die`) + `960×192` (`5 × 192×192`) circular HUD portrait `assets/textures/portrait_pari.png`.
- **Signature Mechanic**: **Elven Recurve Bow** — swift `15 DMG` arrows (every 4th quick shot looses a 3-arrow fan); holding Attack visibly draws and charges a **`30 DMG` Piercing Great-Arrow**.
- **`Shift` Skill**: **Sylvan Gale Vault** — leaps in a swirl of emerald leaves (`0 DMG`), phases cleanly through enemies, slows nearby foes (`×0.55` speed for `1.8s`), and grants `+28%` Tailwind movement haste.

## 4. Velmira — Silver-Haired Hemomancer (`75 HP`)

- **Reference-Extracted Sprite Sheet (`224×224` × 40 frames = `1792×1120`)**: `assets/textures/player_shabnam.png` built from `assets/sprites/vampire/velmira_reference.png` (`scale = 0.165`, `LINEAR_WITH_MIPMAPS`, `GROUND_Y = 200`) + `960×192` (`5 × 192×192`) circular HUD portrait `assets/textures/portrait_shabnam.png`.
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
