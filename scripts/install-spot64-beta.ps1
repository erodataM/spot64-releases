[CmdletBinding()]
param(
    [string]$Repository = "erodataM/spot64-releases",
    [string]$Tag = "latest",
    [switch]$SkipApplicationInstall,
    [switch]$SkipApplicationLaunch,
    [switch]$SilentApplicationInstall
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Invoke-VerifiedDownload {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$Label,
        [int]$Attempts = 5
    )

    $parent = Split-Path -Parent $Destination
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $curl = Get-Command "curl.exe" -ErrorAction SilentlyContinue
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            if ($curl) {
                $arguments = @(
                    "--fail",
                    "--location",
                    "--silent",
                    "--show-error",
                    "--retry", "3",
                    "--retry-all-errors",
                    "--retry-delay", "2",
                    "--connect-timeout", "30"
                )
                if (Test-Path -LiteralPath $Destination) {
                    $arguments += @("--continue-at", "-")
                }
                $arguments += @("--output", $Destination, $Uri)
                & $curl.Source @arguments
                if ($LASTEXITCODE -ne 0) {
                    throw "curl.exe exited with status $LASTEXITCODE"
                }
            } else {
                Invoke-WebRequest -Uri $Uri -OutFile $Destination
            }
            if (-not (Test-PlainFile -Path $Destination)) {
                throw "download did not produce a regular file"
            }
            return
        } catch {
            if ($LASTEXITCODE -eq 33 -and (Test-Path -LiteralPath $Destination)) {
                Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
            }
            if ($attempt -eq $Attempts) {
                throw "Unable to download $Label after $Attempts attempts: $($_.Exception.Message)"
            }
            $delay = [Math]::Min(30, [Math]::Pow(2, $attempt))
            Write-Warning "$Label download interrupted (attempt $attempt/$Attempts). Retrying in $delay seconds."
            Start-Sleep -Seconds $delay
        }
    }
}

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

