[CmdletBinding()]
param(
    [string[]]$Only,
    [switch]$All,
    [switch]$Yes,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
$Root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$Assets = Join-Path $Root 'assets'
$InstallDir = Join-Path $env:LOCALAPPDATA 'THLA-Christmas'
$StatePath = Join-Path $InstallDir 'state.json'
$StartupDir = [Environment]::GetFolderPath('Startup')
$Utf8 = New-Object System.Text.UTF8Encoding $false

$Components = [ordered]@{
    terminal    = 'Windows Terminal: snow background, Christmas colors, festive PowerShell prompt'
    taskbar     = 'Taskbar lights: string lights and snow drift along the taskbar'
    translucent = 'Transparent taskbar (installs TranslucentTB from the Microsoft Store via winget)'
    widget      = 'Spotify now-playing desktop widget with a candy-cane progress bar'
    vscode      = 'VS Code: Christmas color theme and custom Christmas file icons'
    spotify     = 'Spotify: Christmas theme and snow (installs Spicetify if needed)'
    discord     = 'Discord: Christmas theme (uses Vencord, offers to install it)'
    icue        = 'Corsair iCUE: Christmas lighting for keyboard and RAM'
}

if ($List) {
    $Components.GetEnumerator() | ForEach-Object { '{0,-12} {1}' -f $_.Key, $_.Value }
    return
}

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Title($text) { Write-Host ''; Write-Host "== $text" -ForegroundColor Cyan }

function Ask($question, [bool]$default = $true) {
    if ($Yes) { return $default }
    $hint = if ($default) { 'Y/n' } else { 'y/N' }
    $answer = Read-Host "$question [$hint]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $default }
    return $answer.Trim().ToLower().StartsWith('y')
}

function Get-State {
    if (Test-Path $StatePath) { return Get-Content $StatePath -Raw | ConvertFrom-Json }
    return [pscustomobject]@{}
}

function Save-State($state) {
    New-Item -ItemType Directory $InstallDir -Force | Out-Null
    [IO.File]::WriteAllText($StatePath, ($state | ConvertTo-Json -Depth 10), $Utf8)
}

function Set-StateValue($name, $value) {
    $state = Get-State
    if ($state.PSObject.Properties[$name]) { $state.$name = $value }
    else { $state | Add-Member -NotePropertyName $name -NotePropertyValue $value }
    Save-State $state
}

function Backup-File($path) {
    if (-not (Test-Path $path)) { return }
    $backup = "$path.thla-backup"
    if (-not (Test-Path $backup)) { Copy-Item $path $backup -Force }
}

function Read-Jsonc($path) {
    $text = Get-Content $path -Raw
    $text = [regex]::Replace($text, '(?m)^\s*//.*$', '')
    $text = [regex]::Replace($text, '(?s)/\*.*?\*/', '')
    $text = [regex]::Replace($text, ',(\s*[}\]])', '$1')
    if ([string]::IsNullOrWhiteSpace($text)) { return [pscustomobject]@{} }
    return $text | ConvertFrom-Json
}

function Write-Json($path, $object) {
    [IO.File]::WriteAllText($path, ($object | ConvertTo-Json -Depth 32), $Utf8)
}

function Set-Property($object, $name, $value) {
    if ($object.PSObject.Properties[$name]) { $object.$name = $value }
    else { $object | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

function Copy-Assets($name) {
    $target = Join-Path $InstallDir $name
    New-Item -ItemType Directory $target -Force | Out-Null
    Copy-Item (Join-Path $Assets "$name\*") $target -Recurse -Force
    return $target
}

function New-Autostart($label, $scriptPath, $delaySeconds, $python = $false, $extra = '') {
    $launcher = Join-Path $InstallDir "autostart-$label.vbs"
    if ($python) {
        $command = '""' + $scriptPath.Interpreter + '"" ""' + $scriptPath.Script + '""'
    }
    else {
        $command = 'powershell.exe -STA -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""' + $scriptPath + '"" ' + $extra
    }
    $lines = @("WScript.Sleep $($delaySeconds * 1000)", "CreateObject(""WScript.Shell"").Run ""$command"", 0, False")
    [IO.File]::WriteAllLines($launcher, $lines)
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut((Join-Path $StartupDir "THLA Christmas - $label.lnk"))
    $link.TargetPath = Join-Path $env:windir 'System32\wscript.exe'
    $link.Arguments = "`"$launcher`""
    $link.WindowStyle = 7
    $link.Save()
}

function Start-Hidden($filePath, $arguments) {
    Start-Process -FilePath $filePath -ArgumentList $arguments -WindowStyle Hidden
}

function Install-Terminal {
    $dir = Copy-Assets 'terminal'
    $paths = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    ) | Where-Object { Test-Path $_ }
    if (-not $paths) { Say 'Windows Terminal was not found. Install it from the Microsoft Store and run this again.' Yellow; return $false }

    $gif = Join-Path $dir 'snow.gif'
    $prompt = Join-Path $dir 'christmas-prompt.ps1'
    $makeDefault = Ask 'Make "Christmas PowerShell" your default Terminal profile?' $false
    $scheme = [pscustomobject][ordered]@{
        name = 'THLA Christmas'; background = '#0A1913'; foreground = '#FFF4E0'; cursorColor = '#E7BF5A'; selectionBackground = '#C8323F'
        black = '#10241C'; red = '#E56B73'; green = '#6FCF97'; yellow = '#E7BF5A'; blue = '#8FB8E8'; purple = '#D79AC0'; cyan = '#7FD8C8'; white = '#FFF4E0'
        brightBlack = '#4E6B5C'; brightRed = '#FF8A90'; brightGreen = '#8FE3AE'; brightYellow = '#F5D98A'; brightBlue = '#B5D2F2'
        brightPurple = '#E7BAD6'; brightCyan = '#A8EADF'; brightWhite = '#FFFFFF'
    }
    $profiles = @(
        @{ name = 'Christmas PowerShell'; guid = '{c4a15731-2b6e-4d1f-9a0e-5e1d5a7c0c02}'; commandline = "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -File `"$prompt`"" },
        @{ name = 'Christmas CMD'; guid = '{c4a15731-2b6e-4d1f-9a0e-5e1d5a7c0c01}'; commandline = '%SystemRoot%\System32\cmd.exe' }
    )
    foreach ($path in $paths) {
        try {
            Backup-File $path
            $settings = Read-Jsonc $path
            $schemes = @(); if ($settings.PSObject.Properties['schemes']) { $schemes = @($settings.schemes) }
            $schemes = @($schemes | Where-Object { $_.name -ne 'THLA Christmas' }) + $scheme
            Set-Property $settings 'schemes' $schemes
            $list = if ($settings.profiles -is [array]) { @($settings.profiles) } else { @($settings.profiles.list) }
            foreach ($p in $profiles) {
                $list = @($list | Where-Object { $_.guid -ne $p.guid })
                $entry = [pscustomobject][ordered]@{
                    name = $p.name; guid = $p.guid; commandline = $p.commandline; hidden = $false
                    backgroundImage = $gif; backgroundImageOpacity = 0.85; backgroundImageStretchMode = 'uniformToFill'
                    colorScheme = 'THLA Christmas'
                    font = [pscustomobject][ordered]@{ face = 'Cascadia Mono, Segoe UI Emoji, Segoe UI Symbol'; size = 12 }
                    padding = '12'
                }
                $list = @($entry) + $list
            }
            if ($settings.profiles -is [array]) { $settings.profiles = $list } else { $settings.profiles.list = $list }
            if ($makeDefault) { Set-Property $settings 'defaultProfile' $profiles[0].guid }
            Write-Json $path $settings
            Say "Updated $path" Green
        }
        catch { Say "Could not edit $path ($($_.Exception.Message)). Your file was left untouched." Yellow }
    }
    Set-StateValue 'terminalPaths' @($paths)
    return $true
}

function Install-Taskbar {
    $dir = Copy-Assets 'taskbar'
    $script = Join-Path $dir 'taskbar-decor.ps1'
    if (Ask 'Start the taskbar lights automatically when you sign in?') { New-Autostart 'Taskbar Lights' $script 6 }
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'taskbar-decor' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Hidden 'powershell.exe' "-STA -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
    Say 'Taskbar lights are running.' Green
    return $true
}

function Install-Translucent {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Say 'winget is not available. Get TranslucentTB from the Microsoft Store.' Yellow; return $false }
    winget install --id CharlesMilette.TranslucentTB --exact --accept-package-agreements --accept-source-agreements | Out-Null
    $app = Get-AppxPackage *TranslucentTB* -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $app) { Say 'TranslucentTB did not install.' Yellow; return $false }
    $id = (Get-AppxPackageManifest $app).Package.Applications.Application.Id
    Start-Process explorer.exe "shell:AppsFolder\$($app.PackageFamilyName)!$id"
    Say 'TranslucentTB installed. Right-click its tray icon to pick a style and enable Open at boot.' Green
    return $true
}

