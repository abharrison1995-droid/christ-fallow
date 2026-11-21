# Future development

See the [master roadmap](ROADMAP.md) for sequencing. New campaigns use the 760 m valley. Legacy campaigns keep their original terrain. [Shared layout definitions](../scripts/core/world_layout.gd)

## Playable opening tutorial

> **Status: Delivered (20 November 2026)** — Implemented in [Phase 2A](ROADMAP.md#slice-2a--playable-opening-tutorial) and verified by [verify_opening_tutorial.gd](../scripts/tools/verify_opening_tutorial.gd).

Build on the Awakening Guide with a hands-on tutorial at the start of **New Game**. Teach one action at a time in the player's own campaign so the tribe and buildings carry into normal play.

- [x] **Recruit the first tribesfolk.** Point out a nearby wanderer, show the `E` recruit prompt as the leader approaches, then guide the player through recruiting three wanderers.
- [x] **Found the village.** Highlight **Build** (`B`), guide the player to the Tribal Campfire, and demonstrate how to place it on clear ground.
- [x] **Get the village working.** Show the player how to gather nearby resources, assign a worker in **Colony** (`C`), and place and finish a Sleeping Hut. Show how to help with construction using `E`.
- [x] **Hand over to normal play.** Make progress visible, resume at the current step after loading, and keep **Skip** available without cancelling the opening Peace Buffer.

**Delivered and verified:** First-time players are guided by the 3D [TutorialBeacon](../scripts/core/tutorial_beacon.gd), Valley Radar rings, HUD checklists and button highlights, and `BuildDrawer` recommendations through recruiting three tribesfolk, lighting the Campfire, harvesting, assigning a role, placing and finishing a Sleeping Hut with `E`, and testing combat.

**Verification probe:** [verify_opening_tutorial.gd](../scripts/tools/verify_opening_tutorial.gd) steps from New Game through `E` recruitment, `B` Campfire founding, `E` harvest + `C` role assignment, Sleeping Hut placement + `E` construction assist, Step 4 save/load resumption, Step 5 combat handover, and `Skip` + Peace Buffer preservation.

[Awakening Guide rules](../scripts/core/awakening_guide.gd) · [Tutorial beacon](../scripts/core/tutorial_beacon.gd) · [HUD prompts](../scripts/ui/hud_controller.gd) · [Leader interactions](../scripts/entities/player_controller.gd) · [Opening tutorial verifier](../scripts/tools/verify_opening_tutorial.gd) · [Campaign UI verifier](../scripts/tools/verify_campaign_ui.gd)

## Skinned roster expansion

Goliath and Swift-Kin Foragers and adult Spearmen share the promoted Crag-Born rig and equipment kits. Stalker, Ash-Walker, Fen-Tidal, Cave-Kin, and additional roles are candidates for future asset passes. [Asset rollout](../tools/assets/OVERHAUL.md#asset-rollout)

## Larger valley and accessible world map

Both valleys include the Slateback Boar and Reedjaw in layout-specific territories. Standing-Stone Gate awaits traversal verification. [Asset rollout](../tools/assets/OVERHAUL.md#asset-rollout)

- [x] **Give tribes more room.** The 760 m layout gives the settled starting sites at least 170 m of separation and a 62 m growth radius. The nearest rival is about 197 m away.
- [x] **Extend the shared world layout.** Each layout defines its own camps, caves, wildlife territories, fords, and movement, building, camera, and radar bounds. Starting camps keep nearby trees, stone, flint, and berries.
- [ ] **Keep distant tribes active.** Check camp construction, civilian hauling, raid arrival and return, enemy scan cost, and routes around rivers or walls. Preserve the 210-second opening Peace Buffer in the first prototype so spacing can be measured independently. Adjust timing after testing.
- [x] **Add a full-screen World Map.** `M` or a Valley Radar click opens a pannable map with zoom, camps, caves, fords, the player, and the current objective. Left-click places a waypoint on the map and radar. `Tab` opens Tribal Command. Fog of war remains a potential future addition.
- [x] **Version the layout in saves.** `v4` records the layout ID. `v1` through `v3` load in `valley_classic_380` with their saved coordinates. Switching layouts regenerates the appropriate terrain and caves.

**Ready to ship when** all starting tribes can grow a useful colony, resources and crossings are reachable, raids still travel and resolve, and map markers agree with in-world positions across pan, zoom, and save/load.

The expanded valley verifier covers camp spacing, cross-bank routes, distant colony construction, world-to-map projection through pan and zoom, waypoint placement, and layout save/load. The UI verifier covers both map entry points and `Tab` routing at all three supported review sizes. [Expanded valley verifier](../scripts/tools/verify_expanded_valley.gd) · [Campaign UI verifier](../scripts/tools/verify_campaign_ui.gd)

[Terrain and spawning](../scripts/systems/world_generator.gd) · [Camp presets](../scripts/core/game_data.gd) · [Radar](../scripts/ui/minimap_widget.gd) · [HUD keyboard routing](../scripts/ui/hud_controller.gd) · [Save handling](../scripts/core/campaign_save.gd)

## Tribal leaders and diplomacy

Build on the leaders already present in the player tribe and rival colonies. Give every settled tribe and independent village a named leader who is both its strongest individual fighter and its diplomatic representative.

- [ ] **Make leaders easy to recognise.** Give each leader a distinctive appearance and a clear name and title at gameplay distance. Set their combat strength above the rest of their tribe while preserving differences between lineages.
- [ ] **Negotiate with the leader.** Let the player meet a village's leader to offer gifts, negotiate peace, or propose an alliance. Show the current representative in the Diplomacy panel so players know whom to approach.
- [ ] **Handle succession and conquest together.** Decide when a surviving tribe appoints a successor and when the leader's defeat instead triggers a conquest decision. Update the village and Diplomacy panel to point to the successor, and preserve leadership and diplomatic agreements across save and load.

**Ready to ship when** a player can identify a village's strongest fighter as its leader, negotiate an alliance with that leader, and find the correct representative after succession or reload.

**Verification probe:** Run a `SceneTree` campaign probe verifying leader distinctiveness, in-person gift/peace/alliance negotiation, post-succession Diplomacy representative updates, and save/load preservation of agreements and `TRIBUTARY`/`truce_timer` state.

[Leader spawning](../scripts/systems/world_generator.gd) · [Succession](../scripts/systems/faction_controller.gd) · [Diplomacy actions](../scripts/systems/combat_command_system.gd) · [Conquest and faction state](../scripts/core/game_state.gd)

## Taming, farming, and mounts

- [ ] **Animal taming.** Let tribesfolk tame eligible wild animals and bring them back to the settlement. Define which species can be tamed and what happens if a taming attempt fails.
- [ ] **Crop farming.** Let players place fields and assign workers to plant, tend, harvest, and haul crops to storage. Balance harvest yields and labour against hunting and foraging.
- [ ] **Animal husbandry.** Let the tribe keep suitable tamed animals in pens or pastures, feed and breed them, and collect resources from the herd. Check whether a settlement can sustain livestock as it grows.
- [ ] **Mounts.** Let the leader mount, ride, and dismount suitable tamed animals. Check movement, camera, and rider animations before expanding to other riders or mounted combat.

**Ready to ship when** a settlement can complete a crop cycle, sustain and grow a herd, and ride a trained animal. Save and load must restore crop growth, animal ownership, herd state, and rider assignments.

**Verification probe:** Run a `SceneTree` simulation + save/load probe covering taming success/failure, crop plant/tend/harvest/haul, pasture breeding, leader mount/dismount movement/camera, and round-trip persistence.

[Wildlife behavior](../scripts/entities/wildlife_entity.gd) · [Worker routines](../scripts/entities/unit_ai_routines.gd) · [Leader controls](../scripts/entities/player_controller.gd) · [Save handling](../scripts/core/campaign_save.gd)
