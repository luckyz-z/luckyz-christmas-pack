param(
    [ValidateSet('TopRight','TopLeft','BottomRight','BottomLeft')][string]$Corner = 'TopRight',
    [int]$Margin = 40,
    [string]$SnapshotPath = ''
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType = WindowsRuntime]

if (-not $SnapshotPath) {
    $script:mutex = New-Object System.Threading.Mutex($false, 'Global\Luckyz-ChristmasNowPlaying')
    if (-not $script:mutex.WaitOne(0)) { exit }
}

Add-Type @'
using System; using System.Runtime.InteropServices;
public class DeskWin {
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
}
'@

$script:asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, [type]$t) {
    $task = $script:asTask.MakeGenericMethod($t).Invoke($null, @($op))
    [void]$task.Wait(-1)
    $task.Result
}
$MgrType   = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
$PropsType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]
$StrmType  = [Windows.Storage.Streams.IRandomAccessStreamWithContentType]

function Get-NowPlaying {
    try {
        $mgr = Await ($MgrType::RequestAsync()) $MgrType
        $s = $mgr.GetSessions() | Where-Object { $_.SourceAppUserModelId -match 'spotify' } | Select-Object -First 1
        if (-not $s) { return $null }
        $p  = Await ($s.TryGetMediaPropertiesAsync()) $PropsType
        $tl = $s.GetTimelineProperties()
        $pi = $s.GetPlaybackInfo()
        $pos = $tl.Position.TotalSeconds
        $playing = ($pi.PlaybackStatus -eq 'Playing')
        if ($playing) { $pos += ([DateTimeOffset]::UtcNow - $tl.LastUpdatedTime.ToUniversalTime()).TotalSeconds }
        $end = $tl.EndTime.TotalSeconds
        if ($end -gt 0) { $pos = [Math]::Min([Math]::Max($pos, 0), $end) }
        [pscustomobject]@{ Title = $p.Title; Artist = $p.Artist; Playing = $playing; Pos = $pos; End = $end; Props = $p }
    } catch { $null }
}

$script:artReady = $false
try {
    $dll = Join-Path $PSScriptRoot 'NowPlayingArt.dll'
    if (-not (Test-Path $dll)) {
        $net = "$env:windir\Microsoft.NET\Framework64\v4.0.30319"
        $winmd = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\UnionMetadata" -Recurse -Filter Windows.winmd -ErrorAction SilentlyContinue |
            Where-Object { $_.DirectoryName -notmatch 'Facade' } | Sort-Object FullName -Descending | Select-Object -First 1
        if ($winmd) {
            & "$net\csc.exe" /nologo /target:library /out:$dll /reference:$($winmd.FullName) /reference:"$net\System.Runtime.WindowsRuntime.dll" /reference:"$net\System.Runtime.dll" /reference:"$net\System.Core.dll" (Join-Path $PSScriptRoot 'NowPlayingArt.cs') | Out-Null
        }
    }
    if (Test-Path $dll) { Add-Type -Path $dll; $script:artReady = $true }
} catch { }

