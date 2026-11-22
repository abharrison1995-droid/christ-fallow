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
| Camera Orbit / First-Person Look / Zoom | Right-Click Drag / Mouse Wheel |
| First-Person POV Toggle | `Z` or the HUD POV button. Scroll up at close zoom to enter and scroll down to exit. |
| Melee Cleave / Throw Javelin | Left-Click / `F` (or Quick Right-Click) |
| Divine Blessing / Leader Warcry | `Q` |
| Recruit Wanderers / Harvest Resource / Help Build | `E` |
| Inspect Friendly / Wounded Tribesman | Left-Click near the unit in third person. In first person, aim at the unit and click when no enemy is in the swing. |
| Base Building Menu (3D Blueprints) | `B` (`T` to rotate, Left-Click to place, `Shift` + Left-Click to keep placing, `Esc`/RMB cancel) |
| Colony Roster, Roles, Crafting & Arena | `C` |
| Tribal Perks & Skills | `K` |
| Tribal Religion (Patron God & Tenets) | `R` (outside build mode) |
| Diplomacy & Rival Leaders | `V` |
| Select Warband Squad | `1` All, `2` Spearmen, `3` Knife-Raiders, `4` Archers, `5` Club Brutes, `6` Javelineers |
| Tactical Orders | `F1` Follow, `F2` Hold, `F3` Charge, `F4` Retreat, `F5` Fire-at-Will, `F6` Guard Base |
| Emergency Civilian Warhorn | `H` |
| Tribal Command / Pause / Quick Save / Quick Load | `Tab` / `P` or `Esc` / `F9` / `F10` |
| World Map | `M` or click Valley Radar. Right-drag to pan, scroll to zoom, and left-click to set a waypoint. |
| Negotiate with a rival leader | Approach their nameplate and press `E`. |
| Open Blood-Pit Arena | Approach a constructed Blood-Pit Arena and press `E` (or open `C` → Arena). |
| Tame, mount, or dismount | Build an Animal Pen, then press `E` near a wild Deer, Tusked Boar, or Woolly Mammoth to offer Food. Press `E` near a trained adult to mount, then `E` again to dismount. |
| Audio Volume Sliders | Title or Pause → **Settings** → **Audio** (`Master`, `Music`, `SFX`, `Title Ambience`) |

