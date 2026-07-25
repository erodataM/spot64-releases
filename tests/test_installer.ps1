$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../scripts/install-spot64-beta.ps1")

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function New-ManifestEntry {
    param(
        [Parameter(Mandatory = $true)][string]$AppData,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $candidate = Join-Path $AppData ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
    return [pscustomobject]@{
        path = $RelativePath
        size_bytes = (Get-Item -LiteralPath $candidate).Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $candidate).Hash.ToLowerInvariant()
        volume = "fixture.zip"
    }
}

$temporary = Join-Path ([IO.Path]::GetTempPath()) ("spot64-installer-test-" + [guid]::NewGuid())
try {
    $appData = Join-Path $temporary "app-data"
    $target = Join-Path $appData "libase-store"
    $generationId = "a" * 64
    $generation = Join-Path $target "generations/$generationId"
    New-Item -ItemType Directory -Path $generation -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $target "current.json") -Value (
        @{ currentGenerationId = $generationId } | ConvertTo-Json -Compress
    )
    Set-Content -LiteralPath (Join-Path $generation "manifest.json") -Value '{"visibleGames":3}'
    Set-Content -LiteralPath (Join-Path $generation "manifest.sha256") -Value ("b" * 64)
    Set-Content -LiteralPath (Join-Path $generation "segment.bin") -Value "fixture-segment"

    $paths = @(
        "libase-store/current.json",
        "libase-store/generations/$generationId/manifest.json",
        "libase-store/generations/$generationId/manifest.sha256",
        "libase-store/generations/$generationId/segment.bin"
    )
    $manifest = [pscustomobject]@{
        schema_version = 1
        kind = "spot64-corpus"
        generation_id = $generationId
        position_max_ply = 40
        files = @($paths | ForEach-Object {
            New-ManifestEntry -AppData $appData -RelativePath $_
        })
    }

    Assert-True (Test-InstalledCorpus -Target $target -Manifest $manifest) `
        "A matching installed corpus was not reusable."

    $shortHorizonManifest = [pscustomobject]@{
        generation_id = $generationId
        position_max_ply = 20
        files = $manifest.files
    }
    Assert-True (-not (Test-InstalledCorpus -Target $target -Manifest $shortHorizonManifest)) `
        "A corpus with a position horizon below 40 plies was accepted."

    Set-Content -LiteralPath (Join-Path $generation "manifest.json") -Value '{"visibleGames":4}'
    Assert-True (-not (Test-InstalledCorpus -Target $target -Manifest $manifest)) `
        "A modified metadata anchor was accepted."
    Set-Content -LiteralPath (Join-Path $generation "manifest.json") -Value '{"visibleGames":3}'

    Remove-Item -LiteralPath (Join-Path $generation "segment.bin")
    Assert-True (-not (Test-InstalledCorpus -Target $target -Manifest $manifest)) `
        "An incomplete installed corpus was accepted."
    Set-Content -LiteralPath (Join-Path $generation "segment.bin") -Value "fixture-segment"

    $unsafeManifest = [pscustomobject]@{
        generation_id = $generationId
        files = @($manifest.files) + @([pscustomobject]@{
            path = "libase-store/../escape"
            size_bytes = 0
            sha256 = "0" * 64
        })
    }
    Assert-True (-not (Test-InstalledCorpus -Target $target -Manifest $unsafeManifest)) `
        "An unsafe corpus path was accepted."

    $otherGeneration = [pscustomobject]@{
        generation_id = "c" * 64
        files = $manifest.files
    }
    Assert-True (-not (Test-InstalledCorpus -Target $target -Manifest $otherGeneration)) `
        "A different installed generation was accepted."

    $stage = Join-Path $temporary "split-stage"
    $partsRoot = Join-Path $stage ".spot64-parts"
    $plainRoot = Join-Path $stage "libase-store"
    New-Item -ItemType Directory -Path $partsRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $plainRoot -Force | Out-Null
    Set-Content -NoNewline -LiteralPath (Join-Path $plainRoot "current.json") -Value "plain"
    [IO.File]::WriteAllBytes((Join-Path $partsRoot "part-001"), [Text.Encoding]::UTF8.GetBytes("position-"))
    [IO.File]::WriteAllBytes((Join-Path $partsRoot "part-002"), [Text.Encoding]::UTF8.GetBytes("index"))
    $splitFiles = @(
        [pscustomobject]@{
            path = "libase-store/current.json"
        },
        [pscustomobject]@{
            path = "libase-store/generations/$generationId/position.dir"
            parts = @(
                [pscustomobject]@{
                    path = ".spot64-parts/part-001"
                    offset_bytes = 0
                    size_bytes = 9
                },
                [pscustomobject]@{
                    path = ".spot64-parts/part-002"
                    offset_bytes = 9
                    size_bytes = 5
                }
            )
        }
    )
    Restore-CorpusParts -Stage $stage -Files $splitFiles
    Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $plainRoot "current.json")) -ceq "plain") `
        "An unsplit corpus file was incorrectly reconstructed."
    $restored = Join-Path $stage "libase-store/generations/$generationId/position.dir"
    Assert-True ((Get-Content -Raw -LiteralPath $restored) -ceq "position-index") `
        "Split corpus file was not restored byte-for-byte."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $partsRoot "part-001"))) `
        "Restored corpus parts were not removed."

    $cachedVolume = Join-Path $temporary "cached-volume.zip"
    [IO.File]::WriteAllBytes($cachedVolume, [Text.Encoding]::UTF8.GetBytes("cached"))
    $volume = [pscustomobject]@{
        size_bytes = (Get-Item -LiteralPath $cachedVolume).Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $cachedVolume).Hash.ToLowerInvariant()
    }
    Assert-True (Test-CachedVolume -Path $cachedVolume -Volume $volume) `
        "A valid cached volume was rejected."
    Set-Content -NoNewline -LiteralPath $cachedVolume -Value "broken"
    Assert-True (-not (Test-CachedVolume -Path $cachedVolume -Volume $volume)) `
        "A corrupted cached volume was accepted."

    Write-Host "Spot64 installer tests passed."
} finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}
