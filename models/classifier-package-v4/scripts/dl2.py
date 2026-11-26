import json,csv,urllib.request,io,os
from concurrent.futures import ThreadPoolExecutor
from PIL import Image
sel=json.load(open('sel.json'))['train']
th={r[0]:r[10] for r in csv.reader(open('train-img-sel.csv'))}
miss=[k for k in sel if not os.path.exists(f'img/{k}.jpg')]
def f(k):
    try:
        d=urllib.request.urlopen(th[k],timeout=20).read()
        im=Image.open(io.BytesIO(d)).convert('RGB'); im.thumbnail((320,320)); im.save(f'img/{k}.jpg',quality=90); return 1
    except Exception as e: return str(e)[:40]
import collections
with ThreadPoolExecutor(8) as ex: r=list(ex.map(f,miss))
print(collections.Counter(r).most_common(4))
