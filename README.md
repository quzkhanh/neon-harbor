# Neon Harbor

A top-down 2D open-world action game set in Neon Harbor, a fictional port city at night.
You play Jay, a delivery driver who gets pulled into a fight between the broker Rosa and the Red Fangs gang
that runs the docks. Walk, shoot, steal cars, shop for guns, shake off the NHPD, and finish a three-mission story.

This is a vertical slice: one district, three missions, English and Vietnamese, Linux and Web builds.
Made with Godot 4.7.2 (GDScript, Compatibility renderer).

| | |
|---|---|
| ![City](screenshots/city_walk_en.png) | ![Combat](screenshots/combat_en.png) |
| ![Driving](screenshots/driving_en.png) | ![Wanted](screenshots/wanted3_vi.png) |
| ![Shop](screenshots/shop_en.png) | ![Mission complete](screenshots/mission_complete_vi.png) |

## Features

- One hand-authored district (80×60 tiles) loaded at runtime from an ASCII map into `TileMapLayer`s.
  Building roofs are auto-tiled from Kenney's wall tiles (47 edge/corner shapes in three colours).
- On foot: 8 weapons defined as data (`game/data/weapons.json`): pistol, SMG, shotgun, assault rifle,
  sniper rifle (pierces 3 targets), grenades, flamethrower (sets targets on fire), rocket launcher.
  Muzzle flash, ejected casings, tracers, screen shake, knockback and hit flash.
- Vehicles: motorbike, car, police car, a sports car for the heist. Arcade handling with speed-dependent steering,
  reverse, handbrake drift and skid marks. Crashes damage vehicles; a wrecked vehicle burns and explodes.
- A living city: pedestrians walk the sidewalks and flee from gunfire; traffic follows the directed lanes
  in the map, stops for obstacles and honks. Population is spawned and despawned off screen around the camera.
- Wanted level 1–3 stars. Cops arrive from off screen on foot and by car; stay out of their sight long enough and
  the stars go down.
- Gun shop with stat bars, ammo, armor and medkits; locked guns show which mission unlocks them.
- Death sends you to the hospital (lose 10% of your cash and all stars, keep your guns). No game over.
- Save in `user://save.json` (IndexedDB on the Web): money, guns, ammo, finished missions, settings.
- English and Vietnamese, switchable at runtime. All on-screen text comes from `game/i18n/strings.csv`.
- Ads are an API only in this stage (`Ads` autoload with a null provider and a debug provider). No real ad SDK.
- Touch controls (two virtual sticks + buttons) on touch screens.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move / drive | WASD or arrow keys | Left stick (RT accelerate, LT brake) |
| Aim | Mouse | Right stick |
| Fire | Left mouse button | RT |
| Get in / out of a vehicle | E | A |
| Handbrake | Space | B |
| Next / previous weapon | Mouse wheel, Q | RB / LB |
| Select weapon | 1–8 | |
| Reload | R | X |
| Pause | Esc or P | Start |

Walk into the gun shop door to open the shop. Walk into a pink marker to start a mission.

## Running

```bash
./play.sh                 # runs the Linux export if built, otherwise the project with Godot
./play.sh -- --ads=debug  # with the debug ad provider (simulated ad overlay)
./play.sh -- --touch      # force the touch controls on
./play-web.sh             # serves build/web on http://localhost:8060
```

Godot 4.7.2 is expected at `~/games/tools/godot/godot` (or set `GODOT=/path/to/godot`).

## Building

```bash
tools/checks/export.sh    # exports Linux (build/linux/NeonHarbor.x86_64) and Web (build/web/index.html), then tests both
tools/deploy_web.sh       # exports Web and pushes the build to the public GitHub Pages repo
```

Export templates for 4.7.2 must be installed. The Web build uses `variant/thread_support=false`, so it needs no
special HTTP headers. `include_filter` packs the non-resource files read at runtime (`maps/*.txt`, `data/*.json`).

## Checks

```bash
tools/checks/check_all.sh   # clean import, map validator, i18n check, font coverage, smoke, missions, ads,
                            # human-like playtest with a random-input phase, gameplay bot report, reverse tests
tools/checks/take_shots.sh  # real screenshots of every screen in English, Vietnamese and pseudolocalization
NH_HEADED=1 node tools/checks/web_play.mjs http://localhost:8060/index.html reference/shots perf     # Web FPS, full city
NH_HEADED=1 node tools/checks/web_play.mjs http://localhost:8060/index.html reference/shots persist  # save survives a reload
```

