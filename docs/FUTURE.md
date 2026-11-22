# Future development

See the [master roadmap](ROADMAP.md) for sequencing. New campaigns use the 760 m valley. Legacy campaigns keep their original terrain. [Shared layout definitions](../scripts/core/world_layout.gd)

## Playable opening tutorial

> **Status: Delivered (20 November 2026; polished 22 November 2026)** — Implemented in [Phase 2A](ROADMAP.md#slice-2a--playable-opening-tutorial), polished in [Phase 6](ROADMAP.md#phase-6-tribal-level-perks--skills-system--opening-tutorial-polish-completed-22-nov-2026), and verified by [verify_opening_tutorial.gd](../scripts/tools/verify_opening_tutorial.gd).

Build on the Awakening Guide with a hands-on tutorial at the start of **New Game**. Teach one action at a time in the player's own campaign so the tribe and buildings carry into normal play.

- [x] **Recruit the first tribesfolk.** Point out a nearby wanderer, show the `E` recruit prompt as the leader approaches, then guide the player through recruiting three wanderers.
- [x] **Found the village.** Highlight **Build** (`B`), guide the player to the Tribal Campfire, and demonstrate how to place it on clear ground.
- [x] **Get the village working.** Show the player how to gather nearby resources, assign a worker in **Colony** (`C`), and place and finish a Sleeping Hut. Show how to help with construction using `E`.
- [x] **Hand over to normal play.** Make progress visible, resume at the current step after loading, and keep **Skip** available without cancelling the opening Peace Buffer.

**Delivered and verified:** First-time players are guided by the 3D [TutorialBeacon](../scripts/core/tutorial_beacon.gd) (including the 3D directional ground pointer `_leader_pointer` beyond `3.2 m` and `[E]` / `[LMB] Place Here` proximity prompts), Valley Radar rings, HUD checklists and button highlights, `BuildDrawer` recommendations and gold `Place` action highlight, and `ColonyDrawer` Step 3 `Builder / Crafter` role dropdown / Workforce `+` highlights through recruiting three tribesfolk, lighting the Campfire, harvesting, assigning a role, placing and finishing a Sleeping Hut with `E`, and testing combat.

**Verification probe:** [verify_opening_tutorial.gd](../scripts/tools/verify_opening_tutorial.gd) steps from New Game through `E` recruitment, `B` Campfire founding, `E` harvest + `C` role assignment, Sleeping Hut placement + `E` construction assist, Step 4 save/load resumption, Step 5 combat handover, directional pointer & in-drawer highlight checks, and `Skip` + Peace Buffer preservation.

[Awakening Guide rules](../scripts/core/awakening_guide.gd) · [Tutorial beacon](../scripts/core/tutorial_beacon.gd) · [HUD prompts](../scripts/ui/hud_controller.gd) · [Leader interactions](../scripts/entities/player_controller.gd) · [Opening tutorial verifier](../scripts/tools/verify_opening_tutorial.gd) · [Campaign UI verifier](../scripts/tools/verify_campaign_ui.gd)

## Skinned roster expansion

All seven live lineages have six skinned bodies. Adult warriors, workers, nomads, and leaders use the shared equipment kits, and Farmers reuse the Forager kit. The asset catalog records production coverage. [Asset rollout](../tools/assets/OVERHAUL.md#asset-rollout)

## Larger valley and accessible world map

Both valleys include the Slateback Boar and Reedjaw in layout-specific territories. Standing-Stone Gate shipped after traversal checks at all eight placement rotations. [Gate review](../tools/assets/README.md#standing-stone-gate)

- [x] **Give tribes more room.** The 760 m layout gives the settled starting sites at least 170 m of separation and a 62 m growth radius. The nearest rival is about 197 m away.
- [x] **Extend the shared world layout.** Each layout defines its own camps, caves, wildlife territories, fords, and movement, building, camera, and radar bounds. Starting camps keep nearby trees, stone, flint, and berries.
- [x] **Keep distant tribes active.** The expanded valley checks cover civilian hauling, distant construction, raid travel and ford routing. The opening Peace Buffer remains 210 seconds. Extended raid recovery and large-colony throughput are follow-up work.
- [x] **Add a full-screen World Map.** `M` or a Valley Radar click opens a pannable map with zoom, camps, caves, fords, the player, and the current objective. Left-click places a waypoint on the map and radar. `Tab` opens Tribal Command. Fog of war remains a potential future addition.
- [x] **Version the layout in saves.** `v4` records the layout ID. `v1` through `v3` load in `valley_classic_380` with their saved coordinates. Switching layouts regenerates the appropriate terrain and caves.

**Ready to ship when** all starting tribes can grow a useful colony, resources and crossings are reachable, raids still travel and resolve, and map markers agree with in-world positions across pan, zoom, and save/load.

The expanded valley verifier covers camp spacing, cross-bank routes, distant colony construction, world-to-map projection through pan and zoom, waypoint placement, and layout save/load. The UI verifier covers both map entry points and `Tab` routing at all three supported review sizes. [Expanded valley verifier](../scripts/tools/verify_expanded_valley.gd) · [Campaign UI verifier](../scripts/tools/verify_campaign_ui.gd)

[Terrain and spawning](../scripts/systems/world_generator.gd) · [Camp presets](../scripts/core/game_data.gd) · [Radar](../scripts/ui/minimap_widget.gd) · [HUD keyboard routing](../scripts/ui/hud_controller.gd) · [Save handling](../scripts/core/campaign_save.gd)

## Tribal leaders and diplomacy

Build on the leaders already present in the player tribe and rival colonies. Give every settled tribe and independent village a named leader who is both its strongest individual fighter and its diplomatic representative.

- [x] **Make leaders easy to recognise.** Settled leaders have faction-specific crests and titles alongside their names and lineage silhouettes.
- [x] **Negotiate with the leader.** Press `E` nearby for gifts, peace, and alliance actions. Diplomacy lists the live representative’s name and location.
- [x] **Handle succession and conquest together.** A living settlement facing a third-party leader kill can promote an adult successor. Player and qualifying allied victories preserve their conquest decisions across save and load. Tributaries appoint a representative and deliver available stock on day changes. Peace blocks new hostilities through two day changes.

**Ready to ship when** a player can identify a village's strongest fighter as its leader, negotiate an alliance with that leader, and find the correct representative after succession or reload.

The Forward+ probe covers `E` negotiation, gifts, alliance, truce expiry, stock-backed tribute, succession, and conquest reload. [Diplomacy verifier](../scripts/tools/verify_diplomacy_leaders.gd)

[Leader spawning](../scripts/systems/world_generator.gd) · [Succession](../scripts/systems/faction_controller.gd) · [Diplomacy actions](../scripts/systems/combat_command_system.gd) · [Conquest and faction state](../scripts/core/game_state.gd)

## Taming, farming, and mounts

Delivered 21 November 2026. Build both structures from `B` → Settlement and check their status in `C` → Fields & Herds.

- [x] **Animal taming.** With a completed Animal Pen, the leader can approach a Deer, Tusked Boar, or Woolly Mammoth and spend eight Food with `E`. A successful tame walks to its pen. Deer flee after refusing food, while boars and mammoths retaliate.
- [x] **Crop farming.** Assign a Farmer from the Colony drawer. Farmers plant, tend, and harvest crops, then haul the food to storage. Tended fields ripen sooner and yield 24 Food. Untended fields yield 18.
- [x] **Animal husbandry.** Each pen holds up to six animals. Feeding and breeding draw from tribal Food. Surplus adults can be harvested through the Colony drawer while leaving a breeding pair of each species.
- [x] **Mounts.** Two pen feedings train an adult. The Woolly Mammoth moves at `1.15×` the leader's walk, the Tusked Boar at `1.32×`, and the Deer at `1.58×`. Use `E` to mount and to dismount into clear space. Each mount uses its own collision capsule, animated seat, and camera height. Leader combat actions resume on foot.

The Forward+ probe covers crop work and hauling, taming success and failure, travel to the pen, feeding and breeding, and movement speed, dismounting, and save recovery for each mount. [Farming and taming verifier](../scripts/tools/verify_farming_taming.gd)

[Wildlife behavior](../scripts/entities/wildlife_entity.gd) · [Worker routines](../scripts/entities/unit_ai_routines.gd) · [Leader controls](../scripts/entities/player_controller.gd) · [Save handling](../scripts/core/campaign_save.gd)

## Tribal leveling, perks, and skills

> **Status: Delivered (22 November 2026)** — Implemented in [Phase 6](ROADMAP.md#phase-6-tribal-level-perks--skills-system--opening-tutorial-polish-completed-22-nov-2026) and verified by [verify_perks_leveling.gd](../scripts/tools/verify_perks_leveling.gd).

- [x] **Tribal XP and levels (`1..12`).** Tribes earn XP from recruiting, constructing buildings, resource drop-offs, crafting, hunting, taming, advancing tech tiers, and forging alliances (`xp_for_next_level = 80 + (lvl - 1) * 55`). Level-ups grant `+1` Skill Point and heal the faction leader `+30 HP`.
- [x] **Three-branch perk tree (`K`).** [PerksDrawer](../scripts/ui/drawers/perks_drawer.gd) presents 12 multi-rank perks across *Masonry & Settlement*, *Chieftain & Lineage Might*, and *Kinship & Warband Mastery*, backed by [PerkSystem](../scripts/core/perk_system.gd).
- [x] **Unlock gating and colony scaling.** Advanced buildings (`STORAGE_PIT`, `CROP_FIELD`, `BARRACKS`, `SHAMAN_SHACK`, `STANDING_STONE_GATE`, `ANIMAL_PEN`, `WATCHTOWER`) unlock via Masonry and Kinship perks in `BuildDrawer` and rival AI, while *Call of the Hearth* unlocks Nomad Villager hiring in `ColonyDrawer`, *Barracks Drillmasters* raises training past Rank V up to Rank VIII, and *Battle-Hardened Veterans* awards live combat Training XP and stockpile auto-equip.
- [x] **Rival scaling and baseline invariance.** Settled rival tribes earn XP and automatically spend Skill Points via personality priority tables. At Lv.1 with 0 perks, all multipliers remain `1.0`, preserving legacy saves and baseline tests.

[Perk rules](../scripts/core/perk_system.gd) · [Perks drawer](../scripts/ui/drawers/perks_drawer.gd) · [Perks verifier](../scripts/tools/verify_perks_leveling.gd) · [Campaign state](../scripts/core/game_state.gd)

## Sequential Milestone Queue (Phases 7–9)

> **Delivered 22 November 2026.** These phases landed on `main` with a Forward+ gate between phases. [Roadmap](ROADMAP.md#phases-79-and-verification-gates)

### Phase 7 (Plan 1): Custom weapons & armor for Leader and tribesfolk
- [x] **Catalog, crafting & loadouts.** Structured weapon (`GREAT_SPEAR`, `STONE_SPEAR`, `FLINT_DIRK`, `HUNTING_BOW`, `WAR_CLUB`, `BARBED_JAVELIN`, `OBSIDIAN_CLEAVER`) and armor (`HIDE_TUNIC`, `BONE_GUARD`, `PELT_MANTLE`, `OBSIDIAN_PLATE`) definitions in [GameData](../scripts/core/game_data.gd), reflected in [UnitStats](../scripts/entities/unit_stats.gd), [CampaignSave](../scripts/core/campaign_save.gd), 3D rigs/meshes ([CragBornTrial](../scripts/entities/crag_born_trial.gd), [HumanMeshBuilder](../scripts/core/human_mesh_builder.gd), [FirstPersonViewmodel](../scripts/entities/first_person_viewmodel.gd)), [PlayerController](../scripts/entities/player_controller.gd) attacks, and `ColonyDrawer` + `UnitInspector` loadout assignment ([Equipment verifier](../scripts/tools/verify_equipment_system.gd)).

### Phase 8 (Plan 2): Stone Age SFX & dynamic background music
- [x] **Audio pipeline & adaptive music.** Offline synthesized Stone Age foley and music loops under `assets/audio/` ([generator](../tools/audio/generate_stone_age_audio.py)), pooled [SoundManager](../scripts/core/sound_manager.gd) autoload (`Master` / `Music` / `SFX` buses, 2D & 3D cooldown-throttled cues, `TITLE`/`PEACE_DAY`/`NIGHT`/`COMBAT`/`ARENA` crossfading), `SettingsScreen` Audio volume sliders, and gameplay audio hooks ([Audio verifier](../scripts/tools/verify_audio_system.gd)).

### Phase 9 (Plan 3): Blood-Pit Trial Arena
- [x] **Trial arena, isolation & convalescence.** Unlockable `ARENA_PIT` building (`Lv.3` + `BARRACKS_DRILLMASTERS` Rank 1) with `Chieftain's Trial` (1st/3rd-person playable bouts) and spectated `Warband Exhibition` bouts (1–4 trained warriors vs 5 beast/caveman/champion tiers) in [ArenaRules](../scripts/core/arena_rules.gd) for resources, XP, `is_arena_champion` (`+15` Max HP, `1.10x` DMG), and Plan 1 gear rewards, featuring isolated ring combat and non-lethal injury convalescence (`arena_recovery_remaining`) at `SHAMAN_SHACK` / `CAMPFIRE` ([Arena verifier](../scripts/tools/verify_arena_trials.gd)).

## Ranked gameplay and asset proposals

Performance optimization tracks alongside these gameplay proposals — see the [Campaign performance review](PERFORMANCE.md) for current Forward+ measurements and the [Performance plan and handover](PERFORMANCE_HANDOVER.md) for the ordered experiment queue (off-camera damage popups, crowded NPC movement, distant pose sampling, shadows, and worker allocation).

| Rank | Player benefit | Effort and dependencies | First playable release |
| --- | --- | --- | --- |
| 1. Warband rally | A squad separated by terrain or combat can regroup at a visible destination. | Medium. Build on squad orders, the existing hold offsets, and ford-aware navigation. Limit the first release to one squad so formation changes stay legible at choke points. | Give the selected squad one rally marker and a brief order-confirmation sound using the existing warhorn and HUD route. Verify a scattered squad rallies across one ford, takes a new order mid-route, and fits through the gate. |
| 2. Colony job visibility and reservations | Players can see why a worker is idle and finish parallel jobs with less crowding. | Medium. Build on Colony → Workforce, crop and blueprint state, and the Shaman rescue lease pattern. Lease expiry and role changes need explicit coverage. | Show current crop jobs in Fields & Herds, then give Farmers short-lived field claims. Verify three Farmers share two fields and reassign after a field is destroyed or a role changes. |
| 3. Large-battle readability | Players can distinguish orders, ranged attacks, and heavy impacts at command zoom. | Small to medium. Use the shared gear kits, one-shot clips, combat effects, and an audio bus with a limit on concurrent cues. Compare with the stress benchmark to keep the cost measurable. | Add one distinct ranged release cue and one readable heavy-hit effect. Test archers and Brutes in the same four-faction fight at near and far zoom. |
| 4. River Fish Weir | A ford settlement gains a reliable Food job and a reason to expand along the river. | Medium. The reviewed GLB needs stages, legal bank placement, and a workforce and hauling hook. Ford clearance constrains the footprint. | One buildable weir on a valid bank, one worker job, and Food delivered to existing storage. Verify rotated placement and an unblocked ford after save/load. [Prototype](../tools/assets/examples/WILDCARD.md) |
