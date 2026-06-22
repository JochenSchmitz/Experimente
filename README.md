# Experimente

## SAP-ELOG-Verzeichnis pruefen

Das Script `scripts/access_sap_elog.py` greift standardmaessig auf dieses Verzeichnis zu:

```text
C:\Users\schmitz03\OneDrive - FES Frankfurter Entsorgungs- u. Service GmbH\Dokumente - IMM\General\01_Projekte\02_Experimentieren\05_Schlackeoptimierung\07_Daten\SAP-ELOG
```

Aufruf unter Windows:

```powershell
python scripts\access_sap_elog.py
```

Rekursive Ausgabe:

```powershell
python scripts\access_sap_elog.py --recursive
```

JSON-Ausgabe:

```powershell
python scripts\access_sap_elog.py --json
```

Falls das Verzeichnis auf einem anderen Rechner anders liegt, kann der Pfad explizit gesetzt werden:

```powershell
python scripts\access_sap_elog.py --path "C:\Pfad\zum\SAP-ELOG"
```

Wenn der Pfad nicht existiert, kein Verzeichnis ist oder nicht gelesen werden kann, beendet sich das Script mit einer Fehlermeldung und Exit-Code `1`.
