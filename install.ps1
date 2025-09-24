param (
  [Parameter()]
  [switch]
  $UninstallSpotifyStoreEdition = (Read-Host -Prompt 'Uninstall Spotify Windows Store edition if it exists (Y/N)') -eq 'y',
  [Parameter()]
  [switch]
  $UpdateSpotify,
  [Parameter()]
  [switch]
  $InstallSpicetify
)

# Ignore errors from `Stop-Process`
$PSDefaultParameterValues['Stop-Process:ErrorAction'] = [System.Management.Automation.ActionPreference]::SilentlyContinue

[System.Version] $minimalSupportedSpotifyVersion = '1.2.8.923'

########## Helper Functions ##########

function Get-File {
  param (
    [Parameter(Mandatory)]
    [System.Uri]$Uri,
    [Parameter(Mandatory)]
    [System.IO.FileInfo]$TargetFile,
    [int]$Timeout = 15000
  )

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  
  try {
    Invoke-WebRequest -Uri $Uri -OutFile $TargetFile.FullName -TimeoutSec ($Timeout / 1000) -UseBasicParsing
  }
  catch {
    Write-Error "Download failed for '$($Uri)': $_"
    throw
  }
}

function Stop-SpotifyProcesses {
  param (
    [string]$Context = "Stopping Spotify processes"
  )
  Write-Host "$Context..."
  Get-Process -Name "Spotify*" -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Seconds 2
  $maxWait = 10
  $waited = 0
  while ((Get-Process -Name "Spotify*" -ErrorAction SilentlyContinue) -and ($waited -lt $maxWait)) {
    Start-Sleep -Seconds 1
    $waited++
  }
  Get-Process -Name "Spotify*" -ErrorAction SilentlyContinue | Stop-Process -Force
}

function Test-SpotifyVersion {
  param (
    [Parameter(Mandatory)]
    [System.Version]$MinimalSupportedVersion,
    [Parameter(Mandatory)]
    [System.Version]$TestedVersion
  )
  return ($MinimalSupportedVersion.CompareTo($TestedVersion) -le 0)
}

function Test-BlockTheSpotInjection {
  param (
    [string]$SpotifyDirectory
  )
  $dpapiDll = Join-Path -Path $SpotifyDirectory -ChildPath 'dpapi.dll'
  $configIni = Join-Path -Path $SpotifyDirectory -ChildPath 'config.ini'
  return (Test-Path -LiteralPath $dpapiDll) -and (Test-Path -LiteralPath $configIni)
}

function Start-SpotifyWithRetry {
  param (
    [string]$SpotifyDirectory,
    [string]$SpotifyExecutable,
    [int]$MaxRetries = 3
  )
  for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
    Write-Host "Starting Spotify (Attempt $attempt/$MaxRetries)..." -ForegroundColor Cyan
    Stop-SpotifyProcesses -Context "Preparing for attempt $attempt"
    Start-Process -WorkingDirectory $SpotifyDirectory -FilePath $SpotifyExecutable
    Start-Sleep -Seconds 10 # Allow time for Spotify to load the DLL
    $spotifyProcess = Get-Process -Name "Spotify" -ErrorAction SilentlyContinue
    if ($spotifyProcess) {
      Write-Host "Spotify process started." -ForegroundColor Green
      return $true
    }
  }
  Write-Warning "After $MaxRetries attempts, Spotify process could not be confirmed as running."
  return $false
}

########## Installation Step Functions ##########

function Install-Spotify {
  param(
    [string]$SpotifyDirectory
  )
  Write-Host "`n========================================" -ForegroundColor Blue
  Write-Host " Installing/Updating Spotify" -ForegroundColor Cyan
  Write-Host "========================================" -ForegroundColor Blue
  
  Write-Host 'Downloading the latest Spotify full setup, please wait...'
  $spotifySetupFilePath = Join-Path -Path $PWD -ChildPath 'SpotifyFullSetup.exe'
  try {
    if ([Environment]::Is64BitOperatingSystem) {
      $uri = 'https://download.scdn.co/SpotifyFullSetupX64.exe'
    }
    else {
      $uri = 'https://download.scdn.co/SpotifyFullSetup.exe'
    }
    Get-File -Uri $uri -TargetFile $spotifySetupFilePath
  }
  catch {
    Write-Output $_
    Read-Host 'Press any key to exit...'
    exit
  }
  
  Write-Host 'Running installation...'
  Start-Process -FilePath $spotifySetupFilePath -Wait
  
  while ($null -eq (Get-Process -Name Spotify -ErrorAction SilentlyContinue)) {
    Start-Sleep -Milliseconds 200
  }
  Stop-SpotifyProcesses -Context "Stopping Spotify after installation"
}