function Install-Widget {
    $dir = Copy-Assets 'widget'
    $script = Join-Path $dir 'nowplaying-widget.ps1'
    $corner = 'TopRight'
    if (-not $Yes) {
        $choice = Read-Host 'Which corner for the widget? TopRight, TopLeft, BottomRight, BottomLeft [TopRight]'
        if ($choice -in 'TopRight', 'TopLeft', 'BottomRight', 'BottomLeft') { $corner = $choice }
    }
    if (Ask 'Start the widget automatically when you sign in?') { New-Autostart 'Now Playing Widget' $script 8 $false "-Corner $corner" }
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'nowplaying-widget' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Hidden 'powershell.exe' "-STA -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -Corner $corner"
    Say 'The widget is running. Play something on Spotify to see it.' Green
    return $true
}

function Get-CodeClis {
    $found = @()
    foreach ($name in 'code', 'codium') { $c = Get-Command $name -ErrorAction SilentlyContinue; if ($c) { $found += [pscustomobject]@{ Cli = $c.Source; Data = if ($name -eq 'code') { 'Code' } else { 'VSCodium' } } } }
    $local = Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'
    if ((Test-Path $local) -and -not ($found | Where-Object Data -eq 'Code')) { $found += [pscustomobject]@{ Cli = $local; Data = 'Code' } }
    return $found
}

