# Christ Fallow — Agent Guide & Codebase Map

> Stone Age 3D civilization, base-building, religion, diplomacy, and tactical combat game in **Godot 4.3 (Forward+ / Vulkan, GDScript)**.
> Base viewport is `1600×900` with `canvas_items` stretch and `expand` aspect. 3D visuals combine imported GLBs with procedural GDScript meshes and effects. The asset generators use Blender 4.5 LTS.

## Working in this project

- Run the source project from `project.godot` with the Godot 4.3 console executable. `ChristFallow.exe` and `Christ Fallow.lnk` are separate launch artifacts (`2026-11-18`) and lag the source.
- There is currently no `.git` repository in the workspace root; initialize local Git (ignoring `.godot/` and temp outputs) before multi-file refactors.
- Follow the affected feature from its player-facing entry point through the state change and the HUD update. Several features have both a button and a hotkey. Check both when editing their shared behavior.
- Use the smallest check that exercises the changed behavior. Record the command, gameplay path, and result so the next agent can reproduce it. Keep temporary probes, test saves, and showcase images outside the project unless they belong in a lasting test or asset.

## Planning files

- [Master roadmap and bug-fix plan](docs/ROADMAP.md) tracks the active stabilization slices (`Phase 0`), simulation performance/navigation prerequisites (`Phase 1`), asset promotion, future feature sequencing, and the agentic continuation protocol.
- [Codebase refactor](docs/REFACTOR.md) records the completed 20 November 2026 architecture extraction and verification baseline (spatial indexing moved to [Phase 1](docs/ROADMAP.md#phase-1-simulation-performance--navigation-foundation)).
- [Future development](docs/FUTURE.md) details the playable opening tutorial, valley expansion, full-screen map, tribal leaders and diplomacy, animal taming, farming, and mounts.
- [Asset overhaul and combat design](tools/assets/OVERHAUL.md) tracks the active asset rollout and balance proposals. The [asset pipeline plan](tools/assets/PLAN.md) records a completed tooling and leader trial. Use the [asset pipeline guide](tools/assets/README.md) for commands and the [catalog](tools/assets/CATALOG.md) for current coverage.
- When changing a player entry point or moving a responsibility, update the relevant route below in the same change. Keep proposed work and verified results clearly labelled in plans. Link to source files or stable headings for live rules that are likely to move.

## Runtime flow

1. The title owns its front-end screens. `CampaignSession` mounts `scenes/main.tscn` for New Game, Continue, or Load, then removes it and clears the campaign references on Return to Title. The world, command system, player controller, and HUD register in `GameState` during `_ready()`.
2. `GameState.start_new_campaign()` initializes faction data, diplomacy, the clock, and guide flags, populates the world, then activates the HUD. `game_started` fires during initialization before entities are spawned. Code that needs the leader or live buildings must wait for population.
3. `GameState` owns campaign rules, including guide progression, manual and conquest pause, and player role and faith actions. Live entities are children of the world containers. Use `get_faction_units()` and `get_faction_buildings()` for faction queries and the faction controller for standard spawns.
4. Continue, Load Game, `F10`, and Pause → Load Campaign call `GameState.load_game()`. `CampaignStorage` reads and writes the save. `CampaignSave` validates and normalizes it before the live campaign changes. The world restores entities and leader attachment, then `GameState` restores combat commands and emits `campaign_loaded` before any pending conquest modal. Review each entity's `serialize()` alongside `restore_snapshot()` and verify older saves with missing fields.
5. The HUD routes campaign shortcuts. Drawer views own their selection and focus, and `CampaignOverlays` owns pause, settings, confirmation, conquest, and results screens. `PlayerController` handles world input and consults `blocks_world_input()`. `Preferences` applies screen, audio, motion, and world presentation settings independently of the campaign save.

---

## Quick File Router ("Where to Find X")

### Entry Points & Configuration
- [project.godot](project.godot) — Autoloads (`GameData`, `GameState`, `MeshFactory`, `Preferences`), title entry scene (`res://scenes/ui/title_screen.tscn`), display settings (`1600x900`, Forward+).
- [scripts/ui/title_screen.gd](scripts/ui/title_screen.gd) — Title navigation, loading feedback, and ambient backdrop. [CampaignSession](scripts/systems/campaign_session.gd) owns the mounted campaign scene and Return to Title.
- [scripts/ui/awakening_screen.gd](scripts/ui/awakening_screen.gd) and [scripts/ui/settings_screen.gd](scripts/ui/settings_screen.gd) — Campaign setup and shared title/pause settings. [Preferences](scripts/ui/preferences.gd) persists settings. [FallowTheme](scripts/ui/fallow_theme.gd), [MenuOverlay](scripts/ui/menu_overlay.gd), and [MeshPreview](scripts/ui/mesh_preview.gd) provide shared presentation.
- [scenes/main.tscn](scenes/main.tscn) — Root runtime scene: `Main` -> `WorldManager`, `CombatCommandSystem`, `PlayerController`, `UILayer/GameHUD`.
- [scenes/ui/game_hud.tscn](scenes/ui/game_hud.tscn) — HUD scene attaching `scripts/ui/hud_controller.gd`.
- [scenes/asset_showcase.tscn](scenes/asset_showcase.tscn) & [scripts/tools/asset_showcase.gd](scripts/tools/asset_showcase.gd) — Offline visual turntable/stage renderer for inspecting races, classes, combat poses, and deaths.
- [scripts/tools/verify_glb_assets.gd](scripts/tools/verify_glb_assets.gd), [scripts/tools/verify_crag_born.gd](scripts/tools/verify_crag_born.gd), and [scripts/tools/verify_valley_assets.gd](scripts/tools/verify_valley_assets.gd) — Forward+ verification of imported buildings, character rigs/kits, scenery, and wildlife.
- [scripts/tools/verify_campaign_save.gd](scripts/tools/verify_campaign_save.gd) and [scripts/tools/verify_campaign_ui.gd](scripts/tools/verify_campaign_ui.gd) — Automated `SceneTree` campaign persistence and UI/input verification suites.
- [tools/assets/README.md](tools/assets/README.md) and [tools/assets/CATALOG.md](tools/assets/CATALOG.md) — Staged Blender generation, asset contracts, lineage and type directories, and sample GLBs.
- [README.md](README.md) — Player-facing controls and feature summary.

### Core Singletons, Data & Procedural Mesh/VFX
- [scripts/core/game_data.gd](scripts/core/game_data.gd) — Static balance tables & enums: `Lineage` (7 lineages: `GOLIATH`, `SWIFT_KIN`, `STALKER`, `CRAG_BORN`, `ASH_WALKER`, `FEN_TIDAL`, `CAVEMAN`), `PLAYABLE_LINEAGES`, `Role` (`FORAGER`..`WARRIOR`), `WarriorClass` (`SPEARMAN`..`JAVELINEER`), `CLASS_DEFINITIONS`, `BUILDINGS`, `CRAFT_RECIPES`, `TECH_TIER_NAMES`, `GOD_DATA`, `TENET_DATA`, `WILDLIFE_DATA`, `RIVAL_PRESETS`, `SchedulePhase`, `SquadOrder`, `DiplomaticState`, and helpers `resolve_class_key()`, `resolve_effective_lineage()`.
- [scripts/core/game_state.gd](scripts/core/game_state.gd) — Campaign runtime autoload (`factions` 0..6, `diplomacy`, `time_of_day`, `day_count`, `warhorn_active`), opening raid buffer (`BANDIT_GRACE_DURATION = 210.0`, `is_raid_grace_active()`), 5-step Awakening tutorial flags, `is_hostile()`, `save_game()`, `load_game()` (`user://christ_fallow_save.json`), and building/unit queries (`get_faction_buildings(faction_id, building_type = "", constructed_only = false)`).
- [scripts/core/campaign_save.gd](scripts/core/campaign_save.gd) — Validates and normalizes compatible `v1` through `v3` saves. New v3 saves with a live player leader include an optional `player_leader_id` cross-reference. Keep schema validation free of changes to the live campaign.
- [scripts/core/campaign_storage.gd](scripts/core/campaign_storage.gd) — File access for the validated snapshot and temporary sibling writes. Call through `GameState` for campaign entry points and feedback.
- [scripts/core/awakening_guide.gd](scripts/core/awakening_guide.gd) — Five guide steps and the once-only reward. `GameState` advances the guide on the campaign tick, and the HUD renders the current step.
- [scripts/core/world_layout.gd](scripts/core/world_layout.gd) — Ground size and the separate blueprint, wildlife roaming, and radar extents for the current valley.
- [scripts/core/mesh_factory.gd](scripts/core/mesh_factory.gd) — `MeshFactory` autoload facade owning PSX procedural textures/materials (`make_mat`, `add_mesh`, `make_pivot`, `get_gritty_texture`), building stages builder (`build_building_stages`), and delegating mesh construction:
  - [scripts/core/human_mesh_builder.gd](scripts/core/human_mesh_builder.gd) — Procedural articulated humanoid rig (`BodyPivot` -> `HipsPivot` -> `SpinePivot` -> `ChestPivot` -> shoulders/elbows/hands/head/legs), race heads/hair/ears, class kits, and tiered weapon/offhand gear updates (`update_human_gear`, `set_hand_mounts_visible`).
  - [scripts/core/world_mesh_builder.gd](scripts/core/world_mesh_builder.gd) — Multi-stage buildings (intact/damaged/critical/rubble stages via `.glb` or procedural fallback), blueprint holograms, prehistoric wildlife, resource nodes, caveman caves, and projectile meshes.
- [scripts/core/combat_vfx.gd](scripts/core/combat_vfx.gd) — Floating 3D text popups (`spawn_damage_popup`), blood pools (`spawn_blood_pool`), and melee slash arcs (`spawn_slash_arc`).
- [scripts/shaders/psx_diablo_post.gdshader](scripts/shaders/psx_diablo_post.gdshader) — Post-process PSX pixelation, ordered dithering, contrast curve, and configurable brightness multiplier.
- [scripts/shaders/psx_unit_skinned.gdshader](scripts/shaders/psx_unit_skinned.gdshader) — Forward+ depth-safe/fog-safe Spatial PSX shader with XY-only clip-space snapping and nearest filtering for skinned meshes.

### Entities & Animation
- [scripts/entities/human_unit.gd](scripts/entities/human_unit.gd) — Unit stats, unarmed self-defense, damage/death/wounding, warrior combat, world-space status and interaction prompts, and `serialize()`.
- [scripts/entities/unit_stats.gd](scripts/entities/unit_stats.gd) — Pure stat derivation and human armor mitigation. `HumanUnit` applies the result, retains HP and lifecycle ownership, and refreshes the visuals.
- [scripts/entities/unit_ai_routines.gd](scripts/entities/unit_ai_routines.gd) — Extracted civilian daily schedule routines (`run_dusk_routine`, `run_night_routine`, `run_day_work_routine`, `run_train_at_barracks`, `gain_training_xp`) and spatial scanners (`find_enemy_near_point`, `find_nearest_hostile_wildlife`, `find_nearest_blueprint`, `find_nearest_resource_node`, `find_nearest_prey`, `find_wounded_ally`, `find_nearest_enemy_building`).
- [scripts/entities/tribesman_animator.gd](scripts/entities/tribesman_animator.gd) — Articulated procedural joint pose blender supporting idle stances, walk/kite, `WORK_*`, `TOOL_SWING`, class attacks (`SPEAR_THRUST`, `DUAL_SLASH`, `BOW_SHOT`, `HEAVY_SMASH`, `JAVELIN_THROW`, `LEADER_CLEAVE`, `SHAMAN_CAST`, `UNARMED_PUNCH`), directional `DAMAGE_*`, 3-variant `DEATH_*`, and `WOUNDED` states.
- [scripts/entities/skinned_tribesman_trial.gd](scripts/entities/skinned_tribesman_trial.gd) — Player leader's opt-in imported idle and walk rig, faction materials, and `Hand.R` great-spear attachment. Launch with `-- --skinned-tribesman-trial`.
- [scripts/entities/crag_born_trial.gd](scripts/entities/crag_born_trial.gd) — Opt-in imported Crag-Born locomotion for supported Foragers and adult Spearmen outside the leader slot. Launch with `-- --crag-born-trial`.
- [scripts/entities/player_controller.gd](scripts/entities/player_controller.gd) — Leader movement and camera, blueprint placement and its `2.6 m` overlap check, `E` recruitment/aid/harvest, combat and blessings, and squad shortcuts. The HUD handles `F9/F10`.
- [scripts/entities/building_entity.gd](scripts/entities/building_entity.gd) — 4-stage building damage breakdown (`Stage_Intact`, `Stage_Damaged`, `Stage_Critical`, `Stage_Rubble`), hostile-attacked-only billboard `QuadMesh` health bar, critical smoke/embers and light dimming, rubble sinking and debris burst upon destruction, Campfire healing aura, Sleeping Hut reproduction, and Watchtower defense.
- [scripts/entities/wildlife_entity.gd](scripts/entities/wildlife_entity.gd) — Prehistoric animals (`DEER`, `BOAR`, `WOLF`, `SABERTOOTH`, boss `MAMMOTH` & `CAVE_BEAR`).
- [scripts/entities/projectile_3d.gd](scripts/entities/projectile_3d.gd) — Ballistic arrow/javelin flight (`Projectile3D.spawn(...)`).

### Simulation & UI Systems
- [scripts/systems/world_generator.gd](scripts/systems/world_generator.gd) — Terrain, sky/daylight cycle, initial awakening cluster & wanderers at `(0, 0, 52)`, rival colonies & bone caves, PSX shader controls, and save restoration (`restore_from_save`).
- [scripts/systems/faction_controller.gd](scripts/systems/faction_controller.gd) — Per-faction spawning, crafting, tier upgrades, Tribal Succession, and rival colony and raid logic. The Peace Buffer gates cave spawns and autonomous raids. Rival colony development continues during the buffer.
- [scripts/systems/combat_command_system.gd](scripts/systems/combat_command_system.gd) — Squad selection (`1..6`), tactical orders (`F1..F6`), Fire-at-Will toggle, Tribal Warhorn (`H`), captive enlightenment, diplomacy actions, and role count allocator (`adjust_role_count`).
- [scripts/systems/blessing_effects.gd](scripts/systems/blessing_effects.gd) — Shared Patron God blessing & AoE damage/heal implementation used by both Player Leader (`PlayerController`) and Rival Leaders (`HumanUnit`).
- [scripts/ui/hud_controller.gd](scripts/ui/hud_controller.gd) — Resource strip, objectives, guide display, placement banner, event log, combat controls, campaign shortcuts, and view coordination.
- [scripts/ui/drawers/](scripts/ui/drawers/) — [FeatureDrawer](scripts/ui/drawers/feature_drawer.gd) base class plus Tribal Command, Build, Colony, Faith, and Diplomacy. [Shared options](scripts/ui/hud_drawers.gd) provide squad/order definitions and role/class option builders.
- [scripts/ui/unit_inspector.gd](scripts/ui/unit_inspector.gd) and [scripts/ui/campaign_overlays.gd](scripts/ui/campaign_overlays.gd) — Unit detail and campaign dialogs. Use `GameState` actions for role, faith, and pause transitions.
- [scripts/ui/minimap_widget.gd](scripts/ui/minimap_widget.gd) — Valley Radar draws camps, structures, caves, units, boss wildlife, and raid markers. `WorldLayout.RADAR_HALF_EXTENT` sets map projection.

---

## Current Game State & Invariants

1. **Opening Peace Buffer & Awakening Guide**:
   - New campaigns start with `bandit_grace_remaining = BANDIT_GRACE_DURATION` (`210.0s`). This gates bone-cave spawns and autonomous rival raids. Rival colony routines still run, and explicit ally raid orders use a separate path.
   - The 5-step **Awakening Guide** tracks recruitment -> campfire founding -> gather + role assignment -> warrior/building prep -> leader cleave/javelin practice, awarding `+10 Food, +10 Wood, +5 Flint` on completion. Clicking **Skip** hides the guide without cancelling the Peace Buffer.
2. **Villager Self-Defense**:
   - Unarmed civilians use `unarmed_attack_damage` (`3.0..7.5` raw, halved for children) and `"UNARMED_PUNCH"` (`1.65m` reach, `1.15s / attack_speed_mult` cooldown) when cornered (`<= 2.35m`), recently struck by `_self_defense_target` (`<= 4.2m`), or defending camp (`<= 4.5m`). Weapon/offhand mounts are hidden briefly (`_unarmed_punch_vis_timer`) so workers punch bare-handed.
3. **Factions & Diplomacy**:
   - `-3` Wounded (rescue or timed defection into `6`), `-2` Rebels, `-1` Wild Wanderers (`E` to recruit), `0` Player Tribe, `1..4` Rival Tribes, `5` Nomadic Cavemen (permanently hostile), `6` Outcast Rebels.
4. **Screen & HUD layout**:
   - The resource strip and objectives reserve the upper right for Valley Radar. The guide and event log sit on the left. The combat controls are docked at the bottom centre, and management panels open above them. Check layouts at both ends of the interface scale range after changing panel widths or control labels.
5. **Village Building Destruction & Hostile-Only Combat Health Bars**:
   - Buildings have four stages. Intact is above 66% HP. Damaged is above 33% and at most 66%. Critical is above 0% and at most 33%, with smoke, embers, and dimmed lights. Rubble starts at 0% HP.
   - At Stage 3 (Rubble): `is_destroyed = true`, `_col_shape.set_deferred("disabled", true)`, a one-shot wood/stone debris burst fires, stage lights and fire meshes shut down, and rubble lingers for 8.0s before sinking and queue-freeing.
   - Destroyed buildings are excluded from `GameState.get_faction_buildings()`.
   - Health bar rendering: Built with a single camera-facing billboard `QuadMesh` using an unshaded spatial shader (`instance uniform float fill_ratio`, `bar_alpha`).
   - Hostile-only display: Constructed buildings keep health bars hidden by default. Only hostile damage (checked via `GameState.is_hostile(faction_id, attacker_faction)`) activates `_combat_timer = 5.0` (smoothly fading out in the final second). Attacking a neutral rival triggers `AT_WAR` and immediately activates the hostile combat bar. Friendly repair or non-hostile interactions keep the bar hidden.
   - Blueprints (`is_constructed == false`) always display their cyan build progress bar and flash red when damaged without breaking `_flash_timer` recovery.
   - Save/load persistence: `sync_visual_from_state()` derives completed-building damage stages from HP. Unfinished blueprints retain intact holograms. `_combat_timer` defaults to 0.0, keeping completed-building health bars hidden upon loading.
6. **Headless Blender 4.5 LTS Asset Toolchain & `.glb` Contracts**:
   - Portable Blender 4.5 LTS is installed outside the repo at `<USERPROFILE>\AppData\Local\Blender\blender-4.5.16-windows-x64\blender.exe`.
   - `tools/assets/build_assets.ps1` stages the Sleeping Hut, Palisade, and base tribesman. Use `-VerifyOnly -RequireGameplayRig` for strict review without publishing. The Crag-Born and valley batches have separate commands in the [asset pipeline guide](tools/assets/README.md).
   - Current GLB coverage: `2/11` buildings (`SLEEPING_HUT`, `PALISADE_WALL`), `1/7` lineages (`crag_born/` opt-in via `--crag-born-trial`) plus `tribesman_base.glb` (opt-in leader via `--skinned-tribesman-trial`), `2/14` gear kits (`spearman/`, `forager/`), `4` scenery props (`windbent_pine`, `moss_limestone`, `berry_thicket`, `riverbank_reeds`), and `2/6` wildlife (`BOAR`, `SABERTOOTH`). Default rosters still render procedural `HumanMeshBuilder` meshes.
   - Building `.glb` node contract: Root Node3D -> children `Stage_Intact`, `Stage_Damaged`, `Stage_Critical`, `Stage_Rubble` + `Collider-convcolonly` (plus `CampfireLight`, `ShamanLight`, `FlameMesh` when applicable). `FactionTrim` material slots are tinted at runtime with faction colors.
   - Character `.glb` contract uses a 17-bone `Skeleton3D` with vertex skinning, UVs, faction trim, and looping `Idle` and `Walk` clips (plus `GuardIdle` and `GuardWalk` for Crag-Born). Both opt-in trials use the imported rig for locomotion and swap to the procedural rig for work, combat, hit reactions, and death. Verify updates with `build_assets.ps1 -RequireGameplayRig` and `verify_crag_born.gd`.
   - Fallback: `MeshFactory.build_building_stages()` falls back to procedural geometry if a `.glb` is missing, guaranteeing all 11 building types support all 4 stages. Blueprints (`is_blueprint == true`) and placement ghosts currently always use procedural Stage 0 geometry.

---

## Godot 4.3 & Repo Engineering Conventions

- **No `.godot` global class cache reliance**: Helper modules (`HumanMeshBuilder`, `WorldMeshBuilder`, `UnitAIRoutines`, `BlessingEffects`, `HUDDrawers`, `CombatVFX`, `TribesmanAnimator`, `Projectile3D`) are loaded via `const Foo = preload("res://...")` (without `class_name`) so scripts compile cleanly in CLI runs and fresh checkouts. Keep dependency direction strictly acyclic (helper static functions accept `u` or `hud` untyped).
- **Godot 4.3 strict typing pitfalls**: Do NOT use `:=` when the RHS comes from untyped `Dictionary`/`Array` indexing or `node.get("prop")` (`Variant`); annotate explicit types. Never call `bool(null)`—use `== true` or `!= null`.
- **Safe child replacement**: Whenever clearing children before repopulating or loading (`world_generator.gd`, `hud_controller.gd`), call `container.remove_child(c)` before `c.queue_free()` so same-frame queries never see queued-for-free nodes.
- **Building queries** use `get_faction_buildings(faction_id)` for defaults or `get_faction_buildings(faction_id, building_type, constructed_only)` for explicit filters. Pass `""` as the second argument when filtering by construction state across all types.
- **JSON save types** use numbers decoded as `float`. The save validator normalizes faction enum IDs and counters to `int`. Save positions as numeric arrays and decode them before instantiating entities.
- **Pause is campaign state.** The HUD requests manual transitions with `GameState.set_manual_pause()`. Pending conquest owns its pause until resolved. Simulation callbacks and input handlers manage their own guards. When adding a world timer or action, check behavior before campaign start, during pause or conquest, and after victory or defeat.

## Verification on Windows

Run these from the project root. Adjust `$godot` if the console executable is installed elsewhere.

```powershell
$godot = '<USERPROFILE>\AppData\Local\Godot\Godot_v4.3-stable_win64_console.exe'
$project = (Get-Location).Path

# Import assets in a fresh checkout.
& $godot --headless --editor --path $project --import

# Verify imported GLBs, building behavior, and the gameplay rig with Forward+.
$review = Join-Path ([System.IO.Path]::GetTempPath()) ('cf-glb-' + [guid]::NewGuid())
& $godot --path $project --quit-after 600 -s res://scripts/tools/verify_glb_assets.gd -- "--out-dir=$review" --require-gameplay-rig

# Start the project and reach the title screen.
& $godot --path $project --quit-after 420

# Render the seven showcase PNGs to a fresh output folder.
$showcase = Join-Path ([System.IO.Path]::GetTempPath()) ('christ-fallow-showcase-' + [guid]::NewGuid())
& $godot --path $project --quit-after 600 res://scenes/asset_showcase.tscn -- "--out-dir=$showcase"
```

- Use Forward+ with a display for gameplay, mesh, and screenshot checks. The headless renderer is suitable for the import command and cannot validate mesh rendering. For the showcase, verify seven PNG files and inspect the shots relevant to the change. Pass `--out-dir` explicitly because the script's default path is machine-specific.
- For a scripted gameplay probe, run `& $godot --path $project --quit-after 600 -s $testScript` with the absolute path to a `SceneTree` test script. Instantiate the title scene for player-facing flows. For campaign-only checks, instantiate `res://scenes/main.tscn`, let its nodes register, then call `GameState.start_new_campaign()` before asserting on live entities. Check console output for `SCRIPT ERROR`, `Parse Error`, engine errors, and an explicit success marker. Godot can exit with code 0 after a script error or when the frame limit is reached.
- For an opening-flow change, start a campaign, recruit three wanderers with `E`, place the Campfire through `B`, and check guide progression and the Peace Buffer. Exercise the relevant world action with the drawer open and closed when changing input routing.
- For a save change, pass a temporary absolute filename to `GameState.save_game(path)` and `GameState.load_game(path)`. For title, quick-save/load, pause, and Settings checks, set `APPDATA` for the test process to a short, isolated writable directory outside the project. This keeps `user://christ_fallow_save.json` and `user://ui_preferences.cfg` separate from player data. Check a running-campaign reload and a load from a fresh launch. Test invalid data before replacing live state.
- The checked-in [campaign UI](scripts/tools/verify_campaign_ui.gd) and [campaign save](scripts/tools/verify_campaign_save.gd) checks expect `CHRIST_FALLOW_QA_APPDATA` to match the isolated `APPDATA`. Use an empty scratch directory for each UI run. See the [refactor verification commands](docs/REFACTOR.md#implementation-verification).
