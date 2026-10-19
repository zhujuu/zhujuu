# 사용자 사진 정리: EXIF 회전 바로잡기 → 긴 변 1600px로 축소 → 인물 얼굴 모자이크 → images/china/*.jpg
# 박스 좌표는 '미리보기 크기'(긴 변 2000px, 원본이 더 작으면 원본) 기준 x,y,w,h
param([string]$Src = "C:\Users\SY\AppData\Local\Temp\claude\C--Users-SY\7b50e9f6-e9b2-4c26-a809-375f4a6adeb8\images")
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Linq;
public static class Photo {
  public static void Run(string inPath, string outPath, int maxSide, string spec) {
    var boxes = spec.Split(new[]{';'}, StringSplitOptions.RemoveEmptyEntries).Select(q => q.Split(',').Select(int.Parse).ToArray()).ToArray();
    var img = Image.FromFile(inPath);
    if (img.PropertyIdList.Contains(0x0112)) {
      int o = img.GetPropertyItem(0x0112).Value[0];
      RotateFlipType t = RotateFlipType.RotateNoneFlipNone;
      if (o == 2) t = RotateFlipType.RotateNoneFlipX; else if (o == 3) t = RotateFlipType.Rotate180FlipNone;
      else if (o == 4) t = RotateFlipType.Rotate180FlipX; else if (o == 5) t = RotateFlipType.Rotate90FlipX;
      else if (o == 6) t = RotateFlipType.Rotate90FlipNone; else if (o == 7) t = RotateFlipType.Rotate270FlipX;
      else if (o == 8) t = RotateFlipType.Rotate270FlipNone;
      img.RotateFlip(t);
    }
    int W = img.Width, H = img.Height, M = Math.Max(W, H);
    int target = Math.Min(maxSide, M);
    double disp = Math.Min(2000, M);
    double s = (double)target / M, f = target / disp;
    int w = (int)Math.Round(W * s), h = (int)Math.Round(H * s);
    var bmp = new Bitmap(w, h, PixelFormat.Format24bppRgb);
    using (var g = Graphics.FromImage(bmp)) { g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic; g.DrawImage(img, 0, 0, w, h); }
    img.Dispose();
    foreach (var b in boxes) {
      // 자연스러운 흐림: 영역을 작게 줄였다 키워 부드럽게 흐리고, 타원 경계를 서서히 섞음
      int x0 = Math.Max(0, (int)(b[0] * f)), y0 = Math.Max(0, (int)(b[1] * f));
      int x1 = Math.Min(w, (int)((b[0] + b[2]) * f)), y1 = Math.Min(h, (int)((b[1] + b[3]) * f));
      int bw = x1 - x0, bh = y1 - y0; if (bw < 4 || bh < 4) continue;
      var crop = bmp.Clone(new Rectangle(x0, y0, bw, bh), PixelFormat.Format24bppRgb);
      int sw = Math.Max(2, bw / 32), sh = Math.Max(2, bh / 32);
      var small = new Bitmap(sw, sh);
      using (var g = Graphics.FromImage(small)) { g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBilinear; g.DrawImage(crop, 0, 0, sw, sh); }
      var blur = new Bitmap(bw, bh);
      using (var g = Graphics.FromImage(blur)) { g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half; g.DrawImage(small, new Rectangle(0, 0, bw, bh)); }
      for (int y = 0; y < bh; y++) for (int x = 0; x < bw; x++) {
        double dx = (x - bw / 2.0) / (bw / 2.0), dy = (y - bh / 2.0) / (bh / 2.0);
        double d = Math.Sqrt(dx * dx + dy * dy);
        double a = d < 0.85 ? 1 : d > 1.05 ? 0 : (1.05 - d) / 0.2;
        if (a <= 0) continue;
        var o = bmp.GetPixel(x0 + x, y0 + y); var c = blur.GetPixel(x, y);
        bmp.SetPixel(x0 + x, y0 + y, Color.FromArgb((int)(o.R + (c.R - o.R) * a), (int)(o.G + (c.G - o.G) * a), (int)(o.B + (c.B - o.B) * a)));
      }
      crop.Dispose(); small.Dispose(); blur.Dispose();
    }    var enc = ImageCodecInfo.GetImageEncoders().First(e => e.MimeType == "image/jpeg");
    var ep = new EncoderParameters(1); ep.Param[0] = new EncoderParameter(Encoder.Quality, 82L);
    bmp.Save(outPath, enc, ep); bmp.Dispose();
  }
}
"@
$out = "C:\Users\SY\my-intro\images\china"; New-Item -ItemType Directory -Force $out | Out-Null
$P = [ordered]@{
  "28" = @("guangzhou", @())
  "29" = @("nanjing", @())
  "30" = @("dalian", @())
  "31" = @("cert2", @(@(760,560,350,440)))
  "32" = @("xiamen", @())
  "33" = @("shunde", @())
  "34" = @("shenzhen", @())
  "35" = @("bund", @(@(0,1360,2000,140), @(420,1290,230,210)))
  "36" = @("suzhou", @())
  "37" = @("wuxi", @())
  "38" = @("jiaxing", @())
  "39" = @("zhengzhou", @())
  "40" = @("zhuhai", @())
  "41" = @("changsha", @())
  "42" = @("cert1", @())
  "43" = @("chengdu", @())
  "44" = @("chongqing", @())
  "45" = @("taizhou", @())
  "55" = @("me", @())
  "46" = @("classmates", @(@(0,360,210,240), @(450,200,170,200), @(830,30,190,240), @(1290,170,170,200), @(1600,220,250,300) ))
  "47" = @("hangzhou", @(@(560,800,940,480)))
  "48" = @("sy_friends", @(@(370,580,230,270), @(790,740,220,250), @(1040,930,170,170)))
  "49" = @("sy_birthday", @(@(480,450,240,280), @(690,510,150,200), @(910,700,160,230), @(1290,540,140,190)))
  "50" = @("sy_dinner", @(@(370,440,200,270), @(1150,450,170,210)))
  "51" = @("sy_ski", @(@(440,920,110,140), @(630,870,130,160), @(830,900,130,170)))
  "52" = @("sy_love", @())
  "53" = @("sy_cafe", @(@(290,350,230,290), @(430,110,230,280), @(1200,230,190,230), @(620,480,540,560)))
}
foreach ($k in $P.Keys) {
  $name = $P[$k][0]; $v = $P[$k][1]; if ($v.Count -gt 0 -and $v[0] -is [int]) { $v = ,$v }; $boxes = ($v | ForEach-Object { $_ -join "," }) -join ";"
  [Photo]::Run("$Src\$k.$(if (Test-Path "$Src\$k.jpg") {'jpg'} else {'png'})", "$out\$name.jpg", 1600, $boxes)
  Write-Output "$k -> $name"
}
