[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$tree  = [char]::ConvertFromUtf32(0x1F384)
$flake = [char]0x2744
$gift  = [char]::ConvertFromUtf32(0x1F381)
$arrow = [char]0x276F
$xmas  = Get-Date -Year (Get-Date).Year -Month 12 -Day 25 -Hour 0 -Minute 0 -Second 0
if ((Get-Date) -gt $xmas.AddDays(1)) { $xmas = $xmas.AddYears(1) }
$days = [int][math]::Ceiling(($xmas - (Get-Date)).TotalDays)
Clear-Host
Write-Host ""
Write-Host "      $flake   .  *   $flake    .   *     $flake" -ForegroundColor White
Write-Host "          *  .  $flake    *   .  $flake" -ForegroundColor Gray
Write-Host "     $tree  Merry Christmas, $env:USERNAME!  $tree" -ForegroundColor Yellow
if ($days -le 0) { Write-Host "      $gift  It's Christmas today!  $gift" -ForegroundColor Red }
else { Write-Host "      $gift  $days days until Christmas  $gift" -ForegroundColor Green }
Write-Host ""
function prompt {
    $p = (Get-Location).Path.Replace($HOME, '~')
    Write-Host "$tree " -NoNewline
    Write-Host $p -ForegroundColor Yellow -NoNewline
    Write-Host " $arrow" -ForegroundColor Red -NoNewline
    return ' '
}