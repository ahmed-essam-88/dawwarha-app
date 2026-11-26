import json,urllib.request,io,os
from concurrent.futures import ThreadPoolExecutor
from PIL import Image
sel=json.load(open('sel.json'))
items=[(s,k) for s in sel for k in sel[s]]
def f(a):
    s,k=a; p=f'img/{k}.jpg'
    if os.path.exists(p): return 1
    try:
        d=urllib.request.urlopen(f'https://open-images-dataset.s3.amazonaws.com/{s}/{k}.jpg',timeout=30).read()
        im=Image.open(io.BytesIO(d)).convert('RGB'); im.thumbnail((320,320)); im.save(p,quality=90); return 1
    except Exception as e: return 0
with ThreadPoolExecutor(16) as ex: r=list(ex.map(f,items))
print(sum(r),len(r))
