# Solar Siege

**Version 1.1.0** · A game by **Ironite** · A modern HD take on the classic arcade alien shooter, fought across all nine worlds of the solar system. Made with the **Godot Engine 4.7.2**.

Fly a lone fighter from Mercury to Pluto, blast marching alien formations, hide behind crumbling shields, grab power-ups and take down the mothership boss **Erebus** at the edge of the system.

---

## Install and play

Run **`Solar Siege Setup 1.1.0.exe`**. It installs to your user folder (no admin rights needed) and adds Start Menu and desktop shortcuts plus an uninstaller (Settings → Apps).

> Windows SmartScreen may warn about an unknown publisher because the installer isn't code-signed. Click **More info → Run anyway**.

Saves and settings live in `%APPDATA%\Solar Siege`. Uninstalling keeps them.

## How to play

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | ← → or A D | Left stick / D-pad |
| Fire | Space (or Z) | A |
| Nova Bomb | B or Shift | B |
| Pause | Esc or P | Start |
| Menus | Arrows + Enter, or the mouse | D-pad + A, B to go back |

**Saving:** the game saves automatically at the start of each planet. **Continue** on the main menu resumes from there. *Save & Quit* in the pause menu does the same and returns to the menu.

### Power-ups

Destroyed aliens sometimes drop a capsule. The bonus saucer always drops one, and Cruisers drop one half the time.

| Power-up | Effect |
|---|---|
| Dual Lasers | Two parallel lasers for 15 s |
| Triple Spread | Three-way fan of lasers for 15 s (from Earth onward) |
| Rapid Fire | Double fire rate for 12 s |
| Speed Boost | Much faster ship for 12 s |
| Shield | Energy bubble that blocks everything for 10 s |
| Nova Bomb | Stores a bomb (max 3). Press B for a shockwave that wipes enemy fire and damages everything |
| Extra Ship | +1 life |

### The planets

| # | Planet | What's new |
|---|---|---|
| 1 | Mercury | Drones, Crabs and Squids |
| 2 | Venus | Wider formation, faster fire |
| 3 | Earth | Cruiser warships join the fleet; aliens start diving at you |
| 4 | Mars | Armoured Beetles |
| 5 | Jupiter | Bigger, faster fleet |
| 6 | Saturn | Wraiths with triple-spread shots |
| 7 | Uranus | Cruisers and Wraiths together |
| 8 | Neptune | Elite fleet, heavy fire |
| 9 | Pluto | Final fleet, then the boss **Erebus, the Void Sovereign** |

---

## Working on the game

1. Install **Godot 4.7.2** (standard version, not .NET) from https://godotengine.org/download/windows.
2. Open Godot, click **Import**, and pick `project.godot` in this folder.
3. Press **F5** to play.

### How it's built

| Part | Choice | Why |
|---|---|---|
| Engine | **Godot 4.7.2** | Free and open source, exports to Windows, macOS, Linux, Android, iOS and Web from one project |
| Language | **GDScript** | Godot's built-in scripting language; quick to read and change |
| Renderer | Compatibility (OpenGL) | Runs on older PCs, and is the renderer used for web and mobile exports |
| Graphics | **PNG assets** in `assets/` | Every ship, alien, planet, shield, effect and UI piece is an image file you can open or replace |
| Audio | **WAV assets** in `assets/audio` | 32 sound effects and 11 looping music tracks. Godot compresses them (QOA) when exporting |
| Fonts | Inter (`assets/fonts`) | Free font (SIL Open Font License), bundled so text looks the same on every PC |
| Installer | NSIS 3 | Standard Windows installer with uninstaller |

### Project layout

```
solar-siege-godot/
├─ project.godot              Godot project (window size, input map, version number)
├─ scenes/
│  ├─ intro.tscn              Ironite logo intro (first scene)
│  ├─ menu.tscn               main menu
│  └─ play.tscn               gameplay (layers for world, HUD and banners)
├─ scripts/
│  ├─ global.gd               settings, save game, high score, scene switching (autoload)
│  ├─ audio.gd                sound effects and music player (autoload)
│  ├─ play.gd                 gameplay: formation, shields, power-ups, saucer, boss, HUD
│  ├─ menu.gd                 main menu
│  ├─ fx.gd                   explosions, sparks, smoke, floating score text
│  ├─ stars.gd                parallax starfield
│  ├─ level_data.gd           the LevelData resource type
│  ├─ ui.gd                   fonts, colours and text helpers
│  └─ ui/                     buttons, dialogs, options screen, credits/changelog screen
├─ data/levels/               01_mercury.tres … 09_pluto.tres: one file per planet
├─ assets/
│  ├─ sprites/                player, aliens (per planet tint), saucer, boss, shots, power-ups, effects, HUD icons
│  ├─ backgrounds/            one 1920x1080 backdrop per planet + the menu
│  ├─ bunkers/                shield textures per planet
│  ├─ ui/                     title logo, Ironite logo, buttons, panels, sliders, bars (theme.tres uses these)
│  ├─ audio/sfx, audio/music  sound effects and music loops
│  └─ fonts/                  Inter font files and licence
├─ installer/                 NSIS installer script and licence text
├─ tools/                     setup_project.gd (regenerates input map, theme, levels), autotest.gd
├─ build-windows.bat          one-click export + installer build on Windows
└─ CHANGELOG.md
```

### Tuning levels

Open any file in `data/levels/` in Godot. The Inspector shows the planet's alien rows, columns, formation `speed`, `fire_rate`, `bullet_speed`, `dive_chance`, saucer timing, backdrop, shield texture and music. Difficulty multipliers (lives, speed, fire rate, boss health, drop rate) are in `scripts/global.gd` → `DIFFICULTY`.

### Replacing art and sound

Every graphic and sound is a plain file. To restyle the game, replace a file with your own at the **same name and pixel size** and Godot picks it up automatically. Sprites are drawn at twice their on-screen size (for example `assets/sprites/player.png` is 280x248 and shows at 140x124), so keep new art at 2x.

### Build the Windows installer

1. In Godot: **Editor → Manage Export Templates → Download and Install** (once).
2. Install **NSIS 3** from https://nsis.sourceforge.io/Download (once).
3. Double-click **`build-windows.bat`**. If Godot isn't at `C:\Godot\Godot_v4.7.2-stable_win64.exe`, edit the path at the top of the file first.

The installer appears in `build\Solar Siege Setup 1.1.0.exe`.

### Releasing a new version

1. Change the version in **Project → Project Settings → Application → Config → Version**.
2. In **Project → Export → Windows Desktop**, update *File Version* and *Product Version*.
3. Change `!define VERSION` in `installer/solar-siege.nsi`.
4. Add a section to `CHANGELOG.md` and rebuild.

### Porting later

Godot exports the same project to other platforms from **Project → Export → Add…**:

- **Web:** export to HTML5 and upload the folder to any web host.
- **macOS / Linux:** add the preset and export (macOS signing needs a Mac and an Apple developer account).
- **Android / iOS:** add the preset. The main addition is on-screen touch controls: gameplay reads the input actions `move_left`, `move_right`, `fire`, `bomb` and `pause`, so touch buttons just need to press those same actions.
- **Multiplayer:** the menu entry is already in place (`scripts/menu.gd`) and currently shows "Coming Soon".

### A note on level files

`project.godot` sets **Export → Convert Text Resources to Binary** to off. Godot 4.7.2 drops the alien rows from the level files when it converts them, which made every level start empty in v1.0.0. Leave this setting off.

---

© 2026 Ironite. All rights reserved.
