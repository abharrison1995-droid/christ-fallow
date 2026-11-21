# Christ Fallow dinosaur lineup

Eighteen rigged GLBs across six dinosaur types. Each row has a compact, standard, and large design in that order. Size, body breadth, and the length of features such as crests, feathers or horns vary alongside the color palette. Heights on the preview are the in-game dimensions of these stylized models. The models are available for review as standalone assets.

[Shared-scale comparison](previews/dinosaurs-scale.png) · [Raptors, crests and plates](previews/dinosaurs-variants-1.png) · [Horns, jaws and long necks](previews/dinosaurs-variants-2.png)

| Type | Compact, standard, large | Design | Signature clip |
| --- | --- | --- | --- |
| **Velociraptor** | [Bracken](models/dinosaurs/velociraptor_bracken.glb) · [Embercrest](models/dinosaurs/velociraptor_embercrest.glb) · [Nightfeather](models/dinosaurs/velociraptor_nightfeather.glb) | Feather fans, hooked claws and a narrow muzzle. | `Pounce` |
| **Parasaurolophus** | [Reedbank](models/dinosaurs/parasaurolophus_reedbank.glb) · [Coppercrest](models/dinosaurs/parasaurolophus_coppercrest.glb) · [Bluecrest](models/dinosaurs/parasaurolophus_bluecrest.glb) | A duckbill and a backward crest with a contrasting tip. | `Call` |
| **Stegosaurus** | [Mossplate](models/dinosaurs/stegosaurus_mossplate.glb) · [Rustplate](models/dinosaurs/stegosaurus_rustplate.glb) · [Slateplate](models/dinosaurs/stegosaurus_slateplate.glb) | Alternating back plates and four angled tail spikes. | `TailSweep` |
| **Triceratops** | [Ochrefrill](models/dinosaurs/triceratops_ochrefrill.glb) · [Redshield](models/dinosaurs/triceratops_redshield.glb) · [Ironfrill](models/dinosaurs/triceratops_ironfrill.glb) | A rimmed frill, a short nose horn and two sweeping brow horns. | `HeadCharge` |
| **Tyrannosaurus** | [Sandjaw](models/dinosaurs/tyrannosaurus_sandjaw.glb) · [Ridgejaw](models/dinosaurs/tyrannosaurus_ridgejaw.glb) · [Blackcrown](models/dinosaurs/tyrannosaurus_blackcrown.glb) | A deep skull, visible teeth and short two-fingered arms. | `Bite` |
| **Brachiosaurus** | [Fernback](models/dinosaurs/brachiosaurus_fernback.glb) · [Sunspine](models/dinosaurs/brachiosaurus_sunspine.glb) · [Stormneck](models/dinosaurs/brachiosaurus_stormneck.glb) | Raised shoulders and a long neck with contrasting markings. | `Browse` |

Every GLB has its own skinned mesh, looping `Idle` and `Walk` clips, and the listed one-shot action. The models use meters and face local `-Z` after import.

## Regenerate and verify

From the repository root, use a scratch copy of the source project at `$staged`, an absolute capture directory at `$review`, and the Godot 4.3 console executable at `$godot`. Set `APPDATA` and `CHRIST_FALLOW_QA_APPDATA` to a fresh scratch directory for the Godot runs.

```powershell
.\tools\assets\run_blender.ps1 -ScriptPath .\tools\assets\generate_dinosaur_lineup.py -ScriptArgs @('--out-dir', (Join-Path $staged 'assets/models'))
& $godot --headless --editor --path $staged --import
& $godot --path $staged --resolution 1600x900 --quit-after 1800 -s res://scripts/tools/verify_dinosaur_lineup.gd -- "--out-dir=$review"
```

`DINOSAUR LINEUP VERIFICATION PASSED` confirms the size order, skin binding, loop flags, and skeleton movement for all eighteen imports. The verifier writes three Forward+ comparison sheets. [Blender generator](../generate_dinosaur_lineup.py) · [Godot verifier](../../../scripts/tools/verify_dinosaur_lineup.gd)
