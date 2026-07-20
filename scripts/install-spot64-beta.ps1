[CmdletBinding()]
param(
    [string]$Repository = "erodataM/spot64-releases",
    [string]$Tag = "latest",
    [switch]$SkipApplicationInstall
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$headers = @{ "User-Agent" = "Spot64-Beta-Installer" }

function Remove-WorkDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            return
        } catch {
            if ($attempt -lt 10) { Start-Sleep -Seconds 2 }
        }
    }
    Write-Warning "Temporary files remain at '$Path' because another process is using them. They can be deleted later."
}

if ($Tag -eq "latest") {
    $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases?per_page=20" -Headers $headers
    $release = $releases | Where-Object { -not $_.draft } | Select-Object -First 1
    if (-not $release) { throw "No published Spot64 release was found." }
} else {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/tags/$Tag" -Headers $headers
}
$assets = @{}
foreach ($asset in $release.assets) { $assets[$asset.name] = $asset.browser_download_url }
if (-not $assets.ContainsKey("spot64-corpus-manifest.json")) {
    throw "This release has no Spot64 corpus manifest."
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("spot64-beta-" + [guid]::NewGuid())
$stage = Join-Path $work "stage"
New-Item -ItemType Directory -Path $stage -Force | Out-Null
try {
    $manifestPath = Join-Path $work "spot64-corpus-manifest.json"
    Invoke-WebRequest -Uri $assets["spot64-corpus-manifest.json"] -OutFile $manifestPath
    $manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
    if ($manifest.schema_version -ne 1 -or $manifest.kind -ne "spot64-corpus") {
        throw "Unsupported corpus manifest."
    }
    $requiredBytes = [int64]$manifest.unpacked_bytes
    foreach ($volume in $manifest.volumes) { $requiredBytes += [int64]$volume.size_bytes }
    $requiredBytes += 1GB
    $drive = Get-PSDrive -Name ([IO.Path]::GetPathRoot($work).TrimEnd(':\'))
    if ($drive.Free -lt $requiredBytes) {
        throw "Not enough free disk space. Required: $requiredBytes bytes; free: $($drive.Free) bytes."
    }

    foreach ($volume in $manifest.volumes) {
        if (-not $assets.ContainsKey($volume.asset)) { throw "Missing release asset: $($volume.asset)" }
        $archive = Join-Path $work $volume.asset
        Write-Host "Downloading $($volume.asset)..."
        Invoke-WebRequest -Uri $assets[$volume.asset] -OutFile $archive
        $actual = (Get-FileHash -Algorithm SHA256 $archive).Hash.ToLowerInvariant()
        if ($actual -ne $volume.sha256) { throw "SHA-256 mismatch for $($volume.asset)" }
        Expand-Archive -LiteralPath $archive -DestinationPath $stage -Force
    }

    foreach ($file in $manifest.files) {
        if ($file.path -notmatch '^libase-store/[A-Za-z0-9._/-]+$' -or $file.path -match '(^|/)\.\.(/|$)') {
            throw "Unsafe corpus path: $($file.path)"
        }
        $candidate = Join-Path $stage ($file.path -replace '/', [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "Missing corpus file: $($file.path)" }
        if ((Get-Item -LiteralPath $candidate).Length -ne $file.size_bytes) { throw "Size mismatch: $($file.path)" }
        $actual = (Get-FileHash -Algorithm SHA256 $candidate).Hash.ToLowerInvariant()
        if ($actual -ne $file.sha256) { throw "SHA-256 mismatch: $($file.path)" }
    }

    $appData = Join-Path $env:APPDATA "org.libase.desktop"
    $target = Join-Path $appData "libase-store"
    $incoming = Join-Path $stage "libase-store"
    New-Item -ItemType Directory -Path $appData -Force | Out-Null
    $backup = $null
    try {
        if (Test-Path -LiteralPath $target) {
            $backup = Join-Path $appData ("libase-store.backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
            Move-Item -LiteralPath $target -Destination $backup
        }
        Move-Item -LiteralPath $incoming -Destination $target
    } catch {
        if ($backup -and (Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $target)) {
            Move-Item -LiteralPath $backup -Destination $target
        }
        throw
    }
    Write-Host "Corpus $($manifest.generation_id) installed."

    if (-not $SkipApplicationInstall) {
        $installerAsset = $release.assets | Where-Object { $_.name -match '^Libase-x86_64-pc-windows-msvc.*\.exe$' } | Select-Object -First 1
        if (-not $installerAsset) { throw "Windows NSIS installer not found in this release." }
        $installer = Join-Path $work $installerAsset.name
        Write-Host "Downloading the Spot64 application..."
        Invoke-WebRequest -Uri $installerAsset.browser_download_url -OutFile $installer
        if ($assets.ContainsKey("SHA256SUMS.txt")) {
            $sumsPath = Join-Path $work "SHA256SUMS.txt"
            Invoke-WebRequest -Uri $assets["SHA256SUMS.txt"] -OutFile $sumsPath
            $line = Get-Content $sumsPath | Where-Object { $_ -match ("  " + [regex]::Escape($installerAsset.name) + "$") } | Select-Object -First 1
            if (-not $line) { throw "Installer checksum is absent from SHA256SUMS.txt." }
            $expectedInstallerHash = ($line -split '\s+')[0].ToLowerInvariant()
            $actualInstallerHash = (Get-FileHash -Algorithm SHA256 $installer).Hash.ToLowerInvariant()
            if ($actualInstallerHash -ne $expectedInstallerHash) { throw "Installer SHA-256 mismatch." }
        }
        Start-Process -FilePath $installer -Wait
    }
} finally {
    Remove-WorkDirectory -Path $work
}
