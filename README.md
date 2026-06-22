# Experimente

## SAP-ELOG RAW-Archiv erstellen

Das PowerShell-Script `scripts/Export-SapElogRaw.ps1` greift standardmaessig auf dieses Verzeichnis zu:

```text
C:\Users\schmitz03\OneDrive - FES Frankfurter Entsorgungs- u. Service GmbH\Dokumente - IMM\General\01_Projekte\02_Experimentieren\05_Schlackeoptimierung\07_Daten\SAP-ELOG
```

Aufruf unter Windows aus dem Repository:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Export-SapElogRaw.ps1
```

Oder mit PowerShell 7:

```powershell
pwsh -File .\scripts\Export-SapElogRaw.ps1
```

Das Script erstellt im Downloads-Verzeichnis standardmaessig `RAW.zip`. Darin liegen:

- `01_Stammdaten.csv` aus dem neuesten Unterverzeichnis unter `SAP-ELOG`
- `Auftragsdaten.zip`
  - enthaelt je datiertem Unterverzeichnis `02_Auftragsdaten_YYYY_MM_DD.csv`
- `Waage.zip`
  - enthaelt je datiertem Unterverzeichnis `03_Waage_YYYY_MM_DD.csv`
- `Kippsignale.zip`
  - enthaelt je datiertem Unterverzeichnis `04_Kippsignale_YYYY_MM_DD.csv`

Die Unterverzeichnisse unter `SAP-ELOG` muessen im Format `YYYY_MM_DD` benannt sein.

Falls der SAP-ELOG-Pfad oder der Ausgabeordner abweicht:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Export-SapElogRaw.ps1 `
  -SapElogRoot "C:\Pfad\zum\SAP-ELOG" `
  -DownloadsDirectory "$env:USERPROFILE\Downloads"
```

Der Name des RAW-Archivs kann ebenfalls gesetzt werden:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Export-SapElogRaw.ps1 -RawArchiveName "RAW.zip"
```

Das Script arbeitet bewusst strikt: Wenn ein erwarteter Ordner, eine erwartete CSV-Datei oder ein datierter Ordnername nicht passt, bricht es mit einer Fehlermeldung ab.

### Erwartete Dateien pro datiertem Unterverzeichnis

Jedes Unterverzeichnis unter `SAP-ELOG` muss diese Dateien enthalten:

- `01_Stammdaten.csv`
- `02_Auftragsdaten.csv`
- `03_Waage.csv`
- `04_Kippsignale.csv`

### Tests

Wenn PowerShell 7 (`pwsh`) verfuegbar ist:

```powershell
pwsh -File .\tests\Test-ExportSapElogRaw.ps1
```
