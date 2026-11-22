# Campaign performance review

## Reproduce the measurements

Run the Godot 4.3 console executable against `project.godot` in PowerShell. Start with an empty scratch directory for `APPDATA` and `CHRIST_FALLOW_QA_APPDATA`. Run one rendering job at a time for a comparison on your machine.

```powershell
$godot = '<USERPROFILE>\AppData\Local\Godot\Godot_v4.3-stable_win64_console.exe'
$project = (Get-Location).Path
$qa = Join-Path ([IO.Path]::GetTempPath()) ('cf-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $qa | Out-Null
$env:APPDATA = $qa
$env:CHRIST_FALLOW_QA_APPDATA = $qa

& $godot --path $project --resolution 1280x720 --disable-vsync --quit-after 1100 -s res://scripts/tools/benchmark_campaign_frames.gd -- --scenario=all
& $godot --path $project --resolution 1280x720 --fixed-fps 60 --quit-after 1100 -s res://scripts/tools/benchmark_campaign_frames.gd -- --scenario=all --fixed-step
& $godot --path $project --resolution 1280x720 --disable-vsync --quit-after 650 -s res://scripts/tools/benchmark_campaign_frames.gd -- --scenario=battle --samples=100
& $godot --path $project --resolution 1280x720 --fixed-fps 60 --quit-after 900 -s res://scripts/tools/benchmark_simulation.gd -- --expanded-valley
```

Require the explicit completion marker and scan for script and renderer errors. The frame benchmark defaults to 45 warm-up frames or ticks and 180 samples per scenario. Select one scenario with `--scenario=opening`, `settlement`, `battle-on`, or `battle-off`. Select `--scenario=battle --samples=100` to measure the matched battle camera pair in fresh campaigns within one launch. Fixed step requires both `--fixed-fps 60` and `--fixed-step`. [Frame benchmark](../scripts/tools/benchmark_campaign_frames.gd) · [Legacy benchmark](../scripts/tools/benchmark_simulation.gd)

## Test conditions

- Intel Core i5-8250U, Intel UHD Graphics 620 driver 31.0.101.2135, Windows, Godot 4.3 stable `77dcf97d8`, Forward+ and Vulkan 1.3.215. Window 1280×720 with logical HUD coordinates of 1600×900. VSync disabled for elapsed-frame sampling, 3D scale 1.0, 2× MSAA, default directional shadows, PSX filter on, brightness 1.25, and UI scale 1.0. The final rendering slice reduced sky radiance from 256 to 128.
- Seed 17394 and `valley_expanded_760` in each scenario. The opening uses the standard campaign setup and player camera with 43 units, 37 starting buildings, 25 wildlife, and 145 resources and caves. The settlement adds 105 workers across seven roles, 14 finished buildings, and four unfinished palisades. The battle adds 128 warriors split equally among the player and three mutually hostile tribes and issues Guard Base to the player squad. Both battle views start a fresh match with the same seed and setup. The player leader stands 90 m clear of the fight, and the off-camera view center is offset by 130 m on X and 55 m on Z from the camp. The benchmark rejects sampled campaigns that pause or finish.
- Wall intervals are elapsed time between consecutive rendered frames. During slow frames Godot queues up to eight simulation steps, so the exact battle state and surviving entity count can differ at the end of a rendered window. The fixed-step probe disables drawing and times each physics callback pass from the physics-frame signal through a late-priority scene node. Godot's built-in physics monitor reports recent maxima and is printed separately for continuity. It is neither a per-tick sample nor an elapsed-frame sample. [Godot 4.3 timing loop](https://raw.githubusercontent.com/godotengine/godot/77dcf97d8/main/main.cpp)

## Bottleneck attribution

The instrumented 70-tick fixed-step samples used the same scenario setup with 25 warm-up ticks. Probe timings are averages in milliseconds per simulation tick. Enemy searches and path solves are subsets of unit AI.

| Cost | Settlement | Battle |
| --- | ---: | ---: |
| Unit AI | 18.385 | 80.905 |
| Enemy searches | 4.247 | 70.057 |
| Path solves | 0.017 | 0.070 |
| Procedural poses | 14.424 | 14.389 |
| Imported animation | 6.814 | 7.625 |
| Unit `move_and_slide()` | 10.862 | 7.849 |

The large visible scenarios submitted roughly 8,300 draw calls per frame at median. The opening's median viewport GPU time was 72.6 ms. Short diagnostics measured 58.3 ms with frozen lighting, 42.8 ms with directional shadows disabled, and 48.2 ms at half 3D resolution. Run these separately with `--diagnostic=freeze-sky`, `no-sun-shadows`, or `half-resolution`, plus `--warmup=20 --samples=45`. Render CPU and GPU run asynchronously, so interpret the GPU column across a run. A single GPU timestamp cannot assign a specific frame delay to a script. [Godot 4.3 viewport timing](https://docs.godotengine.org/en/4.3/classes/class_renderingserver.html#class-renderingserver-method-viewport-set-measure-render-time)

The worst frames repeatedly ran all eight physics steps. The independent fixed-step profile locates most battle script time in enemy acquisition. Settlement spikes combined high scene tick cost with costly collisions and animation. The settlement also had isolated render-CPU peaks as high as 630 ms. Those peaks and some elapsed-frame outliers remain unattributed. Human path solves averaged under 0.1 ms per tick in both stress fixtures.

HUD live refreshes run on a 0.35 s cadence, and settled leader negotiation labels only replace their text when the prompt changes. The instrumented resource-signal path had no deliveries during the short fixed-step attribution window. Dense combat still creates world-space damage labels and tweens outside the camera. These paths merit a longer capture where their costs can be timed separately. [HUD](../scripts/ui/hud_controller.gd) · [Nameplates](../scripts/entities/human_unit.gd) · [Combat effects](../scripts/core/combat_vfx.gd)

## Implemented slices

