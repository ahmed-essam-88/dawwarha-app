exec(open('ev.py').read().split('# baseline shipped')[0])
import onnx
from onnx import numpy_helper as nh
idx=np.concatenate([tr,oi_tr])
mu=F[idx].mean(0); sd=F[idx].std(0)+1e-6
lr=LogisticRegression(C=0.05,max_iter=3000,class_weight='balanced').fit((F[idx]-mu)/sd,y[idx])
for nm,i2 in [('TrashNet-test',te),('OI-holdout',oi_ho)]:
    rep('final std-LR '+nm,lr.predict((F[i2]-mu)/sd),i2)
W=(lr.coef_/sd).astype(np.float32); b=(lr.intercept_-(lr.coef_*mu/sd).sum(1)).astype(np.float32)
m=onnx.load('bb.onnx')
g=m.graph
for init in list(g.initializer):
    if init.name=='classifier.weight': g.initializer.remove(init)
    if init.name=='classifier.bias': g.initializer.remove(init)
g.initializer.append(nh.from_array(W,'classifier.weight')); g.initializer.append(nh.from_array(b,'classifier.bias'))
# gemm transB
for n in g.node:
    if n.op_type=='Gemm' and 'classifier.weight' in n.input: print([ (a.name,a.i) for a in n.attribute])
# rename input
old='pixel_values'
for n in g.node:
    n.input[:]=['image' if i==old else i for i in n.input]
g.input[0].name='image'
g.input[0].type.tensor_type.shape.dim[0].dim_param='batch_size'
for d,v in zip(g.input[0].type.tensor_type.shape.dim[1:],[3,224,224]): d.ClearField('dim_param'); d.dim_value=v
del g.output[:]; g.output.append(onnx.helper.make_tensor_value_info('logits',1,['batch_size',6]))
m.ir_version=8
onnx.save(m,'dooreha_candidate.onnx')
s=ort.InferenceSession('dooreha_candidate.onnx')
ii=np.concatenate([te[:50],oi_ho[:50]])
x=np.stack([np.asarray(Image.open(('tn/dataset-resized/'+key[i]) if src[i]=='trashnet' else f'img/{key[i]}.jpg').convert('RGB').resize((224,224),Image.BOX),dtype=np.float32).transpose(2,0,1)/255 for i in ii])
lg=s.run(None,{'image':x})[0]
print('onnx vs sklearn argmax agreement',(lg.argmax(1)==lr.predict((F[ii]-mu)/sd)).mean(), lg.shape)
# full end-to-end eval through onnx
for nm,i2 in [('TrashNet-test',te),('OI-holdout',oi_ho)]:
    p=[]
    for j in range(0,len(i2),32):
        c=i2[j:j+32]
        x=np.stack([np.asarray(Image.open(('tn/dataset-resized/'+key[i]) if src[i]=='trashnet' else f'img/{key[i]}.jpg').convert('RGB').resize((224,224),Image.BOX),dtype=np.float32).transpose(2,0,1)/255 for i in c])
        p+=list(s.run(None,{'image':x})[0].argmax(1))
    rep('E2E onnx '+nm,np.array(p),i2)
