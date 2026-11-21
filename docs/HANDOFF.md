# Christ Fallow — Engineering Handoff (21 November 2026)

> **Purpose:** Fast, zero-ambiguity state transfer for continuing Christ Fallow autonomously (e.g., via Codex). Read this file first alongside [AGENTS.md](../AGENTS.md) and [docs/ROADMAP.md](ROADMAP.md).

---

## 1. Current Repository & Environment State

- **Workspace:** `<USERPROFILE>\Desktop\Christ Fallow`
- **Engine / Tooling (Windows):**
  - Godot 4.3 console: `<USERPROFILE>\AppData\Local\Godot\Godot_v4.3-stable_win64_console.exe`
  - Portable Blender 4.5 LTS: `<USERPROFILE>\AppData\Local\Blender\blender-4.5.16-windows-x64\blender.exe`
  - Run from `project.godot` directly; ignore `ChristFallow.exe` and `Christ Fallow.lnk` (`2026-11-18`, stale).
- **Git (`main`, clean working tree):**
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
  - **Phase 5 baseline.** Added crop cycles, animal husbandry, mounting, and `v4` crop, herd, and rider persistence.

---

## 2. Verified Baseline

Every Forward+ suite below passes with exit code `0`, explicit `PASSED` output, and `0` `SCRIPT ERROR` / `Parse Error` / `SHADER ERROR` lines using isolated temp `APPDATA` / `CHRIST_FALLOW_QA_APPDATA`:

| Suite | Scope Verified |
| :--- | :--- |
| [verify_opening_tutorial.gd](../scripts/tools/verify_opening_tutorial.gd) | Steps 1–5, 3D beacon & `[E]` prompts, HUD/BuildDrawer highlights, Sleeping Hut construction, mid-tutorial save/load, once-only reward, Skip + Peace Buffer. |
| [verify_campaign_save.gd](../scripts/tools/verify_campaign_save.gd) | Legacy and v4 saves, corrupt/mismatched-leader rejection, signal order, combat formulas, and all Phase 0A/0B/0C regression suites. |
| [verify_expanded_valley.gd](../scripts/tools/verify_expanded_valley.gd) | Camp spacing, ford routes, raids, hauling, distant construction, World Map projection and waypoint input, and v3/v4 terrain changes. |
| [verify_diplomacy_leaders.gd](../scripts/tools/verify_diplomacy_leaders.gd) | Named leaders, approach negotiation, raid and attack truce guards, tribute, successor identity, and pending-conquest reload. |
| [verify_farming_taming.gd](../scripts/tools/verify_farming_taming.gd) | Crop work and hauling, taming success and failure, pen travel, feeding, breeding, surplus harvest, mount movement and camera, and crop/herd/rider round trips. Runs with the default leader and `--skinned-tribesman-trial`. |
| [verify_campaign_ui.gd](../scripts/tools/verify_campaign_ui.gd) | `1280×720`, `1600×900 --large-ui`, `1920×810 --large-ui`: title/awakening, focus release vs `Space`, non-overlap geometry, `Esc` vs `OptionButton` popup, Diplomacy opinion breakdown & faction-6 recovery, Colony Crafting refresh, UnitInspector, pause/conquest/quit. |
| [verify_phase1_nav.gd](../scripts/tools/verify_phase1_nav.gd) | SpatialIndex parity across spawn/move/convert/death/rubble/save-load; palisade detour & rubble reopening; river ford crossing (`38/38`). |
| [benchmark_simulation.gd](../scripts/tools/benchmark_simulation.gd) | Seed `17394` physics median: Opening `23.943 ms`, Developed `45.300 ms`, Raid `41.956 ms` (down from `61.872 / 104.408 / 123.930 ms`). |
| [verify_glb_assets.gd](../scripts/tools/verify_glb_assets.gd) (`--require-gameplay-rig`) | Building 4-stage + collider contracts; `tribesman_base.glb` 17-bone rig + `Idle`/`Walk`/`Work`/`Wounded`/`Attack`/`Hit`/`Death`. |
| [verify_crag_born.gd](../scripts/tools/verify_crag_born.gd) | Default promoted Crag-Born roster + zero-swap action/hit/death playback, `--check-default-roster`, and `--procedural-roster` opt-out. |
| [verify_skinned_lineages.gd](../scripts/tools/verify_skinned_lineages.gd) | Seven six-body lineups, shared bones and clips, gear fit, combat, child growth, nomad capture and enlightenment, save/load, and roster opt-out. |
| [verify_valley_assets.gd](../scripts/tools/verify_valley_assets.gd) | Four scenery GLBs, wildlife attack and hit volumes, Slateback armor, and four-stage Granary and Tower builds with collider and rubble checks. |

---

## 3. Completed Execution Queue

All six slices through Phase 5 were completed sequentially in independently verified commits on `main`. The asset rollout promoted Standing-Stone Gate in Batch 8 after traversal verification. [Roadmap](ROADMAP.md) · [Engineering conventions](../AGENTS.md)

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

Completed. Farmers use `CROP_FIELD` to plant, tend, harvest, and haul food. `ANIMAL_PEN` shelters tamed Deer and Tusked Boars, feeds them from the stockpile, and supports breeding and surplus harvest. `E` handles taming and mounting or dismounting a trained adult boar. Saves restore crops, ownership, herd and training state, and a mounted player leader. [Shared rules](../scripts/core/farming_rules.gd) · [Farming verifier](../scripts/tools/verify_farming_taming.gd)

---

## 4. Non-Negotiable Engineering & Verification Rules

1. **Godot 4.3 strictness ([AGENTS.md](../AGENTS.md)):**
   - Never add `class_name` to preloaded helper modules (`SpatialIndex`, `ValleyNavigation`, `TutorialBeacon`, `AwakeningGuide`, `UnitStats`, `UnitAIRoutines`, `BlessingEffects`, etc.).
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
