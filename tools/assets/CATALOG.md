# Christ Fallow asset catalog

Use this catalog to find the current asset or locate the right home for a replacement. The game uses **lineage** for inherited body traits, **faction** for allegiance and trim color, and **role or class** for outfits, gear, and animations. A Goliath archer and Goliath woodcutter can share a body and use different kits.

## Lineage bodies

Foragers and adult Spearmen from all seven lineages, plus Cave-Kin nomads, use the [shared skinned lineup](#skinned-lineage-bodies-and-gear). The [base tribesman](../../assets/models/characters/tribesman_base.glb) supplies the opt-in player leader trial. Each row identifies a silhouette and its export directory under `assets/models/characters/lineages/`.

All seven lineages have all six bodies in production. [Production batches](OVERHAUL.md#production-batches)

| Stable lineage ID | Body cues to carry forward | Export directory |
| --- | --- | --- |
| `GOLIATH` | Tall barrel chest, heavy brow, broad shoulders, fur mantle | `goliath/` |
| `SWIFT_KIN` | Compact build, large head silhouette, pointed ears, spiky hair | `swift_kin/` |
| `STALKER` | Long limbs, narrow torso, swept ears and a hunter crest | `stalker/` |
| `CRAG_BORN` | Stocky shoulders, thick forearms, braids or beard | `crag_born/` |
| `ASH_WALKER` | Angular face, ash-grey skin, pale locks and ember markings | `ash_walker/` |
| `FEN_TIDAL` | Finned ears, dorsal crest, reed and shell accents | `fen_tidal/` |
| `CAVEMAN` | Hunched body, heavy jaw, shaggy pelt and bone ornaments | `caveman/` |

Store shared weapon, offhand, head, back, and armor assets under `assets/models/gear/` as they are approved. Store distinct humanoid enemy kits under `assets/models/characters/archetypes/`. Keep child proportions, adult variation, and faction tint compatible with each lineage body. The current rules and stat multipliers live in [GameData](../../scripts/core/game_data.gd).

## Live assets by type

[Standing-Stone Gate](../../assets/models/buildings/standing_stone_gate_stages.glb) is buildable under Defences and has separate pier collision and routing. [Gate review](README.md#standing-stone-gate)

[Flintmask Scout](../../assets/models/characters/archetypes/flintmask_scout.glb) spawns with nomadic packs and carries a [hooked club](../../assets/models/gear/flintmask_scout/hooked_club.glb). [Scout review](README.md#flintmask-scout)

[Campfire](../../assets/models/buildings/campfire_stages.glb), [Forager Lodge](../../assets/models/buildings/forager_lodge_stages.glb), and [Crafting Pit](../../assets/models/buildings/crafting_pit_stages.glb) use imported damage stages. [Settlement review](README.md#settlement-building-batches)

[Sacred Totem](../../assets/models/buildings/sacred_totem_stages.glb), [Healing Shack](../../assets/models/buildings/shaman_shack_stages.glb), [Weapon Rack](../../assets/models/buildings/weapon_rack_stages.glb), and [Barracks](../../assets/models/buildings/barracks_stages.glb) use imported damage stages. [Faith and warband review](README.md#settlement-building-batches)

[Crop Field](../../assets/models/buildings/crop_field_stages.glb) and [Animal Pen](../../assets/models/buildings/animal_pen_stages.glb) have imported stages and shared walkable ground. [Farm review](README.md#farm-structures-and-rider-review)

| Type | Current coverage | Where to work |
| --- | --- | --- |
| Humanoid kits | Leader, Spearman, Knife-Raider, Archer, Club Brute, Javelineer, Forager, Hunter, Woodcutter, Stoneknapper, Builder/Crafter, Shaman, Trainee, and Cave-Kin. Farmers use procedural workwear and tools. Settled leaders pair their lineage silhouette with a faction crest and titled nameplate. | [Class and leader definitions](../../scripts/core/game_data.gd) and [HumanMeshBuilder](../../scripts/core/human_mesh_builder.gd) |
| Gear and tools | Spears, knives, bows, clubs, javelins, armor, shields, work tools, clothing and packs. Three tech tiers for crafted gear. | [Craft recipes](../../scripts/core/game_data.gd) and [gear mounts](../../scripts/core/human_mesh_builder.gd) |
| Buildings | All 14 types use imported four-stage models. | [Sleeping Hut](../../assets/models/buildings/sleeping_hut_stages.glb), [Palisade](../../assets/models/buildings/palisade_wall_stages.glb), [Reed Granary](../../assets/models/buildings/storage_pit_stages.glb), and [Ridge Signal Tower](../../assets/models/buildings/watchtower_stages.glb), plus the buildings above. [Building definitions](../../scripts/core/game_data.gd) · [Loader and procedural fallback](../../scripts/core/world_mesh_builder.gd) |
| Wildlife | Deer, Tusked Boar, Slateback Boar, Dire Wolf, Sabertooth, Reedjaw, Woolly Mammoth, Giant Cave Bear. | [Wildlife definitions](../../scripts/core/game_data.gd), [wildlife entity](../../scripts/entities/wildlife_entity.gd) and [WorldMeshBuilder](../../scripts/core/world_mesh_builder.gd) |
| Resources and landmarks | Trees, stone, flint, berry bushes, bone caves, valley terrain and river. The World Map marks caves and fords from the same layout data as the terrain. | [WorldMeshBuilder](../../scripts/core/world_mesh_builder.gd), [world generation](../../scripts/systems/world_generator.gd), and [World Map](../../scripts/ui/world_map_overlay.gd) |
| Projectiles and effects | Arrow and javelin meshes, hit flash, slash arc, damage numbers, blood pools, smoke and building debris. | [WorldMeshBuilder](../../scripts/core/world_mesh_builder.gd), [CombatVFX](../../scripts/core/combat_vfx.gd), [buildings](../../scripts/entities/building_entity.gd) |
| Presentation | Title backdrop and ambience, shared menu theme, HUD, Valley Radar, launcher icon, and PSX shaders. | [Title backdrop](../../assets/ui/valley_dawn.png), [ambience](../../assets/ui/title_ambience.wav), [theme](../../scripts/ui/fallow_theme.gd), [HUD](../../scripts/ui/hud_controller.gd), [radar](../../scripts/ui/minimap_widget.gd), [icon](../../icon.svg), and [shaders](../../scripts/shaders/) |

Approved exports keep their existing model paths. New imports should follow the category directory, with a stable filename tied to the gameplay ID. The [asset pipeline](README.md) owns generation and preview. The [overhaul plan](OVERHAUL.md) owns sequencing and combat design.

The building batches are complete. Six of eight wildlife species have imported models. [Building batches](OVERHAUL.md#building-batches) · [Wildlife batches](OVERHAUL.md#wildlife-batches)

## Skinned lineage bodies and gear

| Asset | GLBs |
| --- | --- |
| Shared-rig Crag-Born bodies | [Broad man](../../assets/models/characters/lineages/crag_born/crag_born_broad.glb), [cropped-hair man](../../assets/models/characters/lineages/crag_born/crag_born_cropped.glb), [braided woman](../../assets/models/characters/lineages/crag_born/crag_born_braided.glb), [twin-knot woman](../../assets/models/characters/lineages/crag_born/crag_born_twin_knots.glb), [boy](../../assets/models/characters/lineages/crag_born/crag_born_boy.glb), [girl](../../assets/models/characters/lineages/crag_born/crag_born_child.glb) |
| Shared-rig Goliath bodies | [Broad man](../../assets/models/characters/lineages/goliath/goliath_broad.glb), [crested man](../../assets/models/characters/lineages/goliath/goliath_cropped.glb), [braided woman](../../assets/models/characters/lineages/goliath/goliath_braided.glb), [high-knot woman](../../assets/models/characters/lineages/goliath/goliath_twin_knots.glb), [boy](../../assets/models/characters/lineages/goliath/goliath_boy.glb), [girl](../../assets/models/characters/lineages/goliath/goliath_child.glb) |
| Shared-rig Swift-Kin bodies | [Broad man](../../assets/models/characters/lineages/swift_kin/swift_kin_broad.glb), [swept-hair man](../../assets/models/characters/lineages/swift_kin/swift_kin_cropped.glb), [braided woman](../../assets/models/characters/lineages/swift_kin/swift_kin_braided.glb), [twin-knot woman](../../assets/models/characters/lineages/swift_kin/swift_kin_twin_knots.glb), [boy](../../assets/models/characters/lineages/swift_kin/swift_kin_boy.glb), [girl](../../assets/models/characters/lineages/swift_kin/swift_kin_child.glb) |
| Shared-rig Stalker bodies | [High-crest man](../../assets/models/characters/lineages/stalker/stalker_broad.glb), [swept-crest man](../../assets/models/characters/lineages/stalker/stalker_cropped.glb), [braided woman](../../assets/models/characters/lineages/stalker/stalker_braided.glb), [twin-knot woman](../../assets/models/characters/lineages/stalker/stalker_twin_knots.glb), [boy](../../assets/models/characters/lineages/stalker/stalker_boy.glb), [girl](../../assets/models/characters/lineages/stalker/stalker_child.glb) |
| Shared-rig Ash-Walker bodies | [Crested man](../../assets/models/characters/lineages/ash_walker/ash_walker_broad.glb), [side-swept man](../../assets/models/characters/lineages/ash_walker/ash_walker_cropped.glb), [braided woman](../../assets/models/characters/lineages/ash_walker/ash_walker_braided.glb), [paired-lock woman](../../assets/models/characters/lineages/ash_walker/ash_walker_twin_knots.glb), [boy](../../assets/models/characters/lineages/ash_walker/ash_walker_boy.glb), [girl](../../assets/models/characters/lineages/ash_walker/ash_walker_child.glb) |
| Shared-rig Fen-Tidal bodies | [Broad man](../../assets/models/characters/lineages/fen_tidal/fen_tidal_broad.glb), [swept-fin man](../../assets/models/characters/lineages/fen_tidal/fen_tidal_cropped.glb), [braided woman](../../assets/models/characters/lineages/fen_tidal/fen_tidal_braided.glb), [twin-braid woman](../../assets/models/characters/lineages/fen_tidal/fen_tidal_twin_knots.glb), [boy](../../assets/models/characters/lineages/fen_tidal/fen_tidal_boy.glb), [girl](../../assets/models/characters/lineages/fen_tidal/fen_tidal_child.glb) |
| Shared-rig Cave-Kin bodies | [Broad man](../../assets/models/characters/lineages/caveman/caveman_broad.glb), [cropped-mane man](../../assets/models/characters/lineages/caveman/caveman_cropped.glb), [braided woman](../../assets/models/characters/lineages/caveman/caveman_braided.glb), [short-mane woman](../../assets/models/characters/lineages/caveman/caveman_twin_knots.glb), [boy](../../assets/models/characters/lineages/caveman/caveman_boy.glb), [girl](../../assets/models/characters/lineages/caveman/caveman_child.glb) |
| Cave-Kin kit | [Bone club](../../assets/models/gear/caveman/bone_club.glb), [trophy pelt](../../assets/models/gear/caveman/trophy_pelt.glb) |
| Spearman kit | [Spear](../../assets/models/gear/spearman/spear.glb), [hide buckler](../../assets/models/gear/spearman/hide_buckler.glb), [bone guard](../../assets/models/gear/spearman/bone_guard.glb) |
| Forager kit | [Flint sickle](../../assets/models/gear/forager/flint_sickle.glb), [reed basket](../../assets/models/gear/forager/reed_basket.glb), [light workwear](../../assets/models/gear/forager/workwear.glb) |
| Combat kits | [Knife-Raider](../../assets/models/gear/knife_raider/) · [Archer](../../assets/models/gear/archer/) · [Club Brute](../../assets/models/gear/brute/) · [Javelineer](../../assets/models/gear/javelineer/) · [Shared attack clips](../../assets/models/characters/moves/combat.glb) |
| Workforce kits | [Hunter](../../assets/models/gear/hunter/) · [Woodcutter](../../assets/models/gear/lumberjack/) · [Stoneknapper](../../assets/models/gear/stoneknapper/) · [Builder/Crafter](../../assets/models/gear/builder_crafter/) · [Shaman](../../assets/models/gear/shaman/) · [Trainee](../../assets/models/gear/trainee/) · [Shaman cast](../../assets/models/characters/moves/specialist.glb) |
| Leader kit | [Bone crown and regalia](../../assets/models/gear/leader/) · [Leader cleave](../../assets/models/characters/moves/leader.glb) |

[Gameplay-zoom comparison](previews/crag-born-comparison.png) · [Launch, regenerate, and verify](README.md#crag-born-pilot)

## Valley scenery and wildlife

| Asset | Use |
| --- | --- |
| [Wind-bent pine](../../assets/models/environment/windbent_pine.glb) | Harvestable `TREE` |
| [Moss limestone](../../assets/models/environment/moss_limestone.glb) | Harvestable `STONE` |
| [Berry thicket](../../assets/models/environment/berry_thicket.glb) | Harvestable `BERRY_BUSH` |
| [Riverbank reeds](../../assets/models/environment/riverbank_reeds.glb) | Decorative beds along both riverbanks |
| [Tusked Boar](../../assets/models/wildlife/tusked_boar.glb) | Existing `BOAR` population with an articulated chomp and tusk lift |
| [Sabertooth](../../assets/models/wildlife/sabertooth.glb) | Existing `SABERTOOTH` population with an articulated jaw snap |
| [Slateback Boar](../../assets/models/wildlife/slateback_boar.glb) | `SLATEBACK_BOAR` uses an armored hide and retaliates when struck |
| [Reedjaw](../../assets/models/wildlife/reedjaw.glb) | `REEDJAW` hunts near the river and telegraphs a short-range bite |
| [Deer](../../assets/models/wildlife/deer.glb) | `DEER` has antlers, bounding flight, and taming and herd support |
| [Dire Wolf](../../assets/models/wildlife/dire_wolf.glb) | `WOLF` uses a pursuit gait and a skinned bite |

[Scenery and bite poses](previews/valley-assets.png) · [Regenerate and verify](README.md#valley-scenery-and-wildlife)

## Reviewed samples

These models live under [the examples directory](examples/README.md) and can be regenerated by [the example generator](examples/generate_examples.py).

| Category | GLBs | Review |
| --- | --- | --- |
| `buildings/` | [Ridge Signal Tower](examples/models/buildings/ridge_signal_tower.glb), [Standing-Stone Gate](examples/models/buildings/standing_stone_gate.glb), [Reed Granary](examples/models/buildings/reed_granary.glb) | [Four-stage sheet](examples/previews/destruction-stages.png) |
| `characters/archetypes/` | [Flintmask Scout](examples/models/characters/archetypes/flintmask_scout.glb) | [Idle and Walk sheet](examples/previews/enemy-concepts.png) |
| `wildlife/` | [Slateback Boar](examples/models/wildlife/slateback_boar.glb), [Reedjaw](examples/models/wildlife/reedjaw.glb) | [Idle and Walk sheet](examples/previews/enemy-concepts.png) |
