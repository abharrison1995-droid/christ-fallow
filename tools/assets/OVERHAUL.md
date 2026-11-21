# Asset overhaul and combat design

The goal is recognizable silhouettes at normal gameplay zoom, reusable rigs and kits, and consistent rules for how units and structures take damage. [The catalog](CATALOG.md) maps the current assets and sources. The [development notes](../../docs/FUTURE.md) cover the expanded valley, World Map, and farm structures.

**Reviewed 20 November 2026.** The [codebase refactor](../../docs/REFACTOR.md) covers behavior-preserving extraction and regression checks. See the [master roadmap](../../docs/ROADMAP.md) for cross-track sequencing and [Slice 0E](../../docs/ROADMAP.md#slice-0e--3d-asset-pipeline--trial-rig-parity) asset pipeline fixes.

## Asset rollout

| Pass | Status | Work and review gate |
| --- | --- | --- |
| 1. Inventory and organize | Complete | The catalog and example generator use the grouped paths. The six samples imported with valid stages, colliders, and clips. |
| 2. Establish the body and gear contract | Promoted (20 Nov 2026) | Two Crag-Born adult silhouettes and a child share the 17-bone rig and modular Spearman and Forager kits with full skeletal clips (`Idle`, `Walk`, `GuardIdle`, `GuardWalk`, `Work`, `Attack`, `Hit`, `Death`, `Wounded`) and shader hit-flash. Supported Crag-Born Foragers and adult Spearmen run on the skinned rig by default with zero procedural fallback swap (`--procedural-roster` opts out). |
| 3. Build out the lineages and roles | Seven lineages and fourteen kits in production | All seven lineages have six bodies. Forward+ checks cover body scale, gear, actions, capture, enlightenment, and save/load. |
| 4. Refresh buildings and world props | Fourteen buildings in production | All buildable types use imported four-stage models, including Standing-Stone Gate. Crop Field and Animal Pen remain walkable. |
| 5. Refresh wildlife and trial the enemies | Eight wildlife rigs and one enemy in production | All eight wildlife species use imported rigs, including Mammoth and Cave Bear. Flintmask Scout joins nomadic packs. |

## Production batches

Apply the six-body lineup to all seven lineages, including the three already in production. Each lineup has two women, two men, one boy, and one girl. Give each adult pair distinct silhouettes, with visible differences in hair, face shape, or clothing at normal gameplay zoom. Keep the children age-appropriate with their own proportions and work gear fit. Preserve each lineage’s established body cues across all six variants. [Lineage art reference](CATALOG.md#lineage-bodies)

Batch 4 completed all **42 lineage body GLBs**, up from nine before the rollout. Gear kit counts below refer to shared kits, which can contain multiple GLBs. Gate and Scout are separate prototype promotions. [Current body and gear inventory](CATALOG.md#skinned-lineage-bodies-and-gear)

| Order | Batch | Output and promotion gate |
| --- | --- | --- |
| 1 | Crag-Born pilot · Verified | Added the cropped-hair man, twin-knot woman, and boy. Verified all six bodies through spawn, role changes, gear fit, reload, and child growth. [Crag-Born review](README.md#crag-born-pilot) |
| 2 | Goliath and Swift-Kin · Verified | Added one man, one woman, and one boy to each lineage. Verified gear fit, gait clearance, live spawning, role changes, and reload for both six-body lineups. [Batch review](README.md#goliath-and-swift-kin) |
| 3 | Stalker and Ash-Walker · Verified | Added twelve bodies. Verified Stalker’s tall, narrow silhouette, Ash-Walker’s emissive markings, both shared kits, and the live roster and reload paths. [Batch review](README.md#stalker-and-ash-walker) |
| 4 | Fen-Tidal and Cave-Kin · Verified | Added twelve bodies and the Cave-Kin club and trophy pelt. Verified the full roster, nomadic spawn, captive conversion, and save paths. [Batch review](README.md#fen-tidal-and-cave-kin) |
| 5 | Combat kits · Verified | Knife-Raider, Archer, Club Brute, and Javelineer have shared gear and class-specific one-shot clips. Forward+ checked attachment, weapon tiers, armor, melee contact, and projectile release. [Batch review](README.md#combat-kits) |
| 6 | Work and specialist kits · Verified | Added six shared kits and a Shaman cast clip. Verified role changes, mounted tools, work and bow playback, and Farmer reuse of the Forager kit. [Batch review](README.md#workforce-kits) |
| 7 | Leader kit · Verified | Adult player and rival leaders use a bone crown, split mantle, great-spear, back javelins, and cleave clip. Verified succession, naming, mounted pose and camera, and the original trial rig. [Batch review](README.md#leader-kit) |
| 8 | Standing-Stone Gate · Verified | Promoted the four-stage gate after capsule traversal and AI route checks at all eight rotations. Both piers block movement and release when the gate collapses. [Batch review](README.md#standing-stone-gate) |
| 9 | Flintmask Scout · Verified | Nomadic packs include a masked scout with a hooked club and complete skin animation. Verified contact, hit and death playback, and save validation. [Batch review](README.md#flintmask-scout) |
| 10 | Settlement economy · Verified | Promoted the Campfire, Forager Lodge, and Crafting Pit. Verified founding, healing, hauling, the Lodge yield bonus, crafting and tier upgrades, damage, and reload. [Batch review](README.md#settlement-building-batches) |
| 11 | Faith and warband · Verified | Promoted Sacred Totem, Healing Shack, Weapon Rack, and Barracks. Verified Faith, enlightenment, rescue, equipment, training, damage, and reload. [Batch review](README.md#settlement-building-batches) |
| 12 | Farming and husbandry · Verified | Promoted Crop Field and Animal Pen. Verified walkable placement, dynamic crop appearance, damage and reload, and the live crop, taming, breeding, and riding cycle. [Batch review](README.md#farm-structures-and-rider-review) |
| 13 | Deer and Dire Wolf · Verified | Promoted the two skinned rigs. Verified wildlife spawning and persistence in both layouts, deer flight and taming, and wolf pursuit, bite, projectile contact, and yields. [Batch review](README.md#wildlife-lineup) |
| 14 | Megafauna · Verified | Promoted Woolly Mammoth and Giant Cave Bear. Verified territorial behavior, projectile contact, animated area attacks, rewards, and persistence in both layouts. [Batch review](README.md#wildlife-lineup) |
| 15 | Wildcard model round | After Batches 1–14 ship, generate a series of exploratory Blender models and present them for the user to review and select. |

For Batches 1–4, use the shared 17-bone skeleton, compatible rest transforms, nine clips, and `FactionTrim`. Select the child body from age and gender and use a stable choice based on the saved unit ID for adults. Check that reload and role changes keep the same body, that growing up picks the expected adult body, and that older saves still load. Exercise the normal roster and `--procedural-roster`. Capture each lineup at a shared camera distance with the PSX filter enabled. [Generator](generate_crag_born.py) · [Runtime selection](../../scripts/entities/human_unit.gd) · [Lineage verifier](../../scripts/tools/verify_skinned_lineages.gd)

For every batch, stage the exports with Blender 4.5 LTS, import them into Godot 4.3, run the relevant Forward+ probes with isolated saves, and inspect captures before promoting the batch. Make one verified checkpoint per batch and update the catalog with the production paths. [Generation and review workflow](README.md) · [Verification commands](../../docs/ROADMAP.md#verification-gate-commands-windows-powershell)

### Building batches

Batches 10–12 add **nine building GLBs with 36 damage stages** across them. That completes imported coverage for all 13 existing building types. Standing-Stone Gate is a separate addition from Batch 8. Export one `<building_id>_stages.glb` per type with four root stages, `FactionTrim` where appropriate, and the authored footprint reference. Preserve the existing placement and navigation dimensions. [Building contract](README.md#building-contract) · [Building data](../../scripts/core/game_data.gd) · [Asset loader](../../scripts/core/world_mesh_builder.gd)

| Batch | Asset and visual direction | Gameplay check |
| --- | --- | --- |
| 10 | **Tribal Campfire** (`CAMPFIRE`). Ring of scorched stone, stacked fuel, and a low flame. | Preserve `CampfireLight` and `FlameMesh` in standing stages. Found a tribe through the opening guide, drop off resources, check dusk healing, and verify dimming and extinguishing through damage. |
| 10 | **Forager & Hunter Lodge** (`FORAGER_LODGE`). Drying hides, woven packs, and a low shelter. | Compare the existing gathering and hunting yield bonuses before and after construction. |
| 10 | **Flint-Knapping & Crafting Pit** (`CRAFTING_PIT`). Low stone work surface with flint chips, blanks, and tools. | Queue a recipe and complete a gear-tier upgrade in the Colony drawer. |
| 11 | **Sacred Totem** (`SACRED_TOTEM`). Tall carved pole with stone footing and a distinct faction marker. | Verify Faith access, shaman Faith generation, and captive enlightenment after construction. |
| 11 | **Shaman’s Healing Shack** (`SHAMAN_SHACK`). Hide canopy, medicinal bundles, and a shaded lantern. | Preserve `ShamanLight` in standing stages. Follow a wounded unit through rescue, treatment, and recovery. Check light dimming and shutoff. |
| 11 | **Weapon & Armor Rack** (`WEAPON_RACK`). Open-backed timber rack with spear shafts and hide shields visible from the command camera. | Confirm a warrior can approach the rack and equip the expected gear from stock. |
| 11 | **Tribal Barracks** (`BARRACKS`). Training frame, hide targets, and a worn practice yard. | Verify a trainee and an idle guard can approach and accrue training XP. |
| 12 | **Crop Field** (`CROP_FIELD`). Low furrows and grain rows. Flatten or scatter crops as damage advances. | Keep `Crops` under the standing stages so growth and visibility follow the crop state. Place and rotate a blueprint, then verify sowing, tending, harvesting, hauling, and a growing-field reload. |
| 12 | **Animal Pen** (`ANIMAL_PEN`). Low wattle rails and a visible trough. | Keep the pen and field walkable. Verify arrivals, feeding, breeding, and movement through the pen on foot and mounted. Reload with an owned herd in the pen. |

For each building, review the Build drawer preview, rotated placement ghost, completed model, all four damage stages, and reload of a damaged building. Check blueprint progress, hostile damage feedback, and collision and navigation through destruction. Compare the damage silhouettes under the PSX filter at normal gameplay zoom. [Building entity](../../scripts/entities/building_entity.gd) · [Opening verifier](../../scripts/tools/verify_opening_tutorial.gd) · [Valley assets verifier](../../scripts/tools/verify_valley_assets.gd) · [Farming verifier](../../scripts/tools/verify_farming_taming.gd)

### Wildlife batches

Batches 13–14 add **four wildlife GLBs**, completing imported coverage for all eight existing species. Author in-place idle and walk loops for all four and a run cycle for deer and wolf. Export facing local `-Z`. Preserve the existing species IDs, territories, taming and aggro rules, damage, and yields. Reuse the imported `Bite` path for the wolf and verify the boss attack visuals against the existing area-damage event. Check that the larger models fit the active collision and projectile hit volumes before promotion. [Wildlife data](../../scripts/core/game_data.gd) · [Wildlife entity](../../scripts/entities/wildlife_entity.gd) · [Valley territories](../../scripts/core/world_layout.gd)

| Batch | Asset and visual direction | Gameplay check |
| --- | --- | --- |
| 13 | **Deer** (`DEER`). Slender body, a clear antler silhouette, and a bounding flee gait. | Check wild flight after damage, taming with `E`, travel to the pen, scaling for offspring, and ownership after reload. |
| 13 | **Dire Wolf** (`WOLF`). Long muzzle, raised shoulders, and an articulated lunge and bite. | Check pursuit, bite playback, reach and cooldown, projectile hits, and hunting yield. |
| 14 | **Woolly Mammoth** (`MAMMOTH`). Shaggy shoulder hump, curved tusks, and a heavy stomp. | Check roaming and retaliation, the existing stomp damage radius, boss markers, and rewards. |
| 14 | **Giant Cave Bear** (`CAVE_BEAR`). Broad upper body, heavy paw stride, and a swipe readable at tactical zoom. | Check hostile pursuit, the existing swipe damage radius, boss markers, and rewards. |

Capture all four at the same gameplay camera distance. Check species spawning and save/load in both valley layouts, then record the live animation and hit-volume probes. [Valley assets verifier](../../scripts/tools/verify_valley_assets.gd) · [Farming verifier](../../scripts/tools/verify_farming_taming.gd) · [Campaign save verifier](../../scripts/tools/verify_campaign_save.gd)

### Wildcard model round

Once Batches 1–14 are complete, generate a first set of six original 3D prototypes in Blender. Use the finished roster and valley as reference. Explore a mix of wildlife, structures, scenery, character kits, and tools so the review offers distinct directions. [Existing model examples](examples/README.md)

Export each prototype as a GLB and put it on a comparison sheet at gameplay scale with the PSX filter. Include a close view, a short description of where it might fit, and any animation or collision work it would need. Present the numbered set to the user for selection. The user’s picks become candidates for a future production batch. [Generation and review workflow](README.md)

Author assets against scale and attachment contracts, and stage changes through Blender generation, clean Godot import, Forward+ captures, and a live test scene. Keep appearance choices out of balance calculations. When a visual needs different gameplay bounds, tune the collider and hit volume deliberately.

Classic and expanded layouts share the imported scenery, building, and wildlife models. Both place reed beds and ford art through their active layout geometry. [Terrain definitions](../../scripts/core/world_layout.gd)

Crop Fields and Animal Pens have four imported damage stages and walkable footprints. Adult Tusked Boar reuses its imported model when trained. The player leader has a seated riding pose. [Farm structures and rider review](README.md#farm-structures-and-rider-review)

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

The Stalker gets additional reach with bows and javelins. Humans receive `max(2, raw_damage − 0.45 × total_armor)`. A 12-point hit against 10 armor deals 7.5 HP. Worn armor adds 8 points at Tier I and 4 more per additional tier. Warrior Spearmen gain another 3 points. Slateback Boar uses the same mitigation with eight armor. Other wildlife and buildings subtract the incoming amount directly. Completed buildings switch stages at 66%, 33%, and 0% HP. An unfinished blueprint retains its construction hologram.

[`HumanUnit.recalculate_stats()`, `take_damage()`, and `_engage_building()`](../../scripts/entities/human_unit.gd) · [Wildlife damage](../../scripts/entities/wildlife_entity.gd) · [Building damage](../../scripts/entities/building_entity.gd)

### Proposed damage review

1. **Verified.** Golden cases lock down leader cleave, ranged damage and projectile attribution, unarmed self-defense, Brutes against buildings, and blessing damage. The ordinary boar retains full incoming damage. [Campaign save and combat verifier](../../scripts/tools/verify_campaign_save.gd)
2. Give attack definitions explicit data for damage basis, reach, cooldown, delivery, and contact or release timing where the existing rules support it. Coordinate calculation extraction with the [codebase refactor](../../docs/REFACTOR.md). Keep each entity responsible for its own HP, death or destruction, rewards, and diplomacy. Preserve the projectile's stored faction ID when its shooter disappears in flight.
3. Check animation contact and projectile impact against actual hit volumes. Leader javelin now scales off `ranged_attack_damage * 1.25` (with `VALK_TOR` `+25%` or daytime `SOL_KAR` `+20%`), and projectile collision uses swept segment checks against target hit radii. Test small and large bodies, long walls, and attacks through the gate opening before changing hit volumes.
4. **Slateback armor verified.** Its plates reduce a 12-point hit to 8.4 HP. Reedjaw’s 0.16 s wind-up gives the target time to leave reach, and arrows above its low body can miss. Equal-gear duels, focus fire, and structure break times remain future balance work. [Valley asset verifier](../../scripts/tools/verify_valley_assets.gd)

[Leader abilities](../../scripts/entities/player_controller.gd) · [Projectile impact](../../scripts/entities/projectile_3d.gd)

## Encounter and building playtests

These assets are live in campaigns and retain their reviewed behavior.

| Asset | First test values | What should read in play |
| --- | --- | --- |
| Flintmask Scout | 100 HP, 7.4 m/s, 13 raw melee, 0.85 s between attacks | The mask and hooked club mark a light skirmisher. Standard armor and a quick wind-up are enough for the first trial. |
| Slateback Boar | 130 HP, eight armor, 5.8 m/s, 16 raw damage, 1.6 s between attacks | The plates signal a tougher boar. |
| Reedjaw | 135 HP, 6.6 m/s, 18 raw damage, 1.45 s between attacks | A low silhouette and clear crouch signal its short lunge. |
| Reed Granary | Storage Mound behavior, 320 HP, 12 wood and 10 stone | Damage reads through a missing lid, spilled grain, and a collapsed deck. |
| Ridge Signal Tower | Watchtower behavior, 380 HP, current build cost | The brazier and raised deck read at range. The arrow origin should line up with the platform. |
| Standing-Stone Gate | 430 HP, 18 stone and 4 wood | Two piers block movement. The gap stays open for the leader and AI through all standing stages. |
