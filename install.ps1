[CmdletBinding()]
param(
    [string[]]$Only,
    [switch]$All,
    [switch]$Yes,
    [switch]$List,
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$Root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$Assets = Join-Path $Root 'assets'
$InstallDir = Join-Path $env:LOCALAPPDATA 'Luckyz-Christmas'
$StatePath = Join-Path $InstallDir 'state.json'
$StartupDir = [Environment]::GetFolderPath('Startup')
$Utf8 = New-Object System.Text.UTF8Encoding $false
try { [Console]::OutputEncoding = $Utf8 } catch { }
$VersionFile = Join-Path $Root 'VERSION'
$Version = if (Test-Path $VersionFile) { (Get-Content $VersionFile -Raw).Trim() } else { 'dev' }
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ }) }
$Retry = @()
$CurrentComponent = ''

$Components = [ordered]@{
    terminal    = 'Windows Terminal: snow background, Christmas colors, festive PowerShell prompt'
    taskbar     = 'Taskbar lights: string lights and snow drift along the taskbar'
    translucent = 'Transparent taskbar (installs TranslucentTB from the Microsoft Store via winget)'
    widget      = 'Spotify now-playing desktop widget with a candy-cane progress bar'
    icons       = 'App icons: Christmas Discord, Steam, Edge, VS Code, Spotify and File Explorer icons'
    vscode      = 'VS Code: Christmas color theme and custom Christmas file icons'
    spotify     = 'Spotify: Christmas theme and snow (installs Spicetify if needed)'
    discord     = 'Discord: Christmas theme (uses Vencord, offers to install it)'
    icue        = 'Corsair iCUE: Christmas lighting for keyboard and RAM'
}

if ($List) {
    $Components.GetEnumerator() | ForEach-Object { '{0,-12} {1}' -f $_.Key, $_.Value }
    return
}

$Fancy = [bool]($env:WT_SESSION -or $env:TERM_PROGRAM -or $env:ConEmuPID)
$G = if ($Fancy) {
    @{
        tree = [char]::ConvertFromUtf32(0x1F384); gift = [char]::ConvertFromUtf32(0x1F381); santa = [char]::ConvertFromUtf32(0x1F385)
        sock = [char]::ConvertFromUtf32(0x1F9E6); bell = [char]::ConvertFromUtf32(0x1F514); flake = [string][char]0x2744; star = [string][char]0x2B50
    }
}
else {
    @{ tree = '*'; gift = '+'; santa = '>'; sock = 'o'; bell = '!'; flake = '*'; star = '*' }
}

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

function Invoke-Quiet {
    $ErrorActionPreference = 'Continue'
    $program, $rest = $args
    & $program @rest 2>&1 | Out-Null
}

function Paint($segments) {
    foreach ($seg in $segments) { Write-Host $seg[0] -NoNewline -ForegroundColor $seg[1] }
    Write-Host ''
}

function Rule($width = 56) {
    $colors = 'Red', 'White'
    Write-Host '  ' -NoNewline
    for ($i = 0; $i -lt $width; $i++) { Write-Host '=' -NoNewline -ForegroundColor $colors[$i % 2] }
    Write-Host ''
}

function Title($text) {
    Write-Host ''
    Rule
    Write-Host "  $($G.tree) " -NoNewline
    Write-Host $text -ForegroundColor Green
}

function Show-Snow([int]$frames = 22) {
    if ($Yes -or $Update -or -not $Fancy) { return }
    try {
        $width = [Math]::Min([Console]::WindowWidth - 2, 70)
        $height = 8
        for ($i = 0; $i -lt $height; $i++) { Write-Host '' }
        $top = [Console]::CursorTop - $height
        $rand = New-Object System.Random
        $marks = '*', '.', '+', '.'
        $flakes = 1..28 | ForEach-Object { [pscustomobject]@{ X = $rand.Next(0, $width); Y = $rand.Next(0, $height); V = 1 + $rand.Next(0, 2); C = $marks[$rand.Next(0, 4)] } }
        [Console]::CursorVisible = $false
        for ($f = 0; $f -lt $frames; $f++) {
            foreach ($s in $flakes) {
                [Console]::SetCursorPosition($s.X + 2, $top + $s.Y)
                [Console]::Write(' ')
                $s.Y += $s.V
                if ($s.Y -ge $height) { $s.Y = 0; $s.X = $rand.Next(0, $width) }
                [Console]::SetCursorPosition($s.X + 2, $top + $s.Y)
                [Console]::ForegroundColor = if ($s.V -eq 2) { 'White' } else { 'Cyan' }
                [Console]::Write($s.C)
            }
            Start-Sleep -Milliseconds 70
        }
        [Console]::ResetColor()
        for ($y = 0; $y -lt $height; $y++) { [Console]::SetCursorPosition(0, $top + $y); [Console]::Write(' ' * ($width + 4)) }
        [Console]::SetCursorPosition(0, $top)
    }
    catch { }
    finally { try { [Console]::CursorVisible = $true; [Console]::ResetColor() } catch { } }
}

