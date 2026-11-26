import numpy as np,json,onnxruntime as ort,random
from PIL import Image
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import confusion_matrix
F=np.load('feat/F.npy'); meta=json.load(open('feat/meta.json'))
src=np.array([m[0] for m in meta]); lab=np.array([m[2] for m in meta]); key=[m[1] for m in meta]
C=['glass','metal','organic','paper','plastic','trash']
y=np.array([C.index(l) for l in lab])
rng=np.random.RandomState(0)
tn=np.where(src=='trashnet')[0]
te=[];tr=[]
for c in range(6):
    idx=[i for i in tn if y[i]==c]; rng.shuffle(idx); k=int(.2*len(idx)); te+=idx[:k]; tr+=idx[k:]
te=np.array(te);tr=np.array(tr)
oi_tr=np.where(src=='oi_train')[0]; oi_ho=np.where(np.isin(src,['oi_validation','oi_test']))[0]
def norm(X): return X/np.linalg.norm(X,axis=1,keepdims=True)
Fn=norm(F)
def fit(idx,w=None):
    return LogisticRegression(C=10,max_iter=2000,class_weight='balanced').fit(Fn[idx],y[idx])
def rep(name,pred,idx):
    acc=(pred==y[idx]).mean(); 
    f1=[]
    for c in set(y[idx]):
        tp=((pred==c)&(y[idx]==c)).sum(); p=tp/max(1,(pred==c).sum()); r=tp/max(1,(y[idx]==c).sum()); f1.append(2*p*r/max(1e-9,p+r))
    print(f'{name}: n={len(idx)} acc={acc:.3f} macroF1={np.mean(f1):.3f}')
# baseline shipped model identical samples
s=ort.InferenceSession('/tmp/oi/small.onnx')
mean=np.array([0.485,0.456,0.406],dtype=np.float32);std=np.array([0.229,0.224,0.225],dtype=np.float32)
def base(idx):
    out=[]
    for i in idx:
        p=('tn/dataset-resized/'+key[i]) if src[i]=='trashnet' else f'img/{key[i]}.jpg'
        x=(np.asarray(Image.open(p).convert('RGB').resize((224,224),Image.BOX),dtype=np.float32)/255-mean)/std
        lg=s.run(None,{'image':x.transpose(2,0,1)[None]})[0][0]
        mp={0:3,1:0,2:1,3:3,4:4,5:5}; out.append(mp[int(lg.argmax())])
    return np.array(out)
for nm,idx in [('TrashNet-test',te),('OI-holdout',oi_ho)]:
    rep('A shipped argmax '+nm,base(idx),idx)
mB=fit(tr); mC=fit(np.concatenate([tr,oi_tr])); mD=fit(oi_tr)
for nm,idx in [('TrashNet-test',te),('OI-holdout',oi_ho)]:
    for mn,m in [('B trashnet-only',mB),('C trashnet+OI',mC),('D OI-only',mD)]:
        rep(mn+' '+nm,m.predict(Fn[idx]),idx)
# no-organic subset of OI holdout for baseline fairness
no=oi_ho[y[oi_ho]!=2]
rep('A shipped OI-holdout non-organic',base(no),no); rep('C OI-holdout non-organic',mC.predict(Fn[no]),no)
print(C); print(confusion_matrix(y[oi_ho],mC.predict(Fn[oi_ho]),labels=range(6)))
print(confusion_matrix(y[te],mC.predict(Fn[te]),labels=range(6)))
