# Christ Fallow asset pipeline

The generators use Blender 4.5 LTS and the game imports their GLBs with Godot 4.3 Forward+. The pipeline was tested with Blender 4.5.16.

Use the [asset catalog](CATALOG.md) to find lineage bodies, kits, and other asset types. The [asset overhaul](OVERHAUL.md) covers rollout and combat design. The [pipeline plan](PLAN.md) records the completed tooling and leader trial.

## Build and review

Run from PowerShell in the project root with the Godot console executable available. This wrapper builds the Sleeping Hut, Palisade, and base tribesman. Use the separate Crag-Born and valley commands below for those batches.

```powershell
# Generate, import, and review the gameplay rig in isolation.
.\tools\assets\build_assets.ps1 -VerifyOnly -RequireGameplayRig

# Verify the gameplay rig and publish validated GLBs to assets/models.
.\tools\assets\build_assets.ps1 -RequireGameplayRig
```

Set `BLENDER_EXE` for a specific Blender executable. Set `GODOT_EXE` or pass `-GodotExe` to override the local Godot 4.3 console path. Verification needs a Forward+ display. The command prints its staging directory and writes the import log, verification log, and three review PNGs there.

The low-level generators accept an explicit output directory. Run them through `run_blender.ps1` for a nonzero exit code on a Python error.

```powershell
$out = Join-Path ([System.IO.Path]::GetTempPath()) 'christ-fallow-individual-assets'
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_village_building.py -ScriptArgs @('--out-dir', $out)
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_tribesman_rig.py -ScriptArgs @('--out-dir', $out)
```

## Building contract

- Put `Stage_Intact`, `Stage_Damaged`, `Stage_Critical`, and `Stage_Rubble` directly under the imported scene root. Each stage needs renderable mesh geometry.
- Use `FactionTrim` for surfaces that take the owning faction's color. Use Godot local `+Z` as the front of the Sleeping Hut so it matches the placement preview.
- Preserve special node names expected by `building_entity.gd`: `CampfireLight` (`OmniLight3D`) and `FlameMesh` (`MeshInstance3D`) on `CAMPFIRE` stages, and `ShamanLight` (`OmniLight3D`) on `SHAMAN_SHACK` stages, so critical dimming, flicker, and destruction shutoff work identically to procedural fallback.
- The exported `Collider-convcolonly` documents the authored footprint. The building entity supplies the active collider, including the palisade's `3.2 × 2.2 × 0.5` m box. Rubble disables collision.
- Construction uses the intact hologram and feedback through the build bar. Completed buildings switch at 66% and 33% HP.

## Character contract

The GLB uses 17 named bones, connected low-poly limbs, vertex weights, and UVs. It exports looping `Idle`, `Walk`, `Work`, and `Wounded` clips (plus `GuardIdle` and `GuardWalk` for Crag-Born), along with one-shot `Attack`, `Hit`, and `Death` clips. The verifier draws the gameplay shader alongside the imported material and checks that the shader colors the `FactionTrim` surface. Supported skinned units remain on the imported rig across all states with zero procedural swap, and `--procedural-roster` opts out back to procedural meshes.

Use `-RequireGameplayRig` before publishing an updated character. The stricter check requires the full clip set, active bone tracks, UVs, and faction trim.

## Play the leader trial

After importing the source project, launch from PowerShell in the project root:

```powershell
$godot = Join-Path $env:LOCALAPPDATA 'Godot/Godot_v4.3-stable_win64_console.exe'
& $godot --path . -- --skinned-tribesman-trial
```

The launch flag selects the imported `tribesman_base.glb` model for the active player leader's idle, movement, work, combat, hit, wounded, and death animations. The great-spear follows `Hand.R`. The flag applies to the process, so loading a save follows the launch mode.

## Crag-Born pilot

Crag-Born Foragers and adult Spearmen outside the leader slot use the imported skinned rig by default. The two men have broad or cropped silhouettes, and the two women wear braids or twin knots. The girl wears a short braid, and the boy has swept hair and a hide tunic. The children share a smaller rig scale with larger heads and narrower limbs. The runtime uses age, gender, and the saved unit ID to select the body, and role and class to select the kit. `--procedural-roster` switches to procedural meshes. `--crag-born-trial` remains a compatibility no-op.

