# 흰 배경 증명사진에서 배경을 지워 투명 PNG로 저장 (가장자리부터 흰색 영역만 채우기 방식)
param([string]$In, [string]$Out, [int]$Min = 228)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Collections.Generic;
public static class Cutout {
  public static void Run(string inPath, string outPath, int min) {
    var src = new Bitmap(inPath);
    int w = src.Width, h = src.Height;
    var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(bmp)) g.DrawImage(src, 0, 0, w, h);
    src.Dispose();
    var data = bmp.LockBits(new Rectangle(0,0,w,h), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    var px = new byte[w*h*4];
    System.Runtime.InteropServices.Marshal.Copy(data.Scan0, px, 0, px.Length);
    var bg = new bool[w*h];
    var q = new Queue<int>();
    Func<int,bool> white = i => { byte b=px[i*4], gg=px[i*4+1], r=px[i*4+2]; int mn=Math.Min(r,Math.Min(gg,b)), mx=Math.Max(r,Math.Max(gg,b)); return mn>=min && mx-mn<28; };
    // 위·왼쪽·오른쪽 가장자리에서 시작 (아래쪽은 옷이라 제외)
    for (int x=0;x<w;x++){ int i=x; if(white(i)){bg[i]=true;q.Enqueue(i);} }
    for (int y=0;y<h;y++){ foreach (int x in new[]{0,w-1}){ int i=y*w+x; if(!bg[i]&&white(i)){bg[i]=true;q.Enqueue(i);} } }
    while(q.Count>0){ int i=q.Dequeue(); int x=i%w, y=i/w;
      foreach (var d in new[]{-1,1,-w,w}) { int j=i+d; if(j<0||j>=w*h) continue; if((d==-1&&x==0)||(d==1&&x==w-1)) continue;
        if(!bg[j]&&white(j)){bg[j]=true;q.Enqueue(j);} } }
    // 경계 부드럽게: 주변 3x3 배경 비율로 알파
    var a = new byte[w*h];
    for (int y=0;y<h;y++) for (int x=0;x<w;x++){ int n=0,c=0;
      for(int dy=-1;dy<=1;dy++) for(int dx=-1;dx<=1;dx++){ int xx=x+dx, yy=y+dy; if(xx<0||yy<0||xx>=w||yy>=h) continue; n++; if(bg[yy*w+xx]) c++; }
      a[y*w+x] = (byte)(255 - 255*c/n); }
    for (int i=0;i<w*h;i++) px[i*4+3]=a[i];
    System.Runtime.InteropServices.Marshal.Copy(px, 0, data.Scan0, px.Length);
    bmp.UnlockBits(data);
    bmp.Save(outPath, ImageFormat.Png);
    bmp.Dispose();
  }
}
"@
[Cutout]::Run($In, $Out, $Min)
