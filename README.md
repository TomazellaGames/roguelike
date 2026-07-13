# Roguelike

**v1.0.0** — A really Rogue-Like game — ASCII dungeon crawling built with [Godot 4.7](https://godotengine.org/).

You descend one procedurally generated floor at a time, fighting monsters, grabbing gear and gold, and avoiding traps. Escape alive from floor 21 to win, and see how your run scores.

## Gameplay

- **The goal**: reach floor 21 and escape. Doing so ends the run with a victory screen and a score based on your remaining HP, gold collected, traps triggered, and pickups used.
- **Combat**: move into a monster to attack it. Weapons and armor wear down with use and break; the player has a small chance to land a critical hit.
- **Monsters**: rat and goblin throughout, spider from floor 6 (stays near its spawn room), ogre from floor 9 (attacks at half speed), and ghost from floor 15 (always 1 HP/1 atk, moves 2 tiles a turn, passes through walls and doors, immune to traps, and dodges half of all non-critical hits).
- **Gear & potions**: weapon and armor pickups appear every floor; a Potion of Vitality (permanent +HP/attack/defense/crit) appears every 4th floor.
- **Wheel of Fortune** (`%`): appears every 7th floor. Spinning it rolls one of twelve outcomes, from instant death or losing your gear to full heals, bonus monster kills, or a free upgrade.
- **Traps** (`^`): scattered through most floors (up to 3). From floor 11 on, one extra hidden trap per floor stays invisible until you get close, or until you step on it.
- **Doors & switch**: from floor 11 on, the stairs room is sealed behind doors; a hidden switch (`\`) elsewhere on the floor opens them.
- **Toll**: every 10th floor charges a gold toll to proceed — paying it also fully heals you; failing to pay ends the run.

## Requirements

- [Godot Engine 4.7](https://godotengine.org/download) (GL Compatibility renderer)
- Git

## Getting the project (fork & clone)

1. **Fork the repository** on GitHub by clicking the "Fork" button on the project page. This gives you your own copy of the repo under your account.
2. **Clone your fork** to your machine:

   ```bash
   git clone https://github.com/<your-username>/roguelike.git
   cd roguelike
   ```

3. **Add the original repo as an upstream remote** so you can pull in future changes:

   ```bash
   git remote add upstream https://github.com/<original-owner>/roguelike.git
   ```

4. **Open the project in Godot**: launch Godot 4.7, choose "Import", and select the `project.godot` file at the root of the repo.
5. **Run the game** with F5 (or the Play button). The main scene is `scenes/main.tscn`.

## Working on changes

1. Create a branch for your change:

   ```bash
   git checkout -b my-feature
   ```

2. Make your changes in Godot / your editor of choice, and test them by running the game (F5).
3. Commit and push to your fork:

   ```bash
   git add .
   git commit -m "Describe your change"
   git push origin my-feature
   ```

4. Open a Pull Request from your fork's branch back to the original repository.
5. To keep your fork up to date with upstream changes:

   ```bash
   git fetch upstream
   git checkout main
   git merge upstream/main
   ```

## Project structure

```
scenes/            Godot scenes (main.tscn is the entry point)
scripts/
  main.gd          Top-level game loop: input handling, level generation, HUD wiring
  map/              Dungeon grid, tile types, and room/corridor generation
  entities/         Player/monster entity data and item/monster definitions
  systems/          Turn management, movement, combat, monster AI, screenshots
  rendering/        ASCII grid renderer
  ui/               HUD (stats, message log, mobile controls, game-over screen)
addons/funplay_mcp/  Editor plugin exposing an MCP server for AI-assisted editing
```

## Controls

- Move: Arrow keys, WASD, or vim keys (H/J/K/L)
- Hold a direction key briefly before releasing to sprint two tiles at the cost of 1 HP
- On-screen buttons are available for touch/mobile play
- On death or victory: restart instantly, or share/download a screenshot of the result

## Credits

Made by [Tomazella Games](https://tomazellagames.itch.io/), with [Claude Code](https://claude.com/claude-code).

## License

MIT — see [LICENSE](LICENSE).
