#!/usr/bin/env python3
import os,sys,json,glob
from pathlib import Path
from tqdm import tqdm

ROOT=Path(__file__).resolve().parents[1]
INDIR=ROOT/ 'memory'/ 'indexed'
CHROMA_DIR=ROOT/ 'memory'/ 'chroma'

# simple splitter
def split_text(text, max_chars=2000):
    parts=[]
    cur=""
    for para in text.split('\n\n'):
        if len(cur)+len(para) < max_chars:
            cur += para + "\n\n"
        else:
            if cur: parts.append(cur.strip())
            cur = para + "\n\n"
    if cur: parts.append(cur.strip())
    return parts


def load_files():
    files=sorted(glob.glob(str(INDIR/"*.md")))
    docs=[]
    for f in files:
        text=open(f,'r',encoding='utf-8').read()
        parts=split_text(text)
        for i,p in enumerate(parts):
            docs.append({'id':f + f":{i}", 'text':p, 'source':os.path.basename(f)})
    return docs


def get_openai_key():
    import subprocess
    try:
        key = subprocess.check_output(['security','find-generic-password','-s','OPENAI_API_KEY','-a','amby','-w']).decode().strip()
        return key
    except Exception:
        return None


if __name__=='__main__':
    docs=load_files()
    print(f"Found {len(docs)} doc chunks to index")
    if len(docs)==0:
        print("Nothing to index. Place markdown files in workspace/memory/indexed/ and re-run.")
        sys.exit(0)
    key=get_openai_key()
    use_openai = key is not None
    if use_openai:
        # modern OpenAI client
        from openai import OpenAI
        client = OpenAI(api_key=key)
    else:
        print("No OpenAI key found in Keychain; exiting.")
        sys.exit(1)
    # generate embeddings
    from tqdm import tqdm
    embeddings=[]
    for d in tqdm(docs):
        r = client.embeddings.create(input=d['text'], model='text-embedding-3-small')
        emb = r.data[0].embedding
        embeddings.append({'id':d['id'],'emb':emb,'meta':{'source':d['source']}})
    # store minimal chroma-like json for now
    CHROMA_DIR.mkdir(parents=True,exist_ok=True)
    with open(CHROMA_DIR/ 'embeddings.json','w',encoding='utf-8') as f:
        json.dump(embeddings,f)
    print(f"Wrote {len(embeddings)} embeddings to {CHROMA_DIR}")
