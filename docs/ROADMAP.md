# Christ Fallow — Master Roadmap & Stabilization Plan

> Unified engineering, UI/UX, gameplay, and 3D asset roadmap following the [20 November 2026 refactor](REFACTOR.md). For architecture and file routing, see the [agent guide](../AGENTS.md). For quick session-transfer context, see the [engineering handoff](HANDOFF.md).

## Current progress snapshot (21 November 2026)

### Shipped & verified
- **Core Stone Age campaign loop**. Title and Awakening, six playable lineages, a 210 s Peace Buffer, the five-step Awakening Guide, gathering, hunting, crafting, three gear tiers, religion, work schedules, training, Tribal Warhorn, diplomacy, conquest, and succession. The campaign writes `v4` JSON saves and accepts versions 1–4.
- **Refactored runtime boundaries**: `CampaignSession` lifecycle ownership, `GameState` campaign rules, `CampaignSave`/`CampaignStorage`, `AwakeningGuide`, `UnitStats`, `UnitAIRoutines`, `BlessingEffects`, `WorldLayout`, `FeatureDrawer` views, `UnitInspector`, `CampaignOverlays`, and `Preferences`.
- **Phase 0 stabilization (`Slices 0A`–`0E`, Completed 20 Nov 2026)**: Fixed conquest/wounded/pause lifecycle leaks (`0A`), wildlife defense/economy/Warhorn/tech-tier/bounds/combat parity (`0B`), save/load state isolation, cooldown/buff/timer persistence, live `KRAG_UL` HP scaling, and synchronous leader succession (`0C`), HUD focus/layout/diplomacy/radar/control polish (`0D`), and `DUAL_SHEATH`/GLB blueprint hologram/PSX material/trial rig alignment (`0E`). 
- **Phase 1 simulation performance & navigation (Completed 20 Nov 2026)**: `SpatialIndex` (XZ hash grid plus per-faction caches) replaced per-frame container scans, `ValleyNavigation` (`AStarGrid2D`) routes units around constructed buildings and across river fords, and `WorldLayout` now owns the river, ford, camera and scan constants. See [Phase 1](#phase-1-simulation-performance--navigation-foundation) for the benchmark table.
- **Phase 2A playable opening tutorial (Completed 20 Nov 2026)**: Single-source `AwakeningGuide.get_objective_target()`, 3D `TutorialBeacon` with proximity prompts (`[E] Recruit`, `[E] Harvest`, `[E] Help Build`), HUD step checklists and `Build`/`Colony` highlights, `BuildDrawer` recommendations, Valley Radar pulsing rings, and Sleeping Hut construction completion for Step 4.
- **Phase 2B skinned rig action clips & Crag-Born promotion (Completed 20 Nov 2026)**: Added `Attack`, `Work`, `Hit`, `Death`, and `Wounded` skeletal clips across `tribesman_base.glb` and `crag_born_{broad,braided,child}.glb`, replaced procedural fallback swaps with zero-swap shader hit-flash/death handling, and promoted Crag-Born Foragers and adult Spearmen to default-enabled (`--procedural-roster` opts out).
- **Automated baselines passing (20 Nov 2026)**:
  - `scripts/tools/verify_opening_tutorial.gd` (`1600×900`): `OPENING TUTORIAL VERIFICATION PASSED` (exit `0`, `0` script errors/warnings).
  - `scripts/tools/verify_campaign_save.gd`: `CAMPAIGN SAVE VERIFICATION PASSED` (exit `0`, `0` script errors/warnings).
  - `scripts/tools/verify_campaign_ui.gd` (`1280×720`, `1600×900 --large-ui`, `1920×810 --large-ui`): `CAMPAIGN UI VERIFICATION PASSED` + `PASS action Quit` (exit `0`, `0` script errors/warnings).
  - `scripts/tools/verify_phase1_nav.gd`: `PHASE 1 NAV & SPATIAL VERIFICATION PASSED` (exit `0`; index vs container parity across spawn, cell moves, faction conversion, death, construction, rubble and save/load; palisade detour and rubble reopening; ford crossing).
  - `scripts/tools/benchmark_simulation.gd` (seed `17394`) completes with `SIMULATION BENCHMARK COMPLETE`; see the Phase 1 table.
  - `scripts/tools/verify_glb_assets.gd --require-gameplay-rig`, `verify_crag_born.gd` (default promoted mode, `--check-default-roster`, and `--procedural-roster` opt-out), `verify_valley_assets.gd`, and `scenes/asset_showcase.tscn` (7 PNGs) passed in Forward+.

### Partially delivered (3D assets)
- **Buildings**. All fourteen buildable types use imported four-stage models. Blueprints and placement ghosts use a tinted intact stage. Standing-Stone Gate has separate pier collision and verified traversal. [Asset catalog](../tools/assets/CATALOG.md#live-assets-by-type)
- **Characters & gear**. All seven lineages have six skinned bodies for Foragers and adult Spearmen. Nomads mount the Cave-Kin kit. `--procedural-roster` switches the roster to procedural models. `--skinned-tribesman-trial` enables the base skinned rig for the player leader. [Asset catalog](../tools/assets/CATALOG.md#skinned-lineage-bodies-and-gear)
- **Environment & wildlife**. Four scenery props and all eight wildlife species use imported models. Mammoth and Cave Bear have skeletal attacks for their existing area damage. [Asset catalog](../tools/assets/CATALOG.md#valley-scenery-and-wildlife)
- **Asset rollout complete**. All seven six-body lineages, fourteen shared kits, Flintmask Scout, fourteen building models, and eight wildlife models are verified in Forward+. Six wildcard prototypes have individual GLBs and two Forward+ review sheets. [Production batches](../tools/assets/OVERHAUL.md#production-batches) · [Wildcard review](../tools/assets/examples/WILDCARD.md)

### Key architectural & hygiene bottlenecks
- **Navigation**. The active layout defines river crossings and common scan distances. `HumanUnit` steering uses cached paths beyond 6 m from the target. [Valley navigation](../scripts/core/valley_navigation.gd)
- **Repo hygiene**: Local Git is initialized on `main` with `.gitignore` excluding `.godot/` and temp outputs. `ChristFallow.exe` (dated `2026-11-18`) and `Christ Fallow.lnk` lag the `2026-11-20` source.

---

## Phase 0: Mechanics, UI & Asset Stabilization (Bug-Fix Plan)

> **Status: Completed (20 Nov 2026)** — Slices `0A`–`0E` are implemented and verified. ([Phase 1](#phase-1-simulation-performance--navigation-foundation) and [Slices 2A–2B](#phase-2-playable-opening-tutorial--asset-rig-promotion) are also complete.)

### Slice 0A — Campaign Lifecycle, Conquest, Wounded Softlocks & Pause Guards

> **Completed (20 Nov 2026)**

1. **RAZE conquest spares living enemy leader (`High`)** — [game_state.gd](../scripts/core/game_state.gd#L699-L713) (`resolve_conquest`).
   - *Root cause*: `if not u.is_leader: u.queue_free()` spares the enemy leader after `RAZE`, leaving an undefeated-acting leader on a defeated faction.
   - *Fix*: Free all `survivor_units` when `RAZE` is chosen.
2. **Conquest softlock when non-allied AI, Cavemen, or Wildlife eliminate a rival (`High`)** — [game_state.gd](../scripts/core/game_state.gd#L652-L665) (`trigger_conquest_if_eligible`), [game_state.gd](../scripts/core/game_state.gd#L741-L755) (`check_victory_conditions`).
   - *Root cause*: Non-player / non-allied attackers return early from `trigger_conquest_if_eligible()`, leaving a wiped rival with `is_defeated == false` so `check_victory_conditions()` never completes.
   - *Fix*: Mark eliminated rivals defeated when their Campfire/Totem and Leader (or all living units/buildings) are destroyed by third parties, and re-run `check_victory_conditions()`.
3. **Wounded `being_rescued` permanent limbo & defeat softlock (`High`)** — [player_controller.gd](../scripts/entities/player_controller.gd#L492-L494), [unit_ai_routines.gd](../scripts/entities/unit_ai_routines.gd#L112), [human_unit.gd](../scripts/entities/human_unit.gd#L801-L806), [game_state.gd](../scripts/core/game_state.gd#L729-L738).
   - *Root cause*: Field aid without a Shaman Shack sets `being_rescued = true` permanently, Shamans claim `being_rescued = true` before arriving and never clear it if interrupted, and `found_rebel_faction(self)` does not re-check defeat while `wounded_player_units > 0` blocks defeat.
   - *Fix*: Only mark `being_rescued` via an active rescuer/lease (never permanently without a shack), clear stale claims when the Shaman stops rescuing, and call `GameState.check_victory_conditions()` after defection.
4. **Post-game-over & paused simulation leaks (`High`)** — [human_unit.gd](../scripts/entities/human_unit.gd#L740), [building_entity.gd](../scripts/entities/building_entity.gd#L460-L470), [wildlife_entity.gd](../scripts/entities/wildlife_entity.gd#L263), [player_controller.gd](../scripts/entities/player_controller.gd#L210-L231).
   - *Root cause*: Entities omit `GameState.campaign_finished` checks, `BuildingEntity` ticks `_sink_timer` before the pause check, and `PlayerController` ticks `_blessing_cd`/`_dash_cd`/`_javelin_cd`/`_attack_cd`/`_harvest_cd` while paused or finished.
   - *Fix*: Guard all entity `_physics_process` logic (including rubble sinking) and `PlayerController` cooldown ticks with `not GameState.game_active or GameState.is_paused or GameState.campaign_finished`.
5. **`promote_to_player_leader()` missing ring, armor & state cleanup (`Medium`)** — [human_unit.gd](../scripts/entities/human_unit.gd#L682-L693).
   - *Root cause*: Promoted successor lacks `_selection_ring` (only built in `_create_hp_bar` at spawn), keeps unarmored civilian `has_armor`, and does not clear `is_raiding`.
   - *Fix*: Ensure `_selection_ring` is created, grant leader gear/armor, and clear `is_raiding` / `_retreating_to_heal`.
6. **Stale `camp_position` if original Campfire is destroyed (`Medium`)** — [player_controller.gd](../scripts/entities/player_controller.gd#L338-L342), [building_entity.gd](../scripts/entities/building_entity.gd#L382-L385).
   - *Root cause*: `factions[0]["camp_position"]` is only written while `not is_founded`, never refreshed when a replacement Campfire is built after the first is destroyed.
   - *Fix*: Update `camp_position` when a new `CAMPFIRE` completes if no prior living Campfire exists.

**Verification criteria (0A)**: Extend `verify_campaign_save.gd` / a `SceneTree` probe to verify: (a) `RAZE` frees the enemy leader; (b) third-party rival wipe marks `is_defeated` and allows victory; (c) field-aided wounded units still defect and trigger defeat if no healthy units remain; (d) entity AI, rubble sinking, and `PlayerController` cooldowns freeze when paused or `campaign_finished`.

### Slice 0B — Combat, AI Schedules, Economy & World Bounds

> **Completed (20 Nov 2026)**

1. **Warriors & Watchtowers ignore hostile Wildlife (`High`)** — [human_unit.gd](../scripts/entities/human_unit.gd#L903-L910), [unit_ai_routines.gd](../scripts/entities/unit_ai_routines.gd#L338-L371), [building_entity.gd](../scripts/entities/building_entity.gd#L570-L587).
   - *Fix*: Fall back to `find_nearest_hostile_wildlife` in warrior target acquisition and scan hostile wildlife in Watchtower `_find_nearest_hostile()`.
2. **Stoneknappers lock onto Stone or Flint forever (`High`)** — [unit_ai_routines.gd](../scripts/entities/unit_ai_routines.gd#L164-L201).
   - *Fix*: Alternate `FLINT` vs `STONE` target selection by unit parity or lowest faction resource stockpile, or clear `_target_node` after drop-off.
3. **Warhorn arms children & gives militia Archers melee range (`High`)** — [human_unit.gd](../scripts/entities/human_unit.gd), [unit_stats.gd](../scripts/entities/unit_stats.gd#L62-L75).
   - *Fix*: Guard `_get_class_key()`, `_refresh_gear_visual()`, and `_process_tribal_ai()` with `not is_child`, and keep Warhorn militia stats aligned with their visual/weapon class (or enforce `SPEARMAN` militia).
4. **Tech Tier upgrade grants free gear tiers to living units (`High`)** — [faction_controller.gd](../scripts/systems/faction_controller.gd#L131-L133), [human_unit.gd](../scripts/entities/human_unit.gd#L715).
   - *Fix*: Advance `fdata["tech_tier"]` for future crafts and let `try_equip_from_stockpile()` upgrade existing units when weapons/armor are actually crafted (optionally keeping Leader auto-scaled).
5. **AI & Wildlife walk off `380×380 m` world edge (`High`)** — [human_unit.gd](../scripts/entities/human_unit.gd#L839), [wildlife_entity.gd](../scripts/entities/wildlife_entity.gd#L321), [world_generator.gd](../scripts/systems/world_generator.gd).
   - *Fix*: Clamp `HumanUnit` and `WildlifeEntity` XZ positions inside `Layout` bounds or add perimeter rim colliders.
6. **Civilians attack post-truce targets; `ANCESTRAL_STONE` discount leaks (`Medium`)** — [unit_ai_routines.gd](../scripts/entities/unit_ai_routines.gd#L394), [game_state.gd](../scripts/core/game_state.gd#L552-L571).
   - *Fix*: Re-check `GameState.is_hostile()` on `_self_defense_target` before punching; scope `ANCESTRAL_STONE` `-20%` wood/stone discount to building placement only.
7. **Projectile vertical `look_at` error & low-FPS tunneling (`Medium`)** — [projectile_3d.gd](../scripts/entities/projectile_3d.gd).
   - *Fix*: Guard `look_at` against near-vertical velocity vectors and perform swept segment checks from `prev_pos` to `next_pos`.
8. **Combat/economy formula & propagation mismatches (`Medium`–`Low`)**:
   - Leader javelin scales off melee `attack_damage` instead of `ranged_attack_damage` ([player_controller.gd](../scripts/entities/player_controller.gd#L449)) — decide explicitly per [OVERHAUL.md](../tools/assets/OVERHAUL.md#proposed-damage-review).
   - `FORAGER_LODGE` omits Hunter animal yields ([wildlife_entity.gd](../scripts/entities/wildlife_entity.gd#L162-L169)); `_try_hunter_work` hardcodes `18.0` arrow damage ([unit_ai_routines.gd](../scripts/entities/unit_ai_routines.gd#L154)).
   - `VALK_TOR` omits spear knockback bonus ([human_unit.gd](../scripts/entities/human_unit.gd#L497)) and `aoe_damage` takes first 5 in tree order instead of nearest 5 ([blessing_effects.gd](../scripts/systems/blessing_effects.gd#L49-L66)).
   - `toggle_fire_at_will()` misses newly assigned warriors and `CHARGE`/`GUARD_BASE` ([combat_command_system.gd](../scripts/systems/combat_command_system.gd#L64-L70)); `preach_religion()` does not recalculate converted rival unit stats (`line 135`).
   - `Campfire` aura heals 24/7 and stacks across multiple campfires ([building_entity.gd](../scripts/entities/building_entity.gd#L484-L505)).
   - Crafting hardcodes `3.2 s` ignoring `CRAFT_RECIPES[k]["craft_time"]` and builders/shamans/trainees always pick building index `[0]` instead of nearest ([unit_ai_routines.gd](../scripts/entities/unit_ai_routines.gd)); warriors skip Dusk/Night eat & sleep routines ([human_unit.gd](../scripts/entities/human_unit.gd#L905-L922)); Cavemen march exclusively on player camp ([human_unit.gd](../scripts/entities/human_unit.gd#L865-L872)).

**Verification criteria (0B)**: Extend fixed-input combat/economy checks in `verify_campaign_save.gd` (or a dedicated simulation probe) for Watchtower/warrior wildlife defense, Stoneknapper Flint+Stone balance, Warhorn child exclusion, tech-tier stockpile consumption, and XZ boundary clamping.

### Slice 0C — Save/Load Fidelity & State Isolation

> **Completed (20 Nov 2026)**

1. **Unserialized / un-reset cooldowns, buffs, carry & AI timers (`Medium`)** — [player_controller.gd](../scripts/entities/player_controller.gd), [human_unit.gd](../scripts/entities/human_unit.gd#L1261-L1298), [faction_controller.gd](../scripts/systems/faction_controller.gd#L4-L16).
   - *Fix*: Reset `PlayerController` cooldowns on `setup()`/`attach_leader()`, serialize remaining unit/faction/player cooldowns and daily flags (`_dusk_eaten_today`, `_night_morale_today`, `_buff_*`, `_carry_*`), and validate in [campaign_save.gd](../scripts/core/campaign_save.gd).
2. **Legacy `v1`/`v2` in-session reload wildlife leak (`Medium`)** — [world_generator.gd](../scripts/systems/world_generator.gd#L471-L473).
   - *Root cause*: `wildlife_container` is not cleared on in-session load when `save` lacks `"wildlife"`.
   - *Fix*: Clear and respawn baseline wildlife (or require explicit snapshot handling) consistently without leaking previous-session animals.
3. **Building `hp` clamp & live `KRAG_UL` max HP update (`Medium`)** — [building_entity.gd](../scripts/entities/building_entity.gd#L604-L608), [game_state.gd](../scripts/core/game_state.gd#L514-L521).
   - *Fix*: Update existing building `max_hp` (and scale `hp`) on `select_player_patron()`, and clamp restored `hp <= max_hp`.
4. **1-frame leaderless save window during succession (`Medium`)** — [human_unit.gd](../scripts/entities/human_unit.gd#L551-L554).
   - *Fix*: Guard or finalize succession synchronously / handle `player_leader_id`-less mid-succession recovery cleanly on load.
5. **Expand `verify_campaign_save.gd` coverage (`Medium`)**: Assert rubble exclusion (`damage_stage == 3`), multi-faction + faction-6 `pending_conquests`, `captured_cavemen`, `craft_queue`, `blessing_cooldown`, wounded/healing/revolting units, mismatched `player_leader_id`, and `PatronGod`/`Tenet` + `AwakeningGuide` steps `1/2/4/skip`.

**Verification criteria (0C)**: `verify_campaign_save.gd` passes with all new assertions and `0` script errors across `v1`/`v2`/`v3` fixtures and in-session reloads.

### Slice 0D — UI Focus, Layout, Controls & Visual Accuracy

> **Completed (20 Nov 2026)**

1. **Persistent HUD & Inspector controls steal `Space` (Dodge) & `Arrows` (`High`)** — [hud_controller.gd](../scripts/ui/hud_controller.gd), [unit_inspector.gd](../scripts/ui/unit_inspector.gd#L79-L115).
   - *Fix*: Call `release_focus()` on HUD/inspector click handlers while preserving `FOCUS_ALL` for keyboard navigation.
2. **`DiplomacyDrawer` opinion breakdown mismatch, stale `_selected_faction` & double refresh (`High`/`Medium`)** — [diplomacy_drawer.gd](../scripts/ui/drawers/diplomacy_drawer.gd), [game_state.gd](../scripts/core/game_state.gd#L342-L384).
   - *Fix*: Share an opinion-breakdown helper from `GameState` (including `PEACEFUL_OFFERING` `+15` and state clamps), reset/validate `_selected_faction` across reloads, remove redundant `refresh()` calls, and add inline ally-raid target feedback.
3. **`_drawer_panel` overlaps `_minimap_panel` & `_squad_bar` at `ui_scale = 1.1` (`High`)** — [hud_controller.gd](../scripts/ui/hud_controller.gd).
   - *Fix*: Compute `_drawer_panel` horizontal and bottom offsets dynamically in `_align_upper_hud()` clear of `_minimap_panel` and `_squad_bar`.
4. **`HUDController._input` intercepts `Esc` before open `OptionButton` popups (`Medium`)** — [hud_controller.gd](../scripts/ui/hud_controller.gd#L124-L144).
   - *Fix*: Check for active popup menus (or move non-overlay `Esc` handling to `_unhandled_key_input()`).
5. **`BuildDrawer` unbuffed costs/HP & procedural-only preview (`Medium`/`Low`)** — [build_drawer.gd](../scripts/ui/drawers/build_drawer.gd#L59-L89).
   - *Fix*: Display effective `ANCESTRAL_STONE` cost & `KRAG_UL` HP and preview `Stage_Intact` from `build_building_stages()`.
6. **`ColonyDrawer` Crafting tab stale `captured_cavemen` / `CRAFTING_PIT` (`Medium`)** — [colony_drawer.gd](../scripts/ui/drawers/colony_drawer.gd).
   - *Fix*: Include `captured_cavemen`, `tech_tier`, and `has_building(0, "CRAFTING_PIT", true)` in Crafting live refresh.
7. **`_raid_panel` overlap/z-order & `UnitInspector` wildlife-cleave hijack (`Medium`)** — [hud_controller.gd](../scripts/ui/hud_controller.gd), [player_controller.gd](../scripts/entities/player_controller.gd).
   - *Fix*: Reorder `_raid_panel` above `_drawer_panel` and clear of `_build_banner`; check `wildlife_container` in `_try_inspect_clicked_unit()`'s nearby-combat guard.
8. **Silent `F10` pause failure & wheel zoom over non-scroll HUD (`Medium`)** — [hud_controller.gd](../scripts/ui/hud_controller.gd#L147-L148), [player_controller.gd](../scripts/entities/player_controller.gd#L112-L115).
   - *Fix*: Surface `F10` error to `_overlays._pause_status` when pause is visible; guard wheel zoom with `not _is_pointer_over_ui()`.
9. **Mirrored Valley Radar river & missing Controls entries (`Low`)** — [minimap_widget.gd](../scripts/ui/minimap_widget.gd#L44-L47) vs [world_generator.gd](../scripts/systems/world_generator.gd#L189-L202), [settings_screen.gd](../scripts/ui/settings_screen.gd#L24-L33).
   - *Fix*: Update river endpoints to `(+21, -155)` → `(-117, +155)` and document `LMB` inspect, `Shift + LMB` continuous build, and `R` build-mode exclusion in Settings.
10. **Expand `verify_campaign_ui.gd` coverage**: Add assertions for `Space` Dodge after HUD button clicks, `M`/`H`/`F5`/`1–6`/`F1–F6`/`Q`/`F`/`RMB` parity, `UnitInspector`, Colony `Workforce` & `Crafting`, `DiplomacyDrawer` faction-6 & opinion breakdown, `Event Log +/-`, `Pause -> Settings`, `Defeat`, and non-overlap geometry bounds at `1600×900 --large-ui`.

**Verification criteria (0D)**: `verify_campaign_ui.gd` passes at `1280×720`, `1600×900 --large-ui`, and `1920×810 --large-ui` with zero overlap failures and zero script errors.

### Slice 0E — 3D Asset Pipeline & Trial Rig Parity

> **Completed (20 Nov 2026)**

1. **Missing `DUAL_SHEATH` back gear (`Medium`)** — [game_data.gd](../scripts/core/game_data.gd#L366), [human_mesh_builder.gd](../scripts/core/human_mesh_builder.gd#L480-L536).
   - *Fix*: Add `"DUAL_SHEATH"` mesh geometry to `_build_class_kit()` for `KNIFE_RAIDER`.
2. **Blueprint / ghost GLB parity (`Medium`)** — [world_mesh_builder.gd](../scripts/core/world_mesh_builder.gd#L20-L32), [player_controller.gd](../scripts/entities/player_controller.gd#L101).
   - *Fix*: Clone/tint `Stage_Intact` when an imported `*_stages.glb` exists so blueprints and placement ghosts match finished `SLEEPING_HUT` and `PALISADE_WALL` dimensions.
3. **Scenery & wildlife GLBs bypass PSX material rules (`Low`)** — [world_mesh_builder.gd](../scripts/core/world_mesh_builder.gd).
   - *Fix*: Enforce `TEXTURE_FILTER_NEAREST` and `SPECULAR_DISABLED` on imported scenery and wildlife materials.
4. **`SkinnedTribesmanTrial` vs `CragBornTrial` shader/material parity (`Medium`)** — [skinned_tribesman_trial.gd](../scripts/entities/skinned_tribesman_trial.gd#L32-L89), [crag_born_trial.gd](../scripts/entities/crag_born_trial.gd#L50-L55), [human_unit.gd](../scripts/entities/human_unit.gd), [psx_unit_skinned.gdshader](../scripts/shaders/psx_unit_skinned.gdshader#L10-L43).
   - *Fix*: Align `snap_resolution` / `jitter_intensity`, respect `is_psx_filter_enabled()` on leader spawn (`human_unit.gd:226`), map `Mat_Wood`/`Mat_Flint`/`Mat_Hair` etc. to matching gritty textures, apply `psx_unit_skinned` (or consistent snapping) to `TrialSpear`, keep Crag-Born Foragers in Forager kit when Warhorn militia triggers (`human_unit.gd:230-231`), and audit unused uniforms / NDC snap scaling in `psx_unit_skinned.gdshader`.
5. **Showcase & verifier hygiene (`Low`)** — [asset_showcase.gd](../scripts/tools/asset_showcase.gd), [verify_crag_born.gd](../scripts/tools/verify_crag_born.gd#L173).
   - *Fix*: Remove hardcoded personal UUID default path, add `remove_child(c)` before `queue_free()` in `_clear_stage()`, and replace positional `get_child(2)` lookup with a named or metadata lookup.

**Verification criteria (0E)**: `verify_glb_assets.gd --require-gameplay-rig`, `verify_crag_born.gd --crag-born-trial`, `verify_crag_born.gd --check-default-roster`, `verify_valley_assets.gd`, and `asset_showcase.tscn` (7 PNGs) all pass in Forward+ with 0 errors.

---

## Phase 1: Simulation Performance & Navigation Foundation

> **Status: Completed (20 Nov 2026)** — Prerequisite for [Larger valley and accessible world map](FUTURE.md#larger-valley-and-accessible-world-map) (`760×760 m`). **Active next phase: [Phase 2](#phase-2-playable-opening-tutorial--asset-rig-promotion).**

### Delivered
1. **Spatial index & cached rosters** — [spatial_index.gd](../scripts/core/spatial_index.gd): `20 m` XZ hash grid for units, wildlife and buildings plus per-faction unit/building/leader caches. Entities register in `setup()`, update their cell each physics frame (dictionary writes only when the cell changes) and unregister on death, destruction or `_exit_tree`. `faction_id` and `is_leader` setters on `HumanUnit` (and `faction_id` on `BuildingEntity`) keep the caches correct. `GameState.get_faction_units/get_faction_buildings/get_faction_leader` read the index and fall back to container scans while it is empty. `GameState.rebuild_spatial_systems()` runs after `populate_new_world()` and `restore_from_save()`; `end_campaign()` and world clears empty it.
2. **Staggered scans** — `HumanUnit` caches enemy/wildlife/building scan results with `0.18–0.28 s` jitter, `WildlifeEntity` and Watchtowers scan on the same cadence, idle units and animals skip `move_and_slide()`, and `Projectile3D` queries the index around the swept segment.
3. **WorldLayout parameterization** — [world_layout.gd](../scripts/core/world_layout.gd) holds `RIVER_*`, `RIVER_FORD_*`, `river_crossings()`, `CAMERA_FAR`, `CAMERA_RAY_LENGTH`, `MOUNTAIN_RIM_RADIUS`, `SCATTER_HALF_EXTENT`, `REBEL_CAMP_CLAMP` and `SCAN_RANGE_*`; `world_generator.gd`, `player_controller.gd`, `game_state.gd`, `minimap_widget.gd`, `human_unit.gd` and `unit_ai_routines.gd` use them.
4. **Navigation & river fords** — [valley_navigation.gd](../scripts/core/valley_navigation.gd): `AStarGrid2D` (`4 m` cells, diagonals only without obstacles) with a line-of-sight fast path. Deep river cells are solid except at `3` ford crossings. Constructed buildings register ref-counted obstacle cells and clear them at rubble or free. `HumanUnit._steer_toward()` follows cached paths (repath every `~0.5 s` or when the target moves `> 4 m`). The generator builds flat stone-and-log fords and the minimap marks them.
5. **Verification** — [verify_phase1_nav.gd](../scripts/tools/verify_phase1_nav.gd) and [benchmark_simulation.gd](../scripts/tools/benchmark_simulation.gd).

### Benchmark (seed `17394`, `1280×720`, Intel UHD 620, Forward+, isolated `APPDATA`)

| Scenario | Units / Buildings | Physics median BEFORE | Physics median AFTER | Delta | 100 searches BEFORE | 100 searches AFTER | Delta |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Opening | 43 / 37 | 61.872 ms | 23.943 ms | -61.3% | 14.857 ms | 9.594 ms | -35.4% |
| Developed settlement | 91 / 54 | 104.408 ms | 45.300 ms | -56.6% | 25.954 ms | 20.656 ms | -20.4% |
| Raid | 107 / 55 | 123.930 ms | 41.956 ms | -66.1% | 34.224 ms | 32.440 ms | -5.2% |

Verification status: `verify_phase1_nav.gd`, `verify_campaign_save.gd`, `verify_campaign_ui.gd` (three layouts), `verify_crag_born.gd` (both modes) and `verify_valley_assets.gd` all passed with exit `0`.

---

## Phase 2: Playable Opening Tutorial & Asset Rig Promotion

### Slice 2A — Playable Opening Tutorial

> **Completed (20 Nov 2026)**

- **Single-source objective targeting** ([awakening_guide.gd](../scripts/core/awakening_guide.gd)): Added `AwakeningGuide.get_objective_target(state)` and `find_pending_building()`, and updated Step 4 to guide placing and finishing a constructed `SLEEPING_HUT`.
- **3D beacon & world prompts** ([tutorial_beacon.gd](../scripts/core/tutorial_beacon.gd), [player_controller.gd](../scripts/entities/player_controller.gd)): Added unshaded ground ring + bobbing diamond/chevron marker with proximity `[E] Recruit`, `[E] Harvest`, and `[E] Help Build` prompts, respecting `reduced_motion` and hiding on pause/skip/completion.
- **HUD, Build & Radar guidance** ([hud_controller.gd](../scripts/ui/hud_controller.gd), [build_drawer.gd](../scripts/ui/drawers/build_drawer.gd), [minimap_widget.gd](../scripts/ui/minimap_widget.gd)): Added compact `[x]`/`[ ]` step checklists, gold `Build [B]` / `Colony [C]` button highlights, `RECOMMENDED` building tag + auto-select (`CAMPFIRE` on Step 2, `SLEEPING_HUT` on Step 4), and pulsing golden Valley Radar objective rings.
- **Verification**: [verify_opening_tutorial.gd](../scripts/tools/verify_opening_tutorial.gd) and [verify_campaign_save.gd](../scripts/tools/verify_campaign_save.gd) passed under Forward+ with mid-tutorial save/load, once-only reward, and `Skip` + Peace Buffer assertions.

### Slice 2B — Skinned Rig Action Clips & Crag-Born Rig Promotion

> **Completed (20 Nov 2026)**

- **Skeletal action clips** ([generate_tribesman_rig.py](../tools/assets/generate_tribesman_rig.py), [generate_crag_born.py](../tools/assets/generate_crag_born.py)): Added `Work`, `Wounded`, `Attack`, `Hit`, and `Death` clips alongside `Idle`, `Walk`, `GuardIdle`, and `GuardWalk` across `tribesman_base.glb` and `crag_born_{broad,braided,child}.glb`.
- **Zero-swap animation & shader hit flash** ([skinned_tribesman_trial.gd](../scripts/entities/skinned_tribesman_trial.gd), [human_unit.gd](../scripts/entities/human_unit.gd)): Kept `_skinned_trial` visible across all states (idle, walk, work, attack, hit, hit-flash, wounded, and death) without swapping back to procedural blocks.
- **Default Crag-Born promotion** ([crag_born_trial.gd](../scripts/entities/crag_born_trial.gd)): Promoted `CragBornTrial.enabled()` to `true` by default for Crag-Born Foragers and adult Spearmen outside the leader slot, with `--procedural-roster` opt-out (`--crag-born-trial` retained as a compatibility no-op).
- **Verification**: [verify_glb_assets.gd](../scripts/tools/verify_glb_assets.gd) (`--require-gameplay-rig`) and [verify_crag_born.gd](../scripts/tools/verify_crag_born.gd) (default promoted, `--check-default-roster`, and `--procedural-roster` opt-out) passed under Forward+.

### Slice 2C — Pass 3–5 Expansion Assets & Damage Review

> **Completed 21 Nov 2026**. [Asset rollout](../tools/assets/OVERHAUL.md#asset-rollout) · [Handoff](HANDOFF.md#track-a--slice-2c-pass-35-expansion-assets--damage-review)

- **Slice 2C-1 (Lineage scale extremes), completed 21 Nov 2026.** Six Goliath and Swift-Kin GLBs share the 17-bone Crag-Born rig, nine clips, and role kits. The shared loader applies lineage and age scale, including gear and corpse height. Verified live spawn, work and combat playback, save/load, gear fit and scale, and the roster opt-out. [Forward+ lineage verifier](../scripts/tools/verify_skinned_lineages.gd)
- **Slice 2C-2 (Buildings, wildlife & damage review), completed 21 Nov 2026.** Reed Granary and Ridge Signal Tower have four-stage models and matching colliders. Tower arrows use the active deck marker. New campaigns include a Slateback Boar with eight armor and a Reedjaw with a dodgeable bite. The campaign verifier locks down cleave, ranged, unarmed, Brute, and blessing damage. Standing-Stone Gate awaits traversal verification. [Damage cases](../scripts/tools/verify_campaign_save.gd) · [Forward+ asset checks](../scripts/tools/verify_valley_assets.gd)

---

## Phase 3: Larger 760×760 m Valley & Full-Screen World Map

> **Completed 21 Nov 2026.** [Future work](FUTURE.md#larger-valley-and-accessible-world-map) · [Handoff](HANDOFF.md#track-b--phase-3-larger-760760-m-valley--full-screen-world-map)

- **Slice 3A (Expanded layout & `v4` saves), completed 21 Nov 2026.** New Game uses `valley_expanded_760`, with five fords, at least 170 m between settled starting camps, a 62 m growth radius, and a 190×190 navigation grid. Layout-specific rivers, cave sites, camps, wildlife territories, and bounds are shared across terrain, movement, camera, and radar. `v4` stores the layout ID, and prior versions restore `valley_classic_380` with their saved coordinates. [Layout data](../scripts/core/world_layout.gd) · [Expanded valley verifier](../scripts/tools/verify_expanded_valley.gd)
- **Slice 3B (Full-screen World Map), completed 21 Nov 2026.** Open with `M` or a Valley Radar click, pan with right mouse, zoom with the wheel, and left-click for a waypoint. `Tab` still opens Tribal Command. Verified all three UI sizes, input capture, layout projection, and waypoint placement. [World Map overlay](../scripts/ui/world_map_overlay.gd) · [UI verifier](../scripts/tools/verify_campaign_ui.gd)

### Slice 3A benchmark

Seed `17394`, 1280×720, Godot Forward+, Intel UHD 620, isolated `APPDATA`. The developed settlement has 91 units and 54 buildings. All scenarios had matching unit and building counts in the final layout pair.

| Scenario | Pre-expansion checkpoint physics median | Final classic median | Expanded median |
| --- | ---: | ---: | ---: |
| Opening | 25.016 ms | 27.027 ms | 23.560 ms |
| Developed settlement | 65.336 ms | 43.979 ms | 46.899 ms |
| Raid | 67.547 ms | 51.360 ms | 48.617 ms |

Both layouts completed 40/40 ford routes. Median query time was 0.123 ms in classic and 0.085 ms in expanded. Short physics samples showed intermittent tail spikes. Units now reuse their paths while progressing and replan when their target moves, a building changes the grid, or their movement stalls. Wider starting building spacing keeps expanded rival camps connected to the valley. [Benchmark](../scripts/tools/benchmark_simulation.gd) · [Routes and saves verifier](../scripts/tools/verify_expanded_valley.gd)

---

## Phase 4: Tribal Leaders, Diplomacy & Conquest Integration

> **Completed 21 Nov 2026.** [Diplomacy plan](FUTURE.md#tribal-leaders-and-diplomacy) · [Handoff](HANDOFF.md#track-c--phase-4-tribal-leaders-diplomacy--conquest-integration)

- Settled leaders have distinct nameplates. Approach with `E` to open the live representative’s Diplomacy card. Peace blocks strikes, raids and declarations through two day changes. Tributaries send up to eight Food and three Flint from their stock each day. Third-party kills can trigger succession, and unresolved player conquest choices persist through reload. [Campaign rules](../scripts/core/game_state.gd) · [Diplomacy verifier](../scripts/tools/verify_diplomacy_leaders.gd)

---

## Phase 5: Taming, Crop Farming, Husbandry & Mounts

> **Completed 21 Nov 2026.** [Player flow](FUTURE.md#taming-farming-and-mounts) · [Handoff](HANDOFF.md#track-d--phase-5-taming-crop-farming-husbandry--mounts)

- Crop Fields support planting, tending, ripening, harvesting, and delivery to storage by Farmers. Animal Pens accept tamed Deer and Tusked Boars, feed them from the faction stockpile, and breed juveniles when there is room. The Colony drawer shows field and herd progress and offers surplus harvest. [Economy rules](../scripts/core/farming_rules.gd) · [Colony drawer](../scripts/ui/drawers/colony_drawer.gd)
- The leader uses `E` to tame, mount a trained adult boar, and dismount. The camera and both leader rigs adapt while mounted. `v4` saves retain crops, pen and wildlife state, and the rider link. The farming probe verifies the full cycle, a failed tame, and rejection of an invalid rider before the live world changes. [Campaign validator](../scripts/core/campaign_save.gd) · [Forward+ verifier](../scripts/tools/verify_farming_taming.gd)

---

## Agentic Continuation Protocol

### Repo hygiene pre-flight
- **Local Git**: Local Git is initialized on `main` with `.gitignore` excluding `.godot/`, `*.tmp`, and local capture/save directories; checkpoint cleanly between slices for diff clarity and rollback safety.
- **Ignore stale launcher binaries**: Run `project.godot` directly via Godot 4.3 console; `ChristFallow.exe` and `Christ Fallow.lnk` are stale (`2026-11-18`) and should be rebuilt or removed when packaging.
- **Keep paths portable**: Never commit personal paths (`<USERPROFILE>\...`) into scripts or test defaults; use `$env:GODOT_EXE`, `$env:BLENDER_EXE`, and `--out-dir`.

### Standard autonomous slice loop
1. **Pick one slice.** The ordered queue through Phase 5 is complete. The handoff records the verified baseline and outstanding asset work. [Handoff](HANDOFF.md)
2. **Run baseline verifiers** in an isolated temp `APPDATA` directory before editing.
3. **Implement minimal, localized changes** following [AGENTS.md](../AGENTS.md#godot-43--repo-engineering-conventions) (no `class_name` in preloaded helpers, explicit typing on `Variant` indexing, `remove_child` before `queue_free`).
4. **Expand and run verifiers** under Forward+ and confirm explicit `PASSED` markers + zero `SCRIPT ERROR` / `Parse Error` / `SHADER ERROR` lines.
5. **Update docs in the same change**: Mark completed items in `docs/ROADMAP.md`, update `AGENTS.md` if entry points or invariants changed, and commit/checkpoint cleanly.

### Verification gate commands (Windows PowerShell)

Run each Godot command sequentially. Repeat the `$qa` setup before each invocation so it starts with fresh preferences and saves. The benchmark reports `SIMULATION BENCHMARK COMPLETE`, and the showcase gate requires seven PNGs with successful capture messages.

```powershell
$godot = '<USERPROFILE>\AppData\Local\Godot\Godot_v4.3-stable_win64_console.exe'
$project = (Get-Location).Path
$qa = Join-Path ([IO.Path]::GetTempPath()) ('cf-qa-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $qa -Force | Out-Null
$env:APPDATA = $qa
$env:CHRIST_FALLOW_QA_APPDATA = $qa

# 1. Opening tutorial, campaign save & simulation baseline
& $godot --path $project --resolution 1600x900 --fixed-fps 60 --quit-after 1200 -s res://scripts/tools/verify_opening_tutorial.gd
& $godot --path $project --fixed-fps 60 --quit-after 900 -s res://scripts/tools/verify_campaign_save.gd

# 2. Campaign UI baseline
& $godot --path $project --resolution 1280x720 --fixed-fps 60 --quit-after 900 -s res://scripts/tools/verify_campaign_ui.gd -- "--out-dir=$qa/captures"
& $godot --path $project --resolution 1600x900 --fixed-fps 60 --quit-after 900 -s res://scripts/tools/verify_campaign_ui.gd -- "--out-dir=$qa/captures" --large-ui
& $godot --path $project --resolution 1920x810 --fixed-fps 60 --quit-after 900 -s res://scripts/tools/verify_campaign_ui.gd -- "--out-dir=$qa/captures" --large-ui

# 3. Phase 1 spatial index, navigation and benchmark gates
& $godot --path $project --resolution 1280x720 --fixed-fps 60 --quit-after 900 -s res://scripts/tools/verify_phase1_nav.gd
& $godot --path $project --resolution 1280x720 --fixed-fps 60 --quit-after 900 -s res://scripts/tools/benchmark_simulation.gd
& $godot --path $project --resolution 1280x720 --fixed-fps 60 --quit-after 900 -s res://scripts/tools/benchmark_simulation.gd -- --expanded-valley
& $godot --path $project --resolution 1280x720 --fixed-fps 60 --quit-after 900 -s res://scripts/tools/verify_expanded_valley.gd
& $godot --path $project --resolution 1280x720 --fixed-fps 60 --quit-after 900 -s res://scripts/tools/verify_diplomacy_leaders.gd

# 4. Farming, taming, husbandry and mounted saves
& $godot --path $project --resolution 1280x720 --fixed-fps 60 --quit-after 900 -s res://scripts/tools/verify_farming_taming.gd -- "--out-dir=$qa/captures"
& $godot --path $project --resolution 1280x720 --fixed-fps 60 --quit-after 900 -s res://scripts/tools/verify_farming_taming.gd -- "--out-dir=$qa/captures" --skinned-tribesman-trial

# 5. Asset & skinned rig gates (Forward+ display required)
& $godot --path $project --quit-after 600 -s res://scripts/tools/verify_glb_assets.gd -- "--out-dir=$qa/glb" --require-gameplay-rig
& $godot --path $project --resolution 1600x900 --quit-after 1800 -s res://scripts/tools/verify_crag_born.gd -- "--out-dir=$qa/crag"
& $godot --path $project --quit-after 1800 -s res://scripts/tools/verify_crag_born.gd -- --check-default-roster
& $godot --path $project --quit-after 1800 -s res://scripts/tools/verify_crag_born.gd -- --check-default-roster --procedural-roster
& $godot --path $project --resolution 1600x900 --quit-after 1800 -s res://scripts/tools/verify_skinned_lineages.gd -- "--out-dir=$qa/lineages"
& $godot --path $project --quit-after 1800 -s res://scripts/tools/verify_skinned_lineages.gd -- --procedural-roster
& $godot --path $project --resolution 1600x900 --quit-after 900 -s res://scripts/tools/verify_valley_assets.gd -- "--out-dir=$qa/valley"
& $godot --path $project --quit-after 600 res://scenes/asset_showcase.tscn -- "--out-dir=$qa/showcase"
```