Both kits fit the shared bone names and rest transforms. The rigid weapon and offhand GLBs use grip origins and mount on `Hand.R` and `Hand.L`. The spear and sickle point up in the source model. The chestwear and the basket follow `Chest`. Offsets and carry angles use model rest axes, with `-Z` forward in Godot. `FactionTrim` marks the shared belt and cloth, the buckler ring and chest guard trim, and the basket rim and workwear. The Spearman uses `GuardIdle` and `GuardWalk`, based on the original breathing and stride with raised arms. [Shared loader](../../scripts/entities/crag_born_trial.gd)

### Reproduce the review

Run from the project root in PowerShell. The generator writes six Crag-Born body GLBs and six rigid kit GLBs under the staged `assets/models` tree. `--lineage crag_born` generates only the bodies. Use a fresh, isolated `APPDATA` and set `CHRIST_FALLOW_QA_APPDATA` to the same directory for each Godot invocation.

```powershell
$godot = Join-Path $env:LOCALAPPDATA 'Godot/Godot_v4.3-stable_win64_console.exe'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('christ-fallow-crag-born-' + [guid]::NewGuid())
$staged = Join-Path $scratch 'project'
$review = Join-Path $scratch 'review'
New-Item -ItemType Directory -Path $staged, $review | Out-Null
foreach ($entry in 'project.godot', 'icon.svg', 'icon.svg.import', 'assets', 'scenes', 'scripts') {
    Copy-Item -LiteralPath $entry -Destination $staged -Recurse
}
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_crag_born.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'))
if ($LASTEXITCODE -ne 0) { throw 'Crag-Born generation failed' }
& $godot --headless --editor --path $staged --import --log-file (Join-Path $review 'import.log')
& $godot --path $staged --resolution 1600x900 --quit-after 1800 --log-file (Join-Path $review 'pilot.log') --script res://scripts/tools/verify_crag_born.gd -- "--out-dir=$review"
& $godot --path $staged --quit-after 1800 --log-file (Join-Path $review 'default.log') --script res://scripts/tools/verify_crag_born.gd -- --check-default-roster
& $godot --path $staged --quit-after 1800 --log-file (Join-Path $review 'procedural.log') --script res://scripts/tools/verify_crag_born.gd -- --check-default-roster --procedural-roster
```

Check for `CRAG-BORN PILOT PASSED` and `DEFAULT ROSTER CHECK PASSED` and for clean logs. The verifier writes `crag-born-six-variants.png` at the default 12 m camera distance and 58° FOV with the PSX post-process enabled. Its first row shows both men and the boy, and its second row shows both women and the girl. It also writes the original format of the [kit comparison sheet](previews/crag-born-comparison.png), including a rear view for basket fit and a child Spearman attachment study.

### Review results and gaps

- The six-body pilot reproduced the three original body GLBs byte for byte in Blender 4.5.16 and staged three new imports. In Forward+, `verify_crag_born.gd` confirmed all six live spawns, gear attachment motion, appearance through role changes and reload, and both children growing up. The default and procedural roster modes, `verify_skinned_lineages.gd`, and `verify_campaign_save.gd` also passed with clean logs. Use short scratch paths for `APPDATA` so Forward+ can write its shader cache on Windows.
- During the original three-body trial, Blender 4.5.16 produced matching hashes for all nine body and gear GLBs on repeat export. A fresh Godot 4.3 Forward+ project checked bones and rest transforms, skin binds, vertex weights, UVs, and looping clips.
- Both kits kept their hand, offhand, and back offsets through the sampled gait. Both weapons cleared the floor. At some side-on angles the spear shaft overlaps the shin in the image, and the rear braid can overlap the basket rim. Sun Gold and Moss Green trim remained visible with PSX enabled. The in-game filter toggle also toggled pilot vertex snapping.
- The probe uses the shared campaign-start path, then approaches berries, harvests and deposits food, switches to Spearman in the unit inspector, walks in guard, performs a thrust, takes a directional hit with flash, and returns to Forager with the Colony roster opened via `C`. Starter equipment, human armor mitigation, the Awakening role flag, and the serialized unit ID follow the existing rules. The default roster and the original opt-in leader trial also passed separate launch checks.
- All action states (`Work`, `Attack`, `Hit`, `Death`, and `Wounded`) now play natively on the skinned rig with shader hit-flash and zero procedural fallback swap; the shared walk remains in-place.

