# Christ Fallow — Stone Age 3D Civilization & Tactical Combat (Godot 4)

Awaken enlightened in a primeval Stone Age valley. Choose your tribal bloodline, gather wandering men and women, light your first Campfire, construct a living village, craft Stone Age weaponry, worship a Patron Deity, negotiate or war with rival AI tribes, capture and enlighten feral Nomadic Cavemen, and hunt prehistoric megafauna to unite the valley.

## How to Open & Play
1. Install or open **Godot Engine 4.3** (Standard GDScript version).
2. Click **Import** in the Godot Project Manager and select `project.godot` inside this folder (`Christ Fallow`).
3. Click **Run Project (`F5`)** to open the Christ Fallow title screen. Choose **Start**, then **New Game** to set up your tribe or **Continue** to resume your campaign save.

## Controls
| Action | Key / Input |
| :--- | :--- |
| Move Leader | `W` `A` `S` `D` / Arrow Keys |
| Sprint / Dodge Dash | `Shift` (Hold) / `Space` |
| Camera Orbit / Zoom (3rd-Person ↔ Overhead) | Right-Click Drag / Mouse Wheel |
| Melee Cleave / Throw Javelin | Left-Click / `F` (or Quick Right-Click) |
| Divine Blessing / Leader Warcry | `Q` |
| Recruit Wanderers / Harvest Resource / Help Build | `E` |
| Inspect Friendly / Wounded Tribesman | Left-Click near unit |
| Base Building Menu (3D Blueprints) | `B` (`T` to rotate, Left-Click to place, `Shift` + Left-Click to keep placing, `Esc`/RMB cancel) |
| Colony Roster, Roles & Crafting | `C` |
| Tribal Religion (Patron God & Tenets) | `R` (outside build mode) |
| Diplomacy & Rival Leaders | `V` |
| Select Warband Squad | `1` All, `2` Spearmen, `3` Knife-Raiders, `4` Archers, `5` Club Brutes, `6` Javelineers |
| Tactical Orders | `F1` Follow, `F2` Hold, `F3` Charge, `F4` Retreat, `F5` Fire-at-Will, `F6` Guard Base |
| Emergency Civilian Warhorn | `H` |
| Tribal Command / Pause / Quick Save / Quick Load | `Tab` or `M` / `P` or `Esc` / `F9` / `F10` |

## Core Systems Implemented
- **6 Playable Races + Feral Cave-Kin**: Tall Folk (*Goliath*), Small Folk (*Swift-Kin*), Lean Folk (*Stalker*), Hardy Folk (*Crag-Born*), Ash-Born (*Ember-Kin*), Fen-Tidal (*Mire-Folk*), and *Feral Cave-Kin* with distinct anatomical models, racial features, combat/gathering stats, and articulated damage, attack & death animations.
- **Early-Game Peace Buffer, Awakening Guide & Villager Self-Defense**: 3m30s raid-free Peace Buffer before bandits/raiders attack, optional 5-step guided Awakening tutorial, quick-access HUD drawer buttons, `[E]` manual construction assist & floating yield popups, and weak bare-hand punches (`UNARMED_PUNCH`) when unarmed villagers are cornered or defending camp.
- **Strictly Stone Age Economy & Crafting**: Gather Food, Wood, Stone, Flint, Hide, Bone, and Faith. Craft Spears, Flint Knives, Bows, Bone War-Clubs, Barbed Javelins, and Hide/Bone Armor across 3 Stone Age quality tiers (*Crude Wood/Stone → Knapped Flint → Obsidian & Carved Bone*).
- **Day / Dusk / Night Schedule**: Colonists physically gather/build/craft by day, eat and heal around the Campfire at dusk, and sleep/reproduce inside Sleeping Huts at night while Watchtowers guard against raiders.
- **4 Simulated Rival Tribes + Nomadic Cavemen**: *Crag-Goliaths* (Warlord AI), *Sun-Stalkers* (Zealot AI), *Swift-Fang Clan* (Opportunist AI), *Earth-Root Tribe* (Guardian AI), and feral *Nomadic Cavemen* raiding from wilderness bone-caves who can be captured and enlightened.
- **4-Stage Building Destruction & Hostile-Only Combat Health Bars**. Completed buildings show damage at 66% HP, become critical at 33%, and collapse at 0%. Critical buildings emit smoke and embers. Ruins lose collision. Completed building health bars appear after hostile damage, and blueprints display construction progress.
- **Headless Blender Asset Pipeline & PSX Skinned Shaders**: Automated headless Blender 4.5 LTS scripts (`tools/assets/`) batch-generate `.glb` assets rendered with custom PSX shaders. Live campaigns use imported GLBs for `2/11` multi-stage buildings (`Sleeping Hut`, `Log Palisade`), `4` valley scenery props, and `2/6` wildlife (`Tusked Boar`, `Sabertooth`), while default humanoids use procedural low-poly rigs and skinned 17-bone character GLBs run via opt-in launch trials (`--skinned-tribesman-trial`, `--crag-born-trial`).
- **Prehistoric Wildlife & Megafauna**: Deer, Wild Boar, Dire Wolves, Sabertooth Tigers, and Boss Woolly Mammoths & Giant Cave Bears.

## Project guides

- [Agent guide and codebase map](AGENTS.md)
- [Master roadmap and stabilization plan](docs/ROADMAP.md)
- [Codebase refactor plan](docs/REFACTOR.md) and [future development](docs/FUTURE.md)
- [Asset pipeline](tools/assets/README.md) and [asset rollout](tools/assets/OVERHAUL.md)
