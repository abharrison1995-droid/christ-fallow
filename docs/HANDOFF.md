# Christ Fallow — Engineering Handoff (22 November 2026)

> **Purpose:** Fast, zero-ambiguity state transfer for continuing Christ Fallow autonomously on any machine. Read this file first alongside [AGENTS.md](../AGENTS.md), [docs/ROADMAP.md](ROADMAP.md), and [docs/PERFORMANCE_HANDOVER.md](PERFORMANCE_HANDOVER.md).

---

## Continuing on Another Device & Plan Map

### New-Device Setup (PowerShell / Bash)

1. Clone the project and open the checkout.
   ```shell
   git clone https://github.com/abharrison1995-droid/christ-fallow.git
   cd christ-fallow
   ```
2. **Install Godot 4.3 console** (required) and **Blender 4.5 LTS** (optional, only needed to regenerate `.glb` assets):
   - **Windows (PowerShell):** Set `$env:GODOT_EXE` (default: `$env:LOCALAPPDATA\Godot\Godot_v4.3-stable_win64_console.exe`) and optionally `$env:BLENDER_EXE` (default: `$env:LOCALAPPDATA\Blender\blender-4.5.16-windows-x64\blender.exe`).
   - **Linux / macOS (Bash):** Export `GODOT_EXE` (e.g. `godot4` in `$PATH` on Linux, `/Applications/Godot.app/Contents/MacOS/Godot` on macOS) and optionally `BLENDER_EXE` (`blender` 4.5 LTS).
3. **Populate `.godot/` on a fresh checkout** before running Forward+ verification suites or opening the editor:
   ```powershell
   # PowerShell (from <repo-root>)
   $godot = if ($env:GODOT_EXE) { $env:GODOT_EXE } else { Join-Path $env:LOCALAPPDATA 'Godot\Godot_v4.3-stable_win64_console.exe' }
   & $godot --headless --editor --path . --import
   ```
   ```bash
   # Bash (from <repo-root>)
   "${GODOT_EXE:-godot4}" --headless --editor --path . --import
   ```
