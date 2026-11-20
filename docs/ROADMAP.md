# Christ Fallow — Master Roadmap & Stabilization Plan

> Unified engineering, UI/UX, gameplay, and 3D asset roadmap following the [20 November 2026 refactor](REFACTOR.md). For architecture and file routing, see the [agent guide](../AGENTS.md).

## Current progress snapshot (20 November 2026)

### Shipped & verified
- **Core Stone Age campaign loop**: Title screen, Awakening tribe setup (`6` playable lineages), `210 s` Peace Buffer, 5-step Awakening Guide (`+10 Food, +10 Wood, +5 Flint`), gathering/hunting/crafting, 3 tech tiers, 5 Patron Gods & 6 tenets, day/dusk/night schedules, Barracks training, Tribal Warhorn (`H`), diplomacy/conquest/succession, and `v1..v3` atomic JSON persistence.
- **Refactored runtime boundaries**: `CampaignSession` lifecycle ownership, `GameState` campaign rules, `CampaignSave`/`CampaignStorage`, `AwakeningGuide`, `UnitStats`, `UnitAIRoutines`, `BlessingEffects`, `WorldLayout`, `FeatureDrawer` views, `UnitInspector`, `CampaignOverlays`, and `Preferences`.
- **Phase 0 stabilization (`Slices 0A`–`0E`, Completed 20 Nov 2026)**: Fixed conquest/wounded/pause lifecycle leaks (`0A`), wildlife defense/economy/Warhorn/tech-tier/bounds/combat parity (`0B`), save/load state isolation, cooldown/buff/timer persistence, live `KRAG_UL` HP scaling, and synchronous leader succession (`0C`), HUD focus/layout/diplomacy/radar/control polish (`0D`), and `DUAL_SHEATH`/GLB blueprint hologram/PSX material/trial rig alignment (`0E`). **Active next phase: [Phase 1: Simulation Performance & Navigation Foundation](#phase-1-simulation-performance--navigation-foundation).**
- **Automated baselines passing (20 Nov 2026)**:
  - `scripts/tools/verify_campaign_save.gd`: `CAMPAIGN SAVE VERIFICATION PASSED` (exit `0`, `0` script errors/warnings).
  - `scripts/tools/verify_campaign_ui.gd` (`1280×720`, `1600×900 --large-ui`, `1920×810 --large-ui`): `CAMPAIGN UI VERIFICATION PASSED` + `PASS action Quit` (exit `0`, `0` script errors/warnings).
  - `scripts/tools/verify_glb_assets.gd --require-gameplay-rig`, `verify_crag_born.gd` (`--crag-born-trial` and `--check-default-roster`), `verify_valley_assets.gd`, and `scenes/asset_showcase.tscn` (7 PNGs) passed in Forward+.

### Partially delivered (3D assets)
- **Buildings**: `2/11` GLBs (`sleeping_hut_stages.glb`, `palisade_wall_stages.glb`); remaining `9` types use procedural 4-stage meshes. Blueprints and placement ghosts clone and tint `Stage_Intact` from imported `*_stages.glb` files when available, falling back to procedural Stage 0 otherwise.
- **Characters & gear**: `tribesman_base.glb` (opt-in leader via `--skinned-tribesman-trial`), `crag_born/{broad,braided,child}.glb` (`1/7` lineages, opt-in via `--crag-born-trial`), and `2/14` gear kits (`spearman/`, `forager/`). Default campaigns render procedural `HumanMeshBuilder` characters.
- **Environment & wildlife**: `4` scenery GLBs (`windbent_pine`, `moss_limestone`, `berry_thicket`, `riverbank_reeds`), `2/6` wildlife GLBs (`tusked_boar`, `sabertooth`), plus `6` reviewed concept GLBs in `tools/assets/examples/`.

### Key architectural & hygiene bottlenecks
- **Simulation scan cost**: `REFACTOR.md` measured `69.126 ms` physics median at `107` units / `51` buildings (`23.013 ms` per 100 `find_enemy_near_point()` calls) due to per-frame `O(N^2)` container scans and array allocations.
- **Navigation & fixed bounds**: `_steer_toward()` uses straight-line steering with no obstacle avoidance, and several scripts hardcode `380×380 m` valley bounds outside [WorldLayout](../scripts/core/world_layout.gd).
- **Repo hygiene**: Local Git is initialized on `main` with `.gitignore` excluding `.godot/` and temp outputs. `ChristFallow.exe` (dated `2026-11-18`) and `Christ Fallow.lnk` lag the `2026-11-20` source.

---

## Phase 0: Mechanics, UI & Asset Stabilization (Bug-Fix Plan)

> **Status: Completed (20 Nov 2026)** — Slices `0A`–`0E` are implemented and verified. Proceed to **Phase 1: Simulation Performance & Navigation Foundation** next.

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
3. **Warhorn arms children & gives militia Archers melee range (`High`)** — [human_unit.gd](../scripts/entities/human_unit.gd#L175,L259,L899), [unit_stats.gd](../scripts/entities/unit_stats.gd#L62-L75).
   - *Fix*: Guard `_get_class_key()`, `_refresh_gear_visual()`, and `_process_tribal_ai()` with `not is_child`, and keep Warhorn militia stats aligned with their visual/weapon class (or enforce `SPEARMAN` militia).
4. **Tech Tier upgrade grants free gear tiers to living units (`High`)** — [faction_controller.gd](../scripts/systems/faction_controller.gd#L131-L133), [human_unit.gd](../scripts/entities/human_unit.gd#L715).
   - *Fix*: Advance `fdata["tech_tier"]` for future crafts and let `try_equip_from_stockpile()` upgrade existing units when weapons/armor are actually crafted (optionally keeping Leader auto-scaled).
5. **AI & Wildlife walk off `380×380 m` world edge (`High`)** — [human_unit.gd](../scripts/entities/human_unit.gd#L839), [wildlife_entity.gd](../scripts/entities/wildlife_entity.gd#L321), [world_generator.gd](../scripts/systems/world_generator.gd#L159-L165,L206-L227).
   - *Fix*: Clamp `HumanUnit` and `WildlifeEntity` XZ positions inside `Layout` bounds or add perimeter rim colliders.
6. **Civilians attack post-truce targets; `ANCESTRAL_STONE` discount leaks (`Medium`)** — [unit_ai_routines.gd](../scripts/entities/unit_ai_routines.gd#L394), [game_state.gd](../scripts/core/game_state.gd#L552-L571).
   - *Fix*: Re-check `GameState.is_hostile()` on `_self_defense_target` before punching; scope `ANCESTRAL_STONE` `-20%` wood/stone discount to building placement only.
7. **Projectile vertical `look_at` error & low-FPS tunneling (`Medium`)** — [projectile_3d.gd](../scripts/entities/projectile_3d.gd#L39-L45,L58-L59,L76).
   - *Fix*: Guard `look_at` against near-vertical velocity vectors and perform swept segment checks from `prev_pos` to `next_pos`.
8. **Combat/economy formula & propagation mismatches (`Medium`–`Low`)**:
   - Leader javelin scales off melee `attack_damage` instead of `ranged_attack_damage` ([player_controller.gd](../scripts/entities/player_controller.gd#L449)) — decide explicitly per [OVERHAUL.md](../tools/assets/OVERHAUL.md#proposed-damage-review).
   - `FORAGER_LODGE` omits Hunter animal yields ([wildlife_entity.gd](../scripts/entities/wildlife_entity.gd#L162-L169)); `_try_hunter_work` hardcodes `18.0` arrow damage ([unit_ai_routines.gd](../scripts/entities/unit_ai_routines.gd#L154)).
   - `VALK_TOR` omits spear knockback bonus ([human_unit.gd](../scripts/entities/human_unit.gd#L497)) and `aoe_damage` takes first 5 in tree order instead of nearest 5 ([blessing_effects.gd](../scripts/systems/blessing_effects.gd#L49-L66)).
   - `toggle_fire_at_will()` misses newly assigned warriors and `CHARGE`/`GUARD_BASE` ([combat_command_system.gd](../scripts/systems/combat_command_system.gd#L64-L70)); `preach_religion()` does not recalculate converted rival unit stats (`line 135`).
   - `Campfire` aura heals 24/7 and stacks across multiple campfires ([building_entity.gd](../scripts/entities/building_entity.gd#L484-L505)).
   - Crafting hardcodes `3.2 s` ignoring `CRAFT_RECIPES[k]["craft_time"]` and builders/shamans/trainees always pick building index `[0]` instead of nearest ([unit_ai_routines.gd](../scripts/entities/unit_ai_routines.gd#L87,L96,L108,L121,L205)); warriors skip Dusk/Night eat & sleep routines ([human_unit.gd](../scripts/entities/human_unit.gd#L905-L922)); Cavemen march exclusively on player camp ([human_unit.gd](../scripts/entities/human_unit.gd#L865-L872)).

**Verification criteria (0B)**: Extend fixed-input combat/economy checks in `verify_campaign_save.gd` (or a dedicated simulation probe) for Watchtower/warrior wildlife defense, Stoneknapper Flint+Stone balance, Warhorn child exclusion, tech-tier stockpile consumption, and XZ boundary clamping.

### Slice 0C — Save/Load Fidelity & State Isolation

> **Completed (20 Nov 2026)**

1. **Unserialized / un-reset cooldowns, buffs, carry & AI timers (`Medium`)** — [player_controller.gd](../scripts/entities/player_controller.gd#L24-L29,L47-L77), [human_unit.gd](../scripts/entities/human_unit.gd#L1261-L1298), [faction_controller.gd](../scripts/systems/faction_controller.gd#L4-L16).
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

1. **Persistent HUD & Inspector controls steal `Space` (Dodge) & `Arrows` (`High`)** — [hud_controller.gd](../scripts/ui/hud_controller.gd#L255,L309,L421,L486-L533), [unit_inspector.gd](../scripts/ui/unit_inspector.gd#L79-L115).
   - *Fix*: Call `release_focus()` on HUD/inspector click handlers while preserving `FOCUS_ALL` for keyboard navigation.
2. **`DiplomacyDrawer` opinion breakdown mismatch, stale `_selected_faction` & double refresh (`High`/`Medium`)** — [diplomacy_drawer.gd](../scripts/ui/drawers/diplomacy_drawer.gd#L3,L20-L38,L57-L80,L97-L155), [game_state.gd](../scripts/core/game_state.gd#L342-L384).
   - *Fix*: Share an opinion-breakdown helper from `GameState` (including `PEACEFUL_OFFERING` `+15` and state clamps), reset/validate `_selected_faction` across reloads, remove redundant `refresh()` calls, and add inline ally-raid target feedback.
3. **`_drawer_panel` overlaps `_minimap_panel` & `_squad_bar` at `ui_scale = 1.1` (`High`)** — [hud_controller.gd](../scripts/ui/hud_controller.gd#L121,L371-L376,L446-L455,L536-L546).
   - *Fix*: Compute `_drawer_panel` horizontal and bottom offsets dynamically in `_align_upper_hud()` clear of `_minimap_panel` and `_squad_bar`.
4. **`HUDController._input` intercepts `Esc` before open `OptionButton` popups (`Medium`)** — [hud_controller.gd](../scripts/ui/hud_controller.gd#L124-L144).
   - *Fix*: Check for active popup menus (or move non-overlay `Esc` handling to `_unhandled_key_input()`).
5. **`BuildDrawer` unbuffed costs/HP & procedural-only preview (`Medium`/`Low`)** — [build_drawer.gd](../scripts/ui/drawers/build_drawer.gd#L59-L89).
   - *Fix*: Display effective `ANCESTRAL_STONE` cost & `KRAG_UL` HP and preview `Stage_Intact` from `build_building_stages()`.
6. **`ColonyDrawer` Crafting tab stale `captured_cavemen` / `CRAFTING_PIT` (`Medium`)** — [colony_drawer.gd](../scripts/ui/drawers/colony_drawer.gd#L98-L118,L246-L265).
   - *Fix*: Include `captured_cavemen`, `tech_tier`, and `has_building(0, "CRAFTING_PIT", true)` in Crafting live refresh.
7. **`_raid_panel` overlap/z-order & `UnitInspector` wildlife-cleave hijack (`Medium`)** — [hud_controller.gd](../scripts/ui/hud_controller.gd#L335-L408,L536-L546), [player_controller.gd](../scripts/entities/player_controller.gd#L136-L138,L452-L476).
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
3. **Scenery & wildlife GLBs bypass PSX material rules (`Low`)** — [world_mesh_builder.gd](../scripts/core/world_mesh_builder.gd#L16-L17,L710-L719,L835-L839).
   - *Fix*: Enforce `TEXTURE_FILTER_NEAREST` and `SPECULAR_DISABLED` on imported scenery and wildlife materials.
4. **`SkinnedTribesmanTrial` vs `CragBornTrial` shader/material parity (`Medium`)** — [skinned_tribesman_trial.gd](../scripts/entities/skinned_tribesman_trial.gd#L32-L89), [crag_born_trial.gd](../scripts/entities/crag_born_trial.gd#L50-L55), [human_unit.gd](../scripts/entities/human_unit.gd#L226,L230-L239), [psx_unit_skinned.gdshader](../scripts/shaders/psx_unit_skinned.gdshader#L10-L43).
   - *Fix*: Align `snap_resolution` / `jitter_intensity`, respect `is_psx_filter_enabled()` on leader spawn (`human_unit.gd:226`), map `Mat_Wood`/`Mat_Flint`/`Mat_Hair` etc. to matching gritty textures, apply `psx_unit_skinned` (or consistent snapping) to `TrialSpear`, keep Crag-Born Foragers in Forager kit when Warhorn militia triggers (`human_unit.gd:230-231`), and audit unused uniforms / NDC snap scaling in `psx_unit_skinned.gdshader`.
5. **Showcase & verifier hygiene (`Low`)** — [asset_showcase.gd](../scripts/tools/asset_showcase.gd#L3,L143), [verify_crag_born.gd](../scripts/tools/verify_crag_born.gd#L173).
   - *Fix*: Remove hardcoded personal UUID default path, add `remove_child(c)` before `queue_free()` in `_clear_stage()`, and replace positional `get_child(2)` lookup with a named or metadata lookup.

**Verification criteria (0E)**: `verify_glb_assets.gd --require-gameplay-rig`, `verify_crag_born.gd --crag-born-trial`, `verify_crag_born.gd --check-default-roster`, `verify_valley_assets.gd`, and `asset_showcase.tscn` (7 PNGs) all pass in Forward+ with 0 errors.

---

## Phase 1: Simulation Performance & Navigation Foundation

> **Active next phase** — Prerequisite for [Larger valley and accessible world map](FUTURE.md#larger-valley-and-accessible-world-map) (`760×760 m`):

1. **Cached faction lists & spatial hash grid**: Eliminate per-frame `60 Hz` container scans and fresh array allocations in `GameState.get_faction_units()`, `get_faction_buildings()`, `HumanUnit`, `WildlifeEntity`, `BuildingEntity`, and `Projectile3D`. Wire staggered AI target scans (`_ai_think_cd`).
2. **Parameterize `WorldLayout`**: Move all hardcoded `380 m` / `±172 m` / `±140 m` / `±148 m` bounds and fixed scan distances (`65–85 m`) from `player_controller.gd`, `game_state.gd`, `world_generator.gd`, `human_unit.gd`, and `unit_ai_routines.gd` into [WorldLayout](../scripts/core/world_layout.gd).
3. **Navigation & obstacle routing**: Add `NavigationRegion3D` / waypoint or bridge routing so units navigate around walled bases and river crossings instead of walking straight-line vectors.
4. **Benchmark gate**: Re-run the `REFACTOR.md` seed `17394` physics benchmark (`107+` units / `51+` buildings on UHD 620 or baseline hardware) and verify measurable reduction from the `69.126 ms` physics / `23.013 ms` search baseline.

---

## Phase 2: Playable Opening Tutorial & Asset Rig Promotion

1. **Playable opening tutorial**: Deliver all steps and the **Verification probe** in [FUTURE.md](FUTURE.md#playable-opening-tutorial).
2. **Skinned rig promotion & Pass 3–5 rollout** ([OVERHAUL.md](../tools/assets/OVERHAUL.md#asset-rollout)):
   - Resolve the procedural-to-skinned visual handoff (add skinned attack/work/hit/death clips or unified gear/mesh visibility) before removing the `--skinned-tribesman-trial` and `--crag-born-trial` opt-in gates.
   - Deliver Pass 3 first candidates (**Goliath** and **Swift-Kin** scale extremes), Pass 4 **Reed Granary** / **Ridge Signal Tower** / **Standing-Stone Gate**, and Pass 5 **Reedjaw** / **Slateback Boar** / **Flintmask Scout** plus the 4-step damage review.

---

## Phase 3: Larger 760×760 m Valley & Full-Screen World Map

Deliver [Larger valley and accessible world map](FUTURE.md#larger-valley-and-accessible-world-map), including layout-versioned `v4` saves, river crossings, distant-colony activity, and `M` key reassignment coordination across HUD, `settings_screen.gd`, and `README.md`.

---

## Phase 4: Tribal Leaders, Diplomacy & Conquest Integration

Deliver [Tribal leaders and diplomacy](FUTURE.md#tribal-leaders-and-diplomacy), and complete the currently stubbed `DiplomaticState.TRIBUTARY` ([game_data.gd](../scripts/core/game_data.gd#L73)) and `diplomacy[key]["truce_timer"]` ([game_state.gd](../scripts/core/game_state.gd#L265,L300-L302)) mechanics.

---

## Phase 5: Taming, Crop Farming, Husbandry & Mounts

Deliver [Taming, farming, and mounts](FUTURE.md#taming-farming-and-mounts) with full save/load persistence for crops, herds, and rider assignments.

---

## Agentic Continuation Protocol

### Repo hygiene pre-flight
- **Local Git**: Local Git is initialized on `main` with `.gitignore` excluding `.godot/`, `*.tmp`, and local capture/save directories; checkpoint cleanly between slices for diff clarity and rollback safety.
- **Ignore stale launcher binaries**: Run `project.godot` directly via Godot 4.3 console; `ChristFallow.exe` and `Christ Fallow.lnk` are stale (`2026-11-18`) and should be rebuilt or removed when packaging.
- **Keep paths portable**: Never commit personal paths (`<USERPROFILE>\...`) into scripts or test defaults; use `$env:GODOT_EXE`, `$env:BLENDER_EXE`, and `--out-dir`.

### Standard autonomous slice loop
1. **Pick one slice** (in order `0A -> 0B -> 0C -> 0D -> 0E -> Phase 1 -> ...`).
2. **Run baseline verifiers** in an isolated temp `APPDATA` directory before editing.
3. **Implement minimal, localized changes** following [AGENTS.md](../AGENTS.md#godot-43--repo-engineering-conventions) (no `class_name` in preloaded helpers, explicit typing on `Variant` indexing, `remove_child` before `queue_free`).
4. **Expand and run verifiers** under Forward+ and confirm explicit `PASSED` markers + zero `SCRIPT ERROR` / `Parse Error` / `SHADER ERROR` lines.
5. **Update docs in the same change**: Mark completed items in `docs/ROADMAP.md`, update `AGENTS.md` if entry points or invariants changed, and commit/checkpoint cleanly.

### Verification gate commands (Windows PowerShell)

```powershell
$godot = '<USERPROFILE>\AppData\Local\Godot\Godot_v4.3-stable_win64_console.exe'
$project = (Get-Location).Path
$qa = Join-Path ([IO.Path]::GetTempPath()) ('cf-qa-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $qa -Force | Out-Null
$env:APPDATA = $qa
$env:CHRIST_FALLOW_QA_APPDATA = $qa

# 1. Campaign save & simulation baseline
& $godot --path $project --fixed-fps 60 --quit-after 900 -s res://scripts/tools/verify_campaign_save.gd

# 2. Campaign UI baseline (repeat at 1280x720 without --large-ui, and 1920x810 with --large-ui)
& $godot --path $project --resolution 1600x900 --fixed-fps 60 --quit-after 900 -s res://scripts/tools/verify_campaign_ui.gd -- "--out-dir=$qa/captures" --large-ui

# 3. Asset & trial rig gates (Forward+ display required)
& $godot --path $project --quit-after 600 -s res://scripts/tools/verify_glb_assets.gd -- "--out-dir=$qa/glb" --require-gameplay-rig
& $godot --path $project --resolution 1600x900 --quit-after 1800 -s res://scripts/tools/verify_crag_born.gd -- --crag-born-trial "--out-dir=$qa/crag"
& $godot --path $project --quit-after 1800 -s res://scripts/tools/verify_crag_born.gd -- --check-default-roster
& $godot --path $project --resolution 1600x900 --quit-after 900 -s res://scripts/tools/verify_valley_assets.gd -- "--out-dir=$qa/valley"
& $godot --path $project --quit-after 600 res://scenes/asset_showcase.tscn -- "--out-dir=$qa/showcase"
```
