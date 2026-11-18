[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Force,
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

if (-not (Test-Path $StatePath)) {
    Say 'No Luckyz Christmas Pack install was found. Run install.ps1 first.' Yellow
    return
}

$state = Get-Content $StatePath -Raw | ConvertFrom-Json
$parts = @()
if ($state.PSObject.Properties['installed']) { $parts = @($state.installed) | Where-Object { $_ -and $_ -ne 'translucent' } }
$current = ConvertTo-Version $(if ($state.PSObject.Properties['version']) { $state.version } else { '0' })

try {
    $latestText = (Invoke-WebRequest "https://raw.githubusercontent.com/$Repo/$Branch/VERSION" -UseBasicParsing -Headers @{ 'Cache-Control' = 'no-cache' }).Content.Trim()
}
catch {
    Say 'Could not reach GitHub to check for updates. Check your internet connection and try again.' Red
    return
}
$latest = ConvertTo-Version $latestText

Say "  Installed version: $current" Gray
Say "  Latest version:    $latest" Gray

if ($Check) {
    if ($latest -gt $current) { Say '  An update is available. Run update.ps1 to get it.' Yellow }
    else { Say '  You are up to date.' Green }
    return
}

if ($latest -le $current -and -not $Force) {
    Say '  You are up to date. Merry Christmas!' Green
    return
}

if (-not $parts) {
    Say '  Nothing is installed to update.' Yellow
    return
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('luckyz-update-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $temp | Out-Null
try {
    Say '  Downloading the latest version...' Cyan
    $zip = Join-Path $temp 'pack.zip'
    Invoke-WebRequest "https://github.com/$Repo/archive/refs/heads/$Branch.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath $temp -Force
    $root = Get-ChildItem $temp -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'install.ps1') } | Select-Object -First 1
    if (-not $root -or -not (Test-Path (Join-Path $root.FullName 'assets'))) { throw 'The download did not look like the pack.' }

    Say "  Updating: $($parts -join ', ')" Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root.FullName 'install.ps1') -Update -Only ($parts -join ',')
    Say '  Updated. Some apps (Spotify, Discord, VS Code) may need a restart to show the changes.' Green
}
catch {
    Say "  The update did not finish: $($_.Exception.Message)" Red
    Say '  Nothing was removed. You can run update.ps1 again at any time.' Gray
}
finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
