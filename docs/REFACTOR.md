# Codebase refactor plan

**Implemented 20 November 2026.** The rebuilt title screen and in-game UI were the reference for comparing behavior and layout.

## Goal

Give campaign rules, session lifecycle, and UI panels clear owners so each can change independently. Preserve the player-facing flows, the Godot 4.3 Forward+ rendering path, the single campaign save slot, and the current balance. The [larger valley and world map](FUTURE.md) and the [asset rollout](../tools/assets/OVERHAUL.md) have their own plans.

## What drove the order

| Finding | Refactor implication |
| --- | --- |
| The HUD advanced the Awakening Guide and paid its reward during refresh. Drawer callbacks wrote patron and tenet choices into faction data. | Put campaign rules behind shared actions before extracting UI panels. A hidden, rebuilt, or replaced panel should have no effect on whether a rule runs. |
| The title mounted the world directly. `GameState` combined scene references, file access, campaign state, and the load sequence. | Define one start/load/end sequence. `game_started` can fire before the world is ready. |
| `HumanUnit` combined stats, gear, animation, damage, faction transitions, and combat AI. | Extract calculations and threat decisions first. Reuse `UnitAIRoutines` and `BlessingEffects`, and let the unit retain lifecycle and presentation. |
| Simulation loops scan scene containers, and the ground, placement, and radar used extents defined in different files. | Measure scan cost before indexing. Keep each existing extent and document its purpose in the shared layout. |

[HUD controller](../scripts/ui/hud_controller.gd) · [Drawer builders](../scripts/ui/hud_drawers.gd) · [GameState](../scripts/core/game_state.gd) · [World manager](../scripts/systems/world_generator.gd) · [HumanUnit](../scripts/entities/human_unit.gd)

## Implementation sequence

### 0. Establish a repeatable baseline (Completed)

- Bring the smallest useful parts of the 20 November UI probes into a repo-owned `SceneTree` verifier. Exercise controls through the title scene, HUD buttons, and viewport input. Keep generated fixtures, saves, and captures in an isolated scratch directory.
- Cover Start → Awakening → recruit three wanderers with `E` → place the Campfire through `B` and the HUD button. Check the Peace Buffer, blocked input while a drawer is open, `Esc` precedence, and guide completion or skip. Include repeated title → campaign → title cycles and conquest modal ownership.
- Add a focused persistence probe for a current `v3` round trip, representative `v1` and `v2` saves, a malformed or unsupported save, and an in-session reload. Assert live state and signal order. Reuse the existing asset verifiers for mesh, collider, and rig contracts.

**Exit check.** The two probes report explicit success, and a clean Forward+ run captures the title, opening HUD, Build, and a modal at 1600×900 and 720p. Include a wide layout and both ends of the UI scale range when setting the visual baseline.

### 1. Move campaign rules out of the HUD (Completed)

- Start with Awakening. Move the progression checks and reward to campaign-owned code using the existing flags and update paths. Let the guide render progress and request Skip. Move objectives to a gameplay query only where they reuse the same facts.
- Route patron selection, tenet changes, and role assignment through gameplay actions with existing validation and notifications. Reuse the action from every entry point that performs it, including Colony and the unit inspector. Extract one action family at a time.
- Give pause transitions a campaign-owned entry point. Keep modal visibility, focus, and input capture with the HUD. Verify that manual pause, a pending conquest, and campaign results cannot accidentally resume the simulation.

**Exit check.** Guide completion awards +10 Food, +10 Wood, and +5 Flint once. Skip leaves the Peace Buffer active. Saving and loading resumes the same guide step. Shared role and faith actions have the same effects from their existing entry points.

### 2. Split the HUD by feature (Completed)