function Show-Banner {
    Show-Snow
    $rand = New-Object System.Random
    Write-Host ''
    Paint @(, @(('              ' + $G.star), 'Yellow'))
    $ornaments = 'Red', 'Yellow', 'Cyan', 'Magenta'
    for ($row = 1; $row -le 7; $row++) {
        $count = 2 * $row - 1
        Write-Host (' ' * (14 - $row)) -NoNewline
        Write-Host '/' -NoNewline -ForegroundColor DarkGreen
        for ($c = 0; $c -lt $count; $c++) {
            if ($rand.Next(0, 5) -eq 0) { Write-Host 'o' -NoNewline -ForegroundColor $ornaments[$rand.Next(0, 4)] }
            else { Write-Host '^' -NoNewline -ForegroundColor Green }
        }
        Write-Host '\' -NoNewline -ForegroundColor DarkGreen
        Write-Host ''
    }
    Paint @(, @('             |||', 'DarkYellow'))
    Write-Host ''
    Write-Host '  ' -NoNewline
    $letters = 'L U C K Y Z   C H R I S T M A S   P A C K'.ToCharArray()
    for ($i = 0; $i -lt $letters.Count; $i++) { Write-Host $letters[$i] -NoNewline -ForegroundColor $(if ($i % 2) { 'Green' } else { 'Red' }) }
    Write-Host ''
    $xmas = Get-Date -Month 12 -Day 25 -Hour 0 -Minute 0 -Second 0
    if ((Get-Date) -gt $xmas.AddDays(1)) { $xmas = $xmas.AddYears(1) }
    $days = [int][Math]::Ceiling(($xmas - (Get-Date)).TotalDays)
    $line = if ($days -le 0) { 'Merry Christmas!' } else { "$days days until Christmas" }
    Say "  $($G.flake) $line $($G.flake)" Yellow
    Say '  Everything is optional, and every file that gets edited is backed up first.' DarkGray
    Rule
}

function Ask($question, [bool]$default = $true, $key = '') {
    if ($Update -and $Retry -notcontains $CurrentComponent) {
        if ($key -like 'autostart:*') { return (Test-Path (Join-Path $StartupDir ("Luckyz Christmas - $($key.Substring(10)).lnk"))) }
        return $false
    }
    if ($Yes) { return $default }
    $hint = if ($default) { 'Y/n' } else { 'y/N' }
    Write-Host "  $($G.santa) $question " -NoNewline -ForegroundColor Yellow
    Write-Host "[$hint] " -NoNewline -ForegroundColor DarkGray
    $answer = Read-Host
    if ([string]::IsNullOrWhiteSpace($answer)) { return $default }
    return $answer.Trim().ToLower().StartsWith('y')
}

function Select-Presents {
    $keys = @($Components.Keys)
    $on = @{}
    foreach ($k in $keys) { $on[$k] = $true }
    if ($Yes) { return $keys }
    while ($true) {
        Write-Host ''
        Say "  $($G.gift) Pick your presents" Cyan
        for ($i = 0; $i -lt $keys.Count; $i++) {
            $mark = if ($on[$keys[$i]]) { '[x]' } else { '[ ]' }
            $color = if ($on[$keys[$i]]) { 'Green' } else { 'DarkGray' }
            Write-Host ("   {0} {1}  {2}" -f $mark, ($i + 1), $Components[$keys[$i]]) -ForegroundColor $color
        }
        Write-Host ''
        Write-Host '  Type numbers to toggle (like 2,5), A = all, N = none, Enter = unwrap: ' -NoNewline -ForegroundColor Yellow
        $answer = Read-Host
        if ([string]::IsNullOrWhiteSpace($answer)) { break }
        $answer = $answer.Trim().ToLower()
        if ($answer -eq 'a') { foreach ($k in $keys) { $on[$k] = $true }; continue }
        if ($answer -eq 'n') { foreach ($k in $keys) { $on[$k] = $false }; continue }
        foreach ($token in ($answer -split '[,\s]+')) {
            $n = 0
            if ([int]::TryParse($token, [ref]$n) -and $n -ge 1 -and $n -le $keys.Count) { $on[$keys[$n - 1]] = -not $on[$keys[$n - 1]] }
        }
    }
    return @($keys | Where-Object { $on[$_] })
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
    $backup = "$path.luckyz-backup"
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

function Stop-Tool($pattern) {
    $running = { Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match $pattern -and $_.ProcessId -ne $PID } }
    & $running | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    for ($i = 0; $i -lt 12 -and (& $running); $i++) { Start-Sleep -Milliseconds 300 }
}

