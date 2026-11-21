# Christ Fallow asset samples

Six standalone 3D samples and six wildcard prototypes generated in Blender. The examples live under `tools/`, which Godot ignores in the main project. See the [asset catalog](../CATALOG.md) and [overhaul plan](../OVERHAUL.md) for how the samples fit into the game.

## Structures

- **Ridge Signal Tower** loses ladder rungs and railing, then collapses into split posts and scattered stonework. [GLB](models/buildings/ridge_signal_tower.glb)
- **Standing-Stone Gate** loses part of its lintel before the remaining uprights break down into a rubble field. [GLB](models/buildings/standing_stone_gate.glb)
- **Reed Granary** loses its thatch cover and spills grain as the raised deck gives way. [GLB](models/buildings/reed_granary.glb)

Each has the four direct-child stage nodes from the [building contract](../README.md#building-contract) and authored collision references. Show one stage at a time when previewing the raw scene. The gate uses separate pier colliders so its opening stays clear.

## Enemy concepts

- **Flintmask Scout** is a masked humanoid with a hooked club carried by its right hand. [GLB](models/characters/archetypes/flintmask_scout.glb)
- **Slateback Boar** is a stocky tusked animal with overlapping stone-colored back plates. [GLB](models/wildlife/slateback_boar.glb)
- **Reedjaw** is a low marsh predator with splayed legs, amber eyes, and a ridged tail. [GLB](models/wildlife/reedjaw.glb)

All three samples have a bound skeleton and looping `Idle` and `Walk` clips. The production Slateback Boar and Reedjaw exports use the `--production` branch of the generator. [Campaign asset pipeline](../README.md#reed-granary-ridge-signal-tower-and-new-wildlife)

## Review and regenerate

[Destruction stage sheet](previews/destruction-stages.png) · [Enemy pose sheet](previews/enemy-concepts.png)

From the repository root, generate the GLBs with the shared Blender wrapper:

```powershell
$examples = Join-Path (Get-Location).Path 'tools/assets/examples'
.\tools\assets\run_blender.ps1 -ScriptPath "$examples/generate_examples.py" -ScriptArgs @('--out-dir', "$examples/models")
```

For a render check, copy the `models` folder to the root of a scratch Godot 4.3 Forward+ project so the files resolve under `res://models/`. Import the scratch project, then run the example verifier. `$godot` is the Godot 4.3 console executable and `$scratchProject` is the absolute path to that project.

```powershell
& $godot --headless --editor --path $scratchProject --import
& $godot --path $scratchProject --quit-after 140 -s "$examples/render_examples.gd" -- "--out-dir=$examples/previews"
```

The verifier checks stage meshes and colliders, then samples both clips on every skinned enemy before writing the sheets.

## Wildcard models

The six review prototypes have individual GLBs and numbered Forward+ sheets. [Models and proposed campaign uses](WILDCARD.md)
