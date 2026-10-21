# 자기소개서 + 기존 포트폴리오 + 채널 포트폴리오를 HTML 파일 하나로 묶는다 (인터넷 없이도 열림)
# - 사진·슬라이드·PDF: base64로 파일 안에 넣고, 실행할 때 blob URL로 바꿔 끼움
# - 글꼴: scripts\build-fonts.ps1 로 만든 서브셋 글꼴(fonts.css)을 넣음
# - 두 포트폴리오: 파일 안에 base64로 넣고, 탭을 누르면 iframe(blob)으로 띄움
# 실행: powershell -File scripts\build-standalone.ps1 [-Out 경로]
param([string]$Out = "")
$root = Split-Path $PSScriptRoot -Parent
if (-not $Out) { $Out = Join-Path ([Environment]::GetFolderPath('Desktop')) "김서연_포트폴리오.html" }
$fontCss = Join-Path $PSScriptRoot ".cache\fonts.css"
if (-not (Test-Path $fontCss)) { & (Join-Path $PSScriptRoot "build-fonts.ps1") | Out-Null }
$utf8 = New-Object Text.UTF8Encoding $false
$read = { param($p) [IO.File]::ReadAllText((Join-Path $root $p), [Text.Encoding]::UTF8) }

# 실행 시 경로를 blob URL로 바꿔 주는 코드 (세 문서 공통)
$resolver = @'
<script>
function __installResolver(assets, fontCss) {
  if (window.__resolverOn) return; window.__resolverOn = true;
  const st = document.createElement("style"); st.textContent = fontCss; document.head.appendChild(st);
  const cache = {};
  const norm = p => p.replace(/^(\.\.\/|\.\/)+/, "").split(/[?#]/)[0];
  const blobUrl = p => {
    const k = norm(p), a = assets[k]; if (!a) return null;
    if (cache[k]) return cache[k];
    const bin = atob(a[1]), u8 = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
    return cache[k] = URL.createObjectURL(new Blob([u8], { type: a[0] }));
  };
  const HAS = /(images|presentations|resume)\//, RX = /(?:\.\.\/|\.\/)*(?:images|presentations|resume)\/[^"')\s?#]+/g;
  const fix = el => {
    if (!el.getAttribute) return;
    for (const at of ["src", "href"]) {
      const v = el.getAttribute(at);
      if (v && !v.startsWith("blob:") && !v.startsWith("http") && HAS.test(v)) { const u = blobUrl(v); if (u) el.setAttribute(at, u); }
    }
    const s = el.getAttribute("style");
    if (s && HAS.test(s)) el.setAttribute("style", s.replace(RX, m => blobUrl(m) || m));
  };
  const walk = n => { if (n.nodeType !== 1) return; fix(n); n.querySelectorAll("[src],[href],[style]").forEach(fix); };
  walk(document.documentElement);
  new MutationObserver(ms => { for (const m of ms) { if (m.type === "attributes") fix(m.target); else m.addedNodes.forEach(walk); } })
    .observe(document.documentElement, { subtree: true, childList: true, attributes: true, attributeFilter: ["src", "href", "style"] });
}
</script>
'@

function Prep([string]$html) {
  # 외부 글꼴 링크 제거 (글꼴은 파일 안에 들어 있음)
  $html = [regex]::Replace($html, '\s*<link rel="preconnect"[^>]*>', '')
  $html = [regex]::Replace($html, '\s*<link href="https://fonts\.googleapis\.com[^>]*>', '')
  return $html
}

# 1) 두 포트폴리오: 언어는 window.__LANG 으로 받고, 부모가 보내 주는 사진·글꼴을 받아 설치
$child = @'
<script>
// 바깥 문서(자기소개서)에 들어 있는 사진·글꼴을 가져와 설치
(function () {
  const go = () => { try { const p = window.parent; if (p && p !== window && p.__ASSETS) __installResolver(p.__ASSETS, p.__FONT); } catch (e) {} };
  go(); document.addEventListener("DOMContentLoaded", go);
  window.addEventListener("message", e => { if (e.data && e.data.__assets) __installResolver(e.data.__assets, e.data.__font); });
})();
</script>
'@
$tpl = @{}
foreach ($k in @(@("classic", "index.html"), @("channel", "channel\index.html"))) {
  $h = Prep (& $read $k[1])
  $h = $h.Replace('let saved = new URLSearchParams(location.search).get("lang");', 'let saved = window.__LANG || new URLSearchParams(location.search).get("lang");')
  $h = $h.Replace('<head>', "<head>`n$resolver`n$child")
  $tpl[$k[0]] = [Convert]::ToBase64String($utf8.GetBytes($h))
}

# 2) 사진·슬라이드·PDF 모음
$mime = @{ ".jpg" = "image/jpeg"; ".jpeg" = "image/jpeg"; ".png" = "image/png"; ".pdf" = "application/pdf"; ".svg" = "image/svg+xml"; ".gif" = "image/gif" }
$sb = New-Object Text.StringBuilder
[void]$sb.Append("{")
$first = $true; $count = 0
foreach ($dir in "images", "presentations", "resume") {
  Get-ChildItem (Join-Path $root $dir) -Recurse -File | Where-Object { $mime.ContainsKey($_.Extension.ToLower()) -and $_.Name -ne "profile_original.png" } | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
    if (-not $first) { [void]$sb.Append(",") }; $first = $false
    [void]$sb.Append('"' + $rel + '":["' + $mime[$_.Extension.ToLower()] + '","' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName)) + '"]')
    $count++
  }
}
[void]$sb.Append("}")

# 3) 자기소개서(맨 바깥 문서)
$top = Prep (& $read "cover-letter\index.html")
$top = $top.Replace('fr.src = PANEL_SRC[k] + "?lang=" + lang', 'fr.srcdoc = __panelUrl(k, lang)').Replace('if (fr.src) fr.srcdoc', 'if (fr.srcdoc) fr.srcdoc').Replace('&& !fr.src)', '&& !fr.srcdoc)')
$boot = @'
<script>
// 파일 안에 넣어 둔 자료
window.__ASSETS = JSON.parse(document.getElementById("__assets").textContent);
window.__FONT = document.getElementById("__fontcss").textContent;
__installResolver(__ASSETS, __FONT);
function __panelUrl(k, lang) {
  const b64 = document.getElementById("tpl-" + k).textContent.trim();
  const bytes = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
  const html = new TextDecoder().decode(bytes).replace("<head>", "<head><script>window.__LANG=" + JSON.stringify(lang) + ";<\/script>");
  return html;
}

</script>
'@
$data = "<script type=`"application/json`" id=`"__assets`">" + $sb.ToString() + "</script>`n" +
        "<script type=`"text/plain`" id=`"__fontcss`">" + [IO.File]::ReadAllText($fontCss, [Text.Encoding]::UTF8) + "</script>`n" +
        "<script type=`"text/plain`" id=`"tpl-classic`">" + $tpl["classic"] + "</script>`n" +
        "<script type=`"text/plain`" id=`"tpl-channel`">" + $tpl["channel"] + "</script>`n"
$top = $top.Replace('<head>', "<head>`n$resolver")
# 자료와 부팅 코드는 페이지 스크립트보다 먼저 실행되도록 <body> 바로 뒤에
$top = $top.Replace('<body>', "<body>`n$data$boot")
[IO.File]::WriteAllText($Out, $top, $utf8)
Write-Output ("{0}: {1:N1} MB, assets {2}" -f $Out, ((Get-Item $Out).Length / 1MB), $count)