function Install-VSCode {
    $clis = Get-CodeClis
    if (-not $clis) { Say 'VS Code was not found. Install it from https://code.visualstudio.com and run this again.' Yellow; return $false }
    $vsix = Join-Path $Assets 'vscode\thla-christmas-1.0.0.vsix'
    $apply = Ask 'Switch VS Code to the Christmas color theme and icons now?'
    foreach ($c in $clis) {
        & $c.Cli --install-extension $vsix --force 2>&1 | Out-Null
        Say "Installed the extension for $($c.Data)." Green
        if ($apply) {
            $dir = Join-Path $env:APPDATA "$($c.Data)\User"
            New-Item -ItemType Directory $dir -Force | Out-Null
            $path = Join-Path $dir 'settings.json'
            Backup-File $path
            try {
                $settings = if (Test-Path $path) { Read-Jsonc $path } else { [pscustomobject]@{} }
                Set-Property $settings 'workbench.colorTheme' 'THLA Christmas'
                Set-Property $settings 'workbench.iconTheme' 'thla-christmas-icons'
                Write-Json $path $settings
            }
            catch { Say "Could not edit $path. Pick the theme with Ctrl+K Ctrl+T instead." Yellow }
        }
    }
    Say 'If the theme does not switch by itself, press Ctrl+K Ctrl+T and choose THLA Christmas.' Gray
    return $true
}

function Get-Spicetify {
    $c = Get-Command spicetify -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $local = Join-Path $env:LOCALAPPDATA 'spicetify\spicetify.exe'
    if (Test-Path $local) { return $local }
    return $null
}

