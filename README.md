# Neon Harbor

A top-down 2D open-world action game set in Neon Harbor, a fictional port city at night.
You play Jay, a delivery driver who gets pulled into a fight between the broker Rosa and the Red Fangs gang
that runs the docks. Walk, shoot, steal cars, shop for guns, shake off the NHPD, and finish a three-mission story.

Nine districts on both sides of a river, three story missions, English and Vietnamese, Linux and Web builds.
Made with Godot 4.7.2 (GDScript, Compatibility renderer).

**Play in the browser:** https://quzkhanh.github.io/neon-harbor-web/ (Web build only; deployed with `tools/deploy_web.sh`).

| | |
|---|---|
| ![City](screenshots/city_walk_en.png) | ![Combat](screenshots/combat_en.png) |
| ![Driving](screenshots/driving_en.png) | ![Wanted](screenshots/wanted3_vi.png) |
| ![Shop](screenshots/shop_en.png) | ![Mission complete](screenshots/mission_complete_vi.png) |
| ![City map](screenshots/map_vi.png) | ![Takedowns](screenshots/corpses_en.png) |

## Features

- A 238×186-tile city (nine times the size of the first district) loaded at runtime from an ASCII map
  into `TileMapLayer`s: nine districts (Hillside, Downtown, Uptown Park, Night Market, Midtown, Eastside, Rail Yard,
  The Harbor, Marina Beach), a river crossed by four bridges, and a waterfront. The district name appears when you
  enter it. Building roofs are auto-tiled from Kenney's wall tiles (47 edge/corner shapes in three colours);
  neon strips glow under the eaves and market stalls have canopies you can walk under. Buildings stand out like in
  GTA 2: wall and roof layers scale around the camera centre, so roofs lean away from you and show their walls
  (two building heights), roofs are tinted apart from the road, and buildings, trees and crates cast drop shadows.
- On foot: 8 weapons defined as data (`game/data/weapons.json`): pistol, SMG, shotgun, assault rifle,
  sniper rifle (pierces 3 targets), grenades, flamethrower (sets targets on fire), rocket launcher.
  Muzzle flash, ejected casings, tracers, screen shake, knockback and hit flash. Wounded people show a small health
  bar; a takedown is confirmed with a red X and a sound, and the body stays dark on a spreading pool of blood
  (people knocked down by a car get back up instead).
- Vehicles: motorbike, car, police car, a sports car for the heist. Two control schemes (Settings):
  **Arcade** (default) drives like walking — the car turns toward the direction you press, brakes for corners, and
  backs around if you press the opposite way; **Classic** is accelerate/brake plus turning the car body.
  Handbrake drift and skid marks. Crashes damage vehicles; a wrecked vehicle burns and explodes.
- A living city: pedestrians walk the sidewalks and flee from gunfire; traffic follows the directed lanes
  in the map, stops for obstacles and honks. Population is spawned and despawned off screen around the camera.
- Wanted level 1–3 stars. Cops arrive from off screen on foot and by car; stay out of their sight long enough and
  the stars go down, or drive into a respray shop and pay to lose them at once.
- Gun shop with stat bars, armor and medkits (every gun has unlimited ammo, you only reload); locked guns show which mission unlocks them.
- Mission guidance: a GPS route on the minimap (by road when driving) and an arrow at the screen edge.
  Full city map on M / Tab with a legend; gun shops, hospitals, respray shops and the garage each have their own
  icon, and the minimap keeps the nearest one of each pinned to its edge.
- Forgiving difficulty: health regenerates up to 60 after a few seconds without damage, vehicles you drive take
  half crash damage, Rosa hands you an SMG and body armor for mission 2, and a failed mission offers an instant
  retry from its start point.
- Healing: medkits and armor lying around the city (parks, plazas, the stadium, outside the Red Fangs hideout;
  they come back a minute after you take them, and you only pick them up when you need them), small medkits
  dropped by gang members and cops, free full healing when you walk into a hospital door, and medkits in shops.
- Beginner guide on the first game: walk, shoot, open the map, start the first mission, get on the bike, drive,
  where to buy guns. Each step clears when you do it; optional steps time out, and doing something later in the
  list skips ahead. It can be turned back on in Settings.
- When you go down you choose: retry the mission you were on (free), get up right there (20% of your cash,
  wanted level kept, a few seconds of protection), or wake up at the nearest of five hospitals (10%, stars cleared).
  You keep your guns. No game over.
- Save in `user://save.json` (IndexedDB on the Web): money, guns, loaded rounds, finished missions, settings.
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
| City map | M or Tab | Back |
| Pause | Esc or P | Start |

Walk into a gun shop door to open the shop. Walk into a pink marker to start a mission.
With the Classic driving scheme, W/S (or RT/LT) accelerate and brake and A/D turn the car.

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

- Measured on an Intel UHD 630 in Chrome with hardware acceleration: 75 FPS on average (minimum 74) with the
  city at its maximum (pedestrians, traffic and parked vehicles, 3-star police: 54 vehicles, 14 cops). Without GPU acceleration the browser falls back to software rendering
  (about 15 FPS), so keep "Use graphics acceleration" on and check that `chrome://gpu` does not say "Software only".
- Serve the build with gzip or brotli: `index.wasm` is 37.7 MB raw, 9.6 MB gzipped.
- Progress is saved to `user://save.json`, which the browser keeps in IndexedDB for that site. It is written after
  missions, purchases, selling a car, settings changes, every 30 seconds while playing, and when the tab loses
  focus. Clearing site data or using a private window loses it.

## Map format

`game/maps/city.txt`, one character per 64 px tile. It is built by `tools/maps/build_city.py` from the
hand-drawn harbor district (`tools/maps/harbor.txt`, where the missions take place) plus block templates for the
other districts, with a fixed seed so the output never changes; the script also writes `game/data/districts.json`.

| Char | Meaning | Char | Meaning |
|---|---|---|---|
| `#` | building (solid, auto-tiled roof) | `T` | tree (solid) |
| `,` | sidewalk | `"` | grass / park |
| `~` | water (solid) | `.` | bare ground |
| `_` | wooden dock | `-` | parking lot |
| `x` | crate (solid) | `> < ^ v` | directed lane (traffic follows it) |
| `+` | intersection | `=` | crosswalk |
| `:` | plaza | `M` | market stall (plaza with a canopy) |
| `P` | player start | `S` | gun shop door (one or more) |
| `H` | hospital (one or more) | `G` | garage (sell cars, mission 3 drop-off) |
| `R` | respray shop (one or more) | `b` | parked motorbike |
| `h` | medkit spot (respawns) | `a` | armor spot (respawns) |
| `1 2 3` | mission start points | `r` | Red Fangs hideout (mission 2) |
| `d` | delivery point (mission 1) | `k` | heist target car (mission 3) |
| `c` | parked car | `m` | the mission 1 motorbike |

`tools/checks/validate_map.py` checks the format, that every important point is reachable on foot from `P`,
that the directed lane network is strongly connected (no dead ends for traffic), and that shops, hospitals,
the garage and respray shops sit next to a sidewalk.

## Project layout

```
game/
  data/          weapons, vehicles, missions, districts, dialog speakers, wall tile table (JSON)
  i18n/          strings.csv (keys,en,vi)
  maps/          city.txt (generated, see Map format)
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
  maps/          build_city.py and the hand-drawn harbor.txt
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
