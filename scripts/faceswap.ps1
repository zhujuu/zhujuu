# 일상 사진(me.jpg)의 얼굴을 증명사진(profile_original.png)에 맞춰 합성 → images/profile.png
# 두 눈 좌표로 회전·크기·위치를 맞추고, 타원 마스크 경계를 부드럽게 섞고, 피부 톤을 증명사진에 맞춤
param(
  [string]$Src = "C:\Users\SY\my-intro\images\china\me.jpg",
  [string]$Dst = "C:\Users\SY\my-intro\images\profile_original.png",
  [string]$Out = "C:\Users\SY\my-intro\images\profile.png",
  [double[]]$SrcEyes = @(542, 647, 630, 627),   # 왼눈 x,y / 오른눈 x,y (원본 좌표)
  [double[]]$DstEyes = @(152, 180, 246, 180),
  [double[]]$Ellipse = @(199, 236, 66, 104),      # 합성 영역 중심 x,y / 반지름 x,y
  [double]$ToneMix = 0.85                        # 일상 사진 이목구비 세부를 얼마나 살릴지
)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Drawing2D; using System.Drawing.Imaging;
public static class FaceSwap {
  public static void Run(string src, string dst, string outp, double[] se, double[] de, double[] el, double mix) {
    var S = new Bitmap(src); var D = new Bitmap(dst); int w = D.Width, h = D.Height;
    double sdx = se[2]-se[0], sdy = se[3]-se[1], ddx = de[2]-de[0], ddy = de[3]-de[1];
    double scale = Math.Sqrt(ddx*ddx+ddy*ddy) / Math.Sqrt(sdx*sdx+sdy*sdy);
    double ang = Math.Atan2(ddy, ddx) - Math.Atan2(sdy, sdx);
    double smx = (se[0]+se[2])/2, smy = (se[1]+se[3])/2, dmx = (de[0]+de[2])/2, dmy = (de[1]+de[3])/2;
    var warped = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(warped)) {
      g.InterpolationMode = InterpolationMode.HighQualityBicubic;
      var m = new Matrix();
      m.Translate((float)dmx, (float)dmy);
      m.Rotate((float)(ang * 180 / Math.PI));
      m.Scale((float)scale, (float)scale);
      m.Translate((float)-smx, (float)-smy);
      g.Transform = m; g.DrawImage(S, 0, 0, S.Width, S.Height);
    }
    // 주파수 분리: 일상 사진에서는 이목구비(세부)만, 조명·피부색(저주파)은 증명사진 것을 사용
    int[] radius = { 16 };
    Func<Bitmap, double[,,]> toArr = bm => { var a = new double[h,w,3]; for (int y=0;y<h;y++) for (int x=0;x<w;x++){ var c = bm.GetPixel(x,y); a[y,x,0]=c.R; a[y,x,1]=c.G; a[y,x,2]=c.B; } return a; };
    Func<double[,,], int, double[,,]> blur = (a, r) => {
      var cur = a;
      for (int pass = 0; pass < 3; pass++) {
        var tmp = new double[h,w,3]; var o2 = new double[h,w,3];
        for (int y=0;y<h;y++) for (int k=0;k<3;k++){ double s=0; int cnt=0; for (int x=-r;x<=r;x++){ if(x>=0&&x<w){s+=cur[y,x,k];cnt++;} }
          for (int x=0;x<w;x++){ tmp[y,x,k]=s/cnt; int xo=x-r, xi=x+r+1; if(xo>=0){s-=cur[y,xo,k];cnt--;} if(xi<w){s+=cur[y,xi,k];cnt++;} } }
        for (int x=0;x<w;x++) for (int k=0;k<3;k++){ double s=0; int cnt=0; for (int y=-r;y<=r;y++){ if(y>=0&&y<h){s+=tmp[y,x,k];cnt++;} }
          for (int y=0;y<h;y++){ o2[y,x,k]=s/cnt; int yo=y-r, yi=y+r+1; if(yo>=0){s-=tmp[yo,x,k];cnt--;} if(yi<h){s+=tmp[yi,x,k];cnt++;} } }
        cur = o2;
      }
      return cur;
    };
    var A = toArr(warped); var B = toArr(D);
    var Ab = blur(A, radius[0]); var Bb = blur(B, radius[0]);
    var R = new Bitmap(w, h);
    Func<double,int> cl = v => (int)Math.Max(0, Math.Min(255, v));
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
      var b = D.GetPixel(x,y);
      double dx = (x-el[0])/el[2], dy = (y-el[1])/el[3], d = Math.Sqrt(dx*dx+dy*dy);
      double al = d < 0.7 ? 1 : d > 1 ? 0 : (1-d)/0.3; al = al*al*(3-2*al);
      al *= warped.GetPixel(x,y).A / 255.0;
      if (al <= 0) { R.SetPixel(x,y,b); continue; }
      var o = new double[3];
      for (int k=0;k<3;k++) o[k] = Bb[y,x,k] + (A[y,x,k] - Ab[y,x,k]) * mix;
      R.SetPixel(x,y, Color.FromArgb(cl(b.R + (o[0]-b.R)*al), cl(b.G + (o[1]-b.G)*al), cl(b.B + (o[2]-b.B)*al)));
    }    R.Save(outp, ImageFormat.Png);
    S.Dispose(); D.Dispose(); warped.Dispose(); R.Dispose();
  }
}
"@
[FaceSwap]::Run($Src, $Dst, $Out, $SrcEyes, $DstEyes, $Ellipse, $ToneMix)
