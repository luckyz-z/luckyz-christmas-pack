[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Force,
    [switch]$Full,
    [switch]$Repair,
    [switch]$Yes,
    [string]$Branch = 'main'
)

$Repo = 'luckyz-z/luckyz-christmas-pack'
$Here = if ($PSScriptRoot) { $PSScriptRoot } else { Join-Path $env:LOCALAPPDATA 'Luckyz-Christmas' }
$Core = Join-Path $Here 'update-core.ps1'

try {
    $fresh = (Invoke-WebRequest "https://raw.githubusercontent.com/$Repo/$Branch/update-core.ps1" -UseBasicParsing -Headers @{ 'Cache-Control' = 'no-cache' }).Content
    if ($fresh -is [byte[]]) { $fresh = [Text.Encoding]::UTF8.GetString($fresh) }
    [void][scriptblock]::Create($fresh)
    if ($fresh -match '\$Repo = ' -and (-not (Test-Path $Core) -or (Get-Content $Core -Raw) -ne $fresh)) {
        [IO.File]::WriteAllText($Core, $fresh, (New-Object System.Text.UTF8Encoding $false))
    }
}
catch { }

if (-not (Test-Path $Core)) {
    Write-Host 'Could not get the updater. Check your internet connection and try again.' -ForegroundColor Red
    return
}

& $Core @PSBoundParameters