function Copy-Assets($name) {
    $source = Join-Path $Assets $name
    $target = Join-Path $InstallDir $name
    New-Item -ItemType Directory $target -Force | Out-Null
    foreach ($file in Get-ChildItem $source -Recurse -File) {
        $destination = Join-Path $target $file.FullName.Substring($source.Length).TrimStart('\')
        New-Item -ItemType Directory (Split-Path $destination) -Force | Out-Null
        for ($attempt = 1; $attempt -le 6; $attempt++) {
            try { Copy-Item $file.FullName $destination -Force -ErrorAction Stop; break }
            catch {
                if ($attempt -eq 6) { throw }
                Start-Sleep -Milliseconds 700
            }
        }
    }
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
    $link = $shell.CreateShortcut((Join-Path $StartupDir "Luckyz Christmas - $label.lnk"))
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
        name = 'Luckyz Christmas'; background = '#0A1913'; foreground = '#FFF4E0'; cursorColor = '#E7BF5A'; selectionBackground = '#C8323F'
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
            $schemes = @($schemes | Where-Object { $_.name -ne 'Luckyz Christmas' }) + $scheme
            Set-Property $settings 'schemes' $schemes
            $list = if ($settings.profiles -is [array]) { @($settings.profiles) } else { @($settings.profiles.list) }
            foreach ($p in $profiles) {
                $list = @($list | Where-Object { $_.guid -ne $p.guid })
                $entry = [pscustomobject][ordered]@{
                    name = $p.name; guid = $p.guid; commandline = $p.commandline; hidden = $false
                    backgroundImage = $gif; backgroundImageOpacity = 0.85; backgroundImageStretchMode = 'uniformToFill'
                    colorScheme = 'Luckyz Christmas'
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
    Stop-Tool 'taskbar-decor'
    $dir = Copy-Assets 'taskbar'
    $script = Join-Path $dir 'taskbar-decor.ps1'
    if (Ask 'Start the taskbar lights automatically when you sign in?' $true 'autostart:Taskbar Lights') { New-Autostart 'Taskbar Lights' $script 6 }
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
    Stop-Tool 'nowplaying-widget'
    $dir = Copy-Assets 'widget'
    $script = Join-Path $dir 'nowplaying-widget.ps1'
    $corner = 'TopRight'
    if ($Update) { $saved = (Get-State).widgetCorner; if ($saved) { $corner = $saved } }
    elseif (-not $Yes) {
        $choice = Read-Host 'Which corner for the widget? TopRight, TopLeft, BottomRight, BottomLeft [TopRight]'
        if ($choice -in 'TopRight', 'TopLeft', 'BottomRight', 'BottomLeft') { $corner = $choice }
    }
    Set-StateValue 'widgetCorner' $corner
    if (Ask 'Start the widget automatically when you sign in?' $true 'autostart:Now Playing Widget') { New-Autostart 'Now Playing Widget' $script 8 $false "-Corner $corner" }
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'nowplaying-widget' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Hidden 'powershell.exe' "-STA -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -Corner $corner"
    Say 'The widget is running. Play something on Spotify to see it.' Green
    return $true
}

function Set-LinkIcon($path, $icon) {
    $shell = New-Object -ComObject WScript.Shell
    $before = $shell.CreateShortcut($path)
    $target = $before.TargetPath
    $arguments = $before.Arguments
    $link = $shell.CreateShortcut($path)
    $link.IconLocation = "$icon,0"
    $link.Save()
    $after = $shell.CreateShortcut($path)
    return (($after.TargetPath -eq $target) -and ($after.Arguments -eq $arguments) -and ($after.IconLocation -like "*$([IO.Path]::GetFileName($icon))*"))
}

function Find-StartLinks($name) {
    $roots = @((Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'), (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'))
    $hits = @()
    foreach ($root in $roots) {
        if (Test-Path $root) { $hits += @(Get-ChildItem $root -Recurse -Filter "$name.lnk" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }
    }
    return $hits
}

function Install-Icons {
    $dir = Copy-Assets 'icons'
    $apps = @(
        @{ Icon = 'discord'; Label = 'Discord' },
        @{ Icon = 'canary'; Label = 'Discord Canary' },
        @{ Icon = 'steam'; Label = 'Steam' },
        @{ Icon = 'vscode'; Label = 'Visual Studio Code' },
        @{ Icon = 'edge'; Label = 'Microsoft Edge' },
        @{ Icon = 'spotify'; Label = 'Spotify' },
        @{ Icon = 'explorer'; Label = 'File Explorer' }
    )
    $user = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    $pinned = Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
    $pinFolder = Join-Path $InstallDir 'pin-these'
    if (Test-Path $pinFolder) { Remove-Item $pinFolder -Recurse -Force }
    New-Item -ItemType Directory $pinFolder -Force | Out-Null
    $changed = @()
    $handled = @()
    foreach ($app in $apps) {
        $icon = Join-Path $dir "$($app.Icon).ico"
        $links = @(Find-StartLinks $app.Label)
        $pinnedLink = Join-Path $pinned "$($app.Label).lnk"
        $editable = @($links | Where-Object { $_.StartsWith($user, [StringComparison]::OrdinalIgnoreCase) })
        if (Test-Path $pinnedLink) { $editable += $pinnedLink }
        foreach ($path in $editable) {
            Backup-File $path
            if (Set-LinkIcon $path $icon) { $changed += $path }
            elseif (Test-Path "$path.luckyz-backup") { Copy-Item "$path.luckyz-backup" $path -Force }
        }
        $source = $links | Sort-Object { if ($_ -match 'Inc\\') { 0 } else { 1 } } | Select-Object -First 1
        if ($source) {
            $copy = Join-Path $pinFolder "$($app.Label).lnk"
            Copy-Item $source $copy -Force
            [void](Set-LinkIcon $copy $icon)
        }
        if ($editable -or $source) { $handled += $app.Label }
    }
    Set-StateValue 'iconLinks' @($changed)
    if (-not $handled) {
        Say 'None of the supported apps were found, so there was nothing to re-icon.' Yellow
        return $false
    }
    Invoke-Quiet ie4uinit.exe -show
    Say "Christmas icons applied for: $($handled -join ', ')." Green
    Say 'Claude is a Store app, so Windows will not let its icon be changed. The icon file is in the icons folder if you want it.' Gray
    Say 'Apps that are only open (not pinned) keep their old taskbar icon. To pin one with the Christmas icon: close it, then right-click its shortcut in the folder, choose Show more options, then Pin to taskbar.' Gray
    if (Ask 'Open the folder with ready-to-pin shortcuts now?') { Start-Process explorer.exe $pinFolder }
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
    $vsix = Join-Path $Assets 'vscode\luckyz-christmas-1.0.0.vsix'
    $apply = Ask 'Switch VS Code to the Christmas color theme and icons now?'
    foreach ($c in $clis) {
        Invoke-Quiet $c.Cli --install-extension $vsix --force
        Say "Installed the extension for $($c.Data)." Green
        if ($apply) {
            $dir = Join-Path $env:APPDATA "$($c.Data)\User"
            New-Item -ItemType Directory $dir -Force | Out-Null
            $path = Join-Path $dir 'settings.json'
            Backup-File $path
            try {
                $settings = if (Test-Path $path) { Read-Jsonc $path } else { [pscustomobject]@{} }
                Set-Property $settings 'workbench.colorTheme' 'Luckyz Christmas'
                Set-Property $settings 'workbench.iconTheme' 'luckyz-christmas-icons'
                Write-Json $path $settings
            }
            catch { Say "Could not edit $path. Pick the theme with Ctrl+K Ctrl+T instead." Yellow }
        }
    }
    Say 'If the theme does not switch by itself, press Ctrl+K Ctrl+T and choose Luckyz Christmas.' Gray
    return $true
}

function Install-DesktopSpotify {
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($admin) {
        Say 'Spotify refuses to install from an administrator window. Open a normal PowerShell window and run this again.' Yellow
        return $false
    }
    $spotify = Join-Path $env:APPDATA 'Spotify\Spotify.exe'
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Say 'Installing Spotify with winget...' Gray
        Invoke-Quiet winget install --id Spotify.Spotify --exact --source winget --accept-package-agreements --accept-source-agreements
    }
    if (-not (Test-Path $spotify)) {
        Say 'Downloading the Spotify installer from spotify.com...' Gray
        $setup = Join-Path ([IO.Path]::GetTempPath()) 'SpotifyFullSetup.exe'
        Invoke-WebRequest 'https://download.scdn.co/SpotifyFullSetup.exe' -OutFile $setup -UseBasicParsing
        Start-Process $setup -Wait
        Remove-Item $setup -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path $spotify)) {
        Say 'Spotify did not install. Install it from spotify.com and run this again.' Yellow
        return $false
    }
    $prefs = Join-Path $env:APPDATA 'Spotify\prefs'
    if (-not (Test-Path $prefs)) {
        Say 'Starting Spotify once so it can set itself up...' Gray
        Start-Process $spotify
        for ($i = 0; $i -lt 40 -and -not (Test-Path $prefs); $i++) { Start-Sleep 2 }
    }
    if (-not (Test-Path $prefs)) {
        Say 'Open Spotify and sign in once, then run this again to theme it.' Yellow
        return $false
    }
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
    if (-not (Test-Path $spotify)) {
        $store = Get-AppxPackage -Name 'SpotifyAB.SpotifyMusic' -ErrorAction SilentlyContinue
        if ($store) { Say 'Only the Microsoft Store version of Spotify was found, and that one cannot be themed.' Yellow }
        else { Say 'Desktop Spotify was not found.' Yellow }
        if (-not (Ask 'Download and install desktop Spotify from spotify.com now?')) { return $false }
        if (-not (Install-DesktopSpotify)) { return $false }
    }
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
    $themeDir = Join-Path $config 'Themes\luckyz-christmas'
    New-Item -ItemType Directory $themeDir -Force | Out-Null
    Copy-Item (Join-Path $Assets 'spotify\color.ini'), (Join-Path $Assets 'spotify\user.css') $themeDir -Force
    $extDir = Join-Path $config 'Extensions'
    New-Item -ItemType Directory $extDir -Force | Out-Null
    Copy-Item (Join-Path $Assets 'spotify\luckyz-snow.js') $extDir -Force
    $existing = @(($previous.extensions -split '\|') | Where-Object { $_ -and $_ -ne 'luckyz-snow.js' })
    & $sp config current_theme luckyz-christmas color_scheme christmas inject_css 1 replace_colors 1 overwrite_assets 1 | Out-Null
    & $sp config extensions (($existing + 'luckyz-snow.js') -join '|') | Out-Null
    Get-Process Spotify -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep 2
    Invoke-Quiet $sp backup apply
    Say 'Spotify is themed.' Green
    if (Ask 'Open the Christmas playlist that goes with this pack in Spotify now?') {
        Start-Process 'spotify:playlist:4DxlVuyC6plRuGTdobl8MP'
        Say 'Opening the playlist in Spotify.' Green
    }
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
                Invoke-Quiet $exe -install -branch $b.Name
                if (-not (Test-VencordPatched $b)) { Say "Vencord could not patch Discord ($($b.Name)). Close Discord completely and run this again." Yellow }
            }
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    $vencord = Join-Path $env:APPDATA 'Vencord\settings'
    New-Item -ItemType Directory $vencord -Force | Out-Null
    $css = Join-Path $vencord 'quickCss.css'
    Backup-File $css
    Copy-Item (Join-Path $Assets 'discord\luckyz-christmas.css') $css -Force
    $settingsPath = Join-Path $vencord 'settings.json'
    $settings = if (Test-Path $settingsPath) { Get-Content $settingsPath -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
    Set-Property $settings 'useQuickCss' $true
    Write-Json $settingsPath $settings
    foreach ($b in $branches) {
        $updater = Join-Path $env:LOCALAPPDATA "$($b.Dir)\Update.exe"
        if ((Test-Path $updater) -and -not (Get-Process $b.Process -ErrorAction SilentlyContinue)) { Start-Process $updater -ArgumentList '--processStart', "$($b.Process).exe" }
    }
    Say 'Discord theme installed. Press Ctrl+R in Discord if it does not appear.' Green
    return $true
}

function Install-Icue {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { Say 'Python 3 is needed for the lighting effect. Install it from python.org and run this again.' Yellow; return $false }
    if (-not (Get-Process iCUE -ErrorAction SilentlyContinue)) { Say 'iCUE does not seem to be running. Start it, and turn on Settings > Enable SDK.' Yellow }
    Invoke-Quiet $python.Source -c 'import cuesdk'
    if ($LASTEXITCODE -ne 0) {
        if (-not (Ask 'Install Corsair''s cuesdk Python library from PyPI?')) { return $false }
        Invoke-Quiet $python.Source -m pip install --user --quiet cuesdk
    }
    Stop-Tool 'christmas_lights'
    $dir = Copy-Assets 'icue'
    $script = Join-Path $dir 'christmas_lights.py'
    $pythonw = Join-Path (Split-Path $python.Source) 'pythonw.exe'
    if (-not (Test-Path $pythonw)) { $pythonw = $python.Source }
    if (Ask 'Start the lighting automatically when you sign in?' $true 'autostart:iCUE Lighting') { New-Autostart 'iCUE Lighting' @{ Interpreter = $pythonw; Script = $script } 30 $true }
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'christmas_lights' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Hidden $pythonw "`"$script`""
    Say 'Lighting started. In iCUE make sure Settings > Enable SDK is on.' Green
    return $true
}

if ($Update) { Say "  Updating Luckyz Christmas Pack to version $Version" Cyan } else { Show-Banner }

$previous = Get-State
if ($Update -and $previous.PSObject.Properties['failed']) { $Retry = @($previous.failed) }

$selected = @()
if ($All) { $selected = @($Components.Keys) }
elseif ($Only) { $selected = @($Only | ForEach-Object { $_.ToLower() } | Where-Object { $Components.Contains($_) }) }
else { $selected = @(Select-Presents) }

if (-not $selected) { Say "  $($G.sock) Nothing selected. Maybe next year!" Yellow; return }

New-Item -ItemType Directory $InstallDir -Force | Out-Null
foreach ($tool in 'uninstall.ps1', 'update.ps1', 'update-core.ps1', 'update.cmd') { Copy-Item (Join-Path $Root $tool) $InstallDir -Force -ErrorAction SilentlyContinue }
Set-StateValue 'version' $Version

$results = [ordered]@{}
$crashed = @()
$step = 0
foreach ($key in $selected) {
    $step++
    $CurrentComponent = $key
    Title ("[{0}/{1}] Wrapping: {2}" -f $step, $selected.Count, $Components[$key])
    try {
        $ok = & "Install-$((Get-Culture).TextInfo.ToTitleCase($key))"
        $results[$key] = [bool]($ok | Select-Object -Last 1)
        $state = Get-State
        if ($results[$key]) {
            $done = @(); if ($state.PSObject.Properties['installed']) { $done = @($state.installed) }
            Set-StateValue 'installed' @($done + $key | Select-Object -Unique)
        }
        $pending = @(); if ($state.PSObject.Properties['failed']) { $pending = @($state.failed) }
        Set-StateValue 'failed' @($pending | Where-Object { $_ -ne $key })
    }
    catch {
        Say "  Failed: $($_.Exception.Message)" Red
        $results[$key] = $false
        $crashed += $key
        $state = Get-State
        $pending = @(); if ($state.PSObject.Properties['failed']) { $pending = @($state.failed) }
        Set-StateValue 'failed' @($pending + $key | Select-Object -Unique)
    }
}

Write-Host ''
Rule
Say "  $($G.bell) Your presents" Cyan
foreach ($key in $results.Keys) {
    if ($results[$key]) { Say ("   {0}  unwrapped  {1}" -f $G.gift, $key) Green }
    elseif ($crashed -contains $key) { Say ("   {0}  coal       {1}  (failed, update.cmd will try again)" -f $G.sock, $key) Red }
    else { Say ("   {0}  skipped    {1}" -f $G.sock, $key) Yellow }
}
Write-Host ''
Show-Snow 14
Say "  $($G.tree) Merry Christmas! $($G.tree)" Red
Say "  To update later: powershell -ExecutionPolicy Bypass -File `"$InstallDir\update.ps1`"" DarkGray
Say "  To undo everything later: powershell -ExecutionPolicy Bypass -File `"$InstallDir\uninstall.ps1`"" DarkGray
if ($crashed) {
    Say "  Not everything finished ($($crashed -join ', ')). Run update.cmd to try those again." Yellow
    exit 2
}
