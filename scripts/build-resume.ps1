# index.html 의 인쇄용 스타일로 언어별 이력서 PDF를 만든다.
# 페이지 내용을 바꾼 뒤 다시 실행:  powershell -File scripts\build-resume.ps1
$root = Split-Path $PSScriptRoot -Parent
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
          "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
$out = Join-Path $root "resume"
New-Item -ItemType Directory -Force $out | Out-Null
$page = "file:///" + ((Join-Path $root "index.html") -replace '\\', '/')

foreach ($lang in "ko", "zh", "en", "ja") {
    $pdf = Join-Path $out "KIMSEOYEON_resume_$lang.pdf"
    & $edge --headless=new --disable-gpu --no-pdf-header-footer --virtual-time-budget=8000 `
        "--print-to-pdf=$pdf" "$page`?lang=$lang" 2>$null | Out-Null
    Write-Output "$lang -> $pdf"
}
