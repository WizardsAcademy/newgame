# Agent Sprite Forge (vendored subset)

Vendored install of [0x0funky/agent-sprite-forge](https://github.com/0x0funky/agent-sprite-forge)
v0.6.0 (upstream commit `25203d03900b46b444bdd72a75768c33d1895ad6`), installed here with the
project's own installer (`tools/install_skills.py --apply`) and verified by its test suite and
`forge_doctor.py`.

This copy intentionally excludes upstream's 96 MB `src/` showcase media, the translation
READMEs and the 2026-10-06 validation record — everything functional is here.

## Layout

| Path | What it is |
|---|---|
| `skills/` | The 5 agent skills: `generate2dsprite`, `video2dsprite`, `generate2dmap`, `generate2dmedia`, `codeart2d` — each with `SKILL.md`, `references/` and self-contained `scripts/` |
| `skills/.agent-sprite-forge.install.json` | sha256 install manifest (source commit); used by `--check` drift reports |
| `shared/` | Canonical shared modules (the per-skill vendored copies are kept in sync by `tools/vendor_sync.py`) |
| `tools/` | `install_skills.py` (install/update/drift-check), `vendor_sync.py`, `check_links.py` |
| `tests/` | Upstream pytest suite (run from this folder) |
| `outputs/` | Scratch output dir (git-ignored) — doctor reports, generated art, plans |

`.gdignore` in this folder keeps Godot from importing the vendored fixtures and generated art.

## Using the skills

Each skill is self-documenting: read `skills/<name>/SKILL.md` first, then the `references/`
files it points to. Skill scripts are run with the repo venv python:

```bash
/home/user/newgame/.venv/bin/python skills/generate2dmedia/scripts/forge_doctor.py --host-tools <tools> --save outputs/doctor.json
/home/user/newgame/.venv/bin/python skills/generate2dsprite/scripts/master_still.py --help
/home/user/newgame/.venv/bin/python skills/video2dsprite/scripts/sprite_set.py --help
/home/user/newgame/.venv/bin/python skills/generate2dsprite/scripts/export_engine.py --help
```

Godot exports: `export_engine.py --target godot-spriteframes` writes a `SpriteFrames .tres`
plus an `AnimatedSprite2D .tscn` — drop the generated PNGs into `assets/textures/` and the
`.tres`/`.tscn` into `scenes/`/`assets/` of the game.

## Environment notes (this sandbox)

- `host_image` route is ready: the calling agent's own image generation/editing tools serve as
  the image route (record `art_source: host_image`).
- No API keys configured — set `OPENAI_API_KEY`, `GEMINI_API_KEY`, `XAI_API_KEY`, `ARK_API_KEY`
  or `FAL_KEY` (env or `~/.config/agent-sprite-forge/config.json`) to enable API image/video routes.
- No `ffmpeg` on PATH — video decode/encode and WebM/MP4 packaging are unavailable;
  PNG-frame pipelines, keying, registration, QA and Godot/Aseprite exports work without it.
- `PYTHONUTF8=1` is set for runs (upstream recommendation).

## Updating / drift check

```bash
git clone --depth 1 https://github.com/0x0funky/agent-sprite-forge /tmp/agent-sprite-forge
python3 /tmp/agent-sprite-forge/tools/install_skills.py --check --dest <this folder>/skills --source /tmp/agent-sprite-forge/skills
python3 /tmp/agent-sprite-forge/tools/install_skills.py --apply --dest <this folder>/skills
```

## Tests

```bash
cd <this folder>
/home/user/newgame/.venv/bin/python -m pytest -q          # full suite, serial (also runs the JS tests)
node --test tests/js/forge-runtime.test.mjs               # JS runtime tests, per file
node --test tests/js/fx-verify.test.mjs
node --test tests/js/map-runtime.test.mjs
```

Subset status vs upstream: the pytest suite passes (3127 passed / 96 skipped for missing ffmpeg,
at install time). Upstream's `node --test tests/js` directory form needs their exact CI setup —
run the files individually as above.

