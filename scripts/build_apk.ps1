<#
.SYNOPSIS
    Automated VISION AI Android APK build, timestamped archiving, and metadata generator.

.DESCRIPTION
    Runs flutter pub get, flutter analyze, and flutter build apk for the selected mode
    (debug, profile, or release), verifies the generated APK, copies it to
    dist/apk/<mode>/vision-<mode>-YYYYMMDD-HHmmss.apk using the Asia/Kolkata timezone
    without overwriting previous builds, preserves Flutter's original APK output, and
    writes build metadata JSON alongside the archived APK.

.PARAMETER Mode
    Build variant to compile: debug, profile, or release (default: release).

.EXAMPLE
    .\scripts\build_apk.ps1
    .\scripts\build_apk.ps1 -Mode debug
    .\scripts\build_apk.ps1 -Mode profile
    .\scripts\build_apk.ps1 -Mode release
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("debug", "profile", "release")]
    [string]$Mode = "release"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-AsiaKolkataDateTime {
    try {
        $istZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("India Standard Time")
    }
    catch {
        $istZone = [System.TimeZoneInfo]::CreateCustomTimeZone(
            "Asia/Kolkata",
            [TimeSpan]::FromMinutes(330),
            "India Standard Time",
            "IST"
        )
    }
    return [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $istZone)
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    Write-Host "==> $Description" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed ($Description) with exit code $LASTEXITCODE."
    }
}

function Get-PubspecVersionInfo {
    param([string]$PubspecPath)

    $versionName = "1.0.0"
    $versionCode = 1

    if (Test-Path $PubspecPath) {
        $lines = Get-Content -Path $PubspecPath -Encoding UTF8
        foreach ($line in $lines) {
            if ($line -match '^\s*version\s*:\s*([^\s+#]+)(?:\+(\d+))?') {
                $versionName = $Matches[1]
                if ($Matches[2]) {
                    $versionCode = [int]$Matches[2]
                }
                break
            }
        }
    }

    return @{
        VersionName = $versionName
        VersionCode = $versionCode
    }
}

function Get-AndroidPackageId {
    param([string]$GradlePath)

    $packageId = "com.brijesh.vision"
    if (Test-Path $GradlePath) {
        $content = Get-Content -Path $GradlePath -Raw -Encoding UTF8
        if ($content -match 'applicationId\s*=\s*"([^"]+)"') {
            $packageId = $Matches[1]
        }
    }
    return $packageId
}

function Get-FlutterSdkMetadata {
    $flutterVersion = "unknown"
    $dartVersion = "unknown"

    try {
        $rawJson = & flutter --version --machine 2>$null
        if ($LASTEXITCODE -eq 0 -and $rawJson) {
            $parsed = ($rawJson -join "`n") | ConvertFrom-Json
            if ($parsed.frameworkVersion) {
                $flutterVersion = [string]$parsed.frameworkVersion
            }
            if ($parsed.dartSdkVersion) {
                $dartVersion = [string]$parsed.dartSdkVersion
            }
        }
    }
    catch {
        # Fallback cleanly if machine version output is unavailable.
    }

    return @{
        FlutterVersion = $flutterVersion
        DartVersion    = $dartVersion
    }
}

function Get-GitCommitHash {
    param([string]$RepoRoot)

    try {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $previousPref = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $hash = (& git -C $RepoRoot rev-parse HEAD 2>$null)
            $exitCode = $LASTEXITCODE
            $ErrorActionPreference = $previousPref
            if ($exitCode -eq 0 -and $hash) {
                return ([string]$hash).Trim()
            }
        }
    }
    catch {
        # Not a git repository or git unavailable.
    }

    return $null
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

