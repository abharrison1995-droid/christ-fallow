# Asset overhaul and combat design

The goal is recognizable silhouettes at normal gameplay zoom, reusable rigs and kits, and consistent rules for how units and structures take damage. [The catalog](CATALOG.md) maps the current assets and sources. The larger valley and world map are on the [future roadmap](../../docs/FUTURE.md).

**Reviewed 20 November 2026.** The [codebase refactor](../../docs/REFACTOR.md) covers behavior-preserving extraction and regression checks. See the [master roadmap](../../docs/ROADMAP.md) for cross-track sequencing and [Slice 0E](../../docs/ROADMAP.md#slice-0e--3d-asset-pipeline--trial-rig-parity) asset pipeline fixes.

## Asset rollout

| Pass | Status | Work and review gate |
| --- | --- | --- |
| 1. Inventory and organize | Complete | The catalog and example generator use the grouped paths. The six samples imported with valid stages, colliders, and clips. |
| 2. Establish the body and gear contract | Pilot delivered | Two Crag-Born adult silhouettes and a child share the rig and modular Spearman and Forager kits. Work, attacks, hit reactions, and death use procedural visuals during the pilot. Review the visible handoff before promoting the rig to the default roster. |
| 3. Build out the lineages and roles | Proposed | Test Goliath and Swift-Kin next for scale extremes, then Stalker, Ash-Walker, Fen-Tidal, and Cave-Kin. Compare bodies at gameplay zoom and check held items, projectile origins, movement clearance, and save/load. |
| 4. Refresh buildings and world props | Partially delivered | Sleeping Hut and Palisade are production references. Four scenery GLBs are integrated. Trial Reed Granary as a Storage Mound variant, consider Signal Tower for Watchtower, and test the gate as a separate structure. Verify stages, yaw, collider fit, and rubble clearance before promotion. |
| 5. Refresh wildlife and trial the enemies | Partially delivered | Boar and Sabertooth have live imported models and one-shot bites. Reedjaw, Slateback, and Flintmask Scout remain reviewed samples. Give each promoted concept a readable attack, hit or death response, and tested hit volume. |

Author assets against scale and attachment contracts, and stage changes through Blender generation, clean Godot import, Forward+ captures, and a live test scene. Keep appearance choices out of balance calculations. When a visual needs different gameplay bounds, tune the collider and hit volume deliberately.

Blender 4.5.16 regenerated all six samples with matching file hashes. A fresh Godot 4.3 Forward+ import verified the stages, colliders, and clips and rendered both comparison sheets.

The [Crag-Born review](README.md#crag-born-pilot) records the attachment and procedural handoff checks. The [gameplay-zoom comparison](previews/crag-born-comparison.png) shows the silhouettes and attachment fit.

The [valley review](README.md#valley-scenery-and-wildlife) records interaction with imported resources, wildlife behavior, and bite timing.

## Lineage balance reference

These are the reference multipliers before unit rolls, class, equipment, rank, patron effects, or buffs. Attack rate divides the base cooldown. Armor is additive. `GameData.LINEAGE_DATA` is the source of truth for live values.

| Lineage | HP | Melee | Ranged | Move | Attack rate | Gather | Birth rate | Armor |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Goliath | 1.50× | 1.35× | 0.90× | 0.82× | 0.88× | 1.10× | 0.65× | +4 |
| Swift-Kin | 0.75× | 0.92× | 1.05× | 1.30× | 1.25× | 1.00× | 1.60× | 0 |
| Stalker | 0.92× | 0.95× | 1.30× | 1.15× | 1.10× | 1.05× | 1.00× | 0 |
| Crag-Born | 1.15× | 1.05× | 1.00× | 0.96× | 1.00× | 1.25× | 1.05× | +6 |
| Ash-Walker | 1.05× | 1.12× | 1.15× | 1.05× | 1.06× | 1.15× | 0.90× | +2 |
| Fen-Tidal | 0.95× | 1.02× | 1.08× | 1.14× | 1.12× | 1.18× | 1.20× | +1 |
| Cave-Kin | 1.18× | 1.18× | 0.70× | 0.95× | 0.96× | 0.85× | 0.80× | +4 |

[`LINEAGE_DATA`](../../scripts/core/game_data.gd) · [`HumanUnit.recalculate_stats()`](../../scripts/entities/human_unit.gd)

*Naming note:* Asset docs use enum-derived names (`Ash-Walker`, `Fen-Tidal`, `Cave-Kin`); live UI display names in `GameData.LINEAGE_DATA` are `Ash-Born (Ember-Kin)`, `Fen-Tidal (Mire-Folk)`, and `Feral Caveman (Cave-Kin)`.

Start by checking whether each role reads at tactical zoom. Goliath and Crag-Born already trade speed for different kinds of durability. Swift-Kin emphasizes speed and sharp cooldowns. Stalker emphasizes ranged effectiveness. Ash-Walker and Fen-Tidal need clear art cues because their current combat multipliers are closer together. Compare classes using fixed adult base rolls and equal gear tiers before tuning lineages.

## Combat and damage

### Live calculation

Units roll base HP of 88–114, base melee of 9.5–14.5, and base ranged of 8.5–13.5. Max HP applies lineage and role multipliers and adds 10 HP per melee rank before the child modifier. Base movement is 5.8 m/s before lineage, class, and leader bonuses. Melee and ranged damage use the appropriate lineage and rank multipliers. Weapon tier scales base damage by `1 + 0.28 × (tier − 1)`. Equipment, class, blessings, and doctrines apply at their respective call sites.

| Warrior class | Raw damage before situational bonuses | Base reach | Base cooldown |
| --- | --- | ---: | ---: |
| Spearman | 1.12 × melee | 2.75 m | 1.02 s |
| Knife-Raider | 0.92 × melee | 1.9 m | 0.65 s |
| Archer | Ranged | 17.5 m | 1.25 s |
| Club Brute | 1.38 × melee. Building attacks multiply this by a further 1.35. | 2.45 m | 1.32 s |
| Javelineer | 0.72 × ranged + 0.42 × melee | 11.5 m | 1.30 s |

The Stalker gets additional reach with bows and javelins. Humans receive `max(2, raw_damage − 0.45 × total_armor)`. A 12-point hit against 10 armor deals 7.5 HP. Worn armor adds 8 points at Tier I and 4 more per additional tier. Warrior Spearmen gain another 3 points. Wildlife and buildings currently subtract the incoming amount directly. The damage recipient handles health and consequences such as injury, death, loot, diplomacy, or a structure changing stages. Completed buildings switch stages at 66%, 33%, and 0% HP. An unfinished blueprint retains its construction hologram.

[`HumanUnit.recalculate_stats()`, `take_damage()`, and `_engage_building()`](../../scripts/entities/human_unit.gd) · [Wildlife damage](../../scripts/entities/wildlife_entity.gd) · [Building damage](../../scripts/entities/building_entity.gd)

### Proposed damage review

1. Record golden cases for leader cleave, ranged attacks, unarmed self-defense, Brutes hitting buildings, and blessing damage. Capture raw damage, applied damage, and the expected target outcome before changing the calculation.
2. Give attack definitions explicit data for damage basis, reach, cooldown, delivery, and contact or release timing where the existing rules support it. Coordinate calculation extraction with the [codebase refactor](../../docs/REFACTOR.md). Keep each entity responsible for its own HP, death or destruction, rewards, and diplomacy. Preserve the projectile's stored faction ID when its shooter disappears in flight.
3. Check animation contact and projectile impact against actual hit volumes. Leader javelin now scales off `ranged_attack_damage * 1.25` (with `VALK_TOR` `+25%` or daytime `SOL_KAR` `+20%`), and projectile collision uses swept segment checks against target hit radii. Test small and large bodies, long walls, and attacks through the gate opening before changing hit volumes.
4. Add a damage type or armor rule when it produces a readable counter. An armored Slateback would be a useful trial after ordinary wildlife damage has a regression baseline. Test equal-gear duels, focus fire, knockback, structure break times, and frontline clarity at normal zoom.

[Leader abilities](../../scripts/entities/player_controller.gd) · [Projectile impact](../../scripts/entities/projectile_3d.gd)

## Sample starting points for playtests

These are trial targets. Measure time to kill and telegraph readability against equal-tier units before adding values to the campaign.

| Concept | Proposed first test | What should read in play |
| --- | --- | --- |
| Flintmask Scout | 100 HP, 7.4 m/s, 13 raw melee, 0.85 s between attacks | The mask and hooked club mark a light skirmisher. Standard armor and a quick wind-up are enough for the first trial. |
| Slateback Boar | 130 HP, 5.8 m/s, 16 raw damage, 1.6 s between attacks | The plates signal a tougher boar. Compare with the current 85 HP, 11-damage boar before testing any armor multiplier. |
| Reedjaw | 135 HP, 6.6 m/s, 18 raw damage, 1.45 s between attacks | A low silhouette and clear crouch signal its short lunge. Trial it near the existing river, between the wolf and sabertooth in threat. |
| Reed Granary | Storage Mound behavior, 320 HP, 12 wood and 10 stone | Damage reads through a missing lid, spilled grain, and a collapsed deck. A visual variant tests the pipeline without adding an economy rule. |
| Ridge Signal Tower | Watchtower behavior, 380 HP, current build cost | The brazier and raised deck read at range. The arrow origin should line up with the platform. |
| Standing-Stone Gate | Hold balance until passage works through both intact piers | Its silhouette signals a passage. Verify choke points and AI travel before considering a defensive bonus. |

The proposed next candidates are **Goliath and Swift-Kin** for shared-rig scale checks, **Reed Granary** for an existing-building variant, and **Reedjaw** for a standalone enemy encounter. These trials can proceed independently using the delivered Crag-Born and valley assets as references.