1. Imported rigs advance the procedural attack and hit timers while evaluating only the imported pose. Procedural roster units retain their previous pose path. This includes mounted player animation, hit and death transitions, and wounded animation. [Human unit](../scripts/entities/human_unit.gd) · [Procedural animator](../scripts/entities/tribesman_animator.gd)
2. Guard Base reuses staggered camp-centered enemy and wildlife scans, and Retreat skips the scan it never uses. Enemy acquisition checks hostility once per opposing faction during each walk of the spatial results. Cached enemy units and buildings are checked against live allegiance. The Diplomacy regression reproduced the stale enemy cache by pressing Peace while a former enemy was still cached, then passed after the fix. [Unit AI](../scripts/entities/unit_ai_routines.gd) · [Diplomacy verifier](../scripts/tools/verify_diplomacy_leaders.gd)
3. Lighting keeps the sun moving continuously. Fixed sky, light, and fog palette values are submitted at phase transitions, and the procedural gradient uses a 128-pixel radiance map. [World generator](../scripts/systems/world_generator.gd)

### Fixed-step results

Each cell is median / p95 / p99 in ms. The animation and combat slices were each rerun over all four scenarios with 180 ticks per case and one simulation tick per frame. These first fixed-step battle runs started the player leader at camp and retained 171 unit nodes across the short window. The final paired battle runs use the protected leader setup above. Both battle camera modes skip drawing in fixed-step runs.

| Scenario | Before | Animation slice | Combat slice |
| --- | ---: | ---: | ---: |
| Opening | 18.21 / 25.28 / 28.90 | 8.05 / 15.93 / 16.66 | 7.40 / 8.17 / 9.74 |
| Settlement | 59.48 / 90.69 / 100.84 | 33.24 / 55.35 / 58.27 | 31.09 / 38.72 / 48.59 |
| Battle, on camera | 84.03 / 108.99 / 138.89 | 70.06 / 112.38 / 185.60 | 32.48 / 40.86 / 43.73 |
| Battle, off camera | 92.14 / 163.27 / 188.84 | 73.44 / 92.44 / 124.57 | 34.14 / 42.60 / 47.08 |

Final fixed-step comparison after the lighting slice. The battle rows use the corrected, serially run fixture. Each run sampled 180 ticks.

| Scenario | Before | After |
| --- | ---: | ---: |
| Opening | 18.21 / 25.28 / 28.90 | 7.60 / 8.86 / 14.74 |
| Settlement | 59.48 / 90.69 / 100.84 | 31.75 / 34.94 / 39.39 |
| Battle, on camera | 82.16 / 96.66 / 128.52 | 33.94 / 44.11 / 55.06 |
| Battle, off camera | 84.71 / 103.03 / 137.87 | 34.42 / 46.71 / 59.48 |

### Rendered results

Each cell is elapsed median / p95 / p99 in ms. The 60 FPS reference is 16.7 ms. The opening and settlement used 180 frames each. The corrected battles used 100 frames each.

| Scenario | Before | After | Median GPU before → after |
| --- | ---: | ---: | ---: |
| Opening | 159.77 / 201.75 / 236.51 | 62.71 / 80.71 / 215.43 | 72.56 → 42.94 |
| Settlement | 631.03 / 844.69 / 966.79 | 406.05 / 459.36 / 557.90 | 87.16 → 87.85 |
| Battle, on camera | 417.47 / 609.85 / 661.13 | 277.90 / 363.67 / 379.18 | 83.07 → 78.35 |
| Battle, off camera | 422.11 / 609.93 / 658.37 | 272.21 / 360.83 / 382.15 | 76.23 → 64.51 |

The after-run settlement still submitted about 8,325 draw calls at median. Opening frame p95 fell more than p99 because isolated spikes survived the refactor. Every sampled rendered frame remained above 16.7 ms in all four scenarios.

The measurements describe this laptop and these scenarios. Some first-pass baselines overlapped QA or diagnostic processes. The corrected battle comparison ran serially with matching sample counts. Its before build used a scratch source copy with the four changed runtime files restored to their starting content, including the uncommitted mount changes present over HEAD `c7f3a72`. Both views sampled 171 unit nodes at the start and 116 at the end before the refactor, then 171 and 106 after it. Fixed-step results measure scene tick time with drawing disabled.

## Directional shadow attribution

The 21 November 2026 baseline used the working source snapshot at `3abde8c`. The benchmark reports Godot's visible 3D and shadow draw counts and primitive counts separately. Shadow counts include repeated submissions across cascades. The total draw counter also includes work outside those two counters. [Frame benchmark](../scripts/tools/benchmark_campaign_frames.gd) · [Godot 4.3 viewport counters](https://docs.godotengine.org/en/4.3/classes/class_viewport.html#enum-viewport-renderinfotype)

Run these commands serially using the Godot and scratch `APPDATA` setup above. Use a fresh `APPDATA` directory for each launch. The local `checkpoint-stock` project contains the source at `3abde8c` and the updated benchmark. To recreate it, check out `3abde8c` in a scratch worktree, copy in the updated benchmark, and run Godot with `--headless --editor --path $stock --import`.

```powershell
$review = Join-Path ([IO.Path]::GetTempPath()) 'cf-render-15a8a1aa'
$stock = Join-Path $review 'checkpoint-stock'
$render = @('--path', $stock, '--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan', '--resolution', '1280x720', '--disable-vsync', '--quit-after', '1100', '-s', 'res://scripts/tools/benchmark_campaign_frames.gd')
& $godot @render -- --scenario=battle --warmup=45 --samples=100
& $godot @render -- --scenario=battle --warmup=45 --samples=100 --diagnostic=no-sun-shadows
& $godot @render -- --scenario=opening --warmup=45 --samples=180
& $godot @render -- --scenario=settlement --warmup=45 --samples=180
```

Each battle launch ran the on-camera scenario and then the off-camera scenario in fresh campaigns. The camera positions were `(0, 50, 72)` and `(130, 50, 127)` with the same 75° field of view and downward angle. Both launches used 45 warm-up frames and 100 samples per view, seed `17394`, and the 1280×720 Forward+ settings above. Each view went from `[171, 41, 25, 145]` to `[106, 50, 25, 145]` in unit, building, wildlife, and resource node counts. The benchmark's active-campaign check passed throughout every completed sample.