function Get-ArtBitmap($props) {
    try {
        if (-not $script:artReady) { return $null }
        $bytes = [NowPlayingArt]::Get()
        if (-not $bytes) { return $null }
        $ms = New-Object System.IO.MemoryStream(, $bytes)
        $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit(); $bmp.CacheOption = 'OnLoad'; $bmp.StreamSource = $ms; $bmp.EndInit(); $bmp.Freeze()
        $bmp
    } catch { $null }
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="420" Height="168" WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ShowInTaskbar="False" ResizeMode="NoResize" Topmost="False" SnapsToDevicePixels="True" UseLayoutRounding="True">
  <Grid x:Name="Root" Margin="10">
    <Border CornerRadius="26" BorderThickness="1.5" BorderBrush="#E7BF5A">
      <Border.Background>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
          <GradientStop Color="#F2123327" Offset="0"/>
          <GradientStop Color="#F20B1A13" Offset="1"/>
        </LinearGradientBrush>
      </Border.Background>
      <Border.Effect><DropShadowEffect Color="#000000" BlurRadius="22" ShadowDepth="0" Opacity="0.55"/></Border.Effect>
    </Border>
    <Canvas x:Name="Snow" ClipToBounds="True" IsHitTestVisible="False"/>
    <Canvas x:Name="Garland" Height="22" VerticalAlignment="Top" IsHitTestVisible="False"/>
    <Grid Margin="18,26,18,14">
      <Grid.ColumnDefinitions><ColumnDefinition Width="92"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
      <Grid Grid.Column="0" Width="88" Height="88" VerticalAlignment="Center" HorizontalAlignment="Left">
        <Border x:Name="Art" CornerRadius="20" BorderThickness="2" BorderBrush="#FFF4E0">
          <Border.Background>
            <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
              <GradientStop Color="#C8323F" Offset="0"/><GradientStop Color="#2F8F5A" Offset="1"/>
            </LinearGradientBrush>
          </Border.Background>
          <TextBlock x:Name="ArtGlyph" Text="&#x266B;" FontSize="38" Foreground="#FFF4E0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>

        <Canvas Width="88" Height="88" IsHitTestVisible="False" ClipToBounds="False">
          <Canvas.RenderTransform><RotateTransform Angle="-14" CenterX="20" CenterY="10"/></Canvas.RenderTransform>
          <Path Fill="#D8343F" Stroke="#8F2430" StrokeThickness="1" Data="M -8,18 Q 6,-26 40,-6 Q 34,2 30,18 Z"/>
          <Border Canvas.Left="-12" Canvas.Top="12" Width="48" Height="12" CornerRadius="6" Background="#FFF4E0"/>
          <Ellipse Canvas.Left="30" Canvas.Top="-16" Width="13" Height="13" Fill="#FFF4E0"/>
        </Canvas>
      </Grid>
      <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="6,0,0,0">
        <TextBlock x:Name="Tag" Text="NOW PLAYING" FontFamily="Segoe UI" FontSize="10.5" FontWeight="Bold" Foreground="#E7BF5A"/>
        <TextBlock x:Name="Title" Text="Nothing playing" FontFamily="Segoe UI Semibold" FontSize="18" Foreground="#FFF4E0" TextTrimming="CharacterEllipsis" Margin="0,2,0,0"/>
        <TextBlock x:Name="Artist" Text="Press play on Spotify" FontFamily="Segoe UI" FontSize="13" Foreground="#D6C7A8" TextTrimming="CharacterEllipsis"/>
        <Grid Margin="0,10,0,0" Height="9">
          <Border CornerRadius="4.5" Background="#26FFF4E0"/>
          <Border x:Name="Fill" CornerRadius="4.5" HorizontalAlignment="Left" Width="0"/>
        </Grid>
        <Grid Margin="0,4,0,0">
          <TextBlock x:Name="TimeL" Text="0:00" FontSize="10.5" Foreground="#B9AB8E" HorizontalAlignment="Left"/>
          <TextBlock x:Name="TimeR" Text="0:00" FontSize="10.5" Foreground="#B9AB8E" HorizontalAlignment="Right"/>
        </Grid>
      </StackPanel>
    </Grid>
  </Grid>
</Window>
'@
$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$E = @{}; foreach ($n in 'Root','Art','ArtGlyph','Snow','Garland','Tag','Title','Artist','Fill','TimeL','TimeR') { $E[$n] = $win.FindName($n) }

$candy = New-Object Windows.Media.LinearGradientBrush
$candy.MappingMode = 'Absolute'; $candy.StartPoint = '0,0'; $candy.EndPoint = '14,14'; $candy.SpreadMethod = 'Repeat'
foreach ($st in @(@('#D8343F', 0), @('#D8343F', 0.5), @('#FFF4E0', 0.5), @('#FFF4E0', 1))) {
    $gs = New-Object Windows.Media.GradientStop; $gs.Color = [Windows.Media.ColorConverter]::ConvertFromString($st[0]); $gs.Offset = $st[1]; $candy.GradientStops.Add($gs)
}
$tt = New-Object Windows.Media.TranslateTransform; $candy.Transform = $tt
$anim = New-Object Windows.Media.Animation.DoubleAnimation(0, 14, [TimeSpan]::FromSeconds(0.9)); $anim.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
$tt.BeginAnimation([Windows.Media.TranslateTransform]::XProperty, $anim)
$E.Fill.Background = $candy

$bc = [Windows.Media.BrushConverter]::new()
$wire = New-Object Windows.Shapes.Polyline; $wire.Stroke = $bc.ConvertFromString('#3F6B53'); $wire.StrokeThickness = 1.6
for ($x = 0; $x -le 400; $x += 4) { [void]$wire.Points.Add((New-Object Windows.Point(($x + 6), (3 + 5 * [Math]::Abs([Math]::Sin($x / 28.0 * [Math]::PI / 1)))))) }
[void]$E.Garland.Children.Add($wire)
$cols = '#D8434F', '#E7BF5A', '#2F9E63', '#FFF4E0'; $i = 0
for ($x = 22; $x -lt 400; $x += 28) {
    $y = 3 + 5 * [Math]::Abs([Math]::Sin(($x - 6) / 28.0 * [Math]::PI))
    $b = New-Object Windows.Shapes.Ellipse; $b.Width = 8; $b.Height = 11; $b.Fill = $bc.ConvertFromString($cols[$i % 4]); $i++
    $b.Effect = New-Object Windows.Media.Effects.DropShadowEffect -Property @{ Color = $b.Fill.Color; BlurRadius = 8; ShadowDepth = 0; Opacity = 0.9 }
    [Windows.Controls.Canvas]::SetLeft($b, $x); [Windows.Controls.Canvas]::SetTop($b, $y + 1); [void]$E.Garland.Children.Add($b)
}

$rnd = New-Object System.Random(7); $flakes = @()
for ($k = 0; $k -lt 14; $k++) {
    $t = New-Object Windows.Controls.TextBlock; $t.Text = [string][char]0x2744; $t.Foreground = $bc.ConvertFromString('#FFF4E0')
    $t.FontSize = 7 + $rnd.Next(0, 8); $t.Opacity = 0.18 + $rnd.NextDouble() * 0.25
    $f = [pscustomobject]@{ El = $t; X = $rnd.Next(10, 395); Y = $rnd.Next(0, 150); V = 0.25 + $rnd.NextDouble() * 0.6; Ph = $rnd.NextDouble() * 6 }
    [void]$E.Snow.Children.Add($t); $flakes += $f
}

function Fmt([double]$s) { if ($s -lt 0) { $s = 0 }; '{0}:{1:00}' -f [int][Math]::Floor($s / 60), [int]($s % 60) }
$script:lastKey = ''
function Update-Card {
    $np = Get-NowPlaying
    if (-not $np -or -not $np.Title) {
        $E.Tag.Text = 'SPOTIFY'; $E.Title.Text = 'Nothing playing'; $E.Artist.Text = 'Press play on a Christmas song'
        $E.Fill.Width = 0; $E.TimeL.Text = ''; $E.TimeR.Text = ''; return
    }
    $E.Tag.Text = $(if ($np.Playing) { 'NOW PLAYING' } else { 'PAUSED' })
    $E.Title.Text = $np.Title; $E.Artist.Text = $np.Artist
    $key = "$($np.Title)|$($np.Artist)"
    if ($key -ne $script:lastKey) {
        $script:lastKey = $key
        $bmp = Get-ArtBitmap $np.Props
        if ($bmp) {
            $br = New-Object Windows.Media.ImageBrush($bmp); $br.Stretch = 'UniformToFill'; $E.Art.Background = $br; $E.ArtGlyph.Visibility = 'Collapsed'
        }
    }
    $track = 262
    if ($np.End -gt 0) { $E.Fill.Width = [Math]::Max(0, [Math]::Min($track, $track * $np.Pos / $np.End)); $E.TimeL.Text = Fmt $np.Pos; $E.TimeR.Text = Fmt $np.End }
}

$win.Add_Loaded({
    $src = [Windows.PresentationSource]::FromVisual($win); $m = $src.CompositionTarget.TransformFromDevice
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $w = $win.Width; $h = $win.Height
    $left = $wa.Left * $m.M11; $right = $wa.Right * $m.M11; $top = $wa.Top * $m.M22; $bottom = $wa.Bottom * $m.M22
    if ($SnapshotPath) { $win.Left = -4000; $win.Top = 0; return }
    switch ($Corner) {
        'TopRight'    { $win.Left = $right - $w - $Margin; $win.Top = $top + $Margin }
        'TopLeft'     { $win.Left = $left + $Margin;       $win.Top = $top + $Margin }
        'BottomRight' { $win.Left = $right - $w - $Margin; $win.Top = $bottom - $h - $Margin }
        'BottomLeft'  { $win.Left = $left + $Margin;       $win.Top = $bottom - $h - $Margin }
    }
    $hwnd = (New-Object Windows.Interop.WindowInteropHelper $win).Handle
    $ex = [DeskWin]::GetWindowLong($hwnd, -20)
    [void][DeskWin]::SetWindowLong($hwnd, -20, ($ex -bor 0x80 -bor 0x08000000 -bor 0x20))
    $script:hwnd = $hwnd
})

Update-Card
$tick = New-Object Windows.Threading.DispatcherTimer; $tick.Interval = [TimeSpan]::FromSeconds(1)
$tick.Add_Tick({ Update-Card; if ($script:hwnd) { [void][DeskWin]::SetWindowPos($script:hwnd, [IntPtr]1, 0, 0, 0, 0, 0x13) } })
$flakeTimer = New-Object Windows.Threading.DispatcherTimer; $flakeTimer.Interval = [TimeSpan]::FromMilliseconds(50)
$ft = 0.0
$flakeTimer.Add_Tick({
    $script:ft += 0.05
    foreach ($f in $flakes) {
        $f.Y += $f.V; if ($f.Y -gt 160) { $f.Y = -10 }
        [Windows.Controls.Canvas]::SetTop($f.El, $f.Y); [Windows.Controls.Canvas]::SetLeft($f.El, $f.X + 6 * [Math]::Sin($script:ft + $f.Ph))
    }
})

if ($SnapshotPath) {
    $win.Add_ContentRendered({
        $win.Dispatcher.BeginInvoke([Action]{
            $root = $E.Root; $root.Measure([Windows.Size]::new($win.Width, $win.Height)); $root.Arrange([Windows.Rect]::new(0, 0, $win.Width, $win.Height))
            $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap(($win.Width * 2), ($win.Height * 2), 192, 192, [Windows.Media.PixelFormats]::Pbgra32)
            $rtb.Render($root)
            $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder; $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
            $fs = [System.IO.File]::Create($SnapshotPath); $enc.Save($fs); $fs.Close(); $win.Close()
        }, [Windows.Threading.DispatcherPriority]::ApplicationIdle) | Out-Null
    })
} else { $tick.Start(); $flakeTimer.Start() }

[void]$win.ShowDialog()
