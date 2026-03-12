# HP Driver Installer (Windows 11) - HPIA-based
# Goal: download/install recommended HP drivers/BIOS/software using HP Image Assistant (HPIA)

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

# Fetch config.json from GitHub
$workDir = Join-Path $env:TEMP "hp-driver-installer"
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

$configUrl  = "$RepoRawBase/config.json"
$configPath = Join-Path $workDir "config.json"
Download-File -url $configUrl -outFile $configPath

$config = Get-Content $configPath -Raw | ConvertFrom-Json

if (-not $config.hpImageAssistant -or [string]::IsNullOrWhiteSpace($config.hpImageAssistant.downloadPageUrl)) {
    Write-Host "config.json is missing hpImageAssistant.downloadPageUrl"
    exit 1
}

$hpiaPage = $config.hpImageAssistant.downloadPageUrl
$hpiaExe  = "C:\SWSetup\HP_Image_Assistant\HPImageAssistant.exe"

Write-Host "HPIA expected path (after extraction):"
Write-Host "  $hpiaExe"
Write-Host ""

if (-not (Test-Path $hpiaExe)) {
    Write-Host "HPIA is not installed/extracted yet."
    Write-Host "Opening the official HPIA download page now:"
    Write-Host "  $hpiaPage"
    Start-Process $hpiaPage

    Write-Host ""
    Write-Host "Please:"
    Write-Host "1) Download the HPIA SoftPaq EXE from that page"
    Write-Host "2) Run it (it extracts to C:\SWSetup by default)"
    Write-Host "3) Re-run this script"
    exit 0
}

# Run analysis first and generate a report
$reportDir   = Join-Path $workDir "reports"
$softpaqDir  = Join-Path $workDir "softpaqs"
New-Item -ItemType Directory -Force -Path $reportDir  | Out-Null
New-Item -ItemType Directory -Force -Path $softpaqDir | Out-Null

Write-Host "Running HPIA analysis (silent)..."
Start-Process -FilePath $hpiaExe -ArgumentList "/Operation:Analyze /Action:List /Silent /ReportFolder:$reportDir /SoftpaqDownloadFolder:$softpaqDir" -Wait

Write-Host ""
Write-Host "A recommendations report should now exist under:"
Write-Host "  $reportDir"
Write-Host ""

if (-not (Ask-YesNo "Download + install recommended updates now?")) {
    Write-Host "Stopping after analysis. You can review the report folder."
    exit 0
}

Write-Host "Installing recommended updates (silent). This can take a while..."
# Note: HPIA supports /Operation:Analyze with /Action:Install to download/extract/install. Only auto-installable SoftPaqs install silently.
Start-Process -FilePath $hpiaExe -ArgumentList "/Operation:Analyze /Action:Install /Silent /ReportFolder:$reportDir /SoftpaqDownloadFolder:$softpaqDir" -Wait

Write-Host ""
Write-Host "Done. Check reports here:"
Write-Host "  $reportDir"
Write-Host "You might need to reboot if BIOS/firmware was updated."
