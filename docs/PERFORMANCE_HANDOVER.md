# Christ Fallow performance plan and handover

22 November 2026

The off-camera damage-number trial was rolled back, and the two-slide cap was screened out. The next simulation experiment is a short lateral approach for Guard Base warriors blocked by allies. Imported pose sampling follows as a separate trial. [Popup results](PERFORMANCE.md#off-camera-human-damage-numbers) · [Crowded NPC movement](#crowded-npc-movement) · [Engineering guide](../AGENTS.md)

## Starting point

The 21 November checkpoint `3abde8c` captures the source used for the rendering comparison. Later perk and combat edits were preserved in the shared working tree. Use that checkpoint to reproduce the historical results and capture a fresh control from the current source before measuring the next change. Inspect `git status --short --branch`, preserve staged and unstaged edits and untracked work, and checkpoint before a multi-file change. Keep the control and candidate on the same gameplay snapshot, with the same benchmark instrumentation. [Directional shadow attribution](PERFORMANCE.md#directional-shadow-attribution)

| Scenario | Stock rendered median | Stock rendered p95 | Fixed-step scene tick median |
| --- | ---: | ---: | ---: |
| Opening | 63.83 ms | 112.04 ms | 7.43 ms |
| Working settlement | 403.05 ms | 435.30 ms | 31.08 ms |
| Battle on camera | 280.26 ms | 367.33 ms | 36.29 ms |
| Battle off camera | 271.51 ms | 353.46 ms | 34.31 ms |

All 560 rendered confirmation frames exceeded the 16.7 ms budget. Directional shadows accounted for about 59% of on-camera draw submissions and 73% off camera. A custom shadow proxy exited with native status `0xc0000005`. The simpler Spearman trial cut shadow submissions by 10.8% on camera and had no repeatable timing gain, so the stock renderer is the control. [Spearman trial](PERFORMANCE.md#spearman-command-zoom-trial) · [Stock renderer confirmation](PERFORMANCE.md#stock-renderer-confirmation) · [Fixed-step follow-up](PERFORMANCE.md#fixed-step-follow-up)

Suppressing damage popups, slash arcs, and blood pools together cut the off-camera unrendered loop median by 8.69–13.33 ms across both run orders. The three creation paths averaged about 0.22 ms per tick. The 600-tick capture included 632 popup creations, so the first trial isolates their node and tween lifetime from the other two effects. [Off-camera profile](PERFORMANCE.md#off-camera-movement-animation-and-damage-effects)

## First experiment on damage popups

Completed 22 November 2026. The protocol below reproduces the trial. [Measurements and rollback decision](PERFORMANCE.md#off-camera-human-damage-numbers)

1. Add an explicit way for the ordinary numeric popup in `HumanUnit.take_damage()` to opt into visibility checks in `CombatVFX.spawn_damage_popup()`. Make the decision before allocating the `Label3D` or tween. Leave the default behavior available to other callers, including `INCAPACITATED!`, `SLAIN!`, level-up, construction, and harvest feedback. Keep wildlife damage numbers, slash arcs, and blood pools active during the first comparison. [Human damage](../scripts/entities/human_unit.gd) · [Popup creation](../scripts/core/combat_vfx.gd)
2. Use the anchor viewport’s active `Camera3D` so the check also works with the benchmark’s replacement cameras. Use the jittered popup origin and allow room for the billboard and its upward tween when checking the viewport edges. Check camera depth before projection. Keep the popup when the frame edge is uncertain or a camera is unavailable. Apply the existing Reduced Motion preference when evaluating the rise. Evaluate visibility at spawn and let emitted popups finish their usual lifespan. [Godot 4.3 camera projection](https://docs.godotengine.org/en/4.3/classes/class_camera3d.html#class-camera3d-method-unproject-position)
3. Consume the same two random offsets for every valid numeric popup request, even when its label is skipped. Use those values for placement when the label is emitted. Keep the decision in the presentation path so hit damage, XP, knockback, wounded transitions, and diplomacy follow their existing rules. Compare a short seeded damage sequence and the end state at the same fixed tick. [Popup jitter and tween](../scripts/core/combat_vfx.gd) · [Damage and combat state](../scripts/entities/human_unit.gd)
4. Count eligible requests, labels created, and requests skipped in the benchmark or a scratch probe. Run the fixed-step off-camera comparison and the rendered battle pair in control, candidate, candidate, control order. Use the same code for measurement in both variants. Compare the unrendered loop and scene callbacks separately, then compare rendered wall time and spikes. [Frame benchmark](../scripts/tools/benchmark_campaign_frames.gd)

### Popup gameplay checks

Use Forward+ with a display. Land a visible hit at close and command zoom, at each screen edge, and just beyond the edge. Hit while the target is behind the camera, turn back during the popup lifetime, and land another hit after the target comes into view. Check the expected readability at the edge and that newly visible hits show numbers promptly. Repeat the edge check with Reduced Motion and at a wide aspect ratio. The benchmark uses a 1280×720 window and a 1600×900 logical viewport, so check projection and padding in the same coordinate space. [Display configuration](../project.godot) · [Popup creation](../scripts/core/combat_vfx.gd)

Check a wound and a death, plus one unrelated feedback path through the shared helper. Compare visible numbers, colours, the hit reaction, HP and XP with the control. Exercise campaign teardown or reload with a visible popup in flight to check label and tween cleanup. Keep the slice when repeated runs improve target median and tail timings and the on-camera feedback and timing checks pass. Then rerun opening and the working settlement on the retained source. If the result is inconclusive, record the counts and timings before moving to the next experiment. [Crag-Born gameplay checks](../scripts/tools/verify_crag_born.gd) · [Campaign regression commands](ROADMAP.md#verification-gate-commands-windows-powershell)

## Later experiments

### Crowded NPC movement

The current stock profile spent 3.63–4.04 ms per tick in NPC `move_and_slide()` within 32 m of camp. Calls with two or more reported slides accounted for about 54% of that time. The two-slide cap raised scene callback medians and left seven fewer living units in the seeded battle, so it was screened out in scratch. [Fixed-step measurements](PERFORMANCE.md#crowded-npc-movement)

The follow-up traced an opposing ally contact on **2,421 of 2,424** stalled direct Guard Base approaches. Prototype a short lateral approach for a melee guard that repeatedly makes little progress toward a live target outside attack range. Start with one friendly blocker and one hostile. Reuse nearby-unit queries and the existing navigation clearance checks to evaluate a reachable position within attack range. Scope the offset to the current engagement and release it when the guard reaches attack range, the target changes, or the player replaces the order. [Contact trace](PERFORMANCE.md#guard-base-contact-follow-up) · [Guard Base routines](../scripts/entities/unit_combat_ai.gd) · [NPC steering](../scripts/entities/human_unit.gd)

Compare failed requests, time to attack, and native movement and scene tick time in the fixed-step battle. Check Guard Base camp targeting, Retreat and order replacement, knockback, ford and Standing-Stone Gate traversal, and a route around a solid building. Run the active rendered battle pair for a candidate that clears the fixed-step and gameplay checks. [Navigation verifier](../scripts/tools/verify_phase1_nav.gd) · [Expanded valley verifier](../scripts/tools/verify_expanded_valley.gd)

### Imported pose sampling

Native animation sampling averaged **3.52 ms per tick**. First inspect how `update_action()` advances clip time and restarts one-shot actions. Trial a lower sampling cadence for distant imported NPC locomotion, with accumulated delta and prompt resampling on camera return. Preserve immediate clip transitions and validate attack, hit, wounded, and death poses. Off-camera units can still cast visible shadows, so inspect their motion and weapon silhouettes at command zoom. Check the default rig, mounted player pose, and `--procedural-roster` path. Retain the slice when the matched sampling and frame timings improve and the poses pass review. [Imported controller](../scripts/entities/skinned_tribesman_trial.gd) · [Lineage verifier](../scripts/tools/verify_skinned_lineages.gd) · [Mount verifier](../scripts/tools/verify_farming_taming.gd)

### Directional shadows and worker allocation

- **Rendering.** If the GPU remains the next limiting stage, compare one shorter directional shadow distance against the stock sun. Treat a cascade-count change as a separate trial. Use the existing shadow counters and matched render runs. Review dawn and night, close and command zoom, weapon silhouettes, and shadow transitions while moving the camera. [Shadow measurements](PERFORMANCE.md#directional-shadow-attribution) · [World lighting](../scripts/systems/world_generator.gd) · [Godot 4.3 directional shadows](https://docs.godotengine.org/en/4.3/classes/class_directionallight3d.html)
- **Worker allocation.** Keep the 30 workers sharing one gather target as its own settlement case. Reproduce with `--scenario=settlement --fixed-step --warmup=45 --samples=540` and `--fixed-fps 60`. Record the largest shared target, workers hauling, and delivered stock. Use the existing worker plan for blocked approaches and transient crop reservations. [Worker follow-up](PERFORMANCE.md#ai-follow-up) · [Worker routines](../scripts/entities/unit_ai_routines.gd)

## Benchmark commands

Run the Godot 4.3 source project on the same machine, one launch at a time. The battle uses seed `17394`, `valley_expanded_760`, 171 initial units, and the existing on- and off-camera positions. Keep the same graphics and fixtures within each comparison. Rendered runs use 1280×720, VSync off, 3D scale 1.0, 2× MSAA, and the stock shadows and PSX settings. Use a fresh, short scratch `APPDATA` per launch. [Test conditions](PERFORMANCE.md#test-conditions) · [Battle setup](../scripts/tools/benchmark_campaign_frames.gd)

For the popup experiment, add `_summarize("unrendered fixed loop ms", elapsed)` immediately before the fixed-step early return in `_measure()` in the benchmark or its scratch copy. The fixed branch already collects intervals between `physics_frame` signals. Report this series alongside `scene physics tick ms`, which measures the scene callbacks. Keep the existing active-campaign check and the 171-unit setup check. Use the same instrumentation in the control and candidate. [Frame benchmark](../scripts/tools/benchmark_campaign_frames.gd)

```powershell
$godot = '<USERPROFILE>\AppData\Local\Godot\Godot_v4.3-stable_win64_console.exe'
$project = (Get-Location).Path

function Invoke-FallowBenchmark {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string[]] $ScenarioArgs,
        [switch] $Fixed
    )

    $scratch = Join-Path ([IO.Path]::GetTempPath()) ('cf-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $scratch -ErrorAction Stop | Out-Null
    $log = Join-Path $scratch "$Name.log"
    $previousAppData = $env:APPDATA
    $previousQaAppData = $env:CHRIST_FALLOW_QA_APPDATA
    $engineArgs = @('--disable-vsync')
    if ($Fixed) {
        $engineArgs = @('--fixed-fps', '60')
        $ScenarioArgs += '--fixed-step'
    }

    try {
        $env:APPDATA = $scratch
        $env:CHRIST_FALLOW_QA_APPDATA = $scratch
        & $godot --path $Source --rendering-method forward_plus --rendering-driver vulkan --resolution 1280x720 @engineArgs --quit-after 1100 -s res://scripts/tools/benchmark_campaign_frames.gd -- @ScenarioArgs *> $log
        $exitCode = $LASTEXITCODE
    } finally {
        $env:APPDATA = $previousAppData
        $env:CHRIST_FALLOW_QA_APPDATA = $previousQaAppData
    }

    $complete = Select-String -LiteralPath $log -Pattern '^CAMPAIGN FRAME BENCHMARK COMPLETE$' -Quiet
    $errors = Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|Parse Error|^ERROR:' -Quiet
    if ($exitCode -ne 0 -or -not $complete -or $errors) {
        throw "Benchmark failed. Inspect $log"
    }
    $log
}

$offCameraTicks = @('--scenario=battle-off', '--warmup=45', '--samples=600')
$battleFrames = @('--scenario=battle', '--warmup=45', '--samples=100')

# From the project root. Point -Source at the matching source copy for each run.
Invoke-FallowBenchmark -Source $project -Name 'off-camera-ticks' -ScenarioArgs $offCameraTicks -Fixed
Invoke-FallowBenchmark -Source $project -Name 'battle-frames' -ScenarioArgs $battleFrames

# Confirmation on retained source.
Invoke-FallowBenchmark -Source $project -Name 'opening-frames' -ScenarioArgs @('--scenario=opening', '--warmup=45', '--samples=180')
Invoke-FallowBenchmark -Source $project -Name 'settlement-frames' -ScenarioArgs @('--scenario=settlement', '--warmup=45', '--samples=180')
```

## Results to hand over after each experiment

- Record the exact control and candidate revisions or checkpoint, engine and GPU, run order, commands, and scratch log locations. Confirm the battle stayed active through every sample. The benchmark rejects paused or finished campaigns and requires its completion marker.
- Record median, p95, and p99 for the rendered wall, render CPU and viewport GPU times, with visible and shadow draw counts, entity counts, and the number of frames above 16.7 ms. For fixed-step runs, record the scene callback and unrendered loop timings, plus the counters for the code being tested. Compare deterministic end states in the fixed window and note any change in entity counts during rendered runs.
- Attach the focused gameplay path, verification markers, and the visual captures needed to review the change. Update the performance review with the decision, the remaining spikes, and the next experiment to take up. Keep probes, saves, and captures in scratch, and identify the exact candidate diff for rollback. [Performance review](PERFORMANCE.md) · [Engineering handoff](HANDOFF.md)