function Assert-Spot64Stopped {
    $running = Get-Process -Name "desktop", "libase-api", "libase-store-runtime" `
        -ErrorAction SilentlyContinue
    if ($running) {
        throw "Spot64 is currently running. Close the application, then launch this installer again."
    }
}

function Invoke-PrimaryDatabaseRebase {
    param(
        [Parameter(Mandatory = $true)][string]$AppData,
        [Parameter(Mandatory = $true)][string]$Repository
    )

    $catalog = Join-Path $AppData "user-databases"
    if (-not (Test-Path -LiteralPath (Join-Path $catalog "catalog.json"))) {
        Write-Host "No existing user catalog requires migration."
        return
    }
    $runtime = Join-Path $env:LOCALAPPDATA "Libase\libase-store-runtime.exe"
    if (-not (Test-PlainFile -Path $runtime)) {
        throw "The installed Store runtime is missing: $runtime"
    }
    Write-Host "Migrating the primary database to the new corpus..."
    $output = & $runtime `
        --catalog $catalog `
        --primary-repository $Repository `
        --verify manifest `
        --rebase-empty-primary 2>&1
    if ($LASTEXITCODE -ne 0) {
        $detail = ($output | Out-String).Trim()
        throw "Primary database migration refused. No user data was changed. $detail"
    }
    Write-Host (($output | Out-String).Trim())
}

function Test-PlainFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $item = Get-Item -LiteralPath $Path
    return ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0
}

function Test-PlainDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }
    $item = Get-Item -LiteralPath $Path
    return ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0
}

function Get-CorpusRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (
        $Path -notmatch '^libase-store/[A-Za-z0-9._/-]+$' -or
        $Path -match '(^|/)\.\.?(/|$)' -or
        $Path.Contains("//")
    ) {
        throw "Unsafe corpus path: $Path"
    }
    return $Path.Substring("libase-store/".Length) -replace '/', [IO.Path]::DirectorySeparatorChar
}

function Get-StagingRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (
        $Path -notmatch '^(\.spot64-parts|libase-store)/[A-Za-z0-9._/-]+$' -or
        $Path -match '(^|/)\.\.?(/|$)' -or
        $Path.Contains("//")
    ) {
        throw "Unsafe package path: $Path"
    }
    return $Path -replace '/', [IO.Path]::DirectorySeparatorChar
}

function Restore-CorpusParts {
    param(
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)]$Files
    )

    foreach ($file in $Files) {
        if ($null -eq $file.parts) { continue }
        $parts = @($file.parts | Where-Object { $null -ne $_ })
        if ($parts.Count -eq 0) {
            throw "Empty corpus file parts: $($file.path)"
        }
        $logicalPath = Get-StagingRelativePath -Path ([string]$file.path)
        $candidate = Join-Path $Stage $logicalPath
        $parent = Split-Path -Parent $candidate
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $targetStream = [IO.File]::Open(
            $candidate,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None
        )
        try {
            foreach ($part in ($parts | Sort-Object -Property offset_bytes)) {
                $partPath = Join-Path $Stage (
                    Get-StagingRelativePath -Path ([string]$part.path)
                )
                if (-not (Test-PlainFile -Path $partPath)) {
                    throw "Missing corpus file part: $($part.path)"
                }
                if ((Get-Item -LiteralPath $partPath).Length -ne $part.size_bytes) {
                    throw "Size mismatch: $($part.path)"
                }
                $sourceStream = [IO.File]::OpenRead($partPath)
                try {
                    $sourceStream.CopyTo($targetStream)
                } finally {
                    $sourceStream.Dispose()
                }
                Remove-Item -LiteralPath $partPath -Force
            }
        } finally {
            $targetStream.Dispose()
        }
    }
}

function Test-CachedVolume {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Volume
    )

    if (-not (Test-PlainFile -Path $Path)) { return $false }
    if ((Get-Item -LiteralPath $Path).Length -ne [int64]$Volume.size_bytes) {
        return $false
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    return $actual -ceq [string]$Volume.sha256
}

function Test-InstalledCorpus {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)]$Manifest
    )

    try {
        if ([int]$Manifest.position_max_ply -lt 40) { return $false }
        $generationId = [string]$Manifest.generation_id
        if ($generationId -notmatch '^[0-9a-f]{64}$') { return $false }
        if (-not (Test-PlainDirectory -Path $Target)) { return $false }

        $generations = Join-Path $Target "generations"
        $generation = Join-Path $generations $generationId
        if (
            -not (Test-PlainDirectory -Path $generations) -or
            -not (Test-PlainDirectory -Path $generation)
        ) {
            return $false
        }

        $currentPath = Join-Path $Target "current.json"
        if (-not (Test-PlainFile -Path $currentPath)) { return $false }
        $current = Get-Content -Raw -LiteralPath $currentPath | ConvertFrom-Json
        if ([string]$current.currentGenerationId -cne $generationId) { return $false }

        $files = @($Manifest.files)
        if ($files.Count -lt 2) { return $false }
        foreach ($file in $files) {
            $declaredPath = [string]$file.path
            $relativePath = Get-CorpusRelativePath -Path $declaredPath
            $candidate = Join-Path $Target $relativePath
            $expectedSize = [int64]$file.size_bytes
            $expectedHash = [string]$file.sha256
            if (
                $expectedSize -lt 0 -or
                $expectedHash -notmatch '^[0-9a-f]{64}$' -or
                -not (Test-PlainFile -Path $candidate)
            ) {
                return $false
            }
            if ((Get-Item -LiteralPath $candidate).Length -ne $expectedSize) {
                return $false
            }

            # Small metadata files bind the installed repository to the release
            # without re-hashing several gigabytes on every application update.
            if ($expectedSize -le 1MB) {
                $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $candidate).Hash.ToLowerInvariant()
                if ($actualHash -cne $expectedHash) { return $false }
            }
        }
        return $true
    } catch {
        return $false
    }
}

function Invoke-Spot64BetaInstaller {
    param(
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string]$Tag,
        [switch]$SkipApplicationInstall,
        [switch]$SkipApplicationLaunch,
        [switch]$SilentApplicationInstall
    )

    $headers = @{ "User-Agent" = "Spot64-Beta-Installer" }
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

    $installerAsset = $null
    if (-not $SkipApplicationInstall) {
        $installerAsset = $release.assets |
            Where-Object { $_.name -match '^Libase-x86_64-pc-windows-msvc.*\.exe$' } |
            Select-Object -First 1
        if (-not $installerAsset) { throw "Windows NSIS installer not found in this release." }
    }

    $work = Join-Path ([System.IO.Path]::GetTempPath()) ("spot64-beta-" + [guid]::NewGuid())
    $stage = Join-Path $work "stage"
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    $backup = $null
    $target = $null
    $installedNewCorpus = $false
    try {
        Assert-Spot64Stopped
        $manifestPath = Join-Path $work "spot64-corpus-manifest.json"
        Invoke-VerifiedDownload `
            -Uri $assets["spot64-corpus-manifest.json"] `
            -Destination $manifestPath `
            -Label "corpus manifest"
        $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
        if (
            $manifest.schema_version -ne 2 -or
            $manifest.kind -ne "spot64-corpus" -or
            [int]$manifest.position_max_ply -lt 40 -or
            [string]$manifest.generation_id -notmatch '^[0-9a-f]{64}$'
        ) {
            throw "Unsupported corpus manifest."
        }

        $appData = Join-Path $env:APPDATA "org.libase.desktop"
        $target = Join-Path $appData "libase-store"
        $reuseCorpus = Test-InstalledCorpus -Target $target -Manifest $manifest
        $cache = Join-Path $env:LOCALAPPDATA (
            "Spot64\download-cache\" + [string]$manifest.generation_id
        )
        $cachedVolumes = @{}
        if (-not $reuseCorpus) {
            New-Item -ItemType Directory -Path $cache -Force | Out-Null
            foreach ($volume in $manifest.volumes) {
                $cachedPath = Join-Path $cache ([string]$volume.asset)
                if (Test-CachedVolume -Path $cachedPath -Volume $volume) {
                    $cachedVolumes[[string]$volume.asset] = $true
                } elseif (Test-Path -LiteralPath $cachedPath) {
                    Remove-Item -LiteralPath $cachedPath -Force
                }
            }
        }

        $requiredBytes = 512MB
        if (-not $reuseCorpus) {
            $requiredBytes += [int64]$manifest.unpacked_bytes
            foreach ($volume in $manifest.volumes) {
                if (-not $cachedVolumes.ContainsKey([string]$volume.asset)) {
                    $requiredBytes += [int64]$volume.size_bytes
                }
            }
            $requiredBytes += 1GB
        }
        if ($installerAsset) { $requiredBytes += [int64]$installerAsset.size }
        $driveName = [IO.Path]::GetPathRoot($work).TrimEnd([char[]]":\")
        $drive = Get-PSDrive -Name $driveName
        if ($drive.Free -lt $requiredBytes) {
            throw "Not enough free disk space. Required: $requiredBytes bytes; free: $($drive.Free) bytes."
        }

        if ($reuseCorpus) {
            Write-Host "Corpus $($manifest.generation_id) already installed and verified; skipping corpus download."
        } else {
            $volumeIndex = 0
            $volumeCount = @($manifest.volumes).Count
            foreach ($volume in $manifest.volumes) {
                $volumeIndex += 1
                if (-not $assets.ContainsKey($volume.asset)) { throw "Missing release asset: $($volume.asset)" }
                $archive = Join-Path $cache ([string]$volume.asset)
                if ($cachedVolumes.ContainsKey([string]$volume.asset)) {
                    Write-Host "[$volumeIndex/$volumeCount] Reusing verified download $($volume.asset)..."
                } else {
                    $partial = "$archive.download"
                    if (Test-CachedVolume -Path $partial -Volume $volume) {
                        Write-Host "[$volumeIndex/$volumeCount] Recovering completed download $($volume.asset)..."
                    } else {
                        if (
                            (Test-Path -LiteralPath $partial) -and
                            (Get-Item -LiteralPath $partial).Length -ge [int64]$volume.size_bytes
                        ) {
                            Remove-Item -LiteralPath $partial -Force
                        }
                        Write-Host "[$volumeIndex/$volumeCount] Downloading $($volume.asset)..."
                        Invoke-VerifiedDownload `
                            -Uri $assets[$volume.asset] `
                            -Destination $partial `
                            -Label ([string]$volume.asset)
                    }
                    Write-Host "[$volumeIndex/$volumeCount] Verifying $($volume.asset)..."
                    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $partial).Hash.ToLowerInvariant()
                    if ($actual -cne $volume.sha256) {
                        Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
                        throw "SHA-256 mismatch for $($volume.asset)"
                    }
                    Move-Item -LiteralPath $partial -Destination $archive
                }
                Write-Host "[$volumeIndex/$volumeCount] Extracting $($volume.asset)..."
                Expand-Archive -LiteralPath $archive -DestinationPath $stage -Force
            }

            Write-Host "Reconstructing large corpus indexes..."
            Restore-CorpusParts -Stage $stage -Files $manifest.files

            Write-Host "Verifying the complete corpus..."
            foreach ($file in $manifest.files) {
                $null = Get-CorpusRelativePath -Path ([string]$file.path)
                $candidate = Join-Path $stage ($file.path -replace '/', [IO.Path]::DirectorySeparatorChar)
                if (-not (Test-PlainFile -Path $candidate)) { throw "Missing corpus file: $($file.path)" }
                if ((Get-Item -LiteralPath $candidate).Length -ne $file.size_bytes) {
                    throw "Size mismatch: $($file.path)"
                }
                $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $candidate).Hash.ToLowerInvariant()
                if ($actual -cne $file.sha256) { throw "SHA-256 mismatch: $($file.path)" }
            }

            $incoming = Join-Path $stage "libase-store"
            New-Item -ItemType Directory -Path $appData -Force | Out-Null
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
            $installedNewCorpus = $true
            Write-Host "Corpus $($manifest.generation_id) installed."
            Remove-WorkDirectory -Path $cache
        }

        if ($installerAsset) {
            $installer = Join-Path $work $installerAsset.name
            Write-Host "Downloading the Spot64 application..."
            Invoke-VerifiedDownload `
                -Uri $installerAsset.browser_download_url `
                -Destination $installer `
                -Label "Spot64 application"
            if ($assets.ContainsKey("SHA256SUMS.txt")) {
                $sumsPath = Join-Path $work "SHA256SUMS.txt"
                Invoke-VerifiedDownload `
                    -Uri $assets["SHA256SUMS.txt"] `
                    -Destination $sumsPath `
                    -Label "application checksums"
                $line = Get-Content $sumsPath |
                    Where-Object { $_ -match ("  " + [regex]::Escape($installerAsset.name) + "$") } |
                    Select-Object -First 1
                if (-not $line) { throw "Installer checksum is absent from SHA256SUMS.txt." }
                $expectedInstallerHash = ($line -split '\s+')[0].ToLowerInvariant()
                $actualInstallerHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $installer).Hash.ToLowerInvariant()
                if ($actualInstallerHash -cne $expectedInstallerHash) { throw "Installer SHA-256 mismatch." }
            }
            if ($SilentApplicationInstall) {
                $installerProcess = Start-Process `
                    -FilePath $installer `
                    -ArgumentList "/S" `
                    -Wait `
                    -PassThru
            } else {
                $installerProcess = Start-Process -FilePath $installer -Wait -PassThru
            }
            if ($installerProcess.ExitCode -ne 0) {
                throw "The Spot64 application installer exited with status $($installerProcess.ExitCode)."
            }
            $application = Join-Path $env:LOCALAPPDATA "Libase\desktop.exe"
            if (-not (Test-PlainFile -Path $application)) {
                throw "The Spot64 application installer completed but its executable is missing: $application"
            }
        }

        if ($installedNewCorpus -and $backup) {
            try {
                Invoke-PrimaryDatabaseRebase -AppData $appData -Repository $target
            } catch {
                Write-Warning "Restoring the previous corpus because migration did not complete."
                if (Test-Path -LiteralPath $target) {
                    Remove-Item -LiteralPath $target -Recurse -Force
                }
                Move-Item -LiteralPath $backup -Destination $target
                $backup = $null
                throw
            }
        }
        if ($backup -and (Test-Path -LiteralPath $backup)) {
            Remove-WorkDirectory -Path $backup
            $backup = $null
        }

        if (-not $SkipApplicationInstall -and -not $SkipApplicationLaunch) {
            Write-Host "Starting Spot64..."
            Start-Process -FilePath $application
        }
    } catch {
        if ($backup -and (Test-Path -LiteralPath $backup) -and $target) {
            Write-Warning "Restoring the previous corpus after an incomplete installation."
            if (Test-Path -LiteralPath $target) {
                Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
            }
            if (-not (Test-Path -LiteralPath $target)) {
                Move-Item -LiteralPath $backup -Destination $target
                $backup = $null
            }
        }
        throw
    } finally {
        Remove-WorkDirectory -Path $work
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    Invoke-Spot64BetaInstaller `
        -Repository $Repository `
        -Tag $Tag `
        -SkipApplicationInstall:$SkipApplicationInstall `
        -SkipApplicationLaunch:$SkipApplicationLaunch `
        -SilentApplicationInstall:$SilentApplicationInstall
}
