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
| Tribal Command / Pause / Quick Save / Quick Load | `Tab` / `P` or `Esc` / `F9` / `F10` |
| World Map | `M` or click Valley Radar. Right-drag to pan, scroll to zoom, and left-click to set a waypoint. |
| Negotiate with a rival leader | Approach their nameplate and press `E`. |
| Tame, mount, or dismount | Press `E` near a wild Deer or Tusked Boar to tame it after building an Animal Pen. Press `E` near a trained boar to mount, then `E` again to dismount. |

## Core Systems Implemented
- **6 Playable Races + Feral Cave-Kin**: Tall Folk (*Goliath*), Small Folk (*Swift-Kin*), Lean Folk (*Stalker*), Hardy Folk (*Crag-Born*), Ash-Born (*Ember-Kin*), Fen-Tidal (*Mire-Folk*), and *Feral Cave-Kin* with distinct anatomical models, racial features, combat/gathering stats, and articulated damage, attack & death animations.
- **760×760 m Valley**. New campaigns start in a larger valley with five river fords, four distant rival camps, and resources near every starting camp. Older saves open in the classic 380 m valley. The full-screen World Map shows camps, caves, fords, and the active Awakening objective. Waypoints also appear on Valley Radar.
- **Tribal Diplomacy**. Visit a named leader to offer gifts, negotiate peace, or propose an alliance. Peace protects both tribes through two day changes. Tributaries send food and flint from their own stockpiles each day.
- **Farming & Herds**. Build a Crop Field or Animal Pen from the Settlement tab in `B`. Assign a Farmer in `C` → Workforce or Roster to plant, tend, harvest, and haul food. Tamed animals walk back to their pen. Fed pairs can breed, and an adult Tusked Boar can be ridden after two feedings. Use `C` → Fields & Herds to check crop growth and pen capacity or harvest surplus livestock.
- **Early-Game Peace Buffer, Awakening Guide & Villager Self-Defense**: 3m30s raid-free Peace Buffer before bandits/raiders attack, interactive 5-step Awakening tutorial (3D objective beacon, `[E]` proximity prompts, HUD checklists/highlights, `Build` recommendations, and Valley Radar pulse), `[E]` manual construction assist & floating yield popups, and weak bare-hand punches (`UNARMED_PUNCH`) when unarmed villagers are cornered or defending camp.
- **Strictly Stone Age Economy & Crafting**: Gather Food, Wood, Stone, Flint, Hide, Bone, and Faith. Craft Spears, Flint Knives, Bows, Bone War-Clubs, Barbed Javelins, and Hide/Bone Armor across 3 Stone Age quality tiers (*Crude Wood/Stone → Knapped Flint → Obsidian & Carved Bone*).
- **Day / Dusk / Night Schedule**: Colonists physically gather/build/craft by day, eat and heal around the Campfire at dusk, and sleep/reproduce inside Sleeping Huts at night while Watchtowers guard against raiders.
- **4 Simulated Rival Tribes + Nomadic Cavemen**: *Crag-Goliaths* (Warlord AI), *Sun-Stalkers* (Zealot AI), *Swift-Fang Clan* (Opportunist AI), *Earth-Root Tribe* (Guardian AI), and feral *Nomadic Cavemen* raiding from wilderness bone-caves who can be captured and enlightened.
- **4-Stage Building Destruction & Hostile-Only Combat Health Bars**. Completed buildings show damage at 66% HP, become critical at 33%, and collapse at 0%. Critical buildings emit smoke and embers. Ruins lose collision. Completed building health bars appear after hostile damage, and blueprints display construction progress.
- **Blender Assets & PSX Skinned Shaders**. Goliath, Crag-Born, Swift-Kin, Stalker, and Ash-Born Foragers and adult Spearmen use imported 17-bone rigs. Each of these lineages has two men, two women, a boy, and a girl. Launch with `--procedural-roster` for procedural roster models or `--skinned-tribesman-trial` for the imported player leader rig. The Storage Mound and Watchtower use Reed Granary and Ridge Signal Tower models. Armored Slateback Boar and riverbank Reedjaw join Tusked Boar and Sabertooth as imported wildlife. [Asset catalog](tools/assets/CATALOG.md)
- **Prehistoric Wildlife & Megafauna**: Deer, Wild Boar, Dire Wolves, Sabertooth Tigers, and Boss Woolly Mammoths & Giant Cave Bears.

## Project guides

- [Agent guide and codebase map](AGENTS.md)
- [Master roadmap and stabilization plan](docs/ROADMAP.md)
- [Codebase refactor plan](docs/REFACTOR.md) and [future development](docs/FUTURE.md)
- [Asset pipeline](tools/assets/README.md) and [asset rollout](tools/assets/OVERHAUL.md)
