# scripts/thumbs.html 의 디자인을 JPG 썸네일로 저장 (images/thumbs/{id}_{lang}.jpg)
# 가로 1280x720, 's-'로 시작하는 Shorts는 세로 720x1280
# 실행: powershell -File scripts\build-thumbs.ps1   (일부만: -Ids "intro,s-wok" -Langs "ko")
param([string[]]$Ids = @("intro", "shenyang", "shanghai", "chuseok", "orion", "s-wok", "s-notes", "s-trophy", "s-katsu", "s-latte"),
      [string[]]$Langs = @("ko", "zh", "en", "ja"))
$Ids = $Ids -split ','; $Langs = $Langs -split ','
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
          "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
$out = Join-Path $root "images\thumbs"
$tmp = Join-Path $env:TEMP "thumb_render.png"
$page = "file:///" + ((Join-Path $PSScriptRoot "thumbs.html") -replace '\\', '/')
$jpg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 84L

foreach ($id in $Ids) {
    $size = if ($id -like "s-*") { "720,1280" } else { "1280,720" }
    foreach ($lang in $Langs) {
        & $edge --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files `
            --virtual-time-budget=10000 "--window-size=$size" "--screenshot=$tmp" "$page`?id=$id&lang=$lang" 2>$null | Out-Null
        $bmp = [System.Drawing.Bitmap]::FromFile($tmp)
        $dest = Join-Path $out "${id}_${lang}.jpg"
        $bmp.Save($dest, $jpg, $ep)
        $bmp.Dispose()
        Write-Output $dest
    }
}
Remove-Item $tmp -ErrorAction SilentlyContinue
