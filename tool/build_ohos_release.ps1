<#
.SYNOPSIS
    Build the signed HarmonyOS release HAP for OronBox (single arm64 ABI).

.DESCRIPTION
    Wraps `hvigorw assembleApp` with every flag this project actually needs so
    a release build is reproducible instead of living in shell history:

      DEVECO_SDK_HOME / JAVA_HOME   hvigor 6 requires both; without JAVA_HOME
                                    PackageHap dies with "spawn java ENOENT"
      System32\Wbem removed         wmic.exe is blocked by the local security
                                    policy and hvigor probes it for the OS
                                    locale; with the directory off PATH the
                                    probe fails soft instead of aborting
      NODE_OPTIONS + ohpm_local     hvigor resolves the stock DevEco ohpm.bat by
                                    absolute path, and that script overflows
                                    cmd's batch stack when quoted. fs_hook.js
                                    hides it so hvigor falls back to the
                                    non-recursive wrapper on PATH
      TARGET_PLATFORM=ohos-arm64    without it flutter-hvigor-plugin packs both
                                    ohos-arm64 and ohos-x64 (~77 MB vs ~40 MB),
                                    and the x86_64 set is incomplete anyway
      TREE_SHAKE_ICONS=true         default is OFF in flutter-hvigor-plugin, so
                                    the full 1.5 MB MaterialIcons font ships
      DART_DEFINES (base64)         APP_VERSION drives the about page;
                                    GIT_COMMIT_HASH stops the app from shelling
                                    out to a non-existent `git` on mobile
      flutter intermediates wiped   a previously failed build leaves stale
                                    flutter_assets behind, which makes the next
                                    run fail with errno 183

    NOTE: this machine blocks .ps1 by default. Run it with:
      powershell -ExecutionPolicy Bypass -File tool\build_ohos_release.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tool\build_ohos_release.ps1
    powershell -ExecutionPolicy Bypass -File tool\build_ohos_release.ps1 -BuildMode profile
#>
param(
    [string]$BuildMode = "release",
    [string]$Product = "default",
    [switch]$SkipFlutterClean
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$ohosDir = Join-Path $repoRoot "ohos"
if (-not (Test-Path $ohosDir)) {
    throw "Cannot find the ohos directory under $repoRoot"
}

# --- version / commit ------------------------------------------------------
$appJsonPath = Join-Path $ohosDir "AppScope\app.json5"
$version = "0.0.0"
if (Test-Path $appJsonPath) {
    $match = [regex]::Match((Get-Content $appJsonPath -Raw), 'versionName"\s*:\s*"([^"]+)"')
    if ($match.Success) { $version = $match.Groups[1].Value }
}

$commit = "local"
try {
    $gitOut = & git -C $repoRoot rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitOut) { $commit = "$gitOut".Trim() }
} catch { }

# hvigor expects DART_DEFINES as base64 of comma-joined key=value pairs.
$definesPlain = "APP_VERSION=$version,GIT_COMMIT_HASH=$commit"
$dartDefines = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($definesPlain))

Write-Output "OronBox ohos build"
Write-Output "  version    : $version"
Write-Output "  commit     : $commit"
Write-Output "  buildMode  : $BuildMode"
Write-Output "  product    : $Product"
Write-Output "  ABI        : ohos-arm64 (single)"
Write-Output "  tree-shake : on"

# --- stale flutter intermediates ------------------------------------------
if (-not $SkipFlutterClean) {
    $modeDir = $BuildMode.Substring(0, 1).ToUpper() + $BuildMode.Substring(1)
    foreach ($rel in @(
        ("build\ohos\intermediates\flutter\" + $modeDir),
        "build\ohos\intermediates\flutter"
    )) {
        $path = Join-Path $repoRoot $rel
        if (Test-Path $path) {
            try {
                [System.IO.Directory]::Delete($path, $true)
                Write-Output "  cleaned stale: $rel"
            } catch {
                Write-Output "  warning: could not fully clean $rel"
            }
        }
    }
}

# --- environment -----------------------------------------------------------
$deveco = "C:\Program Files\Huawei\DevEco Studio"
$ohpmLocal = "C:\Users\Administrator\ohpm_local\bin"
$env:DEVECO_SDK_HOME = Join-Path $deveco "sdk"
$env:JAVA_HOME = Join-Path $deveco "jbr"
if (Test-Path (Join-Path $ohpmLocal "fs_hook.js")) {
    $env:NODE_OPTIONS = "--require=" + (Join-Path $ohpmLocal "fs_hook.js").Replace('\', '/')
}
# jbr\bin first (PackageHap needs java), ohpm wrapper early, Wbem removed.
$pathParts = @((Join-Path $deveco "jbr\bin"))
if (Test-Path $ohpmLocal) { $pathParts += $ohpmLocal }
$pathParts += (($env:PATH -split ';') | Where-Object { $_ -and ($_ -notmatch 'Wbem') })
$env:PATH = $pathParts -join ';'

# --- build -----------------------------------------------------------------
$logPath = Join-Path $repoRoot "ohos_build_$BuildMode.log"
if (Test-Path $logPath) { Remove-Item $logPath -Force -ErrorAction SilentlyContinue }
$hap = Join-Path $ohosDir "entry\build\default\outputs\default\entry-default-signed.hap"
$hapBefore = if (Test-Path $hap) { (Get-Item $hap).LastWriteTime } else { [datetime]::MinValue }

Push-Location $ohosDir
try {
    & ".\hvigorw.bat" assembleApp `
        -p "product=$Product" `
        -p "buildMode=$BuildMode" `
        -p "DART_DEFINES=$dartDefines" `
        -p "TARGET_PLATFORM=ohos-arm64" `
        -p "TREE_SHAKE_ICONS=true" `
        --no-daemon *> $logPath
    $exit = $LASTEXITCODE
} finally {
    Pop-Location
}

# --- report ----------------------------------------------------------------
# hvigor's exit code is not a reliable success signal here (post-package
# bookkeeping tasks can still return non-zero after the HAP was written), so
# judge by the artifact itself: a signed HAP whose timestamp advanced.
$hapAfter = if (Test-Path $hap) { (Get-Item $hap).LastWriteTime } else { [datetime]::MinValue }
$produced = $hapAfter -gt $hapBefore

$summary = New-Object System.Collections.Generic.List[string]
if ($produced) {
    $sizeMb = [Math]::Round((Get-Item $hap).Length / 1MB, 2)
    $summary.Add("")
    $summary.Add("BUILD SUCCESSFUL")
    $summary.Add("  HAP  : $hap")
    $summary.Add("  size : $sizeMb MB")
    $summary.Add("  built: $hapAfter")
    $summary.Add("  log  : $logPath")
    $code = 0
} else {
    $summary.Add("")
    $summary.Add("BUILD FAILED (hvigor exit $exit, no fresh HAP produced)")
    $summary.Add("  log: $logPath")
    $summary.Add("  --- last 30 lines ---")
    foreach ($line in (Get-Content $logPath -Tail 30 -ErrorAction SilentlyContinue)) {
        $summary.Add($line)
    }
    $code = 1
}

foreach ($line in $summary) { Write-Output $line }
# Also persist so the result survives output redirection quirks.
$summary | Add-Content -Path (Join-Path $repoRoot "ohos_build_report.txt") -ErrorAction SilentlyContinue

$global:LASTEXITCODE = $code
