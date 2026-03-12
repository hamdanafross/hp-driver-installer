# HP OEM Driver Installer Bootstrapper (Windows 11)
# Downloads config.json from your GitHub repo, then downloads and launches HP's official tool.

$RepoRawBase = "https://raw.githubusercontent.com/hamdanafross/hp-driver-installer/main"

function Require-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "Need Administrator privileges. Re-launching elevated..."
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$($MyInvocation.MyCommand.Definition)`"" -Verb RunAs
        exit
    }
}

function Get-SystemInfo {
    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    return [PSCustomObject]@{
        Manufacturer = ($cs.Manufacturer).Trim()
        Model        = ($cs.Model).Trim()
        Serial       = ($bios.SerialNumber).Trim()
    }
}

function Ask-YesNo($prompt) {
    while ($true) {
        $ans = Read-Host "$prompt (Y/N)"
        switch ($ans.ToUpper()) {
            "Y" { return $true }
            "N" { return $false }
            default { Write-Host "Please enter Y or N." }
        }
    }
}

function Download-File($url, $outFile) {
    Write-Host "Downloading:"
    Write-Host "  $url"
    Invoke-WebRequest -Uri $url -OutFile $outFile
}

# --- Start ---
Require-Admin

$info = Get-SystemInfo
Write-Host ""
Write-Host "Detected system:"
Write-Host "  Manufacturer: $($info.Manufacturer)"
Write-Host "  Model:        $($info.Model)"
Write-Host "  Serial:       $($info.Serial)"
Write-Host ""

$manu = $info.Manufacturer.ToLower()
if (-not ($manu -match "hp" -or $manu -match "hewlett")) {
    Write-Host "This script is HP-only. Your manufacturer is: $($info.Manufacturer)"
    if (Ask-YesNo "Open HP drivers website anyway?") {
        Start-Process "https://support.hp.com/drivers"
    }
    exit 1
}

# Fetch config.json from GitHub
$downloadDir = Join-Path $env:TEMP "hp-oem-driver-installer"
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

$configUrl  = "$RepoRawBase/config.json"
$configPath = Join-Path $downloadDir "config.json"

try {
    Download-File -url $configUrl -outFile $configPath
} catch {
    Write-Host "Failed to download config.json from: $configUrl"
    Write-Host "Check that your repo is public and the URL is correct."
    Write-Host $_
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$url = $config.hpSupportAssistant.downloadUrl

if ([string]::IsNullOrWhiteSpace($url) -or $url -like "*PASTE_OFFICIAL_HP_URL_HERE*") {
    Write-Host "config.json has no HP downloadUrl set."
    Write-Host "Fix:"
    Write-Host "1) Open https://support.hp.com/"
    Write-Host "2) Find the official HP Support Assistant download link"
    Write-Host "3) Paste it into config.json and commit to GitHub"
    if (Ask-YesNo "Open HP Support page now?") {
        Start-Process "https://support.hp.com/"
    }
    exit 1
}

Write-Host "Tool to install: $($config.hpSupportAssistant.name)"
Write-Host ""

if (-not (Ask-YesNo "Download and run the official installer now?")) {
    Write-Host "Cancelled."
    exit 0
}

$installerPath = Join-Path $downloadDir "HP_Support_Assistant_Installer.exe"

try {
    Download-File -url $url -outFile $installerPath
} catch {
    Write-Host "Failed to download installer from: $url"
    Write-Host $_
    exit 1
}

Write-Host "Launching installer..."
Start-Process -FilePath $installerPath -Wait

Write-Host ""
Write-Host "Next steps:"
Write-Host "1) Open HP Support Assistant"
Write-Host "2) Go to Updates / Drivers"
Write-Host "3) Install recommended updates"
Write-Host ""
Write-Host "Done."
