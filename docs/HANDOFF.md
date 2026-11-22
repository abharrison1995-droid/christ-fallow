# Christ Fallow — Engineering Handoff (22 November 2026)

> **Purpose:** Fast, zero-ambiguity state transfer for continuing Christ Fallow autonomously (e.g., via Codex). Read this file first alongside [AGENTS.md](../AGENTS.md), [docs/ROADMAP.md](ROADMAP.md), and [docs/PERFORMANCE_HANDOVER.md](PERFORMANCE_HANDOVER.md).

---

## 1. Current Repository & Environment State

- **Workspace:** `<USERPROFILE>\Desktop\Christ Fallow`
- **Engine / Tooling (Windows):**
  - Godot 4.3 console: `<USERPROFILE>\AppData\Local\Godot\Godot_v4.3-stable_win64_console.exe`
  - Portable Blender 4.5 LTS: `<USERPROFILE>\AppData\Local\Blender\blender-4.5.16-windows-x64\blender.exe`
  - Run from `project.godot` directly; ignore `ChristFallow.exe` and `Christ Fallow.lnk` (`2026-11-18`, stale).
- **Git history on `main`:**
  - `5a2b437` — Baseline: pre-Phase 0 snapshot (`.gitignore` excludes `.godot/`, temp outputs, `__pycache__/`).
  - `d2ff849` — **Phase 0A:** Fixed `RAZE` leader leak, third-party rival-wipe conquest softlock, wounded `being_rescued` limbo & defection defeat checks, paused/`campaign_finished` entity/rubble/cooldown leaks, `promote_to_player_leader()` ring/armor cleanup, replacement Campfire `camp_position`, shared `get_diplomatic_opinion_breakdown()`.
  - `912f212` — **Phase 0D:** Fixed HUD/Inspector `Space`/Arrow focus hijack, `DiplomacyDrawer` opinion breakdown (`PEACEFUL_OFFERING` + state bounds) & unfunded faction-6 recovery, `--large-ui` drawer overlap, `Esc` vs open `OptionButton` popup, `BuildDrawer` discounted costs/`KRAG_UL` HP/GLB preview, `ColonyDrawer` Crafting refresh, `_raid_panel` z-order, silent `F10` pause error, mirrored Valley Radar river, Settings controls list.
  - `f075540` — **Phase 0E:** Added `DUAL_SHEATH` back gear, GLB `Stage_Intact` blueprint & ghost holograms, PSX nearest/no-specular materials on scenery/wildlife GLBs, aligned `SkinnedTribesmanTrial` & `CragBornTrial` shaders/textures/spear snapping, cleaned up `asset_showcase.gd` & `verify_crag_born.gd`.
  - `40e06ea` — **Phase 0B:** Fixed warrior & Watchtower defense against hostile wildlife, Stoneknapper `STONE`/`FLINT` balance, Warhorn child exclusion & militia/Crag-Born Forager parity, tech-tier stockpile consumption, AI/wildlife XZ clamping, scoped `ANCESTRAL_STONE` `-20%` discount to buildings only, swept projectile hits & vertical `look_at` guard, `FORAGER_LODGE` hunter yields, `VALK_TOR` knockback & nearest-N AoE, `fire_at_will` propagation, `preach_religion` stat recalc, Dusk-only non-stacking Campfire heal, recipe craft times, nearest-building lookup.
  - `a4090bd` — **Phase 0C + Docs:** Reset/persisted `PlayerController` cooldowns, unit daily/buff/carry fields, faction AI timers, eliminated legacy `v1`/`v2` reload wildlife leaks, added live `KRAG_UL` building `max_hp` scaling & HP clamp, made leader succession synchronous, expanded `verify_campaign_save.gd`.
  - `e138ad2` & `5218acd` — **Phase 1:** Added [spatial_index.gd](../scripts/core/spatial_index.gd), [valley_navigation.gd](../scripts/core/valley_navigation.gd), parameterized [world_layout.gd](../scripts/core/world_layout.gd), added 3 visual & navigable river fords, staggered AI/tower/wildlife scans, added [verify_phase1_nav.gd](../scripts/tools/verify_phase1_nav.gd) and [benchmark_simulation.gd](../scripts/tools/benchmark_simulation.gd) (**−56.6% to −66.1% physics median speedup** on seed `17394`).
  - `baac676` — **Phase 2A:** Playable Opening Tutorial ([awakening_guide.gd](../scripts/core/awakening_guide.gd) `get_objective_target()`, [tutorial_beacon.gd](../scripts/core/tutorial_beacon.gd), HUD `[x]`/`[ ]` checklist & gold `Build`/`Colony` highlights, `BuildDrawer` `[RECOMMENDED]` auto-select, Valley Radar pulsing target ping, Step 4 constructed `SLEEPING_HUT`, [verify_opening_tutorial.gd](../scripts/tools/verify_opening_tutorial.gd)).
  - `d4b1261` — **Phase 2B:** Baked `Work`, `Wounded`, `Attack`, `Hit`, and `Death` skeletal clips in [generate_tribesman_rig.py](../tools/assets/generate_tribesman_rig.py) & [generate_crag_born.py](../tools/assets/generate_crag_born.py), zero-swap animation & shader hit-flash in [skinned_tribesman_trial.gd](../scripts/entities/skinned_tribesman_trial.gd) & [human_unit.gd](../scripts/entities/human_unit.gd), promoted [crag_born_trial.gd](../scripts/entities/crag_born_trial.gd) to **default-enabled** (`--procedural-roster` opt-out).
  - `92ae7d0` — **Docs Sync:** Updated `ROADMAP.md`, `FUTURE.md`, `AGENTS.md`, `README.md`, `OVERHAUL.md`, `tools/assets/README.md`.
  - `7e38544` — **Slice 2C-1.** Promoted Goliath and Swift-Kin skinned Foragers and adult Spearmen.
  - `c225c07` — **Slice 2C-2.** Promoted Reed Granary, Ridge Signal Tower, Slateback Boar, and Reedjaw. Added golden damage fixtures.
  - `f2d2ff2` — **Slice 3A.** Added the expanded valley, classic-compatible v4 saves, and paired layout benchmarks.
  - `b5ac719` — **Slice 3B.** Added the World Map, waypoint projection, and updated controls.
  - `6acd7fb` — **Phase 4.** Added named rival leaders, approach negotiation, truces, tribute, and succession.
  - `039ff9b` — **Phase 5.** Added crop cycles, animal husbandry, mounting, and `v4` crop, herd, and rider persistence.
  - `6090d74` through `971df84` — Promoted the gate, Flintmask Scout, settlement buildings, and additional skinned wildlife. [Production batches](../tools/assets/OVERHAUL.md#production-batches)
  - `3b042dd` and `c7f3a72` — Added [six wildcard prototypes](../tools/assets/examples/WILDCARD.md) and [eighteen standalone dinosaur models](../tools/assets/examples/DINOSAURS.md) for asset review.
  - `3abde8c` — **Performance baseline:** Recorded rendered/fixed-step frame attribution in [PERFORMANCE.md](PERFORMANCE.md) and ordered optimization plan in [PERFORMANCE_HANDOVER.md](PERFORMANCE_HANDOVER.md).
  - **Working tree (22 Nov 2026):** **Phase 6** (Tribal Level, Perks & Skills System + Opening Tutorial directional pointer & in-drawer highlights), **Refactor Pass 2** (`UnitCombatAI`, `DiplomacyConquestRules`, `HUDPanels`), **Phase 7** (Custom Weapons & Armor System), **Phase 8** (Stone Age SFX & Dynamic Music), and **Phase 9** (Blood-Pit Trial Arena).

---

## 2. Verified Baseline

These are Forward+ results using isolated `APPDATA` and `CHRIST_FALLOW_QA_APPDATA`. On 22 November 2026 after Phases 7–9 and all Review Gate 3 fixes, the 7-suite sequential Forward+ gate passed with `EXIT_CODE:0` and zero `SCRIPT ERROR` / `Parse Error` / `SHADER ERROR` lines (`verify_arena_trials.gd`, `verify_equipment_system.gd`, `verify_audio_system.gd`, `verify_first_person_pov.gd`, `verify_perks_leveling.gd`, `verify_campaign_ui.gd -- --large-ui`, `verify_campaign_save.gd`). Historical baseline suites and benchmarks are also listed below. See the [performance review](PERFORMANCE.md) and [performance handover](PERFORMANCE_HANDOVER.md) for current reruns and stress measurements.

| Suite | Scope Verified |
| :--- | :--- |
| [verify_arena_trials.gd](../scripts/tools/verify_arena_trials.gd) | `ARENA_PIT` Lv.3 + `BARRACKS_DRILLMASTERS` gating in `BuildDrawer`, 4 stages + walkable pit floor, `[E]` Arena tab, First-Person (`Z`) Chieftain's Trial + Watchtower/save isolation + `"ARENA"`/`"PEACE_DAY"` music, non-lethal KO & `1.75x` `SHAMAN_SHACK` convalescence, Warband Exhibition + `Spectate Ring` + `is_arena_champion` (`+15` HP, `1.10x` DMG) + Plan 1 gear drop, forfeit cleanup, and save/load (`91` checks, `EXIT_CODE:0`). |
| [verify_equipment_system.gd](../scripts/tools/verify_equipment_system.gd) | Crafting Pit tier gating & recipes, stockpile equip/refund math, `WEAPON_DEFS`/`ARMOR_DEFS` stat changes, bow arrow projectiles, `CragBornTrial` & `FirstPersonViewmodel` visual gear swaps, `ColonyDrawer`/`UnitInspector` loadout UI, and in-session/cold reload persistence (`130` checks, `EXIT_CODE:0`). |
| [verify_audio_system.gd](../scripts/tools/verify_audio_system.gd) | `SoundManager` `Master`/`Music`/`SFX` buses, `Preferences` & `SettingsScreen` Audio sliders, 16 SFX cues & 5 music states, throttling & pool recycling, day/night/combat/title transitions, and silent mount restore (`86` checks, `EXIT_CODE:0`). |
| [verify_first_person_pov.gd](../scripts/tools/verify_first_person_pov.gd) | First-person controls, camera-aligned combat/inspection, HUD blocking, body shadows, succession, and mounted warm/cold loads (`EXIT_CODE:0`). |
| [verify_perks_leveling.gd](../scripts/tools/verify_perks_leveling.gd) | Tribal Lv.1–12 XP curve, `K` `PerksDrawer`, Masonry/Might/Kinship perks, building unlock gating, Nomad Villager hiring, Rank VI+ Barracks training, combat XP & stockpile auto-equip, rival auto-perks, and save/load persistence (`EXIT_CODE:0`). |
| [verify_campaign_ui.gd](../scripts/tools/verify_campaign_ui.gd) | `1600×900 --large-ui` verified 22 Nov 2026 (`EXIT_CODE:0`); historical `1280×720` and `1920×810 --large-ui` runs cover title/awakening, focus release vs `Space`, non-overlap geometry, `Esc` vs `OptionButton`, Diplomacy, Colony Crafting, UnitInspector, pause/conquest/quit. |
| [verify_campaign_save.gd](../scripts/tools/verify_campaign_save.gd) | Legacy and v4 saves, corrupt/mismatched-leader rejection, signal order, combat formulas, and all Phase 0A/0B/0C regression suites (`EXIT_CODE:0`). |
| [verify_expanded_valley.gd](../scripts/tools/verify_expanded_valley.gd) | Camp spacing, ford routes, raids, hauling, distant construction, World Map projection and waypoint input, and v3/v4 terrain changes. |
| [verify_diplomacy_leaders.gd](../scripts/tools/verify_diplomacy_leaders.gd) | Named leaders, approach negotiation, raid and attack truce guards, tribute, successor identity, and pending-conquest reload. |
| [verify_farming_taming.gd](../scripts/tools/verify_farming_taming.gd) | Crop work and hauling, taming success and failure, pen travel, feeding, breeding, surplus harvest, and movement, dismounting, and save recovery for all three mounts. Runs with the default leader, `--skinned-tribesman-trial`, or `--procedural-roster`. |
| [verify_campaign_ui.gd](../scripts/tools/verify_campaign_ui.gd) | `1280×720`, `1600×900 --large-ui`, `1920×810 --large-ui`: title/awakening, focus release vs `Space`, non-overlap geometry, `Esc` vs `OptionButton` popup, Diplomacy opinion breakdown & faction-6 recovery, Colony Crafting refresh, UnitInspector, pause/conquest/quit. |
| [verify_phase1_nav.gd](../scripts/tools/verify_phase1_nav.gd) | SpatialIndex parity across spawn/move/convert/death/rubble/save-load; palisade detour & rubble reopening; river ford crossing (`38/38`). |
| [benchmark_campaign_frames.gd](../scripts/tools/benchmark_campaign_frames.gd) | Rendered frame intervals and fixed-step simulation timings for seed `17394` across `opening`, `settlement`, `battle-on`, and `battle-off` (`CAMPAIGN FRAME BENCHMARK COMPLETE`). |
| [benchmark_simulation.gd](../scripts/tools/benchmark_simulation.gd) | Seed `17394` physics median: Opening `23.943 ms`, Developed `45.300 ms`, Raid `41.956 ms` (down from `61.872 / 104.408 / 123.930 ms`). |
| [verify_glb_assets.gd](../scripts/tools/verify_glb_assets.gd) (`--require-gameplay-rig`) | Building 4-stage + collider contracts; `tribesman_base.glb` 17-bone rig + `Idle`/`Walk`/`Work`/`Wounded`/`Attack`/`Hit`/`Death`. |
| [verify_crag_born.gd](../scripts/tools/verify_crag_born.gd) | Default promoted Crag-Born roster + zero-swap action/hit/death playback, `--check-default-roster`, and `--procedural-roster` opt-out. |
| [verify_skinned_lineages.gd](../scripts/tools/verify_skinned_lineages.gd) | Seven six-body lineups, shared bones and clips, gear fit, combat, child growth, nomad capture and enlightenment, save/load, and roster opt-out. |
| [verify_valley_assets.gd](../scripts/tools/verify_valley_assets.gd) | Four scenery GLBs, wildlife attack and hit volumes, Slateback armor, and four-stage Granary and Tower builds with collider and rubble checks. |

---

## 3. Completed Execution Queue

All slices through Phase 9 and Codebase Refactor Pass 2 are complete. The asset rollout promoted Standing-Stone Gate in Batch 8 after traversal verification. [Roadmap](ROADMAP.md) · [Engineering conventions](../AGENTS.md)

All fifteen asset batches are complete. Batches 1–14 delivered seven six-body lineups, fourteen kits, Flintmask Scout, fourteen buildings, and eight imported wildlife models. Batch 15 delivered six review GLBs with gameplay-scale and close Forward+ captures. The wildcard examples await selection before any campaign integration. [Production batches](../tools/assets/OVERHAUL.md#production-batches) · [Wildcard review](../tools/assets/examples/WILDCARD.md)

### Track A — Slice 2C: Pass 3–5 Expansion Assets & Damage Review
Reference: [tools/assets/OVERHAUL.md](../tools/assets/OVERHAUL.md) · [tools/assets/CATALOG.md](../tools/assets/CATALOG.md) · [tools/assets/README.md](../tools/assets/README.md)
1. **Slice 2C-1 completed.** Goliath and Swift-Kin share the 17-bone Crag-Born rig and gear kits for Foragers and adult Spearmen. [Runtime loader](../scripts/entities/crag_born_trial.gd) · [Generation and review](../tools/assets/README.md#goliath-and-swift-kin)
2. **Slice 2C-2 completed.** Reed Granary, Ridge Signal Tower, Reedjaw, and Slateback Boar are live. Golden damage fixtures passed before the Slateback armor rule was enabled. Standing-Stone Gate passed navigation traversal in the later asset rollout. [Generation and verification](../tools/assets/README.md#reed-granary-ridge-signal-tower-and-new-wildlife)

### Track B — Phase 3: Larger `760×760 m` Valley & Full-Screen World Map
Reference: [docs/FUTURE.md](FUTURE.md#larger-valley-and-accessible-world-map)
1. **Slice 3A completed.** `WorldLayout` now defines `valley_classic_380` and `valley_expanded_760`. New Game uses the expanded layout, and `v4` stores the selected layout ID. `v1` through `v3` load as classic. Compare benchmarks with `--expanded-valley`. [Layout data](../scripts/core/world_layout.gd) · [Benchmark commands](ROADMAP.md#verification-gate-commands-windows-powershell)
2. **Slice 3B completed.** `M` and Valley Radar open the World Map, with pan, zoom, landmarks, and waypoint placement. `Tab` remains Tribal Command. [Map overlay](../scripts/ui/world_map_overlay.gd) · [Expanded valley verifier](../scripts/tools/verify_expanded_valley.gd)

### Track C — Phase 4: Tribal Leaders, Diplomacy & Conquest Integration
Reference: [docs/FUTURE.md](FUTURE.md#tribal-leaders-and-diplomacy)
Completed. Each settled tribe has a live nameplate and title. `E` opens negotiation with the approached representative. Truces bar renewed combat through two day changes. Conquest can create a tributary with its own leader and daily delivery. Third-party leader deaths can trigger succession, and pending conquest choices take priority on reload. [Campaign rules](../scripts/core/game_state.gd) · [Diplomacy verifier](../scripts/tools/verify_diplomacy_leaders.gd)

### Track D — Phase 5: Taming, Crop Farming, Husbandry & Mounts
Reference: [docs/FUTURE.md](FUTURE.md#taming-farming-and-mounts)

Completed. Farmers use `CROP_FIELD` to plant, tend, harvest, and haul food. `ANIMAL_PEN` shelters tamed Deer, Tusked Boars, and Woolly Mammoths, feeds them from the stockpile, and supports breeding and surplus harvest. `E` handles taming, mounting trained adults at species-specific speeds, and dismounting. Saves restore crops, ownership, herd and training state, and a mounted player leader. [Shared rules](../scripts/core/farming_rules.gd) · [Farming verifier](../scripts/tools/verify_farming_taming.gd)

Forward+ verification measured 7.17 m/s for the Woolly Mammoth, 8.23 m/s for the Tusked Boar, and 9.85 m/s for the Deer with a Crag-Born leader. The default, trial, and procedural runs each exercised the `E` interaction, `W` movement, in-session load, and Continue from the title screen. [Regression commands](ROADMAP.md#verification-gate-commands-windows-powershell)

### Track E — Phase 6: Tribal Level, Perks & Skills System & Tutorial Polish
Reference: [docs/FUTURE.md](FUTURE.md#tribal-leveling-perks-and-skills) · [Perk rules](../scripts/core/perk_system.gd) · [Perks drawer](../scripts/ui/drawers/perks_drawer.gd)

Completed. Tribes advance from Level 1 to 12 (`80 + (lvl - 1) * 55` XP per level) via economy, building, hunting, taming, combat, tech-tier, and alliance actions, earning Skill Points spent across three branches (*Masonry & Settlement*, *Chieftain & Lineage Might*, *Kinship & Warband Mastery* — 12 perks). Perks gate advanced buildings in `BuildDrawer` and rival AI (while direct `PlayerController.enter_build_mode()` remains bypassable by low-level tests), unlock `Hire Nomad Villager` in `ColonyDrawer`, raise Barracks training above Rank V up to Rank VIII, grant combat Training XP and stockpile auto-equip, and scale settled rival tribes via personality priority tables. At Lv.1 with 0 perks, all multipliers are `1.0` so legacy saves and tests remain invariant. Opening tutorial polish adds the 3D directional ground pointer (`_leader_pointer`), `[LMB] Place Here` build-mode proximity prompt, and `BuildDrawer` / `ColonyDrawer` in-drawer action highlights. [Perks verifier](../scripts/tools/verify_perks_leveling.gd) · [Tutorial verifier](../scripts/tools/verify_opening_tutorial.gd)

### Track F — Codebase Refactor Pass 2 (`UnitCombatAI`, `DiplomacyConquestRules`, `HUDPanels`)
Reference: [docs/REFACTOR.md](REFACTOR.md#second-extraction-pass-22-november-2026)

Completed. Extracted combat and faction-AI routines from `human_unit.gd` into [unit_combat_ai.gd](../scripts/entities/unit_combat_ai.gd), diplomacy/tribute/rebel/succession/conquest/victory rules from `game_state.gd` into [diplomacy_conquest_rules.gd](../scripts/core/diplomacy_conquest_rules.gd), and HUD panel builders/live refreshers from `hud_controller.gd` into [hud_panels.gd](../scripts/ui/hud_panels.gd). All three are preloaded static-function helpers without `class_name`, with thin forwarding wrappers and preserved properties/signals on the owning classes so existing callers and test suites run unchanged.

### Track G — Phase 7: Custom Weapons & Armor System
Reference: [docs/ROADMAP.md](ROADMAP.md#upcoming-sequential-phases-79--mandatory-inter-phase-reviews) · [Equipment verifier](../scripts/tools/verify_equipment_system.gd)

Completed. Added `GameData.WEAPON_DEFS` (`GREAT_SPEAR`, `STONE_SPEAR`, `FLINT_DIRK`, `HUNTING_BOW`, `WAR_CLUB`, `BARBED_JAVELIN`, `OBSIDIAN_CLEAVER`) and `ARMOR_DEFS` (`HIDE_TUNIC`, `BONE_GUARD`, `PELT_MANTLE`, `OBSIDIAN_PLATE`), expanded `CRAFT_RECIPES`, wired `HumanUnit.equip_loadout()` / `GameState.equip_unit_weapon()` / `equip_unit_armor()` / `UnitStats` / `CampaignSave`, added live 3rd-person & 1st-person gear swaps (`CragBornTrial`, `HumanMeshBuilder`, `FirstPersonViewmodel`), `PlayerController` weapon-driven attacks, and `ColonyDrawer` + `UnitInspector` loadout UI.

### Track H — Phase 8: Stone Age SFX & Dynamic Music
Reference: [docs/ROADMAP.md](ROADMAP.md#upcoming-sequential-phases-79--mandatory-inter-phase-reviews) · [Audio verifier](../scripts/tools/verify_audio_system.gd)

Completed. Added [generate_stone_age_audio.py](../tools/audio/generate_stone_age_audio.py) generating Stone Age foley & music loops in `assets/audio/`, pooled `SoundManager` autoload ([sound_manager.gd](../scripts/core/sound_manager.gd)) with `Master`/`Music`/`SFX` buses, 16 throttled SFX cues, and adaptive `TITLE`/`PEACE_DAY`/`NIGHT`/`COMBAT`/`ARENA` music transitions, `Preferences` & `SettingsScreen` Audio sliders, and gameplay audio hooks.

### Track I — Phase 9: Blood-Pit Trial Arena
Reference: [docs/ROADMAP.md](ROADMAP.md#upcoming-sequential-phases-79--mandatory-inter-phase-reviews) · [Arena verifier](../scripts/tools/verify_arena_trials.gd)

Completed. Added `ARENA_PIT` (`Lv.3` + `BARRACKS_DRILLMASTERS` Rank 1 in `BuildDrawer`, 4 visual stages, walkable interior, pulsing braziers), [arena_rules.gd](../scripts/core/arena_rules.gd) 5-tier bout system (`CHIEFTAIN` in 1st/3rd-person POV & `EXHIBITION` with `Spectate Ring`), `[E]` Arena tab opening, strict bout isolation from Watchtowers/outside units/mid-bout saves, non-lethal KO & `1.75x` `SHAMAN_SHACK`/`CAMPFIRE` convalescence (`arena_recovery_remaining`), `is_arena_champion` (`+15` HP, `1.10x` DMG), Plan 1 gear drops, and `ColonyDrawer` + `UnitInspector` Arena controls/badges.

### Campaign performance review

Imported human rigs skip hidden procedural poses, Guard Base reuses camp-centered target scans, and Peace invalidates cached hostiles. Lighting submits its palette on phase transitions and uses a smaller sky radiance map. The stress runs improved while remaining above the 16.7 ms rendered-frame budget. Draw and shadow passes, crowded movement, and worker job allocation are the next measured areas. [Results and reproduction](PERFORMANCE.md) · [Performance plan and handover](PERFORMANCE_HANDOVER.md) · [Ranked gameplay and asset proposals](FUTURE.md#ranked-gameplay-and-asset-proposals)

---

## 4. Non-Negotiable Engineering & Verification Rules

1. **Godot 4.3 strictness ([AGENTS.md](../AGENTS.md)):**
   - Never add `class_name` to preloaded helper modules (`SpatialIndex`, `ValleyNavigation`, `TutorialBeacon`, `AwakeningGuide`, `PerkSystem`, `ArenaRules`, `DiplomacyConquestRules`, `UnitStats`, `UnitAIRoutines`, `UnitCombatAI`, `BlessingEffects`, `HUDPanels`, etc.).
   - Never use `:=` on untyped `Dictionary`/`Array` indexing or `node.get("prop")` (`Variant`); always annotate explicit types.
   - Never call `bool(null)` — use `== true` or `!= null`.
   - Always call `container.remove_child(c)` before `c.queue_free()` when replacing container children.
2. **SpatialIndex & ValleyNavigation invariants:**
   - Every living `HumanUnit`, `WildlifeEntity`, and `BuildingEntity` registers in `setup()` and unregisters on death/rubble/`_exit_tree()`.
   - Direct test teleports (`unit.global_position = ...`) must call `GameState.spatial_index.update_unit(unit)` before immediate same-frame spatial queries.
   - Every constructed solid building registers in `valley_nav` and clears on Stage 3 rubble or `_exit_tree()`.
3. **Verification gates:**
   - Always run Godot Forward+ probes with a **fresh isolated temp directory** for `$env:APPDATA` and `$env:CHRIST_FALLOW_QA_APPDATA` (never pollute real user `APPDATA` or write temp files into the repo).
   - Never run multiple Forward+ Godot instances simultaneously on Intel UHD 620 (run sequentially to prevent GPU timeouts/flakes).
   - After modifying any `.glb` or Blender script, run `& $godot --headless --editor --path (Get-Location).Path --import` before running Forward+ checks.
   - Run the exact PowerShell verification block in [docs/ROADMAP.md](ROADMAP.md#verification-gate-commands-windows-powershell) and require `EXIT_CODE=0`, explicit `PASSED` lines, and `0` `SCRIPT ERROR` / `Parse Error` / `SHADER ERROR` lines before committing each slice.
4. **Documentation sync:**
   - Keep `docs/ROADMAP.md`, `docs/FUTURE.md`, `AGENTS.md`, `README.md`, `tools/assets/OVERHAUL.md`, and `tools/assets/CATALOG.md` updated in the same commit as the slice they describe, and verify `0` broken local links or `#heading` anchors.
