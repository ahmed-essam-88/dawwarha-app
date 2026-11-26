import onnx,onnxruntime as ort,numpy as np,json,os,glob,sys,time
from PIL import Image
m=onnx.load('bb.onnx'); m.graph.output.append(onnx.helper.make_tensor_value_info('/flatten/Flatten_output_0',1,None))
sess=ort.InferenceSession(m.SerializeToString(),providers=['CPUExecutionProvider'])
sel=json.load(open('sel.json'))
items=[]
for s in sel:
    for k,c in sel[s].items():
        if os.path.exists(f'img/{k}.jpg'): items.append(('oi_'+s,k,c,f'img/{k}.jpg'))
tn={'cardboard':'paper','paper':'paper','glass':'glass','metal':'metal','plastic':'plastic','trash':'trash'}
for d in sorted(os.listdir('tn/dataset-resized')):
    if d in tn and not d.startswith('_'):
        for f in sorted(glob.glob(f'tn/dataset-resized/{d}/*.jpg')): items.append(('trashnet',d+'/'+os.path.basename(f),tn[d],f))
os.makedirs('feat',exist_ok=True)
t0=time.time()
if os.path.exists('feat/done.json'): done=json.load(open('feat/done.json'))
else: done=[]
cache={}
if os.path.exists('feat/F.npy'): F=list(np.load('feat/F.npy'))
else: F=[]
meta=json.load(open('feat/meta.json')) if os.path.exists('feat/meta.json') else []
n0=len(meta)
B=32
todo=items[n0:]
for i in range(0,len(todo),B):
    ch=todo[i:i+B]
    x=np.stack([np.asarray(Image.open(p).convert('RGB').resize((224,224),Image.BOX),dtype=np.float32).transpose(2,0,1)/255 for _,_,_,p in ch])
    f=sess.run(['/flatten/Flatten_output_0'],{'pixel_values':x})[0]
    F+=list(f); meta+=[a[:3] for a in ch]
    if time.time()-t0>95: break
np.save('feat/F.npy',np.array(F)); json.dump(meta,open('feat/meta.json','w'))
print(len(meta),'of',len(items),time.time()-t0)