function Install-Spicetify {
  param (
    [string]$SpotifyDirectory,
    [string]$SpotifyExecutable
  )
  Write-Host "`n========================================" -ForegroundColor Blue
  Write-Host " Installing Spicetify" -ForegroundColor Cyan
  Write-Host "========================================" -ForegroundColor Blue
  Stop-SpotifyProcesses -Context "Preparing for Spicetify installation"
  Start-Process -WorkingDirectory $SpotifyDirectory -FilePath $SpotifyExecutable -WindowStyle Minimized
  Start-Sleep -Seconds 5
  Stop-SpotifyProcesses -Context "Closing Spotify after initialization for Spicetify"
  
  try {
    Write-Host "Installing/Updating Spicetify CLI..." -ForegroundColor Green
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/spicetify/spicetify-cli/master/install.ps1" | Invoke-Expression
    Write-Host "Installing Spicetify Marketplace..." -ForegroundColor Green
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/spicetify/spicetify-marketplace/main/resources/install.ps1" | Invoke-Expression
    return $true
  }
  catch {
    Write-Warning "Failed to install Spicetify: $($_.Exception.Message)"
    return $false
  }
}

function Install-BlockTheSpotPatch {
  param (
    [string]$SpotifyDirectory,
    [bool]$Is64Bit,
    [string]$WorkingDirectory = $PWD
  )
  Write-Host "`n========================================" -ForegroundColor Blue
  Write-Host " Installing BlockTheSpot" -ForegroundColor Cyan
  Write-Host "========================================" -ForegroundColor Blue
  
  Stop-SpotifyProcesses -Context "Preparing for BlockTheSpot patch"
  
  $elfPath = Join-Path -Path $WorkingDirectory -ChildPath 'chrome_elf.zip'
  try {
    if ($Is64Bit) {
      $uri = 'https://github.com/mrpond/BlockTheSpot/releases/latest/download/chrome_elf.zip'
    }
    else {
      # Use a fixed older version for 32-bit as 'latest' may not support it
      $uri = 'https://github.com/mrpond/BlockTheSpot/releases/download/2023.5.20.80/chrome_elf.zip'
    }
    Get-File -Uri $uri -TargetFile $elfPath
    
    Expand-Archive -Force -LiteralPath $elfPath -DestinationPath $WorkingDirectory
    Remove-Item -LiteralPath $elfPath -Force

    Write-Host 'Patching Spotify...'
    $patchFiles = @(
      Join-Path -Path $WorkingDirectory -ChildPath 'dpapi.dll'
      Join-Path -Path $WorkingDirectory -ChildPath 'config.ini'
    )
    Copy-Item -LiteralPath $patchFiles -Destination $SpotifyDirectory -Force
    Write-Host 'Patching Complete!' -ForegroundColor Green
  }
  catch {
    Write-Error "Failed to download or apply BlockTheSpot patch: $_"
    Read-Host 'Press any key to exit...'
    exit
  }
}

########## Main Installation Logic ##########

Write-Host @'
========================================
Authors: @Nuzair46, @KUTlime, @O-ElAlami
========================================
'@

$spotifyDirectory = Join-Path -Path $env:APPDATA -ChildPath 'Spotify'
$spotifyExecutable = Join-Path -Path $spotifyDirectory -ChildPath 'Spotify.exe'
$spicetifyInstalledSuccessfully = $false

Stop-SpotifyProcesses -Context "Initial Spotify shutdown"

