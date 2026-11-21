# Christ Fallow wildcard models

Six Blender prototypes for review after the production rollout. The sheets use the game’s lighting and PSX filter. Every model has an individual GLB. [Gameplay-scale sheet](previews/wildcard-gameplay.png) · [Close views](previews/wildcard-close.png)

| Pick | Model | Where it could fit | Work to bring it into the campaign |
| --- | --- | --- | --- |
| 1 | **Antler Beacon** | A trail or ford marker with a carved ward suspended between split antlers. | Add a base collider and choose whether the ward lights up when a scout approaches. [GLB](models/wildcard/antler_beacon.glb) |
| 2 | **River Fish Weir** | A shallow-water food source. Woven walls funnel fish into a reed basket. | Check placement against river flow and ford cells. Add a fish yield loop and a harvest pose. [GLB](models/wildcard/river_fish_weir.glb) |
| 3 | **Mossback Ibex** | A wary herd animal for rocky slopes and the valley rim. Swept horns distinguish it from the deer. | Add a quadruped rig, bounding gait, slope-aware routes, and a body-sized hit volume. [GLB](models/wildcard/mossback_ibex.glb) |
| 4 | **Obsidian Cache** | A low, cloth-marked stone deposit for exploration rewards near cave routes. | Add an opening pose, a placement footprint, and one-use reward persistence. [GLB](models/wildcard/obsidian_cache.glb) |
| 5 | **Shell Courier Kit** | A roll pack with a shell-marked flap for a trader, messenger, or diplomatic escort. | Fit the pack to the shared chest mount and check the gait, crest clearance, and faction trim. [GLB](models/wildcard/shell_courier_kit.glb) |
| 6 | **Mammoth-Bone Sled** | A load platform with bone runners for hauling stone, timber, or a large carcass. | Add a tow attachment, a turning envelope, and loaded and unloaded movement checks. [GLB](models/wildcard/bone_sled.glb) |

The selected designs can become a later production batch. [Production plan](../OVERHAUL.md#wildcard-model-round)

## Regenerate and verify

From the repository root, use a scratch copy of the source project at `$staged`, an absolute output directory at `$review`, and the Godot 4.3 console executable at `$godot`. Set `APPDATA` and `CHRIST_FALLOW_QA_APPDATA` to the same fresh scratch directory before running Godot.

```powershell
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_wildcard_models.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'))
& $godot --headless --editor --path $staged --import
& $godot --path $staged --resolution 1600x900 --quit-after 1800 -s res://scripts/tools/verify_wildcard_models.gd -- "--out-dir=$review"
```

`WILDCARD MODEL VERIFICATION PASSED` confirms all six scenes imported with visible geometry and both PSX sheets were written. Review the sheets at gameplay scale and close range before replacing the published previews. [Verifier](../../../scripts/tools/verify_wildcard_models.gd)