## Goliath and Swift-Kin

Goliath and Swift-Kin each have two men, two women, a boy, and a girl. The new Goliath bodies use a broad crest and short beard, paired high knots, and an upright forelock. The new Swift-Kin bodies keep the pointed ears and use a rear sweep, paired low knots, and forward tufts. The loader applies the existing lineage height, width relative to Crag-Born, and the shared child scale to the entire rig, including gear. Run the commands below after staging the project as in the Crag-Born review. Give each Godot run a fresh, short `APPDATA` path and set `CHRIST_FALLOW_QA_APPDATA` to match.

```powershell
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_crag_born.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'), '--lineage', 'goliath', '--lineage', 'swift_kin')
& $godot --headless --editor --path $staged --import
& $godot --path $staged --resolution 1600x900 --quit-after 1800 -s res://scripts/tools/verify_skinned_lineages.gd -- "--out-dir=$review"
& $godot --path $staged --quit-after 1800 -s res://scripts/tools/verify_skinned_lineages.gd -- --procedural-roster
```

Look for `SKINNED LINEAGES VERIFICATION PASSED`. The live campaign probe exercises six-body spawning, role changes, child growth, save/load, guard walk, thrust, gathering, hit flash, wounded and death playback, and corpse scaling. The verifier checks all body and kit combinations and writes `goliath-six-variants.png`, `crag-born-six-variants.png`, and `swift-kin-six-variants.png` at a shared camera distance. The first row of each sheet shows both men and the boy. The second shows both women and the girl. `skinned-lineages.png` compares the lineages side by side. [Verifier](../../scripts/tools/verify_skinned_lineages.gd)

Batch 2 reproduced the six original body GLBs byte for byte in Blender 4.5.16 and added six new bodies. Godot 4.3 imported the stage cleanly. The default and procedural multi-lineage runs, Crag-Born default roster check, and campaign save regression passed in Forward+. Both new comparison sheets were reviewed at the same camera distance.

## Stalker and Ash-Walker