## Web performance and saves

- Measured on an Intel UHD 630 in Chrome with hardware acceleration: about 72 FPS with the city at its maximum
  (16 pedestrians, 10 cars, 3-star police). Without GPU acceleration the browser falls back to software rendering
  (about 15 FPS), so keep "Use graphics acceleration" on and check that `chrome://gpu` does not say "Software only".
- Serve the build with gzip or brotli: `index.wasm` is 37.7 MB raw, 9.6 MB gzipped.
- Progress is saved to `user://save.json`, which the browser keeps in IndexedDB for that site. It is written after
  missions, purchases, selling a car, settings changes, every 30 seconds while playing, and when the tab loses
  focus. Clearing site data or using a private window loses it.

## Map format

`game/maps/district1.txt`, one character per 64 px tile:

| Char | Meaning | Char | Meaning |
|---|---|---|---|
| `#` | building (solid, auto-tiled roof) | `T` | tree (solid) |
| `,` | sidewalk | `"` | grass / park |
| `~` | water (solid) | `.` | bare ground |
| `_` | wooden dock | `-` | parking lot |
| `x` | crate (solid) | `> < ^ v` | directed lane (traffic follows it) |
| `+` | intersection | `=` | crosswalk |
| `P` | player start | `S` | gun shop door |
| `H` | hospital | `G` | garage (sell cars, mission 3 drop-off) |
| `1 2 3` | mission start points | `r` | Red Fangs hideout (mission 2) |
| `d` | delivery point (mission 1) | `k` | heist target car (mission 3) |
| `c` | parked car | `m` | parked motorbike |

`tools/checks/validate_map.py` checks the format, that every important point is reachable on foot from `P`,
that the directed lane network is strongly connected (no dead ends for traffic), and that the shop, hospital and
garage sit next to a sidewalk.

## Project layout

```
game/
  data/          weapons, vehicles, missions, dialog speakers, wall tile table (JSON)
  i18n/          strings.csv (keys,en,vi)
  maps/          district1.txt
  scenes/        menu, city, shop, ending
  scripts/
    autoload/    Game (the only game state), I18n, Ads, Sfx, Music, Shot (scripted screenshots / perf run)
    ads/         AdProvider, NullAdProvider, DebugAdProvider
    actors/      Human, Player, Npc (Pedestrian, Cop, Gangster), Vehicle, Pickup
    combat/      Gun, Combat, Projectile, Fx
    core/        Tuning (all gameplay numbers), InputSetup, DataDB, SaveIO
    missions/    mission runner and the three missions
    screens/     menu, ending
    ui/          theme, HUD, minimap, shop, dialog, overlays, touch controls
    world/       City, CityMap, MapData, lanes, traffic and police drivers, population, camera
  tests/         font_coverage, smoke, missions, ads, bot_play
tools/
  assets/        scripts that generate the sounds, music, weapon icons and effect sprites, and copy Kenney assets
                 (copy_vendor.sh needs the original Kenney packs in vendor/, which is not in the repository)
  checks/        check_all.sh, validate_map.py, check_i18n.py, take_shots.sh, export.sh, web_play.mjs
```

All gameplay numbers live in `game/scripts/core/tuning.gd`. Adding a weapon or vehicle is a data change.
A new ad provider subclasses `AdProvider` and is registered in `Ads.PROVIDERS`; gameplay code only calls `Ads`.

## Credits

- Art, UI and UI sounds: [Kenney](https://kenney.nl) — Top-down Shooter, Racing Pack, UI Pack (CC0).
  Licenses copied in `game/assets/vendor/`.
- Fonts (SIL Open Font License 1.1, license files in `game/assets/fonts/`):
  [Be Vietnam Pro](https://github.com/bettergui/BeVietnamPro),
  [Noto Sans](https://github.com/notofonts/latin-greek-cyrillic),
  and a small subset of [Noto Sans Math](https://github.com/notofonts/math) (∞ and arrows only).
- Weapon icons, effect sprites, sound effects and music are generated by the scripts in `tools/assets/`.

All names, places and organisations in the game are fictional.
