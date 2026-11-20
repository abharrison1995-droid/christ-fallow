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

Crag-Born Foragers and adult Spearmen outside the leader slot now use the imported skinned rig **by default** (`--procedural-roster` opts back out to procedural meshes; `--crag-born-trial` is retained as a compatibility no-op). The child has a larger head, narrower limbs, and a smaller model scale on the same rig. The braided and broad adult bodies follow the existing gender field. Role and class select a kit at runtime using the existing unit state.

Both kits fit the shared bone names and rest transforms. The rigid weapon and offhand GLBs use grip origins and mount on `Hand.R` and `Hand.L`. The spear and sickle point up in the source model. The chestwear and the basket follow `Chest`. Offsets and carry angles are defined in [the pilot loader](../../scripts/entities/crag_born_trial.gd) in model rest axes, with `-Z` forward in Godot. Tune those offsets for future lineage profiles. `FactionTrim` marks the shared belt and cloth, the buckler ring and chest guard trim, and the basket rim and workwear. The Spearman uses `GuardIdle` and `GuardWalk`, based on the original breathing and stride with raised arms.

### Reproduce the review

Run from the project root in PowerShell. The generator writes three body GLBs and six rigid kit GLBs under the staged `assets/models` tree.

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

Check for `CRAG-BORN PILOT PASSED` and `DEFAULT ROSTER CHECK PASSED` and for clean logs. The [comparison sheet](previews/crag-born-comparison.png) uses the default 12 m camera distance and 58° FOV at 1600×900 with the PSX post-process enabled. The front columns use the same angle and native pixel scale. The rear column shows the basket fit. The child Spearman view is an attachment fit study.

### Review results and gaps

- Blender 4.5.16 produced matching hashes for all nine GLBs on repeat export and reproduced the existing leader GLB byte for byte. A fresh Godot 4.3 Forward+ project imported the models, matched all 17 named bones and rest transforms against the existing tribesman, and verified skin binds, vertex weights, UVs, and looping clips.
- Both kits kept their hand, offhand, and back offsets through the sampled gait. Both weapons cleared the floor. At some side-on angles the spear shaft overlaps the shin in the image, and the rear braid can overlap the basket rim. Sun Gold and Moss Green trim remained visible with PSX enabled. The in-game filter toggle also toggled pilot vertex snapping.
- The probe uses the shared campaign-start path, then approaches berries, harvests and deposits food, switches to Spearman in the unit inspector, walks in guard, performs a thrust, takes a directional hit with flash, and returns to Forager with the Colony roster opened via `C`. Starter equipment, human armor mitigation, the Awakening role flag, and the serialized unit ID follow the existing rules. The default roster and the original opt-in leader trial also passed separate launch checks.
- All action states (`Work`, `Attack`, `Hit`, `Death`, and `Wounded`) now play natively on the skinned rig with shader hit-flash and zero procedural fallback swap; the shared walk remains in-place.

## Valley scenery and wildlife

The wind-bent pine, moss limestone, and berry thicket use the existing tree, stone, and berry resource slots. The reed beds follow both banks of the existing river and are decorative. The skinned Tusked Boar and Sabertooth use their existing wildlife IDs, spawn counts, roaming, and attack rules. Both GLBs face Godot local `-Z` and export a one-shot `Bite`. Boar tosses its tusks after opening its mouth. Sabertooth crouches and snaps its jaw. Movement continues to use the campaign's existing body motion.

To regenerate the six GLBs and the [Forward+ review sheet](previews/valley-assets.png), run from the project root in PowerShell:

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

Check for `VALLEY ASSETS PASSED` and clean logs. The campaign probe covers imported resource spawning, harvesting a berry thicket with `E`, boar roaming, sabertooth prey detection, jaw motion and replay, pause, normal damage, and serialized wildlife IDs. The review sheet shows both bites with PSX enabled. Damage still lands when the AI starts the attack, before the animated jaws close. Missing imports fall back to the procedural animal or resource mesh.
