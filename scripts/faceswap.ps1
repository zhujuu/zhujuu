# 일상 사진(me.jpg)의 얼굴을 증명사진(profile_original.png)에 맞춰 합성 → images/profile.png
# 두 눈 좌표로 회전·크기·위치를 맞추고, 타원 마스크 경계를 부드럽게 섞고, 피부 톤을 증명사진에 맞춤
param(
  [string]$Src = "C:\Users\SY\my-intro\images\china\me.jpg",
  [string]$Dst = "C:\Users\SY\my-intro\images\profile_original.png",
  [string]$Out = "C:\Users\SY\my-intro\images\profile.png",
  [double[]]$SrcEyes = @(542.5, 648.5, 629, 626.5),   # 왼눈 x,y / 오른눈 x,y (원본 좌표)
  [double[]]$DstEyes = @(153, 181, 242, 180),
  [double[]]$Landmarks = @(600, 705, 616, 731, 200, 252, 200, 290),  # 원본 코·입, 증명사진 코·입
  [double[]]$Ellipse = @(197, 181, 80, 30, 200, 292, 46, 24),  # 눈 영역 x,y,rx,ry / 입 영역 x,y,rx,ry
  [double]$ToneMix = 0.85                        # 일상 사진 이목구비 세부를 얼마나 살릴지
)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Drawing2D; using System.Drawing.Imaging;
public static class FaceSwap {
  public static void Run(string src, string dst, string outp, double[] se, double[] de, double[] el, double mix, double[] lm) {
    var S = new Bitmap(src); var D = new Bitmap(dst); int w = D.Width, h = D.Height;
    // 눈·코·입 세 기준점으로 맞추는 워프: 각 사진의 '눈 기준 좌표계'에서 세로 위치를 구간별로 맞춤
    double sMx=(se[0]+se[2])/2, sMy=(se[1]+se[3])/2, dMx=(de[0]+de[2])/2, dMy=(de[1]+de[3])/2;
    double sA=Math.Atan2(se[3]-se[1], se[2]-se[0]), dA=Math.Atan2(de[3]-de[1], de[2]-de[0]);
    double sD=Math.Sqrt(Math.Pow(se[2]-se[0],2)+Math.Pow(se[3]-se[1],2)), dD=Math.Sqrt(Math.Pow(de[2]-de[0],2)+Math.Pow(de[3]-de[1],2));
    Func<double,double,double,double,double,double,double[]> rel = (px,py,mx,my,an,dd) => { double x=px-mx, y=py-my; return new[]{ (x*Math.Cos(an)+y*Math.Sin(an))/dd, (-x*Math.Sin(an)+y*Math.Cos(an))/dd }; };
    var sN = rel(lm[0],lm[1],sMx,sMy,sA,sD); var sMo = rel(lm[2],lm[3],sMx,sMy,sA,sD);
    var dN = rel(lm[4],lm[5],dMx,dMy,dA,dD); var dMo = rel(lm[6],lm[7],dMx,dMy,dA,dD);
    var warped = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    int SW=S.Width, SH=S.Height;
    for (int y=0;y<h;y++) for (int x=0;x<w;x++) {
      var r = rel(x,y,dMx,dMy,dA,dD); double u=r[0], v=r[1], v2, du;
      if (v <= 0) { v2 = v; du = 0; }
      else if (v <= dN[1]) { double k=v/dN[1]; v2 = k*sN[1]; du = k*(sN[0]-dN[0]); }
      else if (v <= dMo[1]) { double k=(v-dN[1])/(dMo[1]-dN[1]); v2 = sN[1]+k*(sMo[1]-sN[1]); du = (sN[0]-dN[0])+k*((sMo[0]-dMo[0])-(sN[0]-dN[0])); }
      else { v2 = sMo[1] + (v-dMo[1]); du = sMo[0]-dMo[0]; }
      double u2 = u + du;
      double sx = sMx + sD*(u2*Math.Cos(sA) - v2*Math.Sin(sA)), sy = sMy + sD*(u2*Math.Sin(sA) + v2*Math.Cos(sA));
      if (sx<0||sy<0||sx>=SW-1||sy>=SH-1) continue;
      int ix=(int)sx, iy=(int)sy; double fx=sx-ix, fy=sy-iy;
      var c00=S.GetPixel(ix,iy); var c10=S.GetPixel(ix+1,iy); var c01=S.GetPixel(ix,iy+1); var c11=S.GetPixel(ix+1,iy+1);
      Func<int,int,int,int,int> bl = (p00,p10,p01,p11) => (int)Math.Round(p00*(1-fx)*(1-fy)+p10*fx*(1-fy)+p01*(1-fx)*fy+p11*fx*fy);
      warped.SetPixel(x,y, Color.FromArgb(255, bl(c00.R,c10.R,c01.R,c11.R), bl(c00.G,c10.G,c01.G,c11.G), bl(c00.B,c10.B,c01.B,c11.B)));
    }    // 주파수 분리: 일상 사진에서는 이목구비(세부)만, 조명·피부색(저주파)은 증명사진 것을 사용
    int[] radius = { 14 };
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
    Func<int,int,double> alpha = (x, y) => {
      Func<double,double,double,double,double> ea = (cx,cy,rx,ry) => { double ddx=(x-cx)/rx, ddy=(y-cy)/ry, dd=Math.Sqrt(ddx*ddx+ddy*ddy); double q = dd < 0.55 ? 1 : dd > 1 ? 0 : (1-dd)/0.45; return q*q*(3-2*q); };
      return Math.Max(ea(el[0],el[1],el[2],el[3]), ea(el[4],el[5],el[6],el[7]));
    };
    // 색 맞추기: 합성 영역의 고리(가장자리) 피부 평균·표준편차를 증명사진에 맞춤
    double[] mA = new double[3], mB = new double[3], sA2 = new double[3], sB2 = new double[3]; int nPix = 0;
    for (int y=0;y<h;y++) for (int x=0;x<w;x++){ double q = alpha(x,y); if (q < 0.05 || q > 0.6) continue; for(int k=0;k<3;k++){ mA[k]+=A[y,x,k]; mB[k]+=B[y,x,k]; } nPix++; }
    for (int k=0;k<3;k++){ mA[k]/=nPix; mB[k]/=nPix; }
    for (int y=0;y<h;y++) for (int x=0;x<w;x++){ double q = alpha(x,y); if (q < 0.05 || q > 0.6) continue; for(int k=0;k<3;k++){ sA2[k]+=Math.Pow(A[y,x,k]-mA[k],2); sB2[k]+=Math.Pow(B[y,x,k]-mB[k],2); } }
    double[] gn = new double[3]; for (int k=0;k<3;k++) gn[k] = Math.Sqrt(sB2[k]/nPix) / Math.Max(1, Math.Sqrt(sA2[k]/nPix));
    for (int k=0;k<3;k++) gn[k] = Math.Max(0.7, Math.Min(1.3, gn[k]));
    var R = new Bitmap(w, h);
    Func<double,int> cl = v => (int)Math.Max(0, Math.Min(255, v));
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
      var b = D.GetPixel(x,y); double al = alpha(x,y) * warped.GetPixel(x,y).A / 255.0;
      if (al <= 0) { R.SetPixel(x,y,b); continue; }
      double det = 0.299*(A[y,x,0]-Ab[y,x,0]) + 0.587*(A[y,x,1]-Ab[y,x,1]) + 0.114*(A[y,x,2]-Ab[y,x,2]);
      var o = new double[3]; for (int k=0;k<3;k++) o[k] = Bb[y,x,k] + det * mix * 1.15;
      R.SetPixel(x,y, Color.FromArgb(cl(b.R + (o[0]-b.R)*al), cl(b.G + (o[1]-b.G)*al), cl(b.B + (o[2]-b.B)*al)));
    }    R.Save(outp, ImageFormat.Png);
    S.Dispose(); D.Dispose(); warped.Dispose(); R.Dispose();
  }
}
"@
[FaceSwap]::Run($Src, $Dst, $Out, $SrcEyes, $DstEyes, $Ellipse, $ToneMix, $Landmarks)
