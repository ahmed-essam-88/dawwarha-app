exec(open('audit.py').read().split("for nm,d in")[0])
import numpy as np
exec(open('ev.py').read().split('# baseline shipped')[0])
# glass via generic Bottle box (/m/04dr76w) in addition
BOTTLE='/m/04dr76w'
def st2(k,c):
    s=status(k,c)
    if c=='glass':
        b=[r for r in bx.get(k,[]) if r['LabelName']==BOTTLE]
        if not b: return 'nobox'
        if any(r['IsGroupOf']=='1' or r['IsDepiction']=='1' for r in b) or len(b)>1: return 'multi'
        a=(float(b[0]['XMax'])-float(b[0]['XMin']))*(float(b[0]['YMax'])-float(b[0]['YMin']))
        return 'single' if a>=0.25 else 'small'
    return s
ok={}
for i in range(len(y)):
    if src[i].startswith('oi_'): ok[i]=st2(key[i],lab[i])=='single'
import collections
fitsingle=[i for i in oi_tr if ok[i]]; hosingle=[i for i in oi_ho if ok[i]]
print('fit single',len(fitsingle),collections.Counter(lab[i] for i in fitsingle)); print('holdout single',len(hosingle),collections.Counter(lab[i] for i in hosingle))
idx=np.concatenate([tr,np.array(fitsingle)])
mu=F[idx].mean(0); sd=F[idx].std(0)+1e-6
lr=LogisticRegression(C=0.05,max_iter=3000,class_weight='balanced').fit((F[idx]-mu)/sd,y[idx])
old=np.concatenate([tr,oi_tr]); mu2=F[old].mean(0); sd2=F[old].std(0)+1e-6
lr2=LogisticRegression(C=0.05,max_iter=3000,class_weight='balanced').fit((F[old]-mu2)/sd2,y[old])
for nm,i2 in [('TrashNet-test',te),('OI-heldout single-verified',np.array(hosingle))]:
    rep('filtered '+nm,lr.predict((F[i2]-mu)/sd),i2); rep('unfiltered(candidate) '+nm,lr2.predict((F[i2]-mu2)/sd2),i2)
