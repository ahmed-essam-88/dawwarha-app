import csv,json,subprocess,os
sel=json.load(open('sel.json'))
ids=set(k for s in sel for k in sel[s] if os.path.exists(f'img/{k}.jpg'))
out=csv.writer(open('bbox_sel.csv','w'))
for s in ['train','validation','test']:
    p=subprocess.Popen(['curl','-s',f'https://storage.googleapis.com/openimages/2018_04/{s}/{s}-annotations-bbox.csv'],stdout=subprocess.PIPE,text=True)
    rd=csv.reader(p.stdout); h=next(rd)
    if s=='train': out.writerow(h)
    for r in rd:
        if r[0] in ids: out.writerow(r)