4. Launch the game from `project.godot` with `& $godot --path .` in PowerShell or `godot4 --path .` in Bash. [Windows release plan](ROADMAP.md#slice-10c--staged-3d-assets--release-packaging)
5. **Repository hygiene:** `.gitignore` excludes `.godot/`, `captures/`, `qa_out/`, `tmp/`, `*.lnk`, and temp/cache files (`*.tmp`, `*.bak`, `*.log`, `__pycache__/`) while tracked `.import` files and `assets/` travel cleanly in Git. Keep test `APPDATA` / `CHRIST_FALLOW_QA_APPDATA` and `--out-dir` captures in OS temp directories outside `<repo-root>`.

### Master Document & Plan Directory

| Document | Scope & When to Read |
| :--- | :--- |
| [AGENTS.md](../AGENTS.md) | Runtime flow, Quick File Router, game invariants, Godot 4.3 GDScript strictness rules, and verification commands. |
| [README.md](../README.md) | Player-facing overview, controls, implemented systems, fresh-checkout setup, and project guide links. |
| [docs/HANDOFF.md](HANDOFF.md) | Completed Phases 0–9 baseline, verified test matrix, cross-device setup, and Phase 10 handover queue. |
| [docs/ROADMAP.md](ROADMAP.md) | Phase-by-phase engineering history (Phases 0–9), First-Person/Phases 7–9 audit table, formalized Phase 10A–10C slices, and sequential Forward+ verification commands. |
| [docs/FUTURE.md](FUTURE.md) | Gameplay design specs for completed Phases 2–9 plus Phase 10A proposals (`10A-1` through `10A-5`). |
| [docs/PERFORMANCE.md](PERFORMANCE.md) | Forward+ rendered and fixed-step frame-time telemetry, bottleneck attribution, and rolled-back/screened experiments. |
| [docs/PERFORMANCE_HANDOVER.md](PERFORMANCE_HANDOVER.md) | Ordered Phase 10B performance experiments, benchmark protocol, and pass/rollback criteria. |
| [docs/REFACTOR.md](REFACTOR.md) | Architecture extraction boundaries from Pass 1 (20 Nov 2026) and Pass 2 (22 Nov 2026). |
| [tools/assets/OVERHAUL.md](../tools/assets/OVERHAUL.md) | Blender 4.5 LTS production batches (1–16), asset overhaul design, and combat balance notes. |
| [tools/assets/CATALOG.md](../tools/assets/CATALOG.md) | Live `.glb` asset inventory across all 7 lineages, 14 kits, 14 buildings, 8 wildlife species, and scenery. |
| [tools/assets/README.md](../tools/assets/README.md) | Blender generation scripts, GLB node/material contracts, and asset verification commands. |
| [tools/assets/examples/WILDCARD.md](../tools/assets/examples/WILDCARD.md) | Staged wildcard prototype GLBs (`Antler Beacon`, `River Fish Weir`, `Mossback Ibex`, `Obsidian Cache`, `Shell Courier Kit`, `Mammoth-Bone Sled`) for Slices `10A-4` & `10C-2`. |
| [tools/assets/examples/DINOSAURS.md](../tools/assets/examples/DINOSAURS.md) | Staged 18-model rigged dinosaur lineup (6 types × 3 sizes) for Slice `10C-1`. |

---

## 1. Current Repository & Environment State

- **Workspace:** `<repo-root>` (portable checkout; no machine-specific paths in tracked code or docs).
- **Engine / Tooling:**
  - Godot 4.3 console: `$env:GODOT_EXE` (Windows default `$env:LOCALAPPDATA\Godot\Godot_v4.3-stable_win64_console.exe`; Linux `godot4`; macOS `/Applications/Godot.app/Contents/MacOS/Godot`).
  - Portable Blender 4.5 LTS (optional, asset pipeline only): `$env:BLENDER_EXE` (Windows default `$env:LOCALAPPDATA\Blender\blender-4.5.16-windows-x64\blender.exe`).
  - Run the source with the Godot console executable. Slice `10C-4` covers the Windows release export.
- **Git history on `main`:**
  - `5a80538` — Baseline: pre-Phase 0 snapshot (`.gitignore` excludes `.godot/`, temp outputs, `__pycache__/`).
  - `c201020` — **Phase 0A:** Fixed `RAZE` leader leak, third-party rival-wipe conquest softlock, wounded `being_rescued` limbo & defection defeat checks, paused/`campaign_finished` entity/rubble/cooldown leaks, `promote_to_player_leader()` ring/armor cleanup, replacement Campfire `camp_position`, shared `get_diplomatic_opinion_breakdown()`.
  - `30ce2e3` — **Phase 0D:** Fixed HUD/Inspector `Space`/Arrow focus hijack, `DiplomacyDrawer` opinion breakdown (`PEACEFUL_OFFERING` + state bounds) & unfunded faction-6 recovery, `--large-ui` drawer overlap, `Esc` vs open `OptionButton` popup, `BuildDrawer` discounted costs/`KRAG_UL` HP/GLB preview, `ColonyDrawer` Crafting refresh, `_raid_panel` z-order, silent `F10` pause error, mirrored Valley Radar river, Settings controls list.
  - `20a1353` — **Phase 0E:** Added `DUAL_SHEATH` back gear, GLB `Stage_Intact` blueprint & ghost holograms, PSX nearest/no-specular materials on scenery/wildlife GLBs, aligned `SkinnedTribesmanTrial` & `CragBornTrial` shaders/textures/spear snapping, cleaned up `asset_showcase.gd` & `verify_crag_born.gd`.
  - `033189d` — **Phase 0B:** Fixed warrior & Watchtower defense against hostile wildlife, Stoneknapper `STONE`/`FLINT` balance, Warhorn child exclusion & militia/Crag-Born Forager parity, tech-tier stockpile consumption, AI/wildlife XZ clamping, scoped `ANCESTRAL_STONE` `-20%` discount to buildings only, swept projectile hits & vertical `look_at` guard, `FORAGER_LODGE` hunter yields, `VALK_TOR` knockback & nearest-N AoE, `fire_at_will` propagation, `preach_religion` stat recalc, Dusk-only non-stacking Campfire heal, recipe craft times, nearest-building lookup.
  - `76e6543` — **Phase 0C + Docs:** Reset/persisted `PlayerController` cooldowns, unit daily/buff/carry fields, faction AI timers, eliminated legacy `v1`/`v2` reload wildlife leaks, added live `KRAG_UL` building `max_hp` scaling & HP clamp, made leader succession synchronous, expanded `verify_campaign_save.gd`.
  - `19ebf54` & `b939303` — **Phase 1:** Added [spatial_index.gd](../scripts/core/spatial_index.gd), [valley_navigation.gd](../scripts/core/valley_navigation.gd), parameterized [world_layout.gd](../scripts/core/world_layout.gd), added 3 visual & navigable river fords, staggered AI/tower/wildlife scans, added [verify_phase1_nav.gd](../scripts/tools/verify_phase1_nav.gd) and [benchmark_simulation.gd](../scripts/tools/benchmark_simulation.gd) (**−56.6% to −66.1% physics median speedup** on seed `17394`).
  - `d786b8e` — **Phase 2A:** Playable Opening Tutorial ([awakening_guide.gd](../scripts/core/awakening_guide.gd) `get_objective_target()`, [tutorial_beacon.gd](../scripts/core/tutorial_beacon.gd), HUD `[x]`/`[ ]` checklist & gold `Build`/`Colony` highlights, `BuildDrawer` `[RECOMMENDED]` auto-select, Valley Radar pulsing target ping, Step 4 constructed `SLEEPING_HUT`, [verify_opening_tutorial.gd](../scripts/tools/verify_opening_tutorial.gd)).
  - `baeaf06` — **Phase 2B:** Baked `Work`, `Wounded`, `Attack`, `Hit`, and `Death` skeletal clips in [generate_tribesman_rig.py](../tools/assets/generate_tribesman_rig.py) & [generate_crag_born.py](../tools/assets/generate_crag_born.py), zero-swap animation & shader hit-flash in [skinned_tribesman_trial.gd](../scripts/entities/skinned_tribesman_trial.gd) & [human_unit.gd](../scripts/entities/human_unit.gd), promoted [crag_born_trial.gd](../scripts/entities/crag_born_trial.gd) to **default-enabled** (`--procedural-roster` opt-out).
  - `9d83547` — **Docs Sync:** Updated `ROADMAP.md`, `FUTURE.md`, `AGENTS.md`, `README.md`, `OVERHAUL.md`, `tools/assets/README.md`.
  - `d6afedf` — **Slice 2C-1.** Promoted Goliath and Swift-Kin skinned Foragers and adult Spearmen.
  - `809c7e0` — **Slice 2C-2.** Promoted Reed Granary, Ridge Signal Tower, Slateback Boar, and Reedjaw. Added golden damage fixtures.
  - `9cc52ab` — **Slice 3A.** Added the expanded valley, classic-compatible v4 saves, and paired layout benchmarks.
  - `7d2742a` — **Slice 3B.** Added the World Map, waypoint projection, and updated controls.
  - `0ce07b5` — **Phase 4.** Added named rival leaders, approach negotiation, truces, tribute, and succession.
  - `abe0fe0` — **Phase 5.** Added crop cycles, animal husbandry, mounting, and `v4` crop, herd, and rider persistence.
  - `1c15eac` through `3f1706c` — Promoted the gate, Flintmask Scout, settlement buildings, and additional skinned wildlife. [Production batches](../tools/assets/OVERHAUL.md#production-batches)
  - `5116026` and `c76cf55` — Added [six wildcard prototypes](../tools/assets/examples/WILDCARD.md) and [eighteen standalone dinosaur models](../tools/assets/examples/DINOSAURS.md) for asset review.
  - `3abde8c` — **Performance baseline:** Recorded rendered/fixed-step frame attribution in [PERFORMANCE.md](PERFORMANCE.md) and ordered optimization plan in [PERFORMANCE_HANDOVER.md](PERFORMANCE_HANDOVER.md).
  - `328f7e8` — First-person POV, Phase 6 perks and tutorial polish, and Refactor Pass 2.
  - `ea441c1` — Phase 7 custom weapons and armor.
  - `95e1c00` — Phase 8 Stone Age SFX and dynamic music.
  - `0f6d6de` — Phase 9 Blood-Pit Trial Arena.

---

## 2. Verified Baseline

The follow-up audit records the fixes, gate commands, and results for first-person POV and Phases 7–9. [Roadmap audit](ROADMAP.md#first-person-and-phases-79-audit)

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
Reference: [Roadmap](ROADMAP.md#phases-79-and-verification-gates) · [Equipment verifier](../scripts/tools/verify_equipment_system.gd)

Completed. Added `GameData.WEAPON_DEFS` (`GREAT_SPEAR`, `STONE_SPEAR`, `FLINT_DIRK`, `HUNTING_BOW`, `WAR_CLUB`, `BARBED_JAVELIN`, `OBSIDIAN_CLEAVER`) and `ARMOR_DEFS` (`HIDE_TUNIC`, `BONE_GUARD`, `PELT_MANTLE`, `OBSIDIAN_PLATE`), expanded `CRAFT_RECIPES`, wired `HumanUnit.equip_loadout()` / `GameState.equip_unit_weapon()` / `equip_unit_armor()` / `UnitStats` / `CampaignSave`, added live 3rd-person & 1st-person gear swaps (`CragBornTrial`, `HumanMeshBuilder`, `FirstPersonViewmodel`), `PlayerController` weapon-driven attacks, and `ColonyDrawer` + `UnitInspector` loadout UI.

### Track H — Phase 8: Stone Age SFX & Dynamic Music
Reference: [Roadmap](ROADMAP.md#phases-79-and-verification-gates) · [Audio verifier](../scripts/tools/verify_audio_system.gd)

Completed. Added [generate_stone_age_audio.py](../tools/audio/generate_stone_age_audio.py) generating Stone Age foley & music loops in `assets/audio/`, pooled `SoundManager` autoload ([sound_manager.gd](../scripts/core/sound_manager.gd)) with `Master`/`Music`/`SFX` buses, 16 throttled SFX cues, and adaptive `TITLE`/`PEACE_DAY`/`NIGHT`/`COMBAT`/`ARENA` music transitions, `Preferences` & `SettingsScreen` Audio sliders, and gameplay audio hooks.

### Track I — Phase 9: Blood-Pit Trial Arena
Reference: [Roadmap](ROADMAP.md#phases-79-and-verification-gates) · [Arena verifier](../scripts/tools/verify_arena_trials.gd)

Completed. Added `ARENA_PIT` (`Lv.3` + `BARRACKS_DRILLMASTERS` Rank 1 in `BuildDrawer`, 4 visual stages, walkable interior, pulsing braziers), [arena_rules.gd](../scripts/core/arena_rules.gd) 5-tier bout system (`CHIEFTAIN` in 1st/3rd-person POV & `EXHIBITION` with `Spectate Ring`), `[E]` Arena tab opening, strict bout isolation from Watchtowers/outside units/mid-bout saves, non-lethal KO & `1.75x` `SHAMAN_SHACK`/`CAMPFIRE` convalescence (`arena_recovery_remaining`), `is_arena_champion` (`+15` HP, `1.10x` DMG), Plan 1 gear drops, and `ColonyDrawer` + `UnitInspector` Arena controls/badges.

### Campaign performance review

Imported human rigs skip hidden procedural poses, Guard Base reuses camp-centered target scans, and Peace invalidates cached hostiles. Lighting submits its palette on phase transitions and uses a smaller sky radiance map. The stress runs improved while remaining above the 16.7 ms rendered-frame budget. Draw and shadow passes, crowded movement, and worker job allocation are the next measured areas. [Results and reproduction](PERFORMANCE.md) · [Performance plan and handover](PERFORMANCE_HANDOVER.md) · [Ranked gameplay and asset proposals](FUTURE.md#ranked-gameplay-and-asset-proposals)

---

## 4. Next Execution Queue: Phase 10 (Slices 10A–10C)

Full scope, owned files, acceptance criteria, and verification gates live in [docs/ROADMAP.md](ROADMAP.md#phase-10-next-execution-queue-slices-10a10c), [docs/FUTURE.md](FUTURE.md#phase-10a-gameplay--world-map-follow-ups), and [docs/PERFORMANCE_HANDOVER.md](PERFORMANCE_HANDOVER.md).

| Track | Slice | Summary | Primary Spec |
| :--- | :--- | :--- | :--- |
| **10A** | `10A-1` | **Warband Rally Marker:** Squad rally destination marker, reform window, and brief warhorn/HUD confirmation across fords and gates. | [ROADMAP](ROADMAP.md#slice-10a--gameplay--world-map-follow-ups) · [FUTURE](FUTURE.md#10a-1-warband-rally-marker) |
| **10A** | `10A-2` | **Colony Job Visibility & Crop Reservations:** Surface active Field/Herds job telemetry and transient Farmer field claims (modeled on Shaman rescue leases). | [ROADMAP](ROADMAP.md#slice-10a--gameplay--world-map-follow-ups) · [FUTURE](FUTURE.md#10a-2-colony-job-visibility--crop-reservations) |
| **10A** | `10A-3` | **Large-Battle Command-Zoom Readability:** Distinct ranged release cue and readable heavy-impact visual/audio readability at command zoom. | [ROADMAP](ROADMAP.md#slice-10a--gameplay--world-map-follow-ups) · [FUTURE](FUTURE.md#10a-3-large-battle-command-zoom-readability) |
| **10A** | `10A-4` | **River Fish Weir Promotion:** Promote `river_fish_weir.glb` to a 4-stage bank structure with legal bank placement, unblocked fords, worker job, and hauling. | [ROADMAP](ROADMAP.md#slice-10a--gameplay--world-map-follow-ups) · [WILDCARD](../tools/assets/examples/WILDCARD.md) |
| **10A** | `10A-5` | **Optional World Map Fog of War:** Toggleable/campaign-tracked exploration shroud over the `760×760 m` World Map revealing camps, caves, and landmarks as units scout. | [ROADMAP](ROADMAP.md#slice-10a--gameplay--world-map-follow-ups) · [FUTURE](FUTURE.md#10a-5-optional-world-map-fog-of-war) |
| **10B** | `10B-1` | **Lateral Guard Base Approach:** Short lateral offset for melee guards blocked by allies outside attack range (`2,421/2,424` stalled approaches). | [PERFORMANCE_HANDOVER](PERFORMANCE_HANDOVER.md#crowded-npc-movement) |
| **10B** | `10B-2` | **Distant Off-Camera Pose Cadence Sampling:** Lower `AnimationPlayer` sampling cadence for distant off-camera locomotion with prompt resampling on camera return. | [PERFORMANCE_HANDOVER](PERFORMANCE_HANDOVER.md#imported-pose-sampling) |
| **10B** | `10B-3` | **Directional Shadow Distance & Cascade Comparison:** Test shorter directional shadow distance and separate cascade-count reduction against stock sun (`59%–73%` draw share). | [PERFORMANCE_HANDOVER](PERFORMANCE_HANDOVER.md#directional-shadows-and-worker-allocation) |
| **10B** | `10B-4` | **Settlement Gatherer Target Allocation:** Break up 30-worker pileups on a single gather node with blocked-approach handling and transient reservations. | [PERFORMANCE_HANDOVER](PERFORMANCE_HANDOVER.md#directional-shadows-and-worker-allocation) |
| **10C** | `10C-1` | **Dinosaur Lineup Campaign/Arena Integration:** Wire selected 18-model dinosaur GLBs (`Velociraptor`..`Brachiosaurus`) into Valley territories and/or Blood-Pit Arena tiers. | [DINOSAURS](../tools/assets/examples/DINOSAURS.md) |
| **10C** | `10C-2` | **Selected Wildcard Prototype Promotions:** Promote chosen wildcard GLBs (`Antler Beacon`, `Mossback Ibex`, `Obsidian Cache`, `Shell Courier Kit`, `Mammoth-Bone Sled`) beyond `10A-4`. | [WILDCARD](../tools/assets/examples/WILDCARD.md) |
| **10C** | `10C-3` | **Blender-Exported `arena_pit_stages.glb`:** Replace procedural `ARENA_PIT` stages with a Blender 4.5 LTS 4-stage + collider GLB matching the building contract. | [ROADMAP](ROADMAP.md#slice-10c--staged-3d-assets--release-packaging) |
| **10C** | `10C-4` | **Refresh `ChristFallow.exe` Release Binary:** Export `ChristFallow.exe` from Godot 4.3 after Phase 10 features stabilize. | [ROADMAP](ROADMAP.md#slice-10c--staged-3d-assets--release-packaging) |

---

## 5. Non-Negotiable Engineering & Verification Rules

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
