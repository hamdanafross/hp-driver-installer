# HP Driver Installer (Windows 11)

A simple PowerShell bootstrapper that uses **HP Image Assistant (HPIA)** (official HP tool) to analyze and optionally install recommended HP drivers/firmware.

## Run (PowerShell)
Open **PowerShell as Administrator** and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
irm https://raw.githubusercontent.com/hamdanafross/hp-driver-installer/main/install.ps1 | iex
```

## What it does
- Detects HP Manufacturer / Model / Serial number automatically.
- If HPIA is missing, opens the official HPIA download page and exits.
- If HPIA is present, runs Analyze + generates a report, then asks permission before installing updates.

## Notes / Safety
- Installing drivers/firmware can require a reboot.
- Uses HP’s official HPIA tool to pick the right updates for your model.
- Run at your own risk; review the report folder before installing if you want maximum safety.
