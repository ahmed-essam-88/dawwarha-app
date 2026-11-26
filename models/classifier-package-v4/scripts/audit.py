import csv,json,os,collections
mids=[l.strip() for l in open('mids.txt')]
names={r[0]:r[1] for r in csv.reader(open('oidv6-class-descriptions.csv'))}
M={'plastic':['Plastic bottle','Bottled water','Water bottle','Plastic bag'],'metal':['Tin can','Beverage can','Tin'],'glass':['Glass bottle','Wine bottle','Beer bottle'],'paper':['Newspaper','Magazine','Paper bag','Carton'],'organic':['Banana','Apple','Orange','Tomato','Carrot','Broccoli','Potato','Bread']}
inv={n:c for c,l in M.items() for n in l}
sel=json.load(open('sel.json'))
fit={k:c for k,c in sel['train'].items() if os.path.exists(f'img/{k}.jpg')}
ho={k:c for s in ('validation','test') for k,c in sel[s].items() if os.path.exists(f'img/{k}.jpg')}
bx=collections.defaultdict(list)
for r in csv.DictReader(open('bbox_sel.csv')): bx[r['ImageID']].append(r)
def status(k,c):
    b=bx.get(k)
    if not b: return 'nobox'
    tgt=[r for r in b if inv.get(names.get(r['LabelName'],''))==c]
    if not tgt: return 'nobox'
    if any(r['IsGroupOf']=='1' for r in tgt) : return 'group'
    if any(r['IsDepiction']=='1' for r in tgt): return 'depiction'
    area=max((float(r['XMax'])-float(r['XMin']))*(float(r['YMax'])-float(r['YMin'])) for r in tgt)
    if len(tgt)>1 and c!='organic' : return 'multi'
    if len(tgt)>2: return 'multi'
    if area<0.25: return 'small'
    return 'single'
for nm,d in [('fit',fit),('holdout',ho)]:
    t=collections.defaultdict(collections.Counter)
    for k,c in d.items(): t[c][status(k,c)]+=1
    print(nm)
    for c in t: print(' ',c,dict(t[c]),'total',sum(t[c].values()))