function Install-Spotify {
    $spotify = Join-Path $env:APPDATA 'Spotify\Spotify.exe'
    if (-not (Test-Path $spotify)) { Say 'Spotify desktop (the installer from spotify.com, not the Microsoft Store version) was not found.' Yellow; return $false }
    $sp = Get-Spicetify
    if (-not $sp) {
        if (-not (Ask 'Spicetify is needed to theme Spotify. Download and install it from github.com/spicetify/cli?')) { return $false }
        Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/spicetify/cli/main/install.ps1' | Invoke-Expression
        $sp = Get-Spicetify
        if (-not $sp) { Say 'Spicetify did not install.' Yellow; return $false }
    }
    $config = Split-Path (& $sp -c)
    $previous = [pscustomobject]@{
        theme = (& $sp config current_theme)
        scheme = (& $sp config color_scheme)
        extensions = (& $sp config extensions)
    }
    Set-StateValue 'spicetifyPrevious' $previous
    $themeDir = Join-Path $config 'Themes\thla-christmas'
    New-Item -ItemType Directory $themeDir -Force | Out-Null
    Copy-Item (Join-Path $Assets 'spotify\color.ini'), (Join-Path $Assets 'spotify\user.css') $themeDir -Force
    $extDir = Join-Path $config 'Extensions'
    New-Item -ItemType Directory $extDir -Force | Out-Null
    Copy-Item (Join-Path $Assets 'spotify\thla-snow.js') $extDir -Force
    $existing = @(($previous.extensions -split '\|') | Where-Object { $_ -and $_ -ne 'thla-snow.js' })
    & $sp config current_theme thla-christmas color_scheme christmas inject_css 1 replace_colors 1 overwrite_assets 1 | Out-Null
    & $sp config extensions (($existing + 'thla-snow.js') -join '|') | Out-Null
    Get-Process Spotify -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep 2
    & $sp backup apply 2>&1 | Out-Null
    Say 'Spotify is themed. Open Spotify to see it.' Green
    return $true
}

function Get-DiscordBranches {
    @(
        @{ Name = 'stable'; Dir = 'Discord'; Process = 'Discord' },
        @{ Name = 'ptb'; Dir = 'DiscordPTB'; Process = 'DiscordPTB' },
        @{ Name = 'canary'; Dir = 'DiscordCanary'; Process = 'DiscordCanary' }
    ) | Where-Object { Test-Path (Join-Path $env:LOCALAPPDATA $_.Dir) }
}

function Test-VencordPatched($branch) {
    $apps = Get-ChildItem (Join-Path $env:LOCALAPPDATA $branch.Dir) -Directory -Filter 'app-*' -ErrorAction SilentlyContinue
    foreach ($a in $apps) { if (Test-Path (Join-Path $a.FullName 'resources\_app.asar')) { return $true } }
    return $false
}