Timing cells are median / p95 / p99 in ms. Draw counts are medians.

| Sun shadows | View | Elapsed | Render CPU | Viewport GPU | Visible draws | Shadow draws | Total draws |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Default | Battle on | 297.27 / 500.33 / 556.44 | 8.11 / 13.88 / 17.52 | 49.12 / 56.33 / 59.34 | 2,348.5 | 4,795 | 8,087 |
| Default | Battle off | 277.40 / 430.91 / 513.98 | 5.76 / 10.69 / 11.98 | 63.64 / 88.28 / 101.96 | 54 | 2,675 | 3,681.5 |
| Disabled | Battle on | 273.66 / 365.83 / 376.76 | 6.41 / 10.96 / 12.89 | 70.09 / 81.69 / 85.05 | 2,348.5 | 0 | 3,293.5 |
| Disabled | Battle off | 264.27 / 354.59 / 388.78 | 3.33 / 6.32 / 6.66 | 33.96 / 36.67 / 38.21 | 54 | 0 | 1,005.5 |

The directional light accounted for about 59% of total draw submissions on camera and 73% off camera, with identical visible draw and primitive distributions across the toggle. Turning the sun shadows off reduced median render CPU by 1.70 ms on camera and 2.43 ms off camera. The off-camera viewport GPU median fell by 29.68 ms. The on-camera GPU median rose in the comparison, and the first default run had high elapsed and process tails. Use the pass counts for submission attribution and the repeat runs below for timing. [Godot 4.3 viewport timing](https://docs.godotengine.org/en/4.3/classes/class_renderingserver.html#class-renderingserver-method-viewport-set-measure-render-time)

### Spearman command-zoom trial

The battle explicitly adds 28 Spearmen among its 128 warriors. The first trial built shadow-only proxies for their spear and buckler. It passed the small visual fixture, then exited with native status `0xc0000005` during the first dense battle. The second trial kept the body and spear casting and dropped buckler and chestwear shadows at 34 m from the camera. Full casts resumed below 30 m. Both levels used the shipped skinned mesh, trim materials, and bone attachments for the visible pass. [Imported kits](../scripts/entities/crag_born_trial.gd)

The second trial is a single-file patch in the local run folder. Apply it to a scratch source copy at `3abde8c` and copy in the current frame benchmark to repeat the trials. The `--full-spearman-shadows` control is part of the scratch patch. Use the same `$render` arguments and fresh `APPDATA` per launch.

```powershell
$trial = Join-Path $review 'checkpoint-project'
$trialRender = $render.Clone()
$trialRender[1] = $trial
& $godot @trialRender -- --scenario=battle --warmup=45 --samples=100 --full-spearman-shadows
& $godot @trialRender -- --scenario=battle --warmup=45 --samples=100
& $godot @trialRender -- --scenario=battle --warmup=45 --samples=100
```

The full-shadow control preceded the concurrent perk and combat edits in the shared workspace. Both command-shadow repeats ran from the isolated checkpoint with the trial patch. The first two trial measurements in the shared workspace were discarded because they loaded different gameplay code. The three rows for each camera below share the entity counts in the attribution table and the same visible draw and primitive distributions.

| Run | View | Elapsed ms | Render CPU ms | Viewport GPU ms | Median visible draws | Median shadow draws |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Full-shadow repeat | Battle on | 275.72 / 369.07 / 388.20 | 8.62 / 12.52 / 16.05 | 78.06 / 93.07 / 100.22 | 2,348.5 | 4,795 |
| Full-shadow repeat | Battle off | 274.12 / 354.49 / 375.42 | 5.48 / 9.06 / 9.41 | 64.70 / 71.72 / 74.16 | 54 | 2,675 |
| Command shadows 1 | Battle on | 293.84 / 379.08 / 401.15 | 8.61 / 13.86 / 14.91 | 83.04 / 98.21 / 103.37 | 2,348.5 | 4,278 |
| Command shadows 1 | Battle off | 269.49 / 361.00 / 403.61 | 5.25 / 9.21 / 9.95 | 64.99 / 71.94 / 74.63 | 54 | 2,416.5 |
| Command shadows 2 | Battle on | 279.62 / 361.51 / 382.98 | 8.37 / 12.62 / 16.45 | 79.44 / 92.06 / 99.25 | 2,348.5 | 4,278 |
| Command shadows 2 | Battle off | 273.36 / 353.21 / 372.08 | 5.36 / 9.09 / 9.77 | 65.15 / 71.46 / 72.91 | 54 | 2,416.5 |

The command-distance cast reduction saved 517 median shadow draws on camera (10.8%) and 258.5 off camera (9.7%) in both repeats. The on-camera median shadow primitive count fell from 389,859 to 377,451 (3.2%). Both on-camera elapsed medians were higher than the full-shadow repeat. Viewport GPU medians were also higher in each trial view. Off-camera elapsed p99 moved in both directions. The trial was removed from the runtime after the comparison.

The gameplay review used mouse-wheel zoom from 5.5 m to 42 m, back through 33.2 m, and down to 5.5 m. The caster assertions passed at each point, including the return through the transition band. Both faction trims, spear and buckler silhouettes, and the imported thrust pose held up in the captures. The attack damaged the opposing Spearman and played the imported `Attack` clip. Full-shadow, trial, and `--procedural-roster` runs each printed `SPEARMAN SHADOW REVIEW PASSED`. Captures and the probe are in the local run folder.

```powershell
$visual = @('--path', $trial, '--rendering-method', 'forward_plus', '--resolution', '1280x720', '--disable-vsync', '--fixed-fps', '60', '--quit-after', '180', '-s', "$review/verify_spearman_shadows.gd")
& $godot @visual -- "--out-dir=$review/cast-detail-visual-full" --full-spearman-shadows
& $godot @visual -- "--out-dir=$review/cast-detail-visual-command"
& $godot @visual -- "--out-dir=$review/cast-detail-visual-procedural" --procedural-roster
```

### GPU pass timings at one tick per rendered frame

A separate full-shadow diagnostic forced one simulation tick per rendered frame. This kept all 171 units in both sample windows and reduced the variation from physics catch-up. With the same seed, camera positions, warm-up and sample counts, Godot's profiler reported the following medians of its approximately one-second aggregates, including warm-up. The shadow pass label excludes the preceding atlas setup. The no-sun run above establishes that directional lighting supplied the shadow submissions in this fixture. [Godot 4.3 Forward+ pass markers](https://github.com/godotengine/godot/blob/77dcf97d8/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp#L1272-L1338)

| View | Aggregates | Shadow pass GPU ms | Depth prepass GPU ms | Opaque pass GPU ms |
| --- | ---: | ---: | ---: | ---: |
| Battle on | 13 | 8.90 | 3.88 | 15.04 |
| Battle off | 12 | 6.42 | 0.72 | 8.23 |

```powershell
& $godot --path $trial --rendering-method forward_plus --rendering-driver vulkan --resolution 1280x720 --disable-vsync --profile-gpu --fixed-fps 60 --quit-after 1100 -s res://scripts/tools/benchmark_campaign_frames.gd -- --scenario=battle --warmup=45 --samples=100 --full-spearman-shadows
```

### Stock renderer confirmation

The final rerun used the checkpoint's stock renderer and the updated benchmark. The opening and working settlement had initial elapsed medians of 62.46 and 411.16 ms before the trial. The first settlement launch logged shader cache write errors. The confirmation set used short, isolated `APPDATA` paths and completed without script or renderer errors.

```powershell
& $godot @render -- --scenario=battle --warmup=45 --samples=100
& $godot @render -- --scenario=opening --warmup=45 --samples=180
& $godot @render -- --scenario=settlement --warmup=45 --samples=180
```

Timing cells are median / p95 / p99 in ms. Draw counts are medians in visible / shadow / total order.

| Scenario | Elapsed | Render CPU | Viewport GPU | Draws |
| --- | ---: | ---: | ---: | ---: |
| Opening | 63.83 / 112.04 / 159.30 | 2.06 / 2.67 / 3.01 | 44.00 / 49.77 / 51.13 | 217 / 907 / 1,915 |
| Settlement | 403.05 / 435.30 / 484.96 | 7.62 / 8.80 / 9.53 | 86.04 / 97.30 / 100.47 | 2,420 / 4,919 / 8,325 |
| Battle on | 280.26 / 367.33 / 379.79 | 8.45 / 13.25 / 15.37 | 78.57 / 88.91 / 95.87 | 2,348.5 / 4,795 / 8,087 |
| Battle off | 271.51 / 353.46 / 370.11 | 5.33 / 8.83 / 9.63 | 64.59 / 72.05 / 76.89 | 54 / 2,675 / 3,681.5 |

Opening counts changed from `[43, 39, 25, 145]` to `[43, 49, 25, 145]`. Settlement counts changed from `[148, 59, 25, 145]` to `[148, 68, 22, 145]`. Settlement workers delivered 315 Food and 15 Wood, with 16 hauling when sampling ended. Both battle views matched the counts in the first pair. All 560 sampled frames exceeded 16.7 ms. Each median viewport GPU time also exceeded the budget. The worst opening and settlement frames reached 207.51 and 618.10 ms. Both ran eight physics steps, as did every flagged p95-and-higher frame in the final battle pair. The isolated elapsed spikes still need attribution.

## Fixed-step follow-up

The checkpoint control sampled 180 simulation ticks after 45 warm-up ticks in each scenario. Forward+ initialized with a display and the benchmark disabled drawing before warm-up. Both battle views kept 171 unit nodes, went from 37 to 41 building nodes, and held 25 wildlife and 145 resource nodes. The time below is the scene physics callback pass.

```powershell
& $godot --path $stock --rendering-method forward_plus --rendering-driver vulkan --resolution 1280x720 --fixed-fps 60 --quit-after 1100 -s res://scripts/tools/benchmark_campaign_frames.gd -- --scenario=all --fixed-step --warmup=45 --samples=180
```

| Scenario | Median ms | p95 ms | p99 ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| Opening | 7.43 | 8.50 | 15.12 | 16.91 |
| Settlement | 31.08 | 34.57 | 45.71 | 48.33 |
| Battle on | 36.29 | 59.89 | 88.79 | 89.07 |
| Battle off | 34.31 | 44.30 | 59.63 | 64.04 |

### Off-camera movement, animation and damage effects

The scratch probe timed the native `HumanUnit` movement calls, native imported `AnimationPlayer.advance()` and `seek()` calls, and creation of three damage effects on the same off-camera fixture. Dense movement is the subset within 32 m of camp. Each run sampled 600 ticks after 45 warm-up ticks and went from `[171, 37, 25, 145]` to `[157, 45, 25, 145]`. The suppression runs skipped the popup, blood pool, and slash arc nodes and tweens while consuming the same two random draws for each popup. Movement and animation call counts matched in both run orders. [Unit movement](../scripts/entities/human_unit.gd) · [Imported animation](../scripts/entities/skinned_tribesman_trial.gd) · [Combat effects](../scripts/core/combat_vfx.gd)

```powershell
$profile = & "$review/prepare-fixed-profile.ps1" -Project $stock
$fixed = @('--path', $profile, '--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan', '--resolution', '1280x720', '--fixed-fps', '60', '--quit-after', '1100', '-s', 'res://scripts/tools/benchmark_campaign_frames.gd')
& $godot @fixed -- --scenario=battle-off --fixed-step --warmup=45 --samples=600
& $godot @fixed -- --scenario=battle-off --fixed-step --warmup=45 --samples=600 --no-bench-damage-effects
& $godot @fixed -- --scenario=battle-off --fixed-step --warmup=45 --samples=600 --no-bench-damage-effects
& $godot @fixed -- --scenario=battle-off --fixed-step --warmup=45 --samples=600
```

Per-tick timings from the first run with effects active. Times cover the synchronous calls and their work on the calling thread.

| Timed work | Mean ms | Median ms | p95 ms | p99 ms | Calls |
| --- | ---: | ---: | ---: | ---: | ---: |
| NPC `move_and_slide()` | 5.179 | 5.232 | 6.699 | 7.489 | 43,390 |
| Within 32 m of camp | 3.445 | 3.673 | 4.793 | 5.416 | 24,922 |
| Imported `advance()` and `seek()` | 3.516 | 3.460 | 4.307 | 4.985 | 102,872 |
| Damage popup creation | 0.076 | 0.064 | 0.215 | 0.292 | 632 |
| Blood pool creation | 0.019 | 0.000 | 0.177 | 0.286 | 62 |
| Slash arc creation | 0.126 | 0.000 | 0.472 | 0.652 | 282 |
| All three effects | 0.221 | 0.102 | 0.698 | 1.028 | 976 |

The loop timer spans consecutive physics signals with drawing disabled and includes the idle and engine work between them. Timing cells are median / p95 / p99 in ms. Rows are in the order run.

| Effects | Scene physics callback | Unrendered loop |
| --- | ---: | ---: |
| Active | 31.05 / 41.68 / 47.76 | 54.48 / 71.26 / 109.88 |
| Suppressed | 29.43 / 39.28 / 46.31 | 41.15 / 57.63 / 77.66 |
| Suppressed, repeat | 30.41 / 38.47 / 41.77 | 42.41 / 55.23 / 66.11 |
| Active, repeat | 29.58 / 39.11 / 53.41 | 51.10 / 68.35 / 115.66 |

Suppressing the group reduced the loop median by 8.69–13.33 ms. Scene physics medians varied by less than 2 ms, and the timed constructors averaged 0.205–0.221 ms. The loop difference points to work outside those constructors, with individual effect attribution still open. Loop maxima ranged from 742 ms to 1,335 ms and remain unattributed. The settlement and both battles exceeded 16.7 ms at median in the standard fixed-step control. Even with all three effects suppressed, the off-camera scene tick exceeded 16.7 ms at median.

Scratch guard checks forced manual pause and campaign finish separately as sampling began. Both returned exit code 1 with `Campaign paused or ended while sampling opening.` and no completion marker.

## Off-camera human damage numbers

22 November 2026. **Rolled back.** The candidate skipped all eligible numbers in the off-camera fixtures. The fixed-step result was mixed, and both off-camera rendered runs had higher wall medians, p95s, and p99s than their neighboring controls. The focused gameplay checks passed.

The fresh control is scratch commit `af1725476e20ba8b443db23f2777010362c42980` over `c7f3a72`. It captures the working source at the start of the experiment, including the later perk, combat, and refactor work. Both variants used this checkpoint and identical counter and timing instrumentation. The candidate patch marks the ordinary number in `HumanUnit.take_damage()` for culling and checks the jittered label against the anchor viewport's active camera before allocating a label or tween. It bounds the outlined number along its full rise, accounts for Reduced Motion, and consumes both jitter draws on every valid request. The clean candidate diff is `popup-candidate.patch` in the run folder. [Human damage path](../scripts/entities/human_unit.gd) · [Popup helper](../scripts/core/combat_vfx.gd) · [Godot 4.3 camera projection](https://docs.godotengine.org/en/4.3/classes/class_camera3d.html#class-camera3d-method-unproject-position)

### Commands

Godot 4.3 stable `77dcf97d8` used Forward+ and Vulkan 1.3.215 on Intel UHD Graphics 620. The launcher uses `--rendering-method forward_plus --rendering-driver vulkan --resolution 1280x720 --quit-after 1100` with the scratch copy of `benchmark_campaign_frames.gd`. Each group runs `--scenario=battle-off --warmup=45 --samples=600 --fixed-step` with `--fixed-fps 60`, then `--scenario=battle-on` and `--scenario=battle-off` with `--disable-vsync --warmup=45 --samples=100`. The timed windows use seed `17394`, the expanded valley, stock shadows and PSX, 3D scale 1.0, and 2× MSAA. [Benchmark protocol](PERFORMANCE_HANDOVER.md#benchmark-commands)

The first `--scenario=battle` launch exited with native status `0xc0000005` during its second view. A subsequent launch with nested `APPDATA` logged a shader-cache write error. Both attempts were excluded. The measured series used a fresh process per view and a new short `APPDATA` and `CHRIST_FALLOW_QA_APPDATA` for each launch. All 12 accepted launches passed the active-campaign guard and printed `CAMPAIGN FRAME BENCHMARK COMPLETE` without script or renderer errors.

```powershell
$review = '<USERPROFILE>\AppData\Local\Temp\cf-pop-2f0340'
& "$review\run-benchmark.ps1" -Variant control -Repeat 1
& "$review\run-benchmark.ps1" -Variant candidate -Repeat 1
& "$review\run-benchmark.ps1" -Variant candidate -Repeat 2
& "$review\run-benchmark.ps1" -Variant control -Repeat 2
```

Logs are relative to `$review`. Each log folder also records the isolated data directory in `appdata.txt`.

| Run | Fixed step | Battle on | Battle off |
| --- | --- | --- | --- |
| Control 1 | `fixed-con1-2c7c/fixed-con1.log` | `on-con1-894e/on-con1.log` | `off-con1-bc05/off-con1.log` |
| Candidate 1 | `fixed-can1-bd2d/fixed-can1.log` | `on-can1-807c/on-can1.log` | `off-can1-ff2e/off-can1.log` |
| Candidate 2 | `fixed-can2-1a9a/fixed-can2.log` | `on-can2-d76a/on-can2.log` | `off-can2-3277/off-can2.log` |
| Control 2 | `fixed-con2-3b69/fixed-con2.log` | `on-con2-e800/on-con2.log` | `off-con2-1c62/off-con2.log` |

### Fixed step, off camera

Timing triples are median / p95 / p99. The scene timer brackets the physics callbacks. The unrendered loop timer spans consecutive physics-frame signals with drawing disabled and includes the idle and engine work between them.

| Run | Human numbers requested / emitted / skipped | Other popups / blood pools / slash arcs | Scene callback ms | Unrendered loop ms | Loop max ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Control 1 | 576 / 576 / 0 | 56 / 55 / 269 | 32.483 / 54.637 / 66.421 | 55.614 / 91.675 / 135.040 | 1433.500 |
| Candidate 1 | 576 / 0 / 576 | 56 / 55 / 269 | 44.686 / 78.413 / 91.944 | 63.674 / 111.416 / 139.439 | 956.105 |
| Candidate 2 | 576 / 0 / 576 | 56 / 55 / 269 | 32.344 / 51.625 / 75.021 | 47.041 / 76.129 / 105.665 | 810.471 |
| Control 2 | 576 / 576 / 0 | 56 / 55 / 269 | 37.521 / 58.082 / 72.147 | 64.350 / 96.007 / 134.280 | 1613.173 |

All four windows covered exactly 600 ticks. The entity counts (units / buildings / wildlife / resources) went from `[171, 37, 25, 145]` to `[159, 45, 25, 145]`. The combat snapshot digest `1d4d23b44a40` and next RNG value `2055058797` matched across all four runs. The snapshot includes unit HP, position, faction, death and wound state, training XP, faction progression, diplomacy, and building and wildlife HP. Each end state held 115 living units, 44 corpses and zero wounded unit nodes.

The loop median rose **8.060 ms** in the first comparison and fell **17.309 ms** in the reverse comparison. Both loop percentiles moved in the same direction as their median. The longest control intervals occurred at sample 499, with scene callbacks of 28.895 and 41.783 ms within 1.43 and 1.61 s loop intervals. The longest candidate intervals occurred at sample 122 and reached 0.81–0.96 s. Their scene callbacks took 32.736 and 66.734 ms. The rest of those intervals remains unattributed.

### Active rendered battle

Timing triples are median / p95 / p99. Draw counts are medians.

| Run | View | Human numbers requested / emitted / skipped | Wall ms | Render CPU ms | Viewport GPU ms | Visible / shadow / total draws | Frames > 16.7 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Control 1 | On | 458 / 458 / 0 | 382.184 / 633.332 / 683.341 | 11.558 / 21.566 / 23.352 | 85.553 / 104.418 / 108.921 | 2,350 / 4,721 / 8,037 | 100/100 |
| Control 1 | Off | 458 / 458 / 0 | 297.353 / 410.247 / 429.702 | 5.415 / 8.442 / 9.034 | 65.743 / 74.980 / 78.457 | 48 / 2,687 / 3,701 | 100/100 |
| Candidate 1 | On | 458 / 458 / 0 | 365.340 / 463.634 / 501.453 | 10.860 / 17.354 / 19.164 | 81.819 / 93.082 / 94.672 | 2,350 / 4,721 / 8,037 | 100/100 |
| Candidate 1 | Off | 458 / 0 / 458 | 394.327 / 630.192 / 811.643 | 5.893 / 10.312 / 12.581 | 70.076 / 86.669 / 104.722 | 48 / 2,687 / 3,701 | 100/100 |
| Candidate 2 | On | 458 / 458 / 0 | 331.640 / 632.310 / 802.835 | 10.479 / 17.433 / 22.079 | 84.028 / 97.387 / 106.236 | 2,350 / 4,721 / 8,037 | 100/100 |
| Candidate 2 | Off | 458 / 0 / 458 | 469.743 / 693.995 / 766.746 | 7.063 / 13.178 / 19.286 | 61.203 / 86.043 / 112.332 | 48 / 2,687 / 3,701 | 100/100 |
| Control 2 | On | 458 / 458 / 0 | 329.363 / 434.571 / 522.211 | 9.723 / 15.823 / 18.113 | 81.282 / 101.445 / 107.233 | 2,350 / 4,721 / 8,037 | 100/100 |
| Control 2 | Off | 458 / 458 / 0 | 300.411 / 389.839 / 433.858 | 5.257 / 8.751 / 8.913 | 66.067 / 72.700 / 75.484 | 48 / 2,687 / 3,701 | 100/100 |

Each view sampled 100 frames and advanced 800 physics ticks. Counts went from `[171, 41, 25, 145]` to `[109, 45, 25, 145]` in all eight windows, ending with 89 living units, 20 corpses and zero wounded unit nodes. Other popups, blood pools, and slash arcs totaled 50, 49, and 147 per view. The combat snapshot digest `f0f483c89cae` and next RNG value `2354937981` matched across the eight launches.

Off-camera wall medians rose **96.974 ms** and **169.332 ms** against the adjacent controls. Both candidate off-camera p99s exceeded 766 ms. The on-camera comparison moved in different directions across the repeats, with identical popup and draw counts. All 800 frames exceeded 16.7 ms. Every flagged p95-and-higher interval included eight physics steps. The longest control intervals reached 700.451 ms on camera and 534.331 ms off camera. The candidate reached 984.592 ms on camera and 852.180 ms off camera. These spikes need further attribution.

### Gameplay review

The scratch verifier ran the uninstrumented control and candidate on the same campaign path. The third run used a 1280×600 window with a 1920×900 logical viewport. Each run printed `POPUP GAMEPLAY REVIEW PASSED` and produced an identical seeded HP, XP, and RNG trace.

```powershell
& "$review\run-qa.ps1" -Variant control -Resolution 1280x720
& "$review\run-qa.ps1" -Variant candidate -Resolution 1280x720
& "$review\run-qa.ps1" -Variant candidate -Resolution 1280x600
```

- LMB cleave dealt 21.67 damage after armor at 5.5 m and 42 m zoom in both versions. The tests verified the yellow rival number, red player number, imported hit clip and hit flash, and zero nonlethal XP. A fatal hit awarded 18 tribal XP. Subduing a rebel left 5 HP and played the wounded clip. `INCAPACITATED!` and `SLAIN!` appeared in the visible captures and were emitted on the off-camera hits.
- Hits at all four edges kept their numbers 17 logical pixels inside and 9 pixels beyond the boundary. The 1280×720 edge captures matched the control, including the partial clipping on the outer edge. A number starting 70 pixels below the viewport rose into frame. Reduced Motion held the near-edge numbers in place and allowed the candidate to skip that farther hit.
- Within 0.1 simulated second of turning back, the candidate showed the previously visible label and the first new hit. It had skipped the hit behind the active replacement camera. Two jitter draws and the hit damage matched in each case. The no-camera case emitted the number.
- The `E` harvest added five Food and displayed its feedback. Wildlife damage still emitted an off-camera number. Campaign teardown freed a visible label and removed its bound tween.

Logs and captures are in `qa-control-1280x720-3b86`, `qa-candidate-1280x720-c688`, and `qa-candidate-1280x600-64c4`. The captures include `close-cleave.png`, `command-cleave.png`, `edges-*.png`, `rise-into-frame.png`, `camera-return-*.png`, `incapacitated.png`, and `slain.png`. The scratch source was restored to the checkpoint after verification. The patch, probes, and measurements remain in `$review`.

## Crowded NPC movement

22 November 2026. Profiled a fresh control and screened a lower collision slide limit in scratch. The cap raised scene callback medians in both comparisons and changed the battle outcome. The next movement trial targets Guard Base warriors whose approach is blocked by allies.

The scratch checkpoint is `c45e76abd1036d54af0c4cff2afe6e94f48930a4` over `c7f3a72`, including the first-person work in the checkout. All seven launches used Godot 4.3 stable `77dcf97d8`, Forward+ and Vulkan 1.3.215 on Intel UHD Graphics 620 at 1280×720. They used the active 171-unit `battle-off` fixture, seed `17394`, 45 warm-up ticks, and 600 samples at one physics tick per frame with drawing disabled. All returned `CAMPAIGN FRAME BENCHMARK COMPLETE` with the active-campaign checks in place.

### Native movement profile

The probe brackets `HumanUnit.move_and_slide()` with a timer. It reads the reported collision slide count and horizontal progress after the timer. Inside camp means an XZ distance of at most 32 m from the player camp. The timing of each bucket covers the complete calls in that bucket. [Human movement](../scripts/entities/human_unit.gd) · [Godot 4.3 collision slide API](https://docs.godotengine.org/en/4.3/classes/class_characterbody3d.html#class-characterbody3d-method-get-slide-collision-count)

| Scope | Calls in each control | Calls with 1 / 2 / 3+ slides | Mean native ms per tick, control 1 / 2 |
| --- | ---: | ---: | ---: |
| All NPCs | 44,658 | 35,744 / 7,749 / 1,165 | 5.868 / 5.294 |
| Within 32 m | 26,782 | 18,718 / 6,933 / 1,131 | 4.035 / 3.633 |
| Outside 32 m | 17,876 | 17,026 / 816 / 34 | 1.833 / 1.661 |

All calls within 32 m came from adult NPC foot warriors. Calls with two or more slides accounted for 54.0–54.4% of the native time there and 95.8–96.1% of calls at or above the per-call p95. Calls with three or more slides accounted for 0.435–0.464 ms per tick. Among 22,633 horizontal requests within 32 m, 5,880 (26.0%) advanced at most 10% of the requested distance, with a 1 mm tolerance. Each of those calls reported a wall contact.

### Two-slide cap screen

The common scratch harness temporarily set `max_slides` from the stock six to two around each eligible warrior's NPC movement call. It restored the property afterward. The native timer excludes these assignments. The scene timer includes them and the trace collection. The fixed-step loop spans physics-frame signals and includes idle and engine work. Timing triples are median / p95 / p99 in ms.

| Run | Native movement calls | Native movement per tick | Scene physics callback | Unrendered loop |
| --- | ---: | ---: | ---: | ---: |
| Stock 1 | 44,658 | 6.218 / 10.004 / 12.817 | 43.087 / 74.798 / 94.093 | 71.642 / 126.564 / 168.585 |
| Two slides 1 | 42,079 | 6.201 / 11.701 / 13.365 | 45.516 / 88.307 / 100.103 | 78.937 / 145.041 / 182.754 |
| Two slides 2 | 42,079 | 6.011 / 10.658 / 11.698 | 44.911 / 82.363 / 96.000 | 73.649 / 138.988 / 180.355 |
| Stock 2 | 44,658 | 5.468 / 10.041 / 14.410 | 36.475 / 75.036 / 102.385 | 62.900 / 122.525 / 228.521 |

Mean native cost rose from 6.732 to 6.899 ms per tick in the first pairing and from 6.160 to 6.632 ms in the reverse pairing. The cap removed all 3+ slide calls from the near-camp bucket. Near camp, low-progress requests rose from 26.0% to 28.9%, and forward travel as a share of requested distance fell from 66.0% to 63.3%. The stock repeats ended with 115 living units and 44 corpse nodes. Both capped runs ended with 108 living units and 48 corpse nodes. The deterministic snapshot and next RNG value matched within each variant. The fixed-step result screened the cap out before rendered and navigation verification. The longest loop intervals still reached 1.45–1.93 s across this screen.

### Guard Base contact follow-up

A separate stock capture tagged each Guard Base request with its combat intent and steering path. It inspected contacts that opposed the requested horizontal motion during low-progress calls. The 3,073 sampled calls all came from engaging a target. Of the 2,424 direct approaches, 2,423 started outside the actor's attack range and 2,421 reported an opposing contact with an ally. One warrior had 162 consecutive low-progress ticks, about 2.7 simulated seconds. The trace reproduced the stock combat digest and RNG value. [Guard Base and target engagement](../scripts/entities/unit_combat_ai.gd) · [Direct steering](../scripts/entities/human_unit.gd) · [Godot 4.3 contact data](https://docs.godotengine.org/en/4.3/classes/class_kinematiccollision3d.html)

Test a short lateral approach for melee guards repeatedly blocked by an ally while pursuing the same target. Start with one guard, a friendly blocker, and a nearby hostile outside attack range. Measure failed requests and time to attack. Then use the seeded battle and the existing navigation checks to assess retreat, knockback, fords, gates, and routing around solid buildings. [Next movement experiment](PERFORMANCE_HANDOVER.md#crowded-npc-movement)

### Reproduce

The scratch root is `<USERPROFILE>\AppData\Local\Temp\cf-move-d757b8`. The launchers exercise `res://scripts/tools/benchmark_campaign_frames.gd` with `--rendering-method forward_plus --rendering-driver vulkan --resolution 1280x720 --fixed-fps 60 --quit-after 1100` and `--scenario=battle-off --fixed-step --warmup=45 --samples=600`. Each launch uses fresh, short `APPDATA` and `CHRIST_FALLOW_QA_APPDATA` directories.

Install the patch and matching GDScript probe in the scratch checkpoint's `source` directory for the chosen run. Place the probe at `source/scripts/tools/npc_movement_probe.gd`. Use a fresh `-Label` for each rerun. Each recorded directory contains `profile.log` and `movement.csv`.

| Capture | Scratch patch and probe | Launcher and recorded labels in run order |
| --- | --- | --- |
| Movement attribution | `movement-instrumentation.patch` and `npc_movement_probe.gd` | `run-profile.ps1 -Label` with `control-1`, `control-2` |
| Matched cap screen | `movement-slide-trial.patch` and `npc_movement_probe_trial.gd` | `run-slide-trial.ps1 -Label` with `slide-control-1`, `slide-candidate-1`, `slide-candidate-2`, `slide-control-2`. Pass `-SlideCap 2` for the candidates. |
| Guard contacts | `movement-contact-instrumentation.patch` and `npc_movement_probe_contacts.gd` | `run-slide-trial.ps1 -Label guard-contacts` at the default stock cap. Includes `movement.csv.contacts.csv`. |

Run `node summarize-movement.cjs <run-directory> ...` for native times and progress or `node summarize-guard-contacts.cjs guard-contacts/movement.csv.contacts.csv` for contact counts.

## AI follow-up

- **Warbands.** Guard Base searches around the home camp and uses the same class-sensitive scoring as individual combat. Follow, Hold and Charge stay actor-relative. Charge can alternate between local and wide scans when it lacks a target, a useful scenario for a separate acquisition profile. Rival raids set a camp destination on each unit, then individual detection interrupts the march as opportunities appear. Fords and gates route through `ValleyNavigation`. Low-HP units retreat individually and raids can scatter on contact. A rally point and a bounded reform window would make recovery visible and give the player a way to bring separated squads back together. Start with one player squad and one ford. Test scattered troops, a truce during the approach, and an order replacement halfway across. [Unit combat and steering](../scripts/entities/human_unit.gd) · [Warband orders](../scripts/systems/combat_command_system.gd) · [Raid setup](../scripts/systems/faction_controller.gd)
- **Workers.** The 540-tick settlement sample ended with eight workers hauling and 15 Wood delivered to stock. Thirty workers held the same gather target. Gatherers remember that target, while crop and blueprint searches can select the same job for several workers. Haulers pick the nearest eligible drop-off from their current position. A blocked approach has no explicit job failure state. Start with Farm job visibility and short crop reservations, using the Shaman rescue lease as a precedent. Keep claims transient and release them on role change, destruction or expiry. Verify two distant reachable fields, one blocked approach, a worker reassignment, and a save/load with Food in transit. Reproduce the crowding sample with `--fixed-step --scenario=settlement --samples=540`. [Worker routines](../scripts/entities/unit_ai_routines.gd) · [Colony controls](../scripts/ui/drawers/colony_drawer.gd) · [Farming verifier](../scripts/tools/verify_farming_taming.gd)

## Next performance priority

Trial a short lateral approach for Guard Base melee warriors whose direct path to a target is blocked by an ally. Use the contact trace to reproduce the stalled approach and the fixed-step battle to measure progress and native movement cost. [Crowded NPC movement](PERFORMANCE_HANDOVER.md#crowded-npc-movement) · [Guard Base contact follow-up](#guard-base-contact-follow-up)

## Regression verification

Use the [roadmap PowerShell launcher and isolation setup](ROADMAP.md#verification-gate-commands-windows-powershell). Run at 1280×720 with `--fixed-fps 60` and a fresh scratch directory for each command. The recorded suite checks use the normal source project with Forward+. For save, navigation, expanded valley, and diplomacy assertions, add `--disable-render-loop` if only the gameplay assertions are needed.

The suites below returned exit code 0 with their explicit pass markers, including `PASS action Quit` for the UI suite and `CRAG-BORN PILOT PASSED` for the rig. Godot reported startup shader cache initialization errors in the sandbox. Script, parse, and shader compilation checks remained clear in these runs. The legacy expanded benchmark also completed with 40/40 ford routes and a 0.081 ms median route query. Its developed-settlement monitor still recorded second-scale peaks, so use the per-tick and rendered timings above for the stress comparison.

| Suite | Gameplay path |
| --- | --- |
| `verify_campaign_ui.gd` | Title → New Game, F6 and Guard button on a live warrior, Hold and Follow, pause, F9/F10, map, cold load, conquest, Settings, and Quit. Inspected the dawn and night captures. |
| `verify_campaign_save.gd` | v1–v4 restoration, invalid save isolation, warm and cold campaign load paths, combat and pause checks. |
| `verify_phase1_nav.gd` and `verify_expanded_valley.gd` | Index parity, blocked and reopened routes, ford crossings, distant hauling and construction, raid movement, and classic layout recovery. |
| `verify_opening_tutorial.gd` | E recruitment and harvest, B Campfire and Sleeping Hut, C role assignment, combat, skip, and reload. |
| `verify_diplomacy_leaders.gd` | E negotiation and Peace, cached target rejection, gifts, alliances, raid and strike protection, tribute, and succession/conquest reload. |
| `verify_farming_taming.gd` | C Fields & Herds, crops and hauling, E taming/riding/dismounting, rider saves and Continue. Default, `--procedural-roster`, and `--skinned-tribesman-trial` variants. |
| `verify_crag_born.gd` | Imported locomotion, work, attacks, hit flashes, wounds and death. |