Stalkers have lean limbs, swept ears, green cheek paint, and crests with different heights and angles. Ash-Walkers use ash-grey skin, angular jaws, pale locks, obsidian beads, and emissive ember markings. Each lineage uses six bodies on the same skeleton and shared attachment points as the Crag-Born pilot. Ash-Walker appears as Ash-Born in the game. [Lineage reference](CATALOG.md#lineage-bodies)

Generate all twelve models into the staged project, then import and run the same Forward+ lineage commands used in the Goliath and Swift-Kin review. [Import and test commands](#goliath-and-swift-kin)

```powershell
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_crag_born.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'), '--lineage', 'stalker', '--lineage', 'ash_walker')
```

The verifier adds `stalker-six-variants.png` and `ash-walker-six-variants.png`. It checks that the Stalker remains tall and narrow relative to Crag-Born and that the Ash-Walker markings retain emission in the gameplay shader. [Lineage verifier](../../scripts/tools/verify_skinned_lineages.gd)

Batch 3 generated twelve new bodies with Blender 4.5.16. Godot 4.3 imported all twelve cleanly. The default and procedural five-lineage runs, Crag-Born default roster check, and campaign save regression passed in Forward+. Both new lineups were reviewed at the same gameplay camera distance.

## Fen-Tidal and Cave-Kin

Fen-Tidal bodies use moss-teal skin, gold eyes, ear fins, and variant-specific dorsal crests. Cave-Kin use a heavy jaw, tusks, shaggy hair, and a hunched spine baked into the shared clips. Nomads mount a bone club and trophy pelt. Enlightened captives retain Cave-Kin ancestry and use the Forager kit. [Shared rig loader](../../scripts/entities/crag_born_trial.gd) · [Enlightenment command](../../scripts/systems/combat_command_system.gd)

```powershell
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_crag_born.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'), '--lineage', 'fen_tidal', '--lineage', 'caveman', '--kit', 'caveman')
```

Use the same isolated import and Forward+ commands as for Goliath and Swift-Kin. The lineage verifier adds `fen-tidal-six-variants.png`, `caveman-six-variants.png`, and `cave-kin-kit.png`. It exercises both adult genders in a live nomadic pack, then capture, enlightenment, and reload of the convert and surviving nomads. [Import and test commands](#goliath-and-swift-kin) · [Lineage verifier](../../scripts/tools/verify_skinned_lineages.gd)

## Combat kits

The Knife-Raider carries twin dirks and sheaths, the Archer carries a bow and quiver, the Brute carries a flint maul and trophy rack, and the Javelineer carries a barbed javelin, back bundle, and shared buckler. Their attack clips start at the combat event and animate follow-through. Armor visibility and weapon finishes follow equipped armor and weapon tier. [Gear and motion generator](generate_role_kits.py) · [Runtime mounts](../../scripts/entities/crag_born_trial.gd)

```powershell
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_role_kits.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'))
& $godot --headless --editor --path $staged --import
& $godot --path $staged --resolution 1600x900 --quit-after 1800 -s res://scripts/tools/verify_role_kits.gd -- "--out-dir=$review"
```

Use isolated `APPDATA` for each run. `ROLE KIT VERIFICATION PASSED` confirms live class changes, both hands and back attachments, animation binding, equipment changes, and melee contact or ranged release. `combat-kits.png` shows Knife-Raider, Archer, Club Brute, and Javelineer from left to right. [Role kit probe](../../scripts/tools/verify_role_kits.gd)

## Workforce kits

Hunter mounts a pelt capelet and the shared bow set. Woodcutter carries an axe and timber pack, Stoneknapper carries a flint pick and satchel, Builder/Crafter carries a mallet and adze, Shaman carries a spirit staff and charm, and Trainee uses a blunted spear and shared buckler. Farmer shares the Forager kit. [Workforce generator](generate_workforce_kits.py)

```powershell
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_workforce_kits.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'))
```

Run the combat-kit import and role probe again. `workforce-kits.png` shows the six new roles in the order above. The role probe checks attachments, skinned work, Hunter bow release, and Shaman casting. The farming verifier confirms that a live Farmer can still work crops and haul a harvest. [Import and test commands](#combat-kits) · [Farming verifier](../../scripts/tools/verify_farming_taming.gd)

## Leader kit

The lineage rig is the default for adult player and rival leaders. A faction-tinted bone crown and split mantle distinguish the leader. The kit mounts a great-spear and reuses the javelin bundle. The nameplate and campaign leadership rules still follow the live unit. `--skinned-tribesman-trial` selects the original trial model for the player. [Leader generator](generate_leader_kit.py) · [Leader unit setup](../../scripts/entities/human_unit.gd)

```powershell
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_leader_kit.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'))
```

The isolated Forward+ role, diplomacy, and farming probes passed, including procedural roster mode and riding with both the default and original trial leaders. The role probe writes `leader-kit.png`. The farming probe writes `mounted-leader.png`. [Role kit commands](#combat-kits) · [Mounted review](#farm-structures-and-rider-review)

## Valley scenery and wildlife

The wind-bent pine, moss limestone, and berry thicket use the existing tree, stone, and berry resource slots. The reed beds follow both riverbanks in each layout. Tusked Boar and Sabertooth keep their wildlife IDs, roaming, and immediate attack damage. Their GLBs face Godot local `-Z` and export a one-shot `Bite`. The asset verifier runs on the classic layout to compare imported assets against the original terrain. [Layout definitions](../../scripts/core/world_layout.gd)

To regenerate the original four scenery GLBs and two wildlife GLBs, run from the project root in PowerShell. [Original Forward+ comparison](previews/valley-assets.png)

```powershell
$godot = Join-Path $env:LOCALAPPDATA 'Godot/Godot_v4.3-stable_win64_console.exe'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('christ-fallow-valley-' + [guid]::NewGuid())
$staged = Join-Path $scratch 'project'
New-Item -ItemType Directory -Path $staged | Out-Null
foreach ($entry in 'project.godot', 'icon.svg', 'icon.svg.import', 'assets', 'scenes', 'scripts') {
    Copy-Item -LiteralPath $entry -Destination $staged -Recurse
}
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_valley_assets.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'))
if ($LASTEXITCODE -ne 0) { throw 'Valley asset generation failed' }
& $godot --headless --editor --path $staged --import --log-file (Join-Path $scratch 'import.log')
& $godot --path $staged --resolution 1600x900 --quit-after 900 --log-file (Join-Path $scratch 'review.log') --script res://scripts/tools/verify_valley_assets.gd -- "--out-dir=$scratch"
```

Check for `VALLEY ASSETS PASSED` and clean logs. The campaign probe covers imported resources, `E` harvesting, roaming, prey detection, jaw motion, attack replay, and pause. The comparison sheet shows four attack poses with PSX enabled. Missing imports fall back to procedural meshes.

## Reed Granary, Ridge Signal Tower, and new wildlife

The Storage Mound (`STORAGE_PIT`) and Watchtower (`WATCHTOWER`) use the promoted four-stage GLBs. The tower’s standing stages include a brazier light, flame mesh, and an arrow marker above the remaining deck. The wildlife batch adds Slateback Boar’s plates and Reedjaw’s low profile and timed bite. Standing-Stone Gate was promoted in a later batch after its opening passed traversal checks. [Gate review](#standing-stone-gate)

After staging the project as above, use fresh isolated `APPDATA` and `CHRIST_FALLOW_QA_APPDATA` for each Godot launch.

```powershell
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\examples\generate_examples.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'), '--production')
& $godot --headless --editor --path $staged --import
& $godot --path $staged --resolution 1600x900 --quit-after 900 -s res://scripts/tools/verify_valley_assets.gd -- "--out-dir=$scratch"
```

Check `VALLEY ASSETS PASSED` and inspect `valley-assets.png` and `valley-buildings.png`. The verifier exercises blueprint completion, damage stages, arrow origin and rubble clearance, plus Slateback armor, Reedjaw’s dodge window and projectile hit volume. [Valley verifier](../../scripts/tools/verify_valley_assets.gd) · [Damage and save fixtures](../../scripts/tools/verify_campaign_save.gd)

## Standing-Stone Gate

The gate appears in Build → Defences. It uses the four-stage prototype with faction carvings. The building entity has two physical pier boxes. Valley navigation checks those pier bounds precisely so the 4 m grid keeps the opening usable. [Gate dimensions](../../scripts/core/standing_stone_gate.gd) · [Route checks](../../scripts/core/valley_navigation.gd)

```powershell
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_standing_gate.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'))
& $godot --headless --editor --path $staged --import
& $godot --path $staged --resolution 1600x900 --quit-after 1800 -s res://scripts/tools/verify_standing_gate.gd -- "--out-dir=$review"
```

Use isolated app data. The Forward+ probe places a blueprint, checks leader and AI routes at all eight rotations, walks a colonist through the opening, and reloads the critical gate before testing rubble. It writes `standing-stone-gate.png`. [Gate verifier](../../scripts/tools/verify_standing_gate.gd)

## Flintmask Scout

Each new nomadic pack includes one Flintmask Scout. The carved mask and hooked club distinguish the light skirmisher. Campaign snapshots store its optional archetype so saves created before the rollout still load. [Scout generator](generate_flintmask_scout.py) · [Nomad spawning](../../scripts/systems/faction_controller.gd)

```powershell
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_flintmask_scout.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'))
& $godot --headless --editor --path $staged --import
& $godot --path $staged --resolution 1600x900 --quit-after 1800 -s res://scripts/tools/verify_flintmask_scout.gd -- "--out-dir=$review"
```

The Forward+ probe covers actual cave spawning, attack contact, the full skin lifecycle, reload, invalid archetypes, and `--procedural-roster`. It writes `flintmask-scout.png`. [Scout verifier](../../scripts/tools/verify_flintmask_scout.gd)

## Settlement building batches

The economy batch imports the Campfire, Forager Lodge, and Crafting Pit at the existing footprints. The Campfire retains its flame, light, and dusk healing. Each building has four damage stages. [Settlement generator](generate_settlement_assets.py) · [Building contract](#building-contract)

```powershell
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_settlement_assets.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'), '--batch', 'settlement')
& $godot --headless --editor --path $staged --import
& $godot --path $staged --resolution 1600x900 --quit-after 1800 -s res://scripts/tools/verify_settlement_assets.gd -- --batch=settlement "--out-dir=$review"
```

With isolated app data, `SETTLEMENT ASSET VERIFICATION PASSED` covers rotated placement, building behavior, hostile damage stages, reload, and rubble. `settlement-buildings.png` shows Campfire, Lodge, and Pit across all four stages. The opening tutorial and campaign save suites also passed. [Settlement verifier](../../scripts/tools/verify_settlement_assets.gd)

Use `--batch warband` in the Blender command and `--batch=warband` in the verifier for Sacred Totem, Healing Shack, Weapon Rack, and Barracks. `warband-buildings.png` shows those models in that order. The Forward+ probe verified the Totem’s Faith bonus and captive enlightenment, lit Healing Shack rescue and recovery, stockpile equipment, and Barracks training. The diplomacy regression also passed.

## Wildlife lineup

The woodland batch adds a bounding Deer with antlers and a Dire Wolf with a dark shoulder ruff. Both use idle, walk, and run clips, and the wolf plays a one-shot `Bite`. The megafauna batch adds Woolly Mammoth and Giant Cave Bear with idle and walk loops and one-shot `Stomp` and `Swipe` clips. The bosses use their existing damage and rewards, with projectile heights matched to their new torsos. [Wildlife generator](generate_wildlife_lineup.py) · [Wildlife runtime](../../scripts/entities/wildlife_entity.gd)

```powershell
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_wildlife_lineup.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'), '--batch', 'woodland')
& $godot --headless --editor --path $staged --import
& $godot --path $staged --resolution 1600x900 --quit-after 1800 -s res://scripts/tools/verify_wildlife_lineup.gd -- --batch=woodland "--out-dir=$review"
```

Use isolated app data. `WILDLIFE LINEUP VERIFICATION PASSED` covers both layouts, wild flight, deer taming and ownership, wolf pursuit and bite, torso projectile contact, hunting yields, and save/load. `woodland-wildlife.png` compares both animals. The valley asset and farming regressions also passed. [Wildlife verifier](../../scripts/tools/verify_wildlife_lineup.gd)

For Mammoth and Cave Bear, use `megafauna` for both batch arguments. The same success marker covers mammoth retaliation, bear pursuit, animated area attacks and cooldowns, projectile contact, boss markers, loot, and save/load in both layouts. Review `megafauna-wildlife.png` for the idle and attack silhouettes. The woodland and expanded-valley checks also passed after importing both bosses.

## Farm structures and rider review

The Crop Field and Animal Pen use four imported damage stages. Field rows and pen fencing stay walkable so Farmers, animals, and the rider can pass through. The `Crops` child in the active stage follows growing, ripe, and fallow states. The mount reuses the Tusked Boar GLB. [Building stage loader](../../scripts/core/world_mesh_builder.gd) · [Saddle height](../../scripts/core/farming_rules.gd)

Use `--batch farm` in the Blender settlement command and `--batch=farm` in the settlement verifier. It writes `farm-buildings.png`. The farming verifier checks the same models during planting, harvest, husbandry, riding, and reload. [Settlement commands](#settlement-building-batches)

Run the farming verifier with `--out-dir` to capture `mounted-leader.png`. Run it again with `--skinned-tribesman-trial` in a fresh scratch directory to inspect the skinned rider. [Commands](../../docs/ROADMAP.md#verification-gate-commands-windows-powershell) · [Farming verifier](../../scripts/tools/verify_farming_taming.gd)
