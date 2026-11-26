import csv,collections,random,json
names={r[0]:r[1] for r in csv.reader(open('oidv6-class-descriptions.csv'))}
M={'plastic':['Plastic bottle','Bottled water','Water bottle','Plastic bag'],'metal':['Tin can','Beverage can','Tin'],
'glass':['Glass bottle','Wine bottle','Beer bottle'],'paper':['Newspaper','Magazine','Paper bag','Carton'],
'organic':['Banana','Apple','Orange','Tomato','Carrot','Broccoli','Potato','Bread']}
inv={n:c for c,l in M.items() for n in l}
rows=collections.defaultdict(set)
meta={}
for r in csv.reader(open('train-lab-sel.csv')):
    n=names[r[2]]
    if n in inv: rows[r[0]].add(inv[n])
for r in csv.reader(open('train-img-sel.csv')): meta[r[0]]=r
mid2={m:n for m,n in names.items()}
sel={'train':{}}
for k,v in rows.items():
    if len(v)==1: sel['train'][k]=next(iter(v))
for s in ['validation','test']:
    lic={r['ImageID']:r for r in csv.DictReader(open(f'{s}-img.csv'))}
    rr=collections.defaultdict(set)
    for r in csv.DictReader(open(f'{s}-lab.csv')):
        n=names.get(r['LabelName'])
        if n in inv and r['Confidence']=='1': rr[r['ImageID']].add(inv[n])
    sel[s]={k:next(iter(v)) for k,v in rr.items() if len(v)==1}
    for k in sel[s]: meta[k]=[lic[k][x] for x in ['ImageID','Subset','OriginalURL','OriginalLandingURL','License','AuthorProfileURL','Author','Title']]
random.seed(1)
out={}
for s,d in sel.items():
    by=collections.defaultdict(list)
    for k,c in d.items(): by[c].append(k)
    cap={'train':1000,'validation':150,'test':250}[s]
    out[s]={}
    for c,l in by.items():
        random.shuffle(l); 
        for k in l[:cap]: out[s][k]=c
    print(s,{c:len(by[c]) for c in by},'->',collections.Counter(out[s].values()))
json.dump(out,open('sel.json','w'))
json.dump({k:meta[k] for s in out for k in out[s]},open('manifest_meta.json','w'))