## Core Systems Implemented
- **6 Playable Races + Feral Cave-Kin**: Tall Folk (*Goliath*), Small Folk (*Swift-Kin*), Lean Folk (*Stalker*), Hardy Folk (*Crag-Born*), Ash-Born (*Ember-Kin*), Fen-Tidal (*Mire-Folk*), and *Feral Cave-Kin* with distinct anatomical models, racial features, combat/gathering stats, and articulated damage, attack & death animations.
- **760×760 m Valley**. New campaigns start in a larger valley with five river fords, four distant rival camps, and resources near every starting camp. Older saves open in the classic 380 m valley. The full-screen World Map shows camps, caves, fords, and the active Awakening objective. Waypoints also appear on Valley Radar.
- **Tribal Diplomacy**. Visit a named leader to offer gifts, negotiate peace, or propose an alliance. Peace protects both tribes through two day changes. Tributaries send food and flint from their own stockpiles each day.
- **Farming & Herds**. Build a Crop Field or Animal Pen from the Settlement tab in `B`. Assign a Farmer in `C` → Workforce or Roster to plant, tend, harvest, and haul food. Tamed animals walk back to their pen, where fed pairs can breed. Use `C` → Fields & Herds to check crop growth, pen capacity, and trained mounts, or to harvest surplus livestock.
- **Mounts**. Two pen feedings train an adult to ride. The Woolly Mammoth moves 15% faster than the leader's walk, the Tusked Boar 32% faster, and the Deer 58% faster. Save and load keep the rider mounted. Dismount to use the leader's combat abilities.
- **Tribal Leveling, Perks & Skills (`K`)**. Earn XP from recruiting, building, harvesting, crafting, hunting, taming, tech tiers, and alliances to advance from Level 1 to 12. Spend Skill Points across three branches (*Masonry & Settlement*, *Chieftain & Lineage Might*, and *Kinship & Warband Mastery* — 12 multi-rank perks) to unlock advanced buildings (`Storage Mound`, `Crop Field`, `Animal Pen`, `Healing Shack`, `Standing-Stone Gate`, `Lookout Watchtower`, `Tribal Barracks`), hire Nomad Villagers in `C` Colony, train warriors past Rank V up to Rank VIII, and strengthen leader and tribe stats. Settled rival tribes also level up and unlock personality-aligned perks.
- **Early-Game Peace Buffer, Awakening Guide & Villager Self-Defense**: 3m30s raid-free Peace Buffer before bandits/raiders attack, interactive 5-step Awakening tutorial (3D objective beacon, 3D directional ground pointer, `[E]` & `[LMB] Place Here` proximity prompts, HUD checklists/highlights, `Build` & `Colony` in-drawer action highlights, and Valley Radar pulse), `[E]` manual construction assist & floating yield popups, and weak bare-hand punches (`UNARMED_PUNCH`) when unarmed villagers are cornered or defending camp.
- **Strictly Stone Age Economy, Crafting & Custom Loadouts**: Gather Food, Wood, Stone, Flint, Hide, Bone, and Faith. Craft Spears, Flint Knives, Hunting Bows, Bone War-Clubs, Barbed Javelins, Obsidian Cleavers, and Hide/Bone/Pelt/Obsidian Armor across 3 Stone Age quality tiers (*Crude Wood/Stone → Knapped Flint → Obsidian & Carved Bone*), and assign custom weapons and armor directly to your Chieftain (`C` → Crafting) and individual Tribesfolk (`UnitInspector`) with matching 3rd-person and 1st-person gear visuals.
- **Stone Age SFX & Dynamic Music**: Synthesized Stone Age combat, gathering, building, wildlife, warhorn, and UI sound effects with 3D spatial attenuation and throttling, paired with adaptive background music that transitions across Title ambience, Day, Night, Combat, and Blood-Pit Arena bouts, configurable via **Settings → Audio**.
- **Blood-Pit Trial Arena**: Unlock the `Blood-Pit Arena` (`Lv.3` + *Barracks Drillmasters*) in `B` → Defences and approach with `E` (or `C` → Arena) to enter **Chieftain's Trial** (playable in 1st-person `Z` or 3rd-person POV) or spectate **Warband Exhibitions** across 5 encounter tiers. Defeated tribesfolk are knocked out non-lethally and recover at a Healing Shack or Campfire (`1.75×` speed), while Tier III–V victors earn the `[Arena Champion]` trait (`+15` Max HP, `+10%` Damage), Tribal XP, resources, and masterwork gear drops.
- **Day / Dusk / Night Schedule**: Colonists physically gather/build/craft by day, eat and heal around the Campfire at dusk, and sleep/reproduce inside Sleeping Huts at night while Watchtowers guard against raiders.
- **4 Simulated Rival Tribes + Nomadic Cavemen**: *Crag-Goliaths* (Warlord AI), *Sun-Stalkers* (Zealot AI), *Swift-Fang Clan* (Opportunist AI), *Earth-Root Tribe* (Guardian AI), and feral *Nomadic Cavemen* raiding from wilderness bone-caves who can be captured and enlightened.
- **4-Stage Building Destruction & Hostile-Only Combat Health Bars**. Completed buildings show damage at 66% HP, become critical at 33%, and collapse at 0%. Critical buildings emit smoke and embers. Ruins lose collision. Completed building health bars appear after hostile damage, and blueprints display construction progress.
- **Blender Assets & PSX Skinned Shaders**. All seven lineages have imported 17-bone rigs, with two men, two women, a boy, and a girl per lineage. Shared kits cover combat, work, leadership, and Cave-Kin nomads. Enlightened captives retain their lineage. All fourteen buildable types use imported damage stages, and all eight wildlife species use imported models. Launch with `--procedural-roster` for procedural roster models or `--skinned-tribesman-trial` for the original imported player leader trial rig. [Asset catalog](tools/assets/CATALOG.md)
- **Prehistoric Wildlife & Megafauna**: Deer, Wild Boar, Dire Wolves, Sabertooth Tigers, and Boss Woolly Mammoths & Giant Cave Bears.

## Project guides

- [Agent guide and codebase map](AGENTS.md)
- [Master roadmap and stabilization plan](docs/ROADMAP.md)
- [Codebase refactor plan](docs/REFACTOR.md) and [future development](docs/FUTURE.md)
- [Asset pipeline](tools/assets/README.md) and [asset rollout](tools/assets/OVERHAUL.md)
