[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Force,
    [switch]$Full,
    [switch]$Repair,
    [switch]$Yes,
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
$Repo = 'luckyz-z/luckyz-christmas-pack'
$InstallDir = Join-Path $env:LOCALAPPDATA 'Luckyz-Christmas'
$StatePath = Join-Path $InstallDir 'state.json'

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

function ConvertTo-Version($text) {
    $match = [regex]::Match("$text", '\d+(\.\d+){0,2}')
    if (-not $match.Success) { return [version]'0.0.0' }
    $value = $match.Value
    while ($value.Split('.').Count -lt 3) { $value += '.0' }
    return [version]$value
}

function Get-LatestVersion {
    try { return (Invoke-WebRequest "https://raw.githubusercontent.com/$Repo/$Branch/VERSION" -UseBasicParsing -Headers @{ 'Cache-Control' = 'no-cache' }).Content.Trim() }
    catch { return $null }
}

function Get-Package {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('luckyz-update-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $temp | Out-Null
    $zip = Join-Path $temp 'pack.zip'
    Invoke-WebRequest "https://github.com/$Repo/archive/refs/heads/$Branch.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath $temp -Force
    $root = Get-ChildItem $temp -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'install.ps1') } | Select-Object -First 1
    if (-not $root -or -not (Test-Path (Join-Path $root.FullName 'assets'))) { throw 'The download did not look like the pack.' }
    return [pscustomobject]@{ Temp = $temp; Root = $root.FullName }
}

function Show-Menu($behind, $latest, $failedParts) {
    $note = ''
    if ($behind) { $note = "  (new version $latest is available)" }
    elseif ($failedParts) { $note = "  (will retry: $($failedParts -join ', '))" }
    Write-Host ''
    Say '  What would you like to do?' Cyan
    Say "   1  Update what I have installed$note" Green
    Say '   2  Full install: pick which parts to add or change' Green
    Say '   3  Repair: reinstall everything I have, even if it is up to date' Green
    Say '   Q  Quit' DarkGray
    Write-Host '  Choose [1]: ' -NoNewline -ForegroundColor Yellow
    $answer = (Read-Host).Trim().ToLower()
    switch ($answer) {
        '2' { return 'full' }
        '3' { return 'repair' }
        'q' { return 'quit' }
        default { return 'update' }
    }
}

$hasState = Test-Path $StatePath
$state = if ($hasState) { Get-Content $StatePath -Raw | ConvertFrom-Json } else { $null }
$installedParts = @()
$failedParts = @()
if ($state) {
    if ($state.PSObject.Properties['installed']) { $installedParts = @($state.installed) | Where-Object { $_ -and $_ -ne 'translucent' } }
    if ($state.PSObject.Properties['failed']) { $failedParts = @($state.failed) | Where-Object { $_ } }
}
$current = ConvertTo-Version $(if ($state -and $state.PSObject.Properties['version']) { $state.version } else { '0' })

$latestText = Get-LatestVersion
if (-not $latestText) {
    Say 'Could not reach GitHub. Check your internet connection and try again.' Red
    return
}
$latest = ConvertTo-Version $latestText
$behind = ($latest -gt $current) -or $Force

Say "  Installed version: $current" Gray
Say "  Latest version:    $latest" Gray

if ($Check) {
    if ($latest -gt $current) { Say '  An update is available. Run update.ps1 to get it.' Yellow }
    elseif ($failedParts) { Say "  Up to date, but these did not finish last time: $($failedParts -join ', '). Run update.ps1 to retry." Yellow }
    else { Say '  You are up to date.' Green }
    return
}

$mode = 'update'
if ($Full) { $mode = 'full' }
elseif ($Repair) { $mode = 'repair' }
elseif (-not $hasState) { Say '  No install found yet. Starting a full install.' Cyan; $mode = 'full' }
elseif (-not $Yes -and -not $Force) { $mode = Show-Menu $behind $latest $failedParts }

if ($mode -eq 'quit') { return }

$parts = @($installedParts + $failedParts | Select-Object -Unique)
if ($mode -eq 'update') {
    if (-not $behind -and -not $failedParts) {
        Say '  You are up to date. Merry Christmas!' Green
        return
    }
    if (-not $behind) {
        Say "  Some parts did not finish last time: $($failedParts -join ', '). Trying them again." Yellow
        $parts = @($failedParts)
    }
}
if ($mode -ne 'full' -and -not $parts) {
    Say '  Nothing is installed to update. Choose a full install to add parts.' Yellow
    return
}

$package = $null
try {
    Say '  Downloading the latest version...' Cyan
    $package = Get-Package
    $installer = Join-Path $package.Root 'install.ps1'
    if ($mode -eq 'full') {
        Say '  Starting the full install...' Cyan
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer
    }
    else {
        $verb = if ($mode -eq 'repair') { 'Repairing' } else { 'Updating' }
        Say "  ${verb}: $($parts -join ', ')" Cyan
        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer, '-Update', '-Only', ($parts -join ','))
        if ($mode -eq 'repair') { $arguments += '-Repair' }
        & powershell.exe @arguments
    }
    if ($LASTEXITCODE -eq 0) { Say '  All done. Some apps (Spotify, Discord, VS Code) may need a restart to show the changes.' Green }
    else { Say '  Finished, but some parts did not complete. See the messages above, then run update.ps1 again.' Yellow }
}
catch {
    Say "  The update did not finish: $($_.Exception.Message)" Red
    Say '  Nothing was removed. You can run update.ps1 again at any time.' Gray
}
finally {
    if ($package) { Remove-Item $package.Temp -Recurse -Force -ErrorAction SilentlyContinue }
}
