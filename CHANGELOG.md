# Changelog

All notable changes to Solar Siege are recorded here.
Versions follow [Semantic Versioning](https://semver.org): MAJOR.MINOR.PATCH.

- **MAJOR**: big changes that break old save files or change how the game works.
- **MINOR**: new features and content (new levels, enemies, power-ups, multiplayer).
- **PATCH**: bug fixes and balance tweaks.

To release a new version: change `config/version` in `project.godot` (Project → Project Settings →
Application → Config → Version), the two version fields in the Windows export preset and `VERSION` in
`installer/solar-siege.nsi`, add a section below, then rebuild the installer. The in-game Changelog screen
reads this file, so new entries show up in the game automatically.

---

## [1.1.0] - 2026-10-20

### Fixed
- **Enemies now appear on every planet.** In the installed game the alien formations were missing, so each level was "won" instantly. Godot 4.7.2 was dropping the alien rows from the level files when it packed the game for Windows; level files are now exported as-is, and the game falls back to built-in formations if a level file ever loads without them.

### Added
- Ironite logo intro when the game starts (press any key to skip).
- **Credits** screen on the main menu: Solar Siege is a game by Ironite, plus credits for Godot Engine, the Inter typeface and NSIS.
- **Changelog** screen on the main menu, showing this list of changes in the game.
- The changelog is also installed next to the game.

### Changed
- Ironite is now the publisher and copyright holder in the game, the Windows file details and the installer.
- Main menu buttons are slightly smaller to make room for Credits and Changelog.

## [1.0.0] - 2026-10-17

First release, for Windows, by Ironite. Built with the Godot Engine 4.7.2. All graphics, sounds, music and fonts are asset files in `assets/`.

### Gameplay
- Classic top-down alien shooter: a marching alien formation steps down the screen as you fire up at it.
- 9 levels, one per world: Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, Neptune and Pluto.
- Difficulty climbs every planet: bigger formations, faster marching, more and faster enemy fire, and divers that break formation from Earth onward.
- 6 alien types: Drone, Crab, Squid (aimed shots), Beetle (2 hits, heavy shots), Wraith (3 hits, triple spread) and the large Cruiser warship (7+ hits, burst fire).
- Bonus saucer that crosses the top of the screen, takes 3 hits and always drops a power-up.
- 4 destructible shields per level that crumble piece by piece from both sides' fire.
- Final boss on Pluto: **Erebus, the Void Sovereign**, with 5 attack patterns (radial bursts, aimed volleys, laser sweeps, minion spawns and spirals) and an enraged second phase at half health.
- Easy, Normal and Hard difficulty (5, 3 and 3 ships).
- Score, per-level clear bonus and a saved high score.

### Power-ups
- Dual Lasers, Triple Spread, Rapid Fire, Speed Boost, Shield, Nova Bomb (stored, up to 3) and Extra Ship.
- Each power-up has its own pickup sound and an on-screen timer.

### Presentation
- HD 1920x1080 art, with sprites authored at 2x so they stay sharp up to 4K. Scales to any window size.
- A painted backdrop for every planet (Saturn's rings, Jupiter's Great Red Spot, Pluto's heart and more) with a parallax starfield.
- Particle explosions, glow effects, screen shake and hit flashes.
- 32 sound effects (lasers, explosions, power-ups, boss) and a looping music track for the menu, every planet and the boss.

### Menus and saving
- Main menu: Continue, New Game, Options, Multiplayer (Coming Soon) and Exit.
- The game auto-saves at the start of every planet; **Continue** appears whenever a save exists.
- Pause menu with Resume, Options, Save & Quit and Quit to Menu. The game pauses itself if the window loses focus.
- Options: master, music and effects volume; fullscreen; screen shake; FPS counter; reset high score.
- Keyboard, mouse (menus) and gamepad support.

### Platform
- Windows 64-bit, single-file game executable with a Windows installer (Start Menu and desktop shortcuts, uninstaller, no admin rights needed).
- Uses Godot's Compatibility renderer, which also runs on web, Android, iOS, macOS and Linux for future ports.
