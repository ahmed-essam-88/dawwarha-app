import math, os
from PIL import Image, ImageDraw
M=1728; C=M/2
GREEN=(0x17,0x6B,0x45,255); LG=(0x83,0xC9,0x95,255); WHITE=(255,255,255,255)
def fg():
    im=Image.new('RGBA',(M,M),(0,0,0,0)); d=ImageDraw.Draw(im)
    r=420; w=104
    for k in range(3):
        a0=-90+k*120+14; a1=a0+92   # arc span in degrees (screen coords, clockwise)
        pts_o=[];pts_i=[]
        n=60
        for i in range(n+1):
            a=math.radians(a0+(a1-a0)*i/n)
            pts_o.append((C+(r+w/2)*math.cos(a),C+(r+w/2)*math.sin(a)))
            pts_i.append((C+(r-w/2)*math.cos(a),C+(r-w/2)*math.sin(a)))
        d.polygon(pts_o+pts_i[::-1],fill=WHITE)
        # arrowhead at a1, pointing clockwise (tangent)
        a=math.radians(a1); tx,ty=-math.sin(a),math.cos(a)
        bx,by=C+r*math.cos(a),C+r*math.sin(a)
        hw=w*1.05; hl=w*1.25
        p1=(bx+math.cos(a)*hw,by+math.sin(a)*hw); p2=(bx-math.cos(a)*hw,by-math.sin(a)*hw)
        p3=(bx+tx*hl,by+ty*hl)
        d.polygon([p1,p2,p3],fill=WHITE)
    # leaf: vesica shape rotated -45deg
    L=300; Wd=150
    pts=[]
    n=80
    # two arcs between tip points (0,-L) and (0,L), bulge +-Wd
    for i in range(n+1):
        t=i/n; y=-L+2*L*t; x=Wd*math.sin(math.pi*t)**0.85
        pts.append((x,y))
    for i in range(n,-1,-1):
        t=i/n; y=-L+2*L*t; x=-Wd*math.sin(math.pi*t)**0.85
        pts.append((x,y))
    ang=math.radians(40)
    def rot(p): return (C+p[0]*math.cos(ang)-p[1]*math.sin(ang), C+p[0]*math.sin(ang)+p[1]*math.cos(ang))
    d.polygon([rot(p) for p in pts],fill=LG)
    d.line([rot((0,-L*0.92)),rot((0,L*0.92))],fill=GREEN,width=22)
    for yy,s in [(-120,1),(10,1),(-120,-1),(10,-1)]:
        d.line([rot((0,yy+70)),rot((s*85,yy-5))],fill=GREEN,width=14)
    return im
F=fg()
def sz(im,px): return im.resize((px,px),Image.LANCZOS)
dens={'mdpi':1,'hdpi':1.5,'xhdpi':2,'xxhdpi':3,'xxxhdpi':4}
import sys
res=sys.argv[1] if len(sys.argv)>1 else os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','source','android','app','src','main','res')
import os
os.makedirs(res+'/mipmap-anydpi-v26',exist_ok=True); os.makedirs(res+'/values',exist_ok=True)
for k,s in dens.items():
    D=f'{res}/mipmap-{k}'
    sz(F,int(108*s)).save(f'{D}/ic_launcher_foreground.png')
    # legacy: rounded square (48dp)
    px=int(48*s); big=px*4
    bg=Image.new('RGBA',(big,big),(0,0,0,0)); ImageDraw.Draw(bg).rounded_rectangle([0,0,big-1,big-1],radius=int(big*0.18),fill=GREEN)
    sym=F.resize((int(big*108/48*0.0+big*1.5),)*2,Image.LANCZOS)  # adaptive 108dp layer -> content scale: symbol ~58% of 108 => scale to fill ~72% of 48
    sc=big*(108/72)/ M*M  # layer shown at 108/72*? keep simple below
    layer=F.resize((int(big*1.5),)*2,Image.LANCZOS); off=(big-layer.width)//2
    bg.alpha_composite(layer,(off,off)); out=bg.resize((px,px),Image.LANCZOS); out.save(f'{D}/ic_launcher.png')
    # round legacy
    rb=Image.new('RGBA',(big,big),(0,0,0,0)); ImageDraw.Draw(rb).ellipse([0,0,big-1,big-1],fill=GREEN)
    rb.alpha_composite(layer,(off,off))
    m=Image.new('L',(big,big),0); ImageDraw.Draw(m).ellipse([0,0,big-1,big-1],fill=255)
    rb.putalpha(Image.composite(rb.getchannel('A'),Image.new('L',(big,big),0),m)); rb.resize((px,px),Image.LANCZOS).save(f'{D}/ic_launcher_round.png')
open(res+'/values/ic_launcher_background.xml','w').write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#176B45</color>\n</resources>\n')
for n in ['ic_launcher','ic_launcher_round']:
    open(f'{res}/mipmap-anydpi-v26/{n}.xml','w').write('<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n    <background android:drawable="@color/ic_launcher_background"/>\n    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n</adaptive-icon>\n')
# proof sheet: adaptive masks at 432 foreground + small sizes
def mask(shape,px):
    m=Image.new('L',(px*4,px*4),0);d=ImageDraw.Draw(m);b=px*4
    if shape=='circle': d.ellipse([0,0,b-1,b-1],fill=255)
    elif shape=='squircle': d.rounded_rectangle([0,0,b-1,b-1],radius=int(b*0.34),fill=255)
    elif shape=='rounded': d.rounded_rectangle([0,0,b-1,b-1],radius=int(b*0.18),fill=255)
    elif shape=='square': d.rectangle([0,0,b-1,b-1],fill=255)
    return m.resize((px,px),Image.LANCZOS)
def adaptive(shape,px):
    L=int(px*108/72); lay=Image.new('RGBA',(L,L),GREEN); lay.alpha_composite(F.resize((L,L),Image.LANCZOS))
    o=(L-px)//2; c=lay.crop((o,o,o+px,o+px)); c.putalpha(mask(shape,px)); return c
sheet=Image.new('RGBA',(980,520),(236,236,236,255)); x=10
for sh in ['circle','squircle','rounded','square']:
    sheet.alpha_composite(adaptive(sh,192),(x,10)); x+=200
for i,px in enumerate([96,64,48,36]):
    sheet.alpha_composite(adaptive('circle',px),(10+i*110,230))
    sheet.alpha_composite(adaptive('squircle',px),(10+i*110,350))
leg=Image.open(f'{res}/mipmap-xxxhdpi/ic_launcher.png'); rd=Image.open(f'{res}/mipmap-xxxhdpi/ic_launcher_round.png')
sheet.alpha_composite(leg,(480,230)); sheet.alpha_composite(rd,(690,230))
sheet.alpha_composite(leg.resize((48,48),Image.LANCZOS),(480,430)); sheet.alpha_composite(rd.resize((48,48),Image.LANCZOS),(690,430))
os.makedirs('/downloads/shots',exist_ok=True); sheet.convert('RGB').save('/downloads/shots/icon_proof.png')