if ($PSVersionTable.PSVersion.Major -ge 7) {
  Import-Module Appx -UseWindowsPowerShell -WarningAction:SilentlyContinue
}

if (Get-AppxPackage -Name SpotifyAB.SpotifyMusic) {
  Write-Host "The Microsoft Store version of Spotify is not supported.`n"
  if ($UninstallSpotifyStoreEdition) {
    Write-Host "Uninstalling Spotify Store version.`n"
    Get-AppxPackage -Name SpotifyAB.SpotifyMusic | Remove-AppxPackage
  }
  else {
    Read-Host "Please uninstall the Store version of Spotify to continue. Press any key to exit..."
    exit
  }
}

Push-Location -LiteralPath $env:TEMP
$tempWorkDir = New-Item -Type Directory -Name "BlockTheSpot-$(Get-Date -UFormat '%Y-%m-%d_%H-%M-%S')"
Set-Location -Path $tempWorkDir.FullName

########## Refined Installation Flow ##########

$spotifyInstalled = Test-Path -LiteralPath $spotifyExecutable
$unsupportedClientVersion = $false
if ($spotifyInstalled) {
  $actualSpotifyClientVersion = (Get-ChildItem -LiteralPath $spotifyExecutable).VersionInfo.ProductVersionRaw
  if (-not (Test-SpotifyVersion -MinimalSupportedVersion $minimalSupportedSpotifyVersion -TestedVersion $actualSpotifyClientVersion)) {
    $unsupportedClientVersion = $true
    Write-Host "Your Spotify version ($actualSpotifyClientVersion) is unsupported. An update is required." -ForegroundColor Yellow
  }
}

if (-not $spotifyInstalled -or $UpdateSpotify -or $unsupportedClientVersion) {
  Install-Spotify -SpotifyDirectory $spotifyDirectory
}
else {
  Write-Host "Spotify is already installed and up to date." -ForegroundColor Green
}

if ($InstallSpicetify) {
  $spicetifyInstalledSuccessfully = Install-Spicetify -SpotifyDirectory $spotifyDirectory -SpotifyExecutable $spotifyExecutable
}

# Always install/re-install BlockTheSpot after other steps
$bytes = [System.IO.File]::ReadAllBytes($spotifyExecutable)
$peHeader = [System.BitConverter]::ToUInt16($bytes[0x3C..0x3D], 0)
$is64Bit = $bytes[$peHeader + 4] -eq 0x64
Install-BlockTheSpotPatch -SpotifyDirectory $spotifyDirectory -Is64Bit $is64Bit -WorkingDirectory $PWD

########## Finalization and Restart ##########

Pop-Location
Remove-Item -LiteralPath $tempWorkDir.FullName -Recurse -Force

Write-Host "`nFinalizing installation and starting Spotify..." -ForegroundColor Cyan
Start-SpotifyWithRetry -SpotifyDirectory $spotifyDirectory -SpotifyExecutable $spotifyExecutable

########## Installation Summary ##########

Write-Host "`n========================================" -ForegroundColor Blue
Write-Host " Installation Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Blue

if (Test-BlockTheSpotInjection -SpotifyDirectory $spotifyDirectory) {
  Write-Host "[OK] BlockTheSpot files are properly installed." -ForegroundColor Green
  if (Get-Process -Name "Spotify" -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Spotify is running with BlockTheSpot active." -ForegroundColor Green
  }
  else {
    Write-Host "[WARNING] Spotify is not currently running. BlockTheSpot will activate on next start." -ForegroundColor Yellow
  }
}
else {
  Write-Host "[ERROR] BlockTheSpot installation failed. Please check antivirus settings and re-run." -ForegroundColor Red
}

if ($InstallSpicetify) {
  if ($spicetifyInstalledSuccessfully) {
    Write-Host "[OK] Spicetify and Marketplace installed successfully." -ForegroundColor Green
  }
  else {
    Write-Host "[ERROR] Spicetify installation failed." -ForegroundColor Red
  }
}

Write-Host "`n[INFO] If ads still appear, restart Spotify manually." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Blue
Write-Host "`nDone." -ForegroundColor Green