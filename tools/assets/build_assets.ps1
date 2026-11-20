param(
    [string]$GodotExe = $env:GODOT_EXE,
    [switch]$VerifyOnly,
    [switch]$RequireGameplayRig
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
if (-not $GodotExe) {
    $GodotExe = Join-Path $env:LOCALAPPDATA 'Godot/Godot_v4.3-stable_win64_console.exe'
}
$GodotExe = (Get-Command $GodotExe -CommandType Application).Source

$buildId = [guid]::NewGuid().ToString('N')
$work = Join-Path ([IO.Path]::GetTempPath()) "christ-fallow-assets-$buildId"
$stagedProject = Join-Path $work 'project'
$renders = Join-Path $work 'renders'
$stagedModels = Join-Path $stagedProject 'assets/models'
$modelFiles = @(
    'buildings/sleeping_hut_stages.glb'
    'buildings/palisade_wall_stages.glb'
    'characters/tribesman_base.glb'
)

function Invoke-Godot([string[]]$Arguments, [string]$SuccessMarker) {
    $console = & $GodotExe @Arguments 2>&1
    $status = $LASTEXITCODE
    $console | ForEach-Object { Write-Host $_ }
    $log = $console | Out-String
    if ($status -ne 0 -or $log -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|SHADER ERROR:|Parse Error:)') {
        throw "Godot failed during asset verification. Staging directory: $work"
    }
    if ($SuccessMarker -and -not $log.Contains($SuccessMarker)) {
        throw "Godot exited before completing asset verification. Staging directory: $work"
    }
}

function Publish-Models {
    $models = Join-Path $project 'assets/models'
    # Publish under an exclusive lock so two successful builds cannot interleave replacements.
    $lock = [IO.FileStream]::new((Join-Path $models '.asset-publish.lock'),
        [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::Write, [IO.FileShare]::None,
        1, [IO.FileOptions]::DeleteOnClose)
    $changes = @()
    try {
        foreach ($model in $modelFiles) {
            $source = Join-Path $stagedModels $model
            $target = Join-Path $models $model
            $exists = [IO.File]::Exists($target)
            if ($exists -and (Get-FileHash -LiteralPath $source).Hash -eq (Get-FileHash -LiteralPath $target).Hash) {
                continue
            }
            $changes += [pscustomobject]@{
                Target = $target
                Pending = "$target.$buildId.tmp"
                Backup = "$target.$buildId.bak"
                Existed = $exists
                Published = $false
            }
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
            [IO.File]::Copy($source, $changes[-1].Pending)
        }
        foreach ($change in $changes) {
            if ($change.Existed) {
                [IO.File]::Replace($change.Pending, $change.Target, $change.Backup)
            } else {
                [IO.File]::Move($change.Pending, $change.Target)
            }
            $change.Published = $true
        }
    } catch {
        $publicationError = $_
        $restoreErrors = @()
        foreach ($change in $changes) {
            try {
                if ($change.Published -and $change.Existed) {
                    [IO.File]::Replace($change.Backup, $change.Target, [NullString]::Value)
                } elseif ($change.Published) {
                    [IO.File]::Delete($change.Target)
                }
            } catch {
                $restoreErrors += "$($change.Target): $_"
            }
        }
        if ($restoreErrors.Count) {
            throw "Asset publication failed. Retained backup files for build $buildId. $publicationError. Restore errors: $($restoreErrors -join '; ')"
        }
        throw $publicationError
    } finally {
        $lock.Dispose()
        foreach ($change in $changes) {
            [IO.File]::Delete($change.Pending)
        }
    }
    foreach ($change in $changes) {
        [IO.File]::Delete($change.Backup)
    }
}

New-Item -ItemType Directory -Path $stagedProject, $renders | Out-Null
Write-Host "Asset staging directory: $work"
foreach ($entry in 'project.godot', 'icon.svg', 'icon.svg.import', 'assets', 'scenes', 'scripts') {
    Copy-Item -LiteralPath (Join-Path $project $entry) -Destination $stagedProject -Recurse
}
# A generator that returns early cannot pass by inheriting the previous output.
foreach ($model in $modelFiles) {
    [IO.File]::Delete((Join-Path $stagedModels $model))
}

$runner = Join-Path $PSScriptRoot 'run_blender.ps1'
& $runner -ScriptPath (Join-Path $PSScriptRoot 'generate_village_building.py') -ScriptArgs @('--out-dir', (Join-Path $stagedModels 'buildings'))
if ($LASTEXITCODE -ne 0) { throw 'Building generation failed.' }
& $runner -ScriptPath (Join-Path $PSScriptRoot 'generate_tribesman_rig.py') -ScriptArgs @('--out-dir', (Join-Path $stagedModels 'characters'))
if ($LASTEXITCODE -ne 0) { throw 'Character generation failed.' }
foreach ($model in $modelFiles) {
    $file = Get-Item -LiteralPath (Join-Path $stagedModels $model)
    if ($file.Length -le 20) { throw "Invalid GLB output: $($file.FullName)" }
}

Invoke-Godot @('--headless', '--editor', '--path', $stagedProject, '--import', '--log-file', (Join-Path $work 'import.log'))
$verifyArguments = @('--path', $stagedProject, '--resolution', '1280x720', '--quit-after', '600',
    '--log-file', (Join-Path $work 'verify.log'), '--script', 'res://scripts/tools/verify_glb_assets.gd',
    '--', "--out-dir=$renders")
if ($RequireGameplayRig) { $verifyArguments += '--require-gameplay-rig' }
Invoke-Godot $verifyArguments 'ASSET VERIFICATION PASSED'

Write-Host "Review renders: $renders"
if (-not $VerifyOnly) {
    Publish-Models
    Write-Host 'Published verified GLBs.'
}
