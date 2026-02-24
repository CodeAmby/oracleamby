#!/usr/bin/env python3
import sys, json, os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CHROMA_DIR=ROOT/ 'memory'/ 'chroma'

if not (CHROMA_DIR/ 'embeddings.json').exists():
    print('No embeddings found. Run reindex_qmd.py first.')
    sys.exit(1)

embs=json.load(open(CHROMA_DIR/ 'embeddings.json','r',encoding='utf-8'))

if len(sys.argv)<2:
    print('Usage: search_qmd.py "your query"')
    sys.exit(1)

query=' '.join(sys.argv[1:])
# naive: embed query and compute cosine similarity
import subprocess,openai,math
key = subprocess.check_output(['security','find-generic-password','-s','OPENAI_API_KEY','-a','amby','-w']).decode().strip()
openai.api_key = key
r = openai.Embedding.create(input=query, model='text-embedding-3-small')
qvec = r['data'][0]['embedding']

def cosine(a,b):
    dot=sum(x*y for x,y in zip(a,b))
    na=math.sqrt(sum(x*x for x in a))
    nb=math.sqrt(sum(x*x for x in b))
    return dot/(na*nb)

scores=[]
for e in embs:
    scores.append((cosine(qvec,e['emb']), e['id'], e['meta']['source']))
scores.sort(reverse=True)
for s in scores[:5]:
    print(f"score={s[0]:.4f}\t{ s[1]}\t{ s[2]}")
