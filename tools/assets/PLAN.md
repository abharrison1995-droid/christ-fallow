# Asset Pipeline Improvement Plan

**Status** — complete. This document records the tooling, building integration, and single-leader trial batches. Find current commands in the [asset pipeline guide](README.md) and remaining visual work in the [asset rollout](OVERHAUL.md).

## Objective

Make the Blender-to-Godot pipeline reliable enough for unattended asset generation, correct the current building integration, and prove the imported character on one playable unit before expanding its use.

## Completed implementation sequence

| Pass | Scope | Completion criteria |
| --- | --- | --- |
| 1. Generation | Propagate Blender Python errors, document the tested version, and build into a clean staging directory. Publish the three GLBs after verification succeeds. | A failing generator exits with an error and preserves the previous assets. A successful build imports and validates both buildings and the character before publishing. |
| 2. Verification | Check the exact building stage hierarchy, faction trim through the production loader, character skin bindings, and required animations. Render the current assets using Forward+. | Invalid stages, missing skin binding, and missing required clips fail the applicable check. A successful run produces one review image for each asset. |
| 3. Building integration | Keep blueprints visually intact during construction, preserve damage feedback, and match the finished hut's local forward to the preview. Use a rectangular palisade collision shape owned by the building entity. | Unfinished and damaged buildings survive save/load with the expected visuals. Rotated huts face the preview direction. Units can pass alongside palisades, and rubble no longer blocks movement. |
| 4. Building art | Give the damaged hut a torn roof and the critical hut visibly broken rafters. Shorten or break a fence stake in the damaged stage and bring its faction marker forward. | All four states read distinctly at gameplay zoom with the PSX filter enabled. The revised assets pass the generation and runtime checks. |
| 5. Character trial | Close the limb gaps, add UVs and face material assignments, and export looping Idle and Walk clips. Try the imported rig on one opt-in unit with a hand-mounted weapon. | The character walks and turns without visible gaps. The weapon tracks the hand, and faction colors are readable. Verify the trial before replacing the procedural rig on other units. |

## Verification used for the rollout

- The first batch completed passes 1–3. The second batch used the same generation and verification path for passes 4 and 5.
- The prototype gate required a working Idle clip. The gameplay gate also checked Walk, UVs, and faction trim. The second batch passed the gameplay gate before publishing the rig.
- Use the normal asset import and gameplay loading paths. Keep saves and captures in temporary directories. Check both imported buildings and a procedural fallback.
- Record the Blender and Godot versions, output paths, and verification result when handing off each batch.

## First batch results

Passes 1–3 were completed with Blender 4.5.16 LTS and Godot 4.3 Forward+. The staged build imported all three GLBs, saved three review PNGs, and published the corrected hut model. The generation failure test returned exit code 1 and preserved the prior GLBs.

The verifier rejected an incorrectly named damage stage and a character mesh with a missing skin binding. The original tribesman passed the prototype check and failed the gameplay check. The building checks covered doorway alignment at two yaws, collision beside and through joined palisades, and rubble collision removal. A campaign save/load round trip preserved an untouched blueprint, a damaged wall, and a critical hut.

## Second batch results

Passes 4 and 5 were completed with Blender 4.5.16 LTS and Godot 4.3 Forward+. The damaged hut has torn thatch and exposed rafters. Its critical stage leaves broken timbers and scraps. The damaged palisade has a snapped stake, and the faction marker wraps the beam on the intact and damaged stages. All four stages were reviewed at gameplay zoom with the PSX filter enabled.

`build_assets.ps1 -RequireGameplayRig` verified and published the three regenerated GLBs. The new tribesman passed bone, weight, UV, faction material, and looping animation checks. A live campaign tested movement, turning, the great-spear grip, and save/load with the opt-in player leader. Attacks switched to the procedural animation, and a default campaign used the procedural leader throughout.

The plan closed with the single-leader trial. See the [launch instructions](README.md#play-the-leader-trial) and the later [Crag-Born pilot review](README.md#crag-born-pilot).
