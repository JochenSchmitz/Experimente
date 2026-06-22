[CmdletBinding()]
param(
    [Parameter()]
    [string]$SapElogRoot = 'C:\Users\schmitz03\OneDrive - FES Frankfurter Entsorgungs- u. Service GmbH\Dokumente - IMM\General\01_Projekte\02_Experimentieren\05_Schlackeoptimierung\07_Daten\SAP-ELOG',

    [Parameter()]
    [string]$DownloadsDirectory = (Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'),

    [Parameter()]
    [string]$RawArchiveName = 'RAW.zip'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DataSets = @(
    [pscustomobject]@{
        SourceFile = '02_Auftragsdaten.csv'
        ZipName    = 'Auftragsdaten.zip'
        Prefix     = '02_Auftragsdaten'
    },
    [pscustomobject]@{
        SourceFile = '03_Waage.csv'
        ZipName    = 'Waage.zip'
        Prefix     = '03_Waage'
    },
    [pscustomobject]@{
        SourceFile = '04_Kippsignale.csv'
        ZipName    = 'Kippsignale.zip'
        Prefix     = '04_Kippsignale'
    }
)

function Assert-ExistingDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Description darf nicht leer sein."
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Description existiert nicht oder ist kein Verzeichnis: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).ProviderPath
}

function Assert-ExistingFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description existiert nicht oder ist keine Datei: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).ProviderPath
}

function Get-DateDirectoryInfos {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootDirectory
    )

    $directories = @(Get-ChildItem -LiteralPath $RootDirectory -Directory)

    if ($directories.Count -eq 0) {
        throw "Unter SAP-ELOG wurden keine datierten Verzeichnisse gefunden: $RootDirectory"
    }

    foreach ($directory in $directories) {
        $dateInfo = Convert-DateDirectoryName -DirectoryName $directory.Name -FullPath $directory.FullName

        [pscustomobject]@{
            Directory = $directory
            Date      = $dateInfo.Date
            DateStamp = $dateInfo.DateStamp
        }
    }
}

function Convert-DateDirectoryName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryName,

        [Parameter(Mandatory = $true)]
        [string]$FullPath
    )

    if ($DirectoryName -match '^\d{8}$') {
        $dateFormat = 'yyyyMMdd'
    }
    elseif ($DirectoryName -match '^\d{4}_\d{2}_\d{2}$') {
        $dateFormat = 'yyyy_MM_dd'
    }
    else {
        throw "Verzeichnisname entspricht nicht dem erwarteten Datumsformat YYYYMMDD oder YYYY_MM_DD: $FullPath"
    }

    try {
        $date = [datetime]::ParseExact(
            $DirectoryName,
            $dateFormat,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    }
    catch {
        throw "Verzeichnisname ist kein gueltiges Datum: $FullPath"
    }

    [pscustomobject]@{
        Date      = $date
        DateStamp = $date.ToString('yyyy_MM_dd', [System.Globalization.CultureInfo]::InvariantCulture)
    }
}

function New-CleanDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }

    New-Item -Path $Path -ItemType Directory -Force | Out-Null
}

function New-ZipFromDirectoryContents {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$DestinationZip
    )

    $files = @(Get-ChildItem -LiteralPath $SourceDirectory -File)

    if ($files.Count -eq 0) {
        throw "Es gibt keine Dateien fuer das ZIP-Archiv: $DestinationZip"
    }

    if (Test-Path -LiteralPath $DestinationZip) {
        Remove-Item -LiteralPath $DestinationZip -Force
    }

    Compress-Archive `
        -LiteralPath $files.FullName `
        -DestinationPath $DestinationZip `
        -CompressionLevel Optimal `
        -Force
}