try {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw "Flutter CLI not found on PATH. Install Flutter and ensure it is available on PATH."
    }

    $normalizedMode = $Mode.ToLowerInvariant()
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host " VISION AI - Automated Android APK Build ($normalizedMode)" -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor DarkCyan

    Invoke-CheckedCommand -Description "Fetching Flutter dependencies (flutter pub get)" -Command {
        & flutter pub get
    }

    Invoke-CheckedCommand -Description "Running static analysis (flutter analyze)" -Command {
        & flutter analyze
    }

    Invoke-CheckedCommand -Description "Building $normalizedMode APK (flutter build apk --$normalizedMode)" -Command {
        $prevSkip = $env:VISION_SKIP_GRADLE_ARCHIVE
        $env:VISION_SKIP_GRADLE_ARCHIVE = "1"
        try {
            & flutter build apk "--$normalizedMode"
        }
        finally {
            if ($null -eq $prevSkip) {
                Remove-Item Env:VISION_SKIP_GRADLE_ARCHIVE -ErrorAction SilentlyContinue
            }
            else {
                $env:VISION_SKIP_GRADLE_ARCHIVE = $prevSkip
            }
        }
    }

    $sourceApkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-$normalizedMode.apk"
    if (-not (Test-Path $sourceApkPath -PathType Leaf)) {
        throw "Expected APK was not generated at: $sourceApkPath"
    }

    $distModeDir = Join-Path $projectRoot "dist\apk\$normalizedMode"
    if (-not (Test-Path $distModeDir)) {
        New-Item -ItemType Directory -Path $distModeDir -Force | Out-Null
    }

    # Generate Asia/Kolkata timestamp at build completion and guarantee no overwrite.
    do {
        $istNow = Get-AsiaKolkataDateTime
        $dateCompact = $istNow.ToString("yyyyMMdd")
        $timeCompact = $istNow.ToString("HHmmss")
        $baseName = "vision-$normalizedMode-$dateCompact-$timeCompact"
        $destApkPath = Join-Path $distModeDir "$baseName.apk"
        $destMetadataPath = Join-Path $distModeDir "$baseName.json"
        if ((Test-Path $destApkPath) -or (Test-Path $destMetadataPath)) {
            Start-Sleep -Seconds 1
        }
        else {
            break
        }
    } while ($true)

    Copy-Item -Path $sourceApkPath -Destination $destApkPath -ErrorAction Stop

    if (-not (Test-Path $destApkPath -PathType Leaf)) {
        throw "Failed to copy APK to destination: $destApkPath"
    }

    $apkFileInfo = Get-Item -Path $destApkPath
    $apkSizeBytes = [int64]$apkFileInfo.Length
    $apkSizeMB = [Math]::Round($apkSizeBytes / 1MB, 2)

    $versionInfo = Get-PubspecVersionInfo -PubspecPath (Join-Path $projectRoot "pubspec.yaml")
    $packageId = Get-AndroidPackageId -GradlePath (Join-Path $projectRoot "android\app\build.gradle.kts")
    $sdkInfo = Get-FlutterSdkMetadata
    $gitHash = Get-GitCommitHash -RepoRoot $projectRoot

    $metadata = [ordered]@{
        applicationName = "VISION"
        packageId       = $packageId
        buildMode       = $normalizedMode
        buildDate       = $istNow.ToString("yyyy-MM-dd")
        buildTime       = $istNow.ToString("HH:mm:ss")
        buildTimestamp  = "$dateCompact-$timeCompact"
        timezone        = "Asia/Kolkata"
        flutterVersion  = $sdkInfo.FlutterVersion
        dartVersion     = $sdkInfo.DartVersion
        gitCommitHash   = $gitHash
        apkFilename     = "$baseName.apk"
        apkSizeBytes    = $apkSizeBytes
        apkSizeFormatted = "$apkSizeMB MB ($apkSizeBytes bytes)"
        versionName     = $versionInfo.VersionName
        versionCode     = $versionInfo.VersionCode
    }

    $metadataJson = $metadata | ConvertTo-Json -Depth 4
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($destMetadataPath, $metadataJson + [Environment]::NewLine, $utf8NoBom)

    $resolvedOutputApk = (Resolve-Path $destApkPath).Path
    $resolvedMetadata = (Resolve-Path $destMetadataPath).Path
    $resolvedFlutterApk = (Resolve-Path $sourceApkPath).Path

    Write-Host ""
    Write-Host "BUILD SUCCESSFUL" -ForegroundColor Green
    Write-Host "  Application    : VISION ($packageId)"
    Write-Host "  Build Mode     : $normalizedMode"
    Write-Host "  Timestamp      : $($istNow.ToString('yyyy-MM-dd HH:mm:ss')) (Asia/Kolkata)"
    Write-Host "  File Size      : $apkSizeMB MB ($apkSizeBytes bytes)"
    Write-Host "  Output APK     : $resolvedOutputApk"
    Write-Host "  Metadata JSON  : $resolvedMetadata"
    Write-Host "  Flutter APK    : $resolvedFlutterApk (preserved)"
    Write-Host ""

    exit 0
}
catch {
    Write-Error $_
    exit 1
}
finally {
    Pop-Location
}