function Install-Discord {
    $branches = @(Get-DiscordBranches)
    if (-not $branches) { Say 'Discord was not found.' Yellow; return $false }
    $needs = @($branches | Where-Object { -not (Test-VencordPatched $_) })
    if ($needs) {
        $names = ($needs | ForEach-Object { $_.Name }) -join ', '
        Say "Custom Discord themes need Vencord, a third-party client mod. Using client mods may go against Discord's terms; that is your call." Yellow
        if (Ask "Download the official Vencord installer from github.com/Vencord/Installer and patch Discord ($names)? Discord will be closed.") {
            $release = Invoke-RestMethod 'https://api.github.com/repos/Vencord/Installer/releases/latest'
            $asset = $release.assets | Where-Object name -eq 'VencordInstallerCli.exe'
            $tmp = Join-Path ([IO.Path]::GetTempPath()) ('vencord-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory $tmp | Out-Null
            $exe = Join-Path $tmp 'VencordInstallerCli.exe'
            Invoke-WebRequest $asset.browser_download_url -OutFile $exe -UseBasicParsing
            $expected = ($asset.digest -replace '^sha256:', '').ToUpper()
            if ($expected -and (Get-FileHash $exe -Algorithm SHA256).Hash -ne $expected) { Say 'The downloaded installer failed its checksum. Aborting.' Red; return $false }
            foreach ($b in $needs) {
                Get-Process $b.Process -ErrorAction SilentlyContinue | Stop-Process -Force
                Start-Sleep 2
                & $exe -install -branch $b.Name 2>&1 | Out-Null
            }
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    $vencord = Join-Path $env:APPDATA 'Vencord\settings'
    New-Item -ItemType Directory $vencord -Force | Out-Null
    $css = Join-Path $vencord 'quickCss.css'
    Backup-File $css
    Copy-Item (Join-Path $Assets 'discord\thla-christmas.css') $css -Force
    $settingsPath = Join-Path $vencord 'settings.json'
    $settings = if (Test-Path $settingsPath) { Get-Content $settingsPath -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
    Set-Property $settings 'useQuickCss' $true
    Write-Json $settingsPath $settings
    foreach ($b in $branches) {
        $update = Join-Path $env:LOCALAPPDATA "$($b.Dir)\Update.exe"
        if ((Test-Path $update) -and -not (Get-Process $b.Process -ErrorAction SilentlyContinue)) { Start-Process $update -ArgumentList '--processStart', "$($b.Process).exe" }
    }
    Say 'Discord theme installed. Press Ctrl+R in Discord if it does not appear.' Green
    return $true
}

function Install-Icue {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { Say 'Python 3 is needed for the lighting effect. Install it from python.org and run this again.' Yellow; return $false }
    if (-not (Get-Process iCUE -ErrorAction SilentlyContinue)) { Say 'iCUE does not seem to be running. Start it, and turn on Settings > Enable SDK.' Yellow }
    if (-not (Ask 'Install Corsair''s cuesdk Python library from PyPI?')) { return $false }
    & $python.Source -m pip install --user --quiet cuesdk 2>&1 | Out-Null
    $dir = Copy-Assets 'icue'
    $script = Join-Path $dir 'christmas_lights.py'
    $pythonw = Join-Path (Split-Path $python.Source) 'pythonw.exe'
    if (-not (Test-Path $pythonw)) { $pythonw = $python.Source }
    if (Ask 'Start the lighting automatically when you sign in?') { New-Autostart 'iCUE Lighting' @{ Interpreter = $pythonw; Script = $script } 30 $true }
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'christmas_lights' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Hidden $pythonw "`"$script`""
    Say 'Lighting started. In iCUE make sure Settings > Enable SDK is on.' Green
    return $true
}

$selected = @()
if ($All) { $selected = @($Components.Keys) }
elseif ($Only) { $selected = @($Only | ForEach-Object { $_.ToLower() } | Where-Object { $Components.Contains($_) }) }
else {
    Say 'THLA Christmas Pack' Cyan
    Say 'Pick what you want. Everything is optional and every file that gets edited is backed up first.'
    foreach ($key in $Components.Keys) { if (Ask "$($Components[$key])?") { $selected += $key } }
}

if (-not $selected) { Say 'Nothing selected.' Yellow; return }

New-Item -ItemType Directory $InstallDir -Force | Out-Null
Copy-Item (Join-Path $Root 'uninstall.ps1') $InstallDir -Force -ErrorAction SilentlyContinue

$results = [ordered]@{}
foreach ($key in $selected) {
    Title $Components[$key]
    try {
        $ok = & "Install-$((Get-Culture).TextInfo.ToTitleCase($key))"
        $results[$key] = [bool]($ok | Select-Object -Last 1)
        if ($results[$key]) { $state = Get-State; $done = @(); if ($state.PSObject.Properties['installed']) { $done = @($state.installed) }; Set-StateValue 'installed' @($done + $key | Select-Object -Unique) }
    }
    catch { Say "Failed: $($_.Exception.Message)" Red; $results[$key] = $false }
}

Title 'Summary'
foreach ($key in $results.Keys) {
    if ($results[$key]) { Say ("  done     {0}" -f $key) Green } else { Say ("  skipped  {0}" -f $key) Yellow }
}
Say ''
Say "To remove everything later run: powershell -ExecutionPolicy Bypass -File `"$InstallDir\uninstall.ps1`""
