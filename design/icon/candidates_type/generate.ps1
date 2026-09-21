
param([string]$Out)
Add-Type -AssemblyName System.Drawing

$SZ = 1024

function New-Canvas {
  $bmp = New-Object System.Drawing.Bitmap $SZ, $SZ
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  return @($bmp, $g)
}

function Get-Grad($x1, $y1, $x2, $y2, $c1, $c2) {
  $p1 = New-Object System.Drawing.PointF $x1, $y1
  $p2 = New-Object System.Drawing.PointF $x2, $y2
  return New-Object System.Drawing.Drawing2D.LinearGradientBrush($p1, $p2,
    [System.Drawing.ColorTranslator]::FromHtml($c1),
    [System.Drawing.ColorTranslator]::FromHtml($c2))
}

# 关键一步：按**字的墨迹包围盒**定位，不按字体的排版框。
# 汉字在 em 框里本来就偏上偏左，直接 DrawString 居中一定是歪的——
# 前面几版最刺眼的「不讲究」就出在这类地方。
function Get-GlyphPath($ch, $family, $style, $targetW, $cx, $cy) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $ff = New-Object System.Drawing.FontFamily $family
  $fmt = [System.Drawing.StringFormat]::GenericTypographic
  $origin = New-Object System.Drawing.PointF 0, 0
  $path.AddString($ch, $ff, $style, 800.0, $origin, $fmt)
  $b = $path.GetBounds()
  $scale = $targetW / [math]::Max($b.Width, $b.Height)
  $m = New-Object System.Drawing.Drawing2D.Matrix
  $m.Translate($cx, $cy)
  $m.Scale($scale, $scale)
  $m.Translate(-($b.X + $b.Width / 2), -($b.Y + $b.Height / 2))
  $path.Transform($m)
  return $path
}

function Save-Icon($name, $g, $bmp) {
  $bmp.Save("$Out\$name.png", [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}

# ---------- M1 黑体「阁」阳文：最直接的一版，字顶满画布 ----------
$r = New-Canvas; $bmp = $r[0]; $g = $r[1]
$g.FillRectangle((Get-Grad 0 0 $SZ $SZ "#1E6FA6" "#07202F"), 0, 0, $SZ, $SZ)
$p = Get-GlyphPath "阁" "SimHei" ([System.Drawing.FontStyle]::Regular) 660 512 520
$g.FillPath((Get-Grad 512 180 512 860 "#EAFBFF" "#7FDCFF"), $p)
Save-Icon "M1_heiti_ge" $g $bmp

# ---------- M2 楷体「藏」：笔锋带来的性格，黑体给不了 ----------
$r = New-Canvas; $bmp = $r[0]; $g = $r[1]
$g.FillRectangle((Get-Grad 0 0 $SZ $SZ "#1E6FA6" "#07202F"), 0, 0, $SZ, $SZ)
$p = Get-GlyphPath "藏" "KaiTi" ([System.Drawing.FontStyle]::Regular) 690 512 520
$g.FillPath((Get-Grad 512 160 512 880 "#EAFBFF" "#7FDCFF"), $p)
Save-Icon "M2_kaiti_cang" $g $bmp

# ---------- M3 藏书印·阳文：冰蓝印面，字留白 ----------
$r = New-Canvas; $bmp = $r[0]; $g = $r[1]
$g.FillRectangle((Get-Grad 0 0 $SZ $SZ "#0E3348" "#05151F"), 0, 0, $SZ, $SZ)
$seal = New-Object System.Drawing.Drawing2D.GraphicsPath
$d = 92; $w = $SZ - $d * 2; $rad = 96
$seal.AddArc($d, $d, $rad, $rad, 180, 90)
$seal.AddArc($d + $w - $rad, $d, $rad, $rad, 270, 90)
$seal.AddArc($d + $w - $rad, $d + $w - $rad, $rad, $rad, 0, 90)
$seal.AddArc($d, $d + $w - $rad, $rad, $rad, 90, 90)
$seal.CloseFigure()
$g.FillPath((Get-Grad 512 92 512 932 "#A8E7FF" "#3FAEE6"), $seal)
$p = Get-GlyphPath "阁" "SimHei" ([System.Drawing.FontStyle]::Regular) 580 512 512
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#07202F"))), $p)
Save-Icon "M3_yin_yangwen" $g $bmp

# ---------- M4 藏书印·阴文：只留一圈边框与字，最克制 ----------
$r = New-Canvas; $bmp = $r[0]; $g = $r[1]
$g.FillRectangle((Get-Grad 0 0 $SZ $SZ "#14486A" "#05151F"), 0, 0, $SZ, $SZ)
$pen = New-Object System.Drawing.Pen((Get-Grad 512 92 512 932 "#CDF4FF" "#5FC8F5")), 46
$pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawPath($pen, $seal)
$p = Get-GlyphPath "藏" "KaiTi" ([System.Drawing.FontStyle]::Regular) 520 512 516
$g.FillPath((Get-Grad 512 280 512 740 "#EAFBFF" "#7FDCFF"), $p)
Save-Icon "M4_yin_yinwen" $g $bmp

# ---------- M5 仿宋「阁」+ 一道书口：字是主角，书只做落款 ----------
$r = New-Canvas; $bmp = $r[0]; $g = $r[1]
$g.FillRectangle((Get-Grad 0 0 $SZ $SZ "#1B5F8C" "#061A27"), 0, 0, $SZ, $SZ)
$p = Get-GlyphPath "阁" "FangSong" ([System.Drawing.FontStyle]::Regular) 650 512 448
$g.FillPath((Get-Grad 512 160 512 760 "#EAFBFF" "#8FE0FF"), $p)
$g.FillRectangle((Get-Grad 512 800 512 860 "#8FE0FF" "#3FAEE6"), 300, 806, 424, 34)
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(70, 6, 26, 39))), 300, 834, 424, 8)
Save-Icon "M5_fangsong_ge" $g $bmp

# ---------- M6 黑体「藏」双色：横细竖粗的对比靠两层叠加做出来 ----------
$r = New-Canvas; $bmp = $r[0]; $g = $r[1]
$g.FillRectangle((Get-Grad 0 0 $SZ $SZ "#0B2B41" "#04121B"), 0, 0, $SZ, $SZ)
$p = Get-GlyphPath "藏" "Microsoft YaHei" ([System.Drawing.FontStyle]::Bold) 700 512 512
$g.FillPath((Get-Grad 512 150 512 880 "#CDF4FF" "#3FAEE6"), $p)
Save-Icon "M6_yahei_cang" $g $bmp

Write-Output "done"
