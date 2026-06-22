Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$ScriptPath = Join-Path $RepoRoot 'scripts/Export-SapElogRaw.ps1'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-FileExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Assert-True `
        -Condition (Test-Path -LiteralPath $Path -PathType Leaf) `
        -Message "Datei fehlt: $Path"
}

function New-SapElogDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$DateStamp,

        [Parameter(Mandatory = $true)]
        [string]$Marker
    )

    $directory = Join-Path $Root $DateStamp
    New-Item -Path $directory -ItemType Directory -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $directory '01_Stammdaten.csv') -Value "stammdaten-$Marker" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $directory '02_Auftragsdaten.csv') -Value "auftragsdaten-$Marker" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $directory '03_Waage.csv') -Value "waage-$Marker" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $directory '04_Kippsignale.csv') -Value "kippsignale-$Marker" -Encoding UTF8
}

function Expand-Zip {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Archive,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    New-Item -Path $Destination -ItemType Directory -Force | Out-Null
    Expand-Archive -LiteralPath $Archive -DestinationPath $Destination -Force
}

function Test-ExportsRawArchive {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('sap-elog-test-' + [guid]::NewGuid().ToString('N'))

    try {
        $sapElogRoot = Join-Path $tempRoot 'SAP-ELOG'
        $downloads = Join-Path $tempRoot 'Downloads'
        New-Item -Path $sapElogRoot -ItemType Directory -Force | Out-Null
        New-Item -Path $downloads -ItemType Directory -Force | Out-Null

        New-SapElogDirectory -Root $sapElogRoot -DateStamp '2024_01_02' -Marker 'old'
        New-SapElogDirectory -Root $sapElogRoot -DateStamp '20240103' -Marker 'new'

        & $ScriptPath `
            -SapElogRoot $sapElogRoot `
            -DownloadsDirectory $downloads `
            -RawArchiveName 'RAW.zip' | Out-Null

        $rawArchive = Join-Path $downloads 'RAW.zip'
        Assert-FileExists -Path $rawArchive

        $rawExpanded = Join-Path $tempRoot 'RAW-expanded'
        Expand-Zip -Archive $rawArchive -Destination $rawExpanded

        Assert-FileExists -Path (Join-Path $rawExpanded '01_Stammdaten.csv')
        Assert-True `
            -Condition ((Get-Content -LiteralPath (Join-Path $rawExpanded '01_Stammdaten.csv') -Raw).Contains('stammdaten-new')) `
            -Message 'Die Stammdaten wurden nicht aus dem neuesten Verzeichnis uebernommen.'

        $expectedArchives = @(
            [pscustomobject]@{
                Archive = 'Auftragsdaten.zip'
                Files   = @('02_Auftragsdaten_2024_01_02.csv', '02_Auftragsdaten_2024_01_03.csv')
            },
            [pscustomobject]@{
                Archive = 'Waage.zip'
                Files   = @('03_Waage_2024_01_02.csv', '03_Waage_2024_01_03.csv')
            },
            [pscustomobject]@{
                Archive = 'Kippsignale.zip'
                Files   = @('04_Kippsignale_2024_01_02.csv', '04_Kippsignale_2024_01_03.csv')
            }
        )

        foreach ($expectedArchive in $expectedArchives) {
            $archivePath = Join-Path $rawExpanded $expectedArchive.Archive
            Assert-FileExists -Path $archivePath

            $expandedArchive = Join-Path $tempRoot ($expectedArchive.Archive + '-expanded')
            Expand-Zip -Archive $archivePath -Destination $expandedArchive

            foreach ($expectedFile in $expectedArchive.Files) {
                Assert-FileExists -Path (Join-Path $expandedArchive $expectedFile)
            }
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

function Test-FailsForInvalidDirectoryName {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('sap-elog-test-' + [guid]::NewGuid().ToString('N'))

    try {
        $sapElogRoot = Join-Path $tempRoot 'SAP-ELOG'
        $downloads = Join-Path $tempRoot 'Downloads'
        New-Item -Path (Join-Path $sapElogRoot 'kein-datum') -ItemType Directory -Force | Out-Null

        $powerShellExecutable = (Get-Process -Id $PID).Path
        $stdoutFile = Join-Path $tempRoot 'stdout.txt'
        $stderrFile = Join-Path $tempRoot 'stderr.txt'

        & $powerShellExecutable `
            -NoProfile `
            -File $ScriptPath `
            -SapElogRoot $sapElogRoot `
            -DownloadsDirectory $downloads `
            -RawArchiveName 'RAW.zip' 1>$stdoutFile 2>$stderrFile

        Assert-True -Condition ($LASTEXITCODE -ne 0) -Message 'Ungueltige Verzeichnisnamen muessen fehlschlagen.'

        $stderr = Get-Content -LiteralPath $stderrFile -Raw
        Assert-True `
            -Condition ($stderr -match 'YYYY_MM_DD') `
            -Message 'Der Fehler fuer ungueltige Verzeichnisnamen ist nicht eindeutig.'
        Assert-True `
            -Condition ($stderr -match 'YYYYMMDD') `
            -Message 'Der Fehler nennt das kompakte Datumsformat YYYYMMDD nicht.'
        Assert-True `
            -Condition ($stderr -notmatch 'CategoryInfo') `
            -Message 'Fehlerausgaben sollen keinen PowerShell-Stacktrace enthalten.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

Test-ExportsRawArchive
Test-FailsForInvalidDirectoryName

Write-Host 'Alle PowerShell-Tests sind gruen.'
