# 사이트에 실제로 쓰인 글자만 담은 웹폰트를 Google Fonts에서 받아 @font-face CSS(데이터 URI)로 만든다.
# 결과: $Out (기본: scripts\.cache\fonts.css). 내려받은 조각은 같은 폴더에 캐시한다.
param([string]$Out = "")
$root = Split-Path $PSScriptRoot -Parent
$cache = Join-Path $PSScriptRoot ".cache\fonts"; New-Item -ItemType Directory -Force $cache | Out-Null
if (-not $Out) { $Out = Join-Path $PSScriptRoot ".cache\fonts.css" }

# 1) 세 페이지에 나오는 모든 글자 모으기
$text = ""
foreach ($f in "index.html", "channel\index.html", "cover-letter\index.html") { $text += [IO.File]::ReadAllText((Join-Path $root $f), [Text.Encoding]::UTF8) }
$chars = New-Object 'System.Collections.Generic.SortedSet[int]'
for ($i = 0; $i -lt $text.Length; $i++) {
  $c = [int]$text[$i]
  if ([char]::IsHighSurrogate($text[$i])) { $i++; continue }
  if ($c -ge 32) { [void]$chars.Add($c) }
}
$hangul = @(); $kana = @(); $han = @(); $other = @()
foreach ($c in $chars) {
  if (($c -ge 0xAC00 -and $c -le 0xD7A3) -or ($c -ge 0x3130 -and $c -le 0x318F) -or ($c -ge 0x1100 -and $c -le 0x11FF)) { $hangul += $c }
  elseif (($c -ge 0x3040 -and $c -le 0x30FF) -or ($c -ge 0x31F0 -and $c -le 0x31FF) -or ($c -ge 0xFF66 -and $c -le 0xFF9F)) { $kana += $c }
  elseif (($c -ge 0x4E00 -and $c -le 0x9FFF) -or ($c -ge 0x3400 -and $c -le 0x4DBF) -or ($c -ge 0xF900 -and $c -le 0xFAFF)) { $han += $c }
  else { $other += $c }
}
Write-Output ("chars: hangul {0}, kana {1}, han {2}, other {3}" -f $hangul.Count, $kana.Count, $han.Count, $other.Count)

# 2) 글꼴별로 필요한 글자 묶음
$sets = @{
  kr = $hangul + $han + $other; sc = $han + $other; jp = $kana + $han + $other; latin = $other
}
$fonts = @(
  @("Noto Sans KR", @(400,500,700,900), "kr"), @("Noto Sans SC", @(400,500,700,900), "sc"), @("Noto Sans JP", @(400,500,700,900), "jp"),
  @("Noto Serif KR", @(700), "kr"), @("Noto Serif SC", @(700), "sc"), @("Noto Serif JP", @(700), "jp"),
  @("Black Han Sans", @(400), "kr"), @("Gowun Batang", @(700), "kr"), @("Ma Shan Zheng", @(400), "sc"),
  @("Poppins", @(500,600,700), "latin"), @("Playfair Display", @(700), "latin")
)

$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
$wc = New-Object System.Net.WebClient
$css = New-Object System.Text.StringBuilder
$chunk = 120
foreach ($f in $fonts) {
  $fam = $f[0]; $set = $sets[$f[2]]
  foreach ($wt in $f[1]) {
    for ($s = 0; $s -lt $set.Count; $s += $chunk) {
      $part = $set[$s..([Math]::Min($s + $chunk, $set.Count) - 1)]
      $str = -join ($part | ForEach-Object { [char]$_ })
      $key = "{0}_{1}_{2}" -f ($fam -replace ' ', ''), $wt, ([BitConverter]::ToString((New-Object Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([Text.Encoding]::UTF8.GetBytes($str))) -replace '-', '').Substring(0, 12)
      $file = Join-Path $cache "$key.woff2"
      if (-not (Test-Path $file)) {
        $url = "https://fonts.googleapis.com/css2?family=" + ($fam -replace ' ', '+') + ":wght@$wt&text=" + [Uri]::EscapeDataString($str)
        $wc.Headers["User-Agent"] = $ua
        try { $resp = $wc.DownloadString($url) } catch { Write-Output "skip $fam $wt ($($_.Exception.Message))"; continue }
        $m = [regex]::Match($resp, 'url\((https://[^)]+)\)')
        if (-not $m.Success) { continue }
        $wc.Headers["User-Agent"] = $ua
        try { $wc.DownloadFile($m.Groups[1].Value, $file) } catch { Write-Output "fail $fam $wt"; continue }
      }
      $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($file))
      $range = ($part | ForEach-Object { "U+{0:X}" -f $_ }) -join ","
      [void]$css.AppendLine("@font-face{font-family:'$fam';font-style:normal;font-weight:$wt;font-display:block;src:url(data:font/woff2;base64,$b64) format('woff2');unicode-range:$range;}")
    }
    Write-Output "$fam $wt done"
  }
}
[IO.File]::WriteAllText($Out, $css.ToString(), (New-Object Text.UTF8Encoding $false))
Write-Output ("fonts.css {0:N1} MB" -f ((Get-Item $Out).Length / 1MB))
