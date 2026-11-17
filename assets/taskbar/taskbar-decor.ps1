param([string]$SnapshotPath = '')
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing
if (-not $SnapshotPath) {
    $script:mutex = New-Object System.Threading.Mutex($false, 'Global\THLA-ChristmasTaskbarDecor')
    if (-not $script:mutex.WaitOne(0)) { exit }
}
Add-Type @'
using System; using System.Runtime.InteropServices;
public class TbWin {
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
}
'@

$bc = [Windows.Media.BrushConverter]::new()
$H = 40
function New-Decor([double]$width) {
    $cv = New-Object Windows.Controls.Canvas; $cv.Width = $width; $cv.Height = $H; $cv.IsHitTestVisible = $false
    $bulbs = @()
    $wire = New-Object Windows.Shapes.Polyline; $wire.Stroke = $bc.ConvertFromString('#4A7A60'); $wire.StrokeThickness = 1.6
    for ($x = 0; $x -le $width; $x += 3) { $fr = ($x % 120) / 120.0; [void]$wire.Points.Add((New-Object Windows.Point($x, (11 + 9 * [Math]::Sin([Math]::PI * $fr))))) }
    [void]$cv.Children.Add($wire)
    $cols = '#E04B57', '#E7BF5A', '#35B070', '#FFF4E0', '#6FA8F0'; $i = 0
    for ($x = 15; $x -lt $width; $x += 30) {
        $fr = ($x % 120) / 120.0; $y = 11 + 9 * [Math]::Sin([Math]::PI * $fr)
        $col = $cols[$i % 5]; $i++
        $b = New-Object Windows.Shapes.Ellipse; $b.Width = 7; $b.Height = 10; $b.Fill = $bc.ConvertFromString($col)
        $b.Effect = New-Object Windows.Media.Effects.DropShadowEffect -Property @{ Color = $b.Fill.Color; BlurRadius = 9; ShadowDepth = 0; Opacity = 1 }
        [Windows.Controls.Canvas]::SetLeft($b, $x - 3.5); [Windows.Controls.Canvas]::SetTop($b, $y + 1)
        [void]$cv.Children.Add($b); $bulbs += $b
    }
    $drift = New-Object Windows.Shapes.Polygon; $drift.Fill = $bc.ConvertFromString('#F4F8FF'); $drift.Opacity = 0.95
    [void]$drift.Points.Add((New-Object Windows.Point(0, 11)))
    for ($x = 0; $x -le $width; $x += 4) {
        $h = 3.2 + 2.2 * [Math]::Sin($x / 23.0) + 1.6 * [Math]::Sin($x / 9.0 + 1) + 1.3 * [Math]::Sin($x / 61.0)
        [void]$drift.Points.Add((New-Object Windows.Point($x, (9 - $h))))
    }
    [void]$drift.Points.Add((New-Object Windows.Point($width, 11)))
    $drift.Effect = New-Object Windows.Media.Effects.DropShadowEffect -Property @{ Color = [Windows.Media.Colors]::White; BlurRadius = 6; ShadowDepth = 0; Opacity = 0.35 }
    [void]$cv.Children.Add($drift)
    [pscustomobject]@{ Canvas = $cv; Bulbs = $bulbs }
}

function New-DecorWindow($left, $top, $width) {
    $d = New-Decor $width
    $w = New-Object Windows.Window
    $w.WindowStyle = 'None'; $w.AllowsTransparency = $true; $w.Background = [Windows.Media.Brushes]::Transparent
    $w.ShowInTaskbar = $false; $w.ResizeMode = 'NoResize'; $w.Topmost = $true; $w.ShowActivated = $false
    $w.Width = $width; $w.Height = $H; $w.Left = $left; $w.Top = $top; $w.Content = $d.Canvas
    $w | Add-Member -NotePropertyName Bulbs -NotePropertyValue $d.Bulbs
    $w
}

$wins = @()
if ($SnapshotPath) {
    $dec = New-Decor 1000
    $host_ = New-Object Windows.Controls.Grid; $host_.Width = 1000; $host_.Height = 90; $host_.Background = $bc.ConvertFromString('#2A1A1F2A')
    $host_.Background = $bc.ConvertFromString('#FF1B2A24'); $dec.Canvas.VerticalAlignment = 'Top'; $dec.Canvas.HorizontalAlignment = 'Left'
    [void]$host_.Children.Add($dec.Canvas)
    $host_.Measure([Windows.Size]::new(1000, 90)); $host_.Arrange([Windows.Rect]::new(0, 0, 1000, 90)); $host_.UpdateLayout()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap(2000, 180, 192, 192, [Windows.Media.PixelFormats]::Pbgra32); $rtb.Render($host_)
    $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder; $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [System.IO.File]::Create($SnapshotPath); $enc.Save($fs); $fs.Close(); exit
}

foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
    $barH = $s.Bounds.Bottom - $s.WorkingArea.Bottom
    if ($barH -le 0) { continue }
    $w = New-DecorWindow $s.Bounds.Left ($s.WorkingArea.Bottom - 11) $s.Bounds.Width
    $w.Add_SourceInitialized({
        param($sender, $e)
        $h = (New-Object Windows.Interop.WindowInteropHelper $sender).Handle
        $ex = [TbWin]::GetWindowLong($h, -20)
        [void][TbWin]::SetWindowLong($h, -20, ($ex -bor 0x80 -bor 0x08000000 -bor 0x20))
    })
    $wins += $w
}
$rnd = New-Object System.Random
$tw = New-Object Windows.Threading.DispatcherTimer; $tw.Interval = [TimeSpan]::FromMilliseconds(700)
$tw.Add_Tick({ foreach ($w in $wins) { foreach ($b in $w.Bulbs) { $b.Opacity = 0.55 + 0.45 * $rnd.NextDouble() } } })
$tw.Start()
foreach ($w in $wins) { $w.Show() }
[Windows.Threading.Dispatcher]::Run()