- Extract Build and Colony first, followed by Faith, Diplomacy, and the inspector. Move the remaining HUD feature views and campaign dialogs where independent scene composition helps. Keep `hud_controller.gd` as the coordinator for navigation, signals, and which view owns input. Reuse `FallowTheme` and `MenuOverlay`.
- Give each extracted view its own selection, refresh, and focus state. Refresh live values in place when practical. When rows do need rebuilding, restore selection by building ID, unit ID, or faction ID instead of the visible button label.
- Keep world input in `PlayerController` and centralize each shared menu or tactical action at its current boundary. Preserve `Tab` and `M`, `P`, `F9/F10`, `B/C/R/V`, and squad shortcuts. Keep layout and control-copy changes out of this pass so screenshot comparisons can reveal regressions.

**Exit check.** Hotkeys and buttons agree, a click on UI never places a blueprint or attacks, long names and scrolling preserve selection, and the HUD remains readable at the verified window sizes and scale range.

### 3. Make campaign lifecycle and save ownership explicit (Completed)

- Keep the existing `GameState` entry points while extracting file access and atomic writing from live campaign application. Use `CampaignSave` as the shared validation and normalization boundary for title preview, Continue, and gameplay load. Maintain temporary sibling writes and the existing filename.
- Document and enforce the sequence from scene creation through registration, population or restore, leader attachment, and HUD activation. Centralize teardown and make repeated return-to-title safe. Treat legacy saves missing wildlife differently on cold load and in-session reload as the current code does.
- Reproduce the intermittent title shutdown warning recorded below. Check both the normal Quit button and process exit, including title ambience disposal, when verifying session teardown.
- Keep restore pairs close to the owning entity. Preserve unit IDs where valid, repair missing or duplicate IDs as today, and retain serialized cooldowns, faction state, warhorn, squad orders, pending conquest, and damage stages. Keep `ui_preferences.cfg` separate.

**Exit check.** Invalid loads leave the active campaign intact. `campaign_loaded` follows live restoration and combat-command restore. Pending conquest opens after that signal. Cold load, quick load, and repeated launches leave no stale HUD, controller, entity, or build-preview references. The refactor emits `v3` saves.

### 4. Extract unit rules and then measure simulation cost (Completed — spatial indexing deferred to [Phase 1 of the master roadmap](ROADMAP.md#phase-1-simulation-performance--navigation-foundation))

- Extract stat derivation and selected damage calculations into directly callable helpers. Keep `HumanUnit` responsible for HP changes, wounding, death, conversion, and presentation. Preserve serialized IDs, equip behavior, current attack timing, and projectile faction attribution when the shooter disappears.
- Take one responsibility at a time out of the unit tick. Reuse `UnitAIRoutines` for schedules and target queries and `BlessingEffects` for shared blessings. Keep animation and skin handoff intact while changing decisions.
- Profile a fixed-seed opening, a developed settlement, and a raid before adding caches or a spatial index. If scans dominate, change one query family and test updates on spawn, death, conversion, destruction, and load. Consolidate world extent values into a shared layout description while preserving the current ground, placement, and radar extents.
- Split large content or mesh helpers by domain only where it makes the verified gameplay boundary easier to maintain. Keep stable enum values, serialized keys, and GLB node/material contracts. Leave balance and visual promotion decisions with the [asset and combat design plan](../tools/assets/OVERHAUL.md).

**Exit check.** Fixed-input combat outcomes agree with the baseline, including civilian self-defense, a Brute hitting a building, and a projectile whose shooter was removed. Crag-Born and valley checks pass with Forward+. Performance claims include before and after measurements from the same scenarios.

## First implementation batch

The first batch established the Forward+ campaign and save probes, then moved **Awakening Guide progression and reward** into campaign processing. The probes also provide the entry points for checking the later extractions.

When a slice lands, record its status and the verification command, gameplay path, and result here. Update the [agent guide](../AGENTS.md) when a responsibility or entry point moves.

## Delivered changes

| Area | Implementation |
| --- | --- |
| Campaign rules | `AwakeningGuide` advances from the campaign tick. `GameState` owns role and faith actions and manual and conquest pause. |
| UI | Build, Colony, Faith, Diplomacy, and Tribal Command have their own drawer views. The unit inspector and campaign overlays own their own controls. Drawer refreshes retain focus by stable identity. |
| Sessions and persistence | `CampaignSession` owns the mounted scene. `CampaignStorage` handles file access and staging writes. Entity restore methods sit beside serialization. |
| Simulation | `UnitStats` owns stat math, `UnitAIRoutines` owns civilian threat response, and `WorldLayout` describes the existing world extents. |