function Copy-LatestStammdaten {
    param(
        [Parameter(Mandatory = $true)]
        [array]$DateDirectories,

        [Parameter(Mandatory = $true)]
        [string]$RawWorkDirectory
    )

    $latestDirectory = $DateDirectories | Sort-Object -Property Date -Descending | Select-Object -First 1
    $sourceFile = Assert-ExistingFile `
        -Path (Join-Path $latestDirectory.Directory.FullName '01_Stammdaten.csv') `
        -Description 'Neueste Stammdaten-Datei'

    Copy-Item `
        -LiteralPath $sourceFile `
        -Destination (Join-Path $RawWorkDirectory '01_Stammdaten.csv') `
        -Force
}

function New-DataSetZip {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$DataSet,

        [Parameter(Mandatory = $true)]
        [array]$DateDirectories,

        [Parameter(Mandatory = $true)]
        [string]$WorkDirectory,

        [Parameter(Mandatory = $true)]
        [string]$RawWorkDirectory
    )

    $dataSetWorkDirectory = Join-Path $WorkDirectory $DataSet.Prefix
    New-CleanDirectory -Path $dataSetWorkDirectory

    foreach ($dateDirectory in ($DateDirectories | Sort-Object -Property Date)) {
        $sourceFile = Assert-ExistingFile `
            -Path (Join-Path $dateDirectory.Directory.FullName $DataSet.SourceFile) `
            -Description "$($DataSet.SourceFile) fuer $($dateDirectory.DateStamp)"

        $targetFileName = '{0}_{1}.csv' -f $DataSet.Prefix, $dateDirectory.DateStamp

        Copy-Item `
            -LiteralPath $sourceFile `
            -Destination (Join-Path $dataSetWorkDirectory $targetFileName) `
            -Force
    }

    New-ZipFromDirectoryContents `
        -SourceDirectory $dataSetWorkDirectory `
        -DestinationZip (Join-Path $RawWorkDirectory $DataSet.ZipName)
}

function Invoke-SapElogRawExport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SapElogRoot,

        [Parameter(Mandatory = $true)]
        [string]$DownloadsDirectory,

        [Parameter(Mandatory = $true)]
        [string]$RawArchiveName
    )

    if ([System.IO.Path]::GetExtension($RawArchiveName) -ne '.zip') {
        throw "RawArchiveName muss auf .zip enden: $RawArchiveName"
    }

    $sapElogDirectory = Assert-ExistingDirectory -Path $SapElogRoot -Description 'SAP-ELOG-Verzeichnis'

    if (-not (Test-Path -LiteralPath $DownloadsDirectory -PathType Container)) {
        New-Item -Path $DownloadsDirectory -ItemType Directory -Force | Out-Null
    }

    $downloadDirectory = Assert-ExistingDirectory -Path $DownloadsDirectory -Description 'Downloads-Verzeichnis'
    $dateDirectories = @(Get-DateDirectoryInfos -RootDirectory $sapElogDirectory)
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('sap-elog-raw-' + [guid]::NewGuid().ToString('N'))
    $rawWorkDirectory = Join-Path $tempRoot 'RAW'

    try {
        New-CleanDirectory -Path $rawWorkDirectory

        Copy-LatestStammdaten `
            -DateDirectories $dateDirectories `
            -RawWorkDirectory $rawWorkDirectory

        foreach ($dataSet in $DataSets) {
            New-DataSetZip `
                -DataSet $dataSet `
                -DateDirectories $dateDirectories `
                -WorkDirectory $tempRoot `
                -RawWorkDirectory $rawWorkDirectory
        }

        $rawArchive = Join-Path $downloadDirectory $RawArchiveName
        New-ZipFromDirectoryContents `
            -SourceDirectory $rawWorkDirectory `
            -DestinationZip $rawArchive

        Write-Output "RAW-Archiv erstellt: $rawArchive"
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

try {
    Invoke-SapElogRawExport `
        -SapElogRoot $SapElogRoot `
        -DownloadsDirectory $DownloadsDirectory `
        -RawArchiveName $RawArchiveName
}
catch {
    [Console]::Error.WriteLine(('Fehler: {0}' -f $_.Exception.Message))
    $global:LASTEXITCODE = 1
    $host.SetShouldExit(1)
    return
}
