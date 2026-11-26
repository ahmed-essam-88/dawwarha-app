import csv,sys,subprocess,collections
ids=set(r[0] for r in csv.reader(open('train-lab-sel.csv')))
p=subprocess.Popen(['curl','-s','https://storage.googleapis.com/openimages/2018_04/train/train-images-with-labels-with-rotation.csv'],stdout=subprocess.PIPE,text=True)
out=open('train-img-sel.csv','w'); w=csv.writer(out)
rd=csv.reader(p.stdout); h=next(rd); w.writerow(h)
for r in rd:
    if r[0] in ids: w.writerow(r)