An independent GPT‑6.1 Terra High review found a stale Colony roster after maturation, an unvalidated save reference, and a suspended coroutine in the Quit probe. The roster now refreshes when a unit's role, class, or eligibility changes. New v3 saves with a live player leader record and validate that unit's ID. Unmarked saves retain their previous behavior, including legitimate leaderless states. The Quit probe ends its coroutine before shutdown. The reviewer rechecked the fixes and found no new actionable regression.

## Implementation verification

Run from PowerShell in the project root. Set `$godot` to the Godot 4.3 console executable and `$qa` to a short, empty scratch directory outside the project. Use a fresh directory for each UI attempt because the verifier exercises the default campaign save slot.

```powershell
New-Item -ItemType Directory -Path $qa -Force | Out-Null
$env:APPDATA = $qa
$env:CHRIST_FALLOW_QA_APPDATA = $qa
$project = (Get-Location).Path
& $godot --path $project --fixed-fps 60 --quit-after 900 -s res://scripts/tools/verify_campaign_save.gd
& $godot --path $project --resolution 1600x900 --fixed-fps 60 --quit-after 900 -s res://scripts/tools/verify_campaign_ui.gd -- "--out-dir=$qa/captures" --large-ui
```

Require `CAMPAIGN SAVE VERIFICATION PASSED` and `CAMPAIGN UI VERIFICATION PASSED`, a zero exit code, and no script errors. For responsive checks, repeat at `1280x720` without `--large-ui` and `1920x810` with it. The save probe also exercises the guide reward with the HUD hidden and verifies civilian self-defense, Brute damage to buildings, and projectile attribution after the shooter is gone.

### Results

- The final save probe passed its v1, v2, and v3 fixtures, corrupt and unsupported saves, signal order, legacy wildlife behavior, and fixed-input combat checks. Removing the recorded leader from a newly written save leaves the live campaign intact.
- The final UI probe passed at 1280×720, 1600×900, and 1920×810. Each run exercised title navigation, recruitment, blueprint controls, Colony maturation and Faith focus, save/load, conquest pause, repeated return to title, and Quit. The quit-time resource warning was absent. Three separate title startup runs with `--quit-after 120` also exited cleanly.
- The Crag-Born, Valley Assets, and strict gameplay-rig verifiers passed in Forward+. The final showcase produced seven PNGs. A scratch copy with a fresh asset cache imported cleanly.

### Simulation measurement

The Forward+ probe used seed `17394` at 1280×720 on the Intel UHD 620. After 15 warm-up physics frames, it sampled 30 physics frames per scenario. The target-search column measures a separate batch of 100 existing `find_enemy_near_point()` calls, with 11 batches per scenario and the median reported.

| Scenario | Unit nodes | Building nodes | Physics median | 100 target searches |
| --- | ---: | ---: | ---: | ---: |
| Opening | 43 | 37 | 36.329 ms | 18.346 ms |
| Developed settlement | 91 | 50 | 61.889 ms | 19.584 ms |
| Raid | 107 | 51 | 69.126 ms | 23.013 ms |

The search batch measures the cost of that query on each population. It does not measure its share of the live frame. A spatial index remains a separate optimization pending attribution of the frame cost.

## Baseline checks from the planning audit

- Checked local links and headings across all nine project Markdown files. All 56 lineage multipliers and armor values in the asset plan match `GameData.LINEAGE_DATA`.
- Ran the [agent guide's Forward+ checks](../AGENTS.md#verification-on-windows) at 1280×720 with isolated application data. The strict GLB verifier reported `ASSET VERIFICATION PASSED (gameplay rig contract)` and wrote three review images. The asset showcase wrote seven images, including the current Awakening screen and in-game HUD.
- The original direct source launch reported `ObjectDB instances leaked at exit` once under `--quit-after 120`. That result became a lifecycle regression check. See the final startup and Quit results above.
