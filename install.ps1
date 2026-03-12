# HP Driver Installer (Windows 11) - HPIA-based
# Uses HP Image Assistant to download/install recommended drivers for the current HP model.

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
    if (Ask-YesNo "Open HP drivers website anyway?") { Start-Process "https://support.hp.com/drivers" }
    exit 1
}

# Work dir
$workDir = Join-Path $env:TEMP "hp-driver-installer"
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

# Fetch config.json from GitHub
$configUrl  = "$RepoRawBase/config.json"
$configPath = Join-Path $workDir "config.json"
Download-File -url $configUrl -outFile $configPath
$config = Get-Content $configPath -Raw | ConvertFrom-Json

if (-not $config.hpImageAssistant -or [string]::IsNullOrWhiteSpace($config.hpImageAssistant.downloadPageUrl)) {
    Write-Host "config.json is missing hpImageAssistant.downloadPageUrl"
    Write-Host "Fix config.json and try again."
    exit 1
}

$hpiaPage = $config.hpImageAssistant.downloadPageUrl

# Where HPIA usually ends up after you run the SoftPaq extractor
$hpiaExe = "C:\SWSetup\HP_Image_Assistant\HPImageAssistant.exe"

Write-Host "Using tool: $($config.hpImageAssistant.name)"
Write-Host "Expected path:"
Write-Host "  $hpiaExe"
Write-Host ""

if (-not (Test-Path $hpiaExe)) {
    Write-Host "HPIA not found yet."
    Write-Host "Opening official HPIA download page:"
    Write-Host "  $hpiaPage"
    Start-Process $hpiaPage

    Write-Host ""
    Write-Host "Please:"
    Write-Host "1) Download the HPIA SoftPaq from that page"
    Write-Host "2) Run it to extract (default is under C:\SWSetup\HP_Image_Assistant)"
    Write-Host "3) Re-run this script"
    exit 0
}

$reportDir  = Join-Path $workDir "reports"
$softpaqDir = Join-Path $workDir "softpaqs"
New-Item -ItemType Directory -Force -Path $reportDir  | Out-Null
New-Item -ItemType Directory -Force -Path $softpaqDir | Out-Null

Write-Host "Analyzing system and listing recommendations..."
Start-Process -FilePath $hpiaExe -ArgumentList "/Operation:Analyze /Action:List /Silent /ReportFolder:$reportDir /SoftpaqDownloadFolder:$softpaqDir" -Wait

Write-Host ""
Write-Host "Report folder:"
Write-Host "  $reportDir"
Write-Host ""

if (-not (Ask-YesNo "Download + install recommended updates now?")) {
    Write-Host "Stopping after analysis."
    exit 0
}

Write-Host "Installing recommended updates..."
Start-Process -FilePath $hpiaExe -ArgumentList "/Operation:Analyze /Action:Install /Silent /ReportFolder:$reportDir /SoftpaqDownloadFolder:$softpaqDir" -Wait

Write-Host ""
Write-Host "Done. You may need to reboot."
Write-Host "Reports:"
Write-Host "  $reportDir"
