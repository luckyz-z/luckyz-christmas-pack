[CmdletBinding()]
param([switch]$Yes)

$ErrorActionPreference = 'Continue'
$InstallDir = Join-Path $env:LOCALAPPDATA 'Luckyz-Christmas'
$StatePath = Join-Path $InstallDir 'state.json'
$StartupDir = [Environment]::GetFolderPath('Startup')
$Utf8 = New-Object System.Text.UTF8Encoding $false

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

function Invoke-Quiet {
    $ErrorActionPreference = 'Continue'
    $program, $rest = $args
    & $program @rest 2>&1 | Out-Null
}

function Ask($question) {
    if ($Yes) { return $true }
    $answer = Read-Host "$question [Y/n]"
    return [string]::IsNullOrWhiteSpace($answer) -or $answer.Trim().ToLower().StartsWith('y')
}

function Read-Jsonc($path) {
    $text = Get-Content $path -Raw
    $text = [regex]::Replace($text, '(?m)^\s*//.*$', '')
    $text = [regex]::Replace($text, '(?s)/\*.*?\*/', '')
    $text = [regex]::Replace($text, ',(\s*[}\]])', '$1')
    return $text | ConvertFrom-Json
}

function Write-Json($path, $object) {
    [IO.File]::WriteAllText($path, ($object | ConvertTo-Json -Depth 32), $Utf8)
}

function Remove-Autostart($label) {
    Remove-Item (Join-Path $StartupDir "Luckyz Christmas - $label.lnk") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $InstallDir "autostart-$label.vbs") -Force -ErrorAction SilentlyContinue
}

function Stop-Matching($pattern) {
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match $pattern } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

if (-not (Test-Path $StatePath)) { Say 'Nothing to uninstall: no Luckyz Christmas install was found.' Yellow; return }
$state = Get-Content $StatePath -Raw | ConvertFrom-Json
$installed = @(); if ($state.PSObject.Properties['installed']) { $installed = @($state.installed) }
if (-not (Ask "Remove: $($installed -join ', ')?")) { return }

if ($installed -contains 'taskbar') { Stop-Matching 'taskbar-decor'; Remove-Autostart 'Taskbar Lights'; Say 'Removed taskbar lights.' Green }
if ($installed -contains 'widget') { Stop-Matching 'nowplaying-widget'; Remove-Autostart 'Now Playing Widget'; Say 'Removed the widget.' Green }
if ($installed -contains 'icue') { Stop-Matching 'christmas_lights'; Remove-Autostart 'iCUE Lighting'; Say 'Removed iCUE lighting.' Green }

if ($installed -contains 'terminal' -and $state.PSObject.Properties['terminalPaths']) {
    $guids = '{c4a15731-2b6e-4d1f-9a0e-5e1d5a7c0c02}', '{c4a15731-2b6e-4d1f-9a0e-5e1d5a7c0c01}'
    foreach ($path in @($state.terminalPaths)) {
        if (-not (Test-Path $path)) { continue }
        try {
            $settings = Read-Jsonc $path
            if ($settings.PSObject.Properties['schemes']) { $settings.schemes = @($settings.schemes | Where-Object { $_.name -ne 'Luckyz Christmas' }) }
            if ($settings.profiles -is [array]) { $settings.profiles = @($settings.profiles | Where-Object { $_.guid -notin $guids }) }
            else { $settings.profiles.list = @($settings.profiles.list | Where-Object { $_.guid -notin $guids }) }
            if ($settings.PSObject.Properties['defaultProfile'] -and $settings.defaultProfile -in $guids) { $settings.PSObject.Properties.Remove('defaultProfile') }
            Write-Json $path $settings
        }
        catch { Say "Could not clean $path. A backup is next to it as settings.json.luckyz-backup." Yellow }
    }
    Say 'Removed the Terminal profiles and color scheme.' Green
}

if ($installed -contains 'translucent' -and (Get-Command winget -ErrorAction SilentlyContinue)) {
    if (Ask 'Also uninstall TranslucentTB?') { winget uninstall --id CharlesMilette.TranslucentTB --exact | Out-Null; Say 'Removed TranslucentTB.' Green }
}

if ($installed -contains 'vscode') {
    foreach ($name in 'code', 'codium') {
        $cli = Get-Command $name -ErrorAction SilentlyContinue
        if (-not $cli -and $name -eq 'code') {
            $local = Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'
            if (Test-Path $local) { $cli = [pscustomobject]@{ Source = $local } }
        }
        if ($cli) { Invoke-Quiet $cli.Source --uninstall-extension luckyz.christmas-theme }
    }
    foreach ($data in 'Code', 'VSCodium') {
        $path = Join-Path $env:APPDATA "$data\User\settings.json"
        if (-not (Test-Path $path)) { continue }
        try {
            $settings = Read-Jsonc $path
            foreach ($key in 'workbench.colorTheme', 'workbench.iconTheme') {
                if ($settings.PSObject.Properties[$key] -and $settings.$key -in 'Luckyz Christmas', 'luckyz-christmas-icons') { $settings.PSObject.Properties.Remove($key) }
            }
            Write-Json $path $settings
        }
        catch { }
    }
    Say 'Removed the VS Code theme and icons.' Green
}

if ($installed -contains 'spotify') {
    $sp = (Get-Command spicetify -ErrorAction SilentlyContinue).Source
    if (-not $sp) { $sp = Join-Path $env:LOCALAPPDATA 'spicetify\spicetify.exe' }
    if (Test-Path $sp) {
        $prev = $state.spicetifyPrevious
        $theme = if ($prev -and $prev.theme) { $prev.theme } else { 'SpicetifyDefault' }
        $config = Split-Path (& $sp -c)
        & $sp config current_theme $theme color_scheme $(if ($prev) { $prev.scheme } else { '' }) | Out-Null
        & $sp config extensions luckyz-snow.js- | Out-Null
        Remove-Item (Join-Path $config 'Themes\luckyz-christmas') -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $config 'Extensions\luckyz-snow.js') -Force -ErrorAction SilentlyContinue
        Get-Process Spotify -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep 2
        Invoke-Quiet $sp apply
        Say 'Restored your previous Spotify theme.' Green
    }
}

if ($installed -contains 'discord') {
    $css = Join-Path $env:APPDATA 'Vencord\settings\quickCss.css'
    $backup = "$css.luckyz-backup"
    if (Test-Path $backup) { Move-Item $backup $css -Force } else { [IO.File]::WriteAllText($css, '', $Utf8) }
    Say 'Removed the Discord theme. Vencord itself was left installed; use its installer to remove it.' Green
}

Remove-Item $StatePath -Force -ErrorAction SilentlyContinue
Start-Process cmd.exe -ArgumentList '/c', "timeout /t 3 /nobreak >nul & rmdir /s /q `"$InstallDir`"" -WindowStyle Hidden
Say 'Done. Everything the pack added has been removed.' Cyan
