# Run Blender in headless background mode with a specified Python script and arguments.
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ScriptPath,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$ScriptArgs
)

# 1. Resolve Blender executable
$blenderExe = $null

if ($env:BLENDER_EXE) {
    if (-not (Test-Path -LiteralPath $env:BLENDER_EXE -PathType Leaf)) {
        throw "BLENDER_EXE does not point to a file: $env:BLENDER_EXE"
    }
    $blenderExe = $env:BLENDER_EXE
} else {
    $searchPaths = @(
        (Join-Path $env:LOCALAPPDATA 'Blender'),
        'C:\Program Files\Blender Foundation',
        'C:\Program Files (x86)\Blender Foundation'
    )
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $found = Get-ChildItem -Path $path -Filter 'blender.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
            if ($found) {
                $blenderExe = $found
                break
            }
        }
    }
}

if (-not $blenderExe) {
    Write-Error "Could not locate blender.exe. Set `$env:BLENDER_EXE to its full path."
    exit 1
}

if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
    Write-Error "Script file not found: $ScriptPath"
    exit 1
}

$resolvedScript = (Resolve-Path -LiteralPath $ScriptPath).Path

Write-Host "Using Blender: $blenderExe"
Write-Host "Running Script: $resolvedScript"

# Blender applies the error policy to scripts that appear after the flag.
& $blenderExe --background --factory-startup --python-exit-code 1 --python $resolvedScript -- @ScriptArgs

$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    Write-Error "Blender script failed with exit code $exitCode"
    exit $exitCode
}
Write-Host "Blender script completed successfully."
exit 0
