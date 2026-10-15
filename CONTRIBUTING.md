# Contributing to Neon Harbor

Thanks for wanting to help! Bug reports, balance feedback, translations and pull requests are all welcome.

## Before you start

- Open an issue first for anything bigger than a small fix, so we can agree on the approach.
- Neon Harbor is **source-available, not open source**: the code is under the PolyForm Noncommercial License 1.0.0
  and the game content under CC BY-NC 4.0 (see `README.md`, "License"). Nobody may use it commercially.

## Contribution license

By submitting a contribution (a pull request, a patch, an issue with code or assets), you agree that:

1. it is your own work, or you have the right to submit it, and it contains nothing copied from other games;
2. it is licensed to everyone under the same terms as the rest of the project (PolyForm Noncommercial 1.0.0 for code,
   CC BY-NC 4.0 for content); and
3. you also grant the project maintainer (quzkhanh) a perpetual, worldwide, irrevocable, royalty-free license to use,
   modify, sublicense and distribute your contribution for any purpose, including commercially, as part of Neon Harbor.

If you cannot agree to point 3, please say so in your pull request instead of submitting it.

## Setup

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) (standard build, not .NET) and its export
   templates. Point `GODOT` at the binary, or put it at `~/games/tools/godot/godot`.
2. Import once: `godot --headless --path game --import`
3. Run: `./play.sh` (or open `game/project.godot` in the editor).

## Rules the checks enforce

- **No hard-coded player-facing text.** Every visible string is a key in `game/i18n/strings.csv` with English and
  Vietnamese columns. `tools/checks/check_i18n.py` fails on literal text and on unused keys.
- **Gameplay numbers live in one place** (`game/scripts/core/tuning.gd`, or a named constant at the top of the script
  that owns them). Colors live in `game/scripts/ui/palette.gd`.
- **Keep files short** and readable; split a script when it grows past roughly 200 lines.
- **No dead code**, no unused assets.
- **Fictional world only:** no real brands, real people, real cities, or anything taken from other crime games.
- Tests run with `-s` are compiled before autoloads exist: do not reference the game's `class_name`s in tests; use
  `load()` and duck typing (see `game/tests/harness.gd`).

## Before opening a pull request

```bash
tools/checks/check_all.sh   # must print CHECK_ALL: PASS
```

Add or extend a test under `game/tests/` for any behaviour you change, and make sure it fails without your change.
CI runs the same checks on Linux, Windows and macOS for every pull request.
