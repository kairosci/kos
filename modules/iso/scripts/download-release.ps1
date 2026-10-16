param(
    [string]$Tag
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ($PSVersionTable.PSVersion.Major -lt 6) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

$repository = 'kairosci/os'
$apiBase = "https://api.github.com/repos/$repository/releases"
$headers = @{
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'os-iso-downloader'
}

if ([string]::IsNullOrWhiteSpace($Tag)) {
    $releaseUri = "$apiBase/latest"
} else {
    if ($Tag -notmatch '^v[0-9]+\.[0-9]+(-rc\.[1-9][0-9]*)?$') {
        throw 'Tag must use the vX.Y or vX.Y-rc.N format.'
    }
    $releaseUri = "$apiBase/tags/$Tag"
}

$release = Invoke-RestMethod -Uri $releaseUri -Headers $headers -Method Get
$releaseTag = [string]$release.tag_name
if ($releaseTag -notmatch '^v[0-9]+\.[0-9]+(-rc\.[1-9][0-9]*)?$') {
    throw "Release has an unsupported tag: $releaseTag"
}

$isoName = "os-$releaseTag.iso"
$checksumName = "$isoName.sha256"
$partPattern = '^' + [regex]::Escape("$isoName.part-") + '([0-9]{2,})$'
$parts = @(
    $release.assets |
        Where-Object { $_.name -match $partPattern } |
        Sort-Object { [int]($_.name -replace '^.*\.part-', '') }
)
if ($parts.Count -eq 0) {
    throw "Release $releaseTag has no ISO parts."
}

$checksumAssets = @($release.assets | Where-Object { $_.name -ceq $checksumName })
if ($checksumAssets.Count -ne 1) {
    throw "Release $releaseTag must contain exactly one $checksumName asset."
}

$outputPath = (Get-Location).Path
$isoPath = Join-Path $outputPath $isoName
$outputChecksumPath = Join-Path $outputPath $checksumName
if ((Test-Path -LiteralPath $isoPath) -or (Test-Path -LiteralPath $outputChecksumPath)) {
    throw "Refusing to overwrite an existing versioned artifact in $outputPath."
}

$workDirectory = Join-Path $outputPath (".os-iso-download-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $workDirectory | Out-Null

function Save-ReleaseAsset {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Path
    )

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $Path -UseBasicParsing
            return
        } catch {
            if (Test-Path -LiteralPath $Path) {
                Remove-Item -LiteralPath $Path -Force
            }
            if ($attempt -eq 3) {
                throw
            }
            Start-Sleep -Seconds ([math]::Pow(2, $attempt))
        }
    }
}

try {
    $expectedPart = 0
    foreach ($part in $parts) {
        if ($part.name -notmatch $partPattern) {
            throw "Invalid ISO part name: $($part.name)"
        }
        $partNumber = [int]$Matches[1]
        if ($partNumber -ne $expectedPart) {
            throw "Expected ISO part $expectedPart but found $partNumber."
        }
        Save-ReleaseAsset -Uri $part.browser_download_url -Path (Join-Path $workDirectory $part.name)
        $expectedPart++
    }

    $checksumPath = Join-Path $workDirectory $checksumName
    Save-ReleaseAsset -Uri $checksumAssets[0].browser_download_url -Path $checksumPath

    $assembledPath = Join-Path $workDirectory $isoName
    $outputStream = [IO.File]::Open($assembledPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        foreach ($part in $parts) {
            $partPath = Join-Path $workDirectory $part.name
            $partStream = [IO.File]::OpenRead($partPath)
            try {
                $partStream.CopyTo($outputStream, 4194304)
            } finally {
                $partStream.Dispose()
            }
        }
    } finally {
        $outputStream.Dispose()
    }

    $checksumLine = Get-Content -LiteralPath $checksumPath -TotalCount 1
    if ($checksumLine -notmatch ('^([0-9a-fA-F]{64})\s+\*?' + [regex]::Escape($isoName) + '$')) {
        throw "Checksum file does not describe $isoName."
    }
    $expectedHash = $Matches[1].ToLowerInvariant()
    $actualHash = (Get-FileHash -LiteralPath $assembledPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -cne $expectedHash) {
        throw "SHA-256 verification failed for $isoName."
    }

    Move-Item -LiteralPath $assembledPath -Destination $isoPath
    Move-Item -LiteralPath $checksumPath -Destination $outputChecksumPath
    Write-Output "Verified $isoName in $outputPath"
} finally {
    if (Test-Path -LiteralPath $workDirectory) {
        Remove-Item -LiteralPath $workDirectory -Recurse -Force
    }
}
