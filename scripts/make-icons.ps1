# Generates the PWA icons and favicon from the wordmark (two ultramarine frames + the yellow playhead).
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "frontend\web\icons"
New-Item -ItemType Directory -Force -Path $out | Out-Null

function New-RoundPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function New-Icon([int]$size, [bool]$maskable, [string]$path) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $ink = [System.Drawing.ColorTranslator]::FromHtml('#121A33')
    $ultra = [System.Drawing.ColorTranslator]::FromHtml('#3A36E8')
    $sodium = [System.Drawing.ColorTranslator]::FromHtml('#FFC83D')
    $g.Clear([System.Drawing.Color]::Transparent)
    $bg = New-Object System.Drawing.SolidBrush $ink
    if ($maskable) {
        $g.FillRectangle($bg, 0, 0, $size, $size)
        $scale = 0.5
    } else {
        $g.FillPath($bg, (New-RoundPath 0 0 $size $size ($size * 0.22)))
        $scale = 0.62
    }
    $fw = $size * $scale * 0.24
    $fh = $size * $scale * 0.62
    $gap = $size * $scale * 0.1
    $total = 3 * $fw + 2 * $gap
    $x = ($size - $total) / 2
    $y = ($size - $fh) / 2
    $colors = @($ultra, $ultra, $sodium)
    foreach ($c in $colors) {
        $b = New-Object System.Drawing.SolidBrush $c
        $g.FillPath($b, (New-RoundPath $x $y $fw $fh ($fw * 0.28)))
        $x += $fw + $gap
    }
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

New-Icon 192 $false (Join-Path $out "Icon-192.png")
New-Icon 512 $false (Join-Path $out "Icon-512.png")
New-Icon 192 $true (Join-Path $out "Icon-maskable-192.png")
New-Icon 512 $true (Join-Path $out "Icon-maskable-512.png")
New-Icon 32 $false (Join-Path $out "favicon.png")
Write-Host "[ OK ] Icons written to frontend\web\icons"