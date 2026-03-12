# HP Driver Installer (Windows 11)

This downloads and launches HP's official tool (HP Support Assistant), which then installs OEM drivers.

## Run (PowerShell)
Open Windows Terminal (PowerShell) and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
irm https://raw.githubusercontent.com/hamdanafross/hp-driver-installer/main/install.ps1 | iex
```

## Notes
- Requires Administrator privileges (UAC prompt).
- You must set the official HP Support Assistant download URL in `config.json`.
