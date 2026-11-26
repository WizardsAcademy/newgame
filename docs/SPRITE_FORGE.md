# Agent Sprite Forge — AI sprite pipeline

**Agent Sprite Forge v0.6.0** (upstream: <https://github.com/0x0funky/agent-sprite-forge>,
commit `25203d03900b46b444bdd72a75768c33d1895ad6`) is vendored at `tools/agent-sprite-forge/`
and installed alongside the game's own procedural sprite generators (`tools/make_*.py`).

It is an agent-skill pack: five self-documenting skills that an agent follows to produce
game-ready art, with deterministic Python scripts doing all gating, keying, palette and export
work. See `tools/agent-sprite-forge/README.md` and each `skills/<name>/SKILL.md`.

## The five skills

| Skill | Use for |
|---|---|
| `generate2dsprite` | Master stills, FX / icon / prop sheets, keying, palettes, Godot/Aseprite exports |
| `video2dsprite` | One approved master → a whole animated set: one image-to-video clip per action, keyed, registered, retimed, packaged |
| `generate2dmap` | Layered maps, tilesets, prop packs, parallax; exports to Godot `TileMapLayer`, Tiled, LDtk |
| `generate2dmedia` | The single media entry point (`route_media.py`): routes a request to API / CLI / host tools / codeart |
| `codeart2d` | Explicit-only last resort: palette-exact art drawn from code (PixelSpec, SVG, rigs, FX) |

## Using it in this repo

- Python: always the repo venv — `/home/user/newgame/.venv/bin/python` (numpy, Pillow, scipy,
  resvg-py installed; the game's `tools/make_*.py` generators run with the same venv).
- `tools/agent-sprite-forge/.gdignore` keeps Godot from importing vendored fixtures/outputs.
- Scratch output goes to `tools/agent-sprite-forge/outputs/` (git-ignored); finished, approved
  assets get copied into `assets/textures/` like any other game art and must then satisfy
  `docs/ART_CONTRACT.md` (run `python tools/measure_hero_sheets.py --strict`).

### Godot export example

```bash
cd tools/agent-sprite-forge
/home/user/newgame/.venv/bin/python skills/generate2dsprite/scripts/export_engine.py \
  --target godot-spriteframes --help   # writes SpriteFrames .tres + AnimatedSprite2D .tscn
```

## Capability status at install time (2026-11-26)

- ✅ Image route `host_image` (the agent's own image generation/editing tools)
- ✅ `codeart2d` fallback (resvg-py 0.5.0 for SVG)
- ❌ API routes — no `OPENAI_API_KEY` / `GEMINI_API_KEY` / `XAI_API_KEY` / `ARK_API_KEY` / `FAL_KEY` configured
- ❌ Video routes — no image-to-video capability and no `ffmpeg` on PATH (PNG-frame pipelines
  still work; WebM/MP4 packaging needs ffmpeg 5.1+)
- ✅ Upstream test suite green: 3127 passed / 96 skipped (ffmpeg- and video-only tests), JS
  runtime tests pass on node 22

Set an API key in the environment or `~/.config/agent-sprite-forge/config.json` to unlock the
API image/video routes; install ffmpeg 5.1+ to unlock clip processing and video packaging.

## Updating

```bash
git clone --depth 1 https://github.com/0x0funky/agent-sprite-forge /tmp/agent-sprite-forge
python3 /tmp/agent-sprite-forge/tools/install_skills.py --check --dest tools/agent-sprite-forge/skills --source /tmp/agent-sprite-forge/skills
python3 /tmp/agent-sprite-forge/tools/install_skills.py --apply --dest tools/agent-sprite-forge/skills
```

`--check` compares the installed skills against the sha256 manifest written at install time
(`tools/agent-sprite-forge/skills/.agent-sprite-forge.install.json`).
