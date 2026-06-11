# -*- coding: utf-8 -*-
"""Full-corpus LLM enrichment orchestrator — resumable, block-based.

The deterministic engine covers rule-derivable spellings; this pipeline routes
the ENTIRE unique vocabulary through the Worker→Supervisor LLM stages for the
classes rules cannot derive (Sanskrit/Hindi loanwords: bhakti~bhagatee,
shakti~sakat, kripa~kirapaa; deep structural typos).

Commands:
  python3 enrich_orchestrator.py prepare <db>     # build blocks from full vocab
  python3 enrich_orchestrator.py status           # blocks done/pending
  python3 enrich_orchestrator.py merge <db>       # validate+dedupe+load approved
State lives in pipeline/enrichment/ :
  blocks/block_NNN.jsonl      inputs ({gurmukhi, standard_roman, freq})
  out/block_NNN.jsonl         Worker proposals (written by LLM agents)
  approved/block_NNN.jsonl    Supervisor-passed variants
  qa_log.jsonl                full audit trail (append-only)
A block is DONE when approved/block_NNN.jsonl exists. Re-running any command
is safe; merge is idempotent (INSERT after dedupe against current table).
"""
import sys, os, json, sqlite3, re, glob, collections

HERE = os.path.dirname(os.path.abspath(__file__))
ENR = os.path.join(HERE, 'enrichment')
BLOCK_SIZE = 750

def vocab(db):
    con = sqlite3.connect(f'file:{db}?mode=ro', uri=True)
    rows = con.execute("""SELECT gurmukhi, translit, MAX(freq) FROM variants
                          GROUP BY gurmukhi ORDER BY MAX(freq) DESC""").fetchall()
    con.close()
    return rows

def prepare(db):
    os.makedirs(os.path.join(ENR, 'blocks'), exist_ok=True)
    os.makedirs(os.path.join(ENR, 'out'), exist_ok=True)
    os.makedirs(os.path.join(ENR, 'approved'), exist_ok=True)
    rows = vocab(db)
    nb = 0
    for i in range(0, len(rows), BLOCK_SIZE):
        nb += 1
        p = os.path.join(ENR, 'blocks', f'block_{nb:03d}.jsonl')
        if os.path.exists(p): continue                      # resumable
        with open(p, 'w', encoding='utf-8') as f:
            for g, tr, fr in rows[i:i+BLOCK_SIZE]:
                f.write(json.dumps({'gurmukhi': g, 'standard_roman': tr, 'freq': fr},
                                   ensure_ascii=False) + '\n')
    print(f'vocabulary: {len(rows)} words -> {nb} blocks of <= {BLOCK_SIZE}')

def status():
    blocks = sorted(glob.glob(os.path.join(ENR, 'blocks', 'block_*.jsonl')))
    done = pend_out = pend_work = 0
    for b in blocks:
        name = os.path.basename(b)
        if os.path.exists(os.path.join(ENR, 'approved', name)): done += 1
        elif os.path.exists(os.path.join(ENR, 'out', name)): pend_out += 1
        else: pend_work += 1
    print(f'blocks: {len(blocks)} | approved: {done} | awaiting-supervisor: {pend_out} | awaiting-worker: {pend_work}')
    for b in blocks:
        name = os.path.basename(b)
        st = ('APPROVED' if os.path.exists(os.path.join(ENR, 'approved', name))
              else 'NEEDS-SUPERVISOR' if os.path.exists(os.path.join(ENR, 'out', name))
              else 'NEEDS-WORKER')
        if st != 'APPROVED': print(' ', name, st)

def supervise(db):
    """Deterministic Supervisor gates (english veto / canonical / duplicate /
    form / self) for every out/ block lacking an approved/ file."""
    con = sqlite3.connect(f'file:{db}?mode=ro', uri=True)
    lc = collections.Counter()
    for (t,) in con.execute("SELECT text FROM translations WHERE lang='en'"):
        for w in re.findall(r'[A-Za-z]{2,}', t):
            if w.islower(): lc[w] += 1
    veto = {w for w, n in lc.items() if n >= 2}
    canon = {r[0] for r in con.execute('SELECT DISTINCT translit FROM variants')}
    existing = {r[0] for r in con.execute('SELECT DISTINCT variant FROM variants')}
    con.close()
    qa = open(os.path.join(ENR, 'qa_log.jsonl'), 'a', encoding='utf-8')
    for outp in sorted(glob.glob(os.path.join(ENR, 'out', 'block_*.jsonl'))):
        name = os.path.basename(outp)
        ap = os.path.join(ENR, 'approved', name)
        if os.path.exists(ap): continue
        approved, counts = [], collections.Counter()
        for raw in open(outp, encoding='utf-8'):
            raw = raw.strip()
            if not raw: continue
            try: p = json.loads(raw)
            except json.JSONDecodeError: counts['badjson'] += 1; continue
            v = (p.get('variant') or '').strip()
            sr = (p.get('standard_roman') or '').strip()
            reason = None
            if not v or len(v) < 2 or not v.isalnum() or v != v.lower(): reason = 'form'
            elif v == sr: reason = 'self'
            elif v in veto: reason = 'english'
            elif v in canon: reason = 'canonical'
            elif v in existing: reason = 'duplicate'
            if reason: counts[reason] += 1
            else:
                approved.append(p); existing.add(v); counts['approved'] += 1
            qa.write(json.dumps({'variant': v, 'standard_roman': sr,
                                 'decision': 'purged' if reason else 'approved',
                                 'reason': reason, 'block': name}) + '\n')
        with open(ap, 'w', encoding='utf-8') as f:
            for p in approved:
                f.write(json.dumps(p, ensure_ascii=False) + '\n')
        print(f'{name}: {dict(counts)}')
    qa.close()

def merge(db):
    supervise(db)
    con = sqlite3.connect(db)
    existing = {r[0] for r in con.execute('SELECT DISTINCT variant FROM variants')}
    rows = []
    for ap in sorted(glob.glob(os.path.join(ENR, 'approved', 'block_*.jsonl'))):
        for raw in open(ap, encoding='utf-8'):
            p = json.loads(raw)
            v = p['variant']
            if v in existing: continue
            rows.append((v, p['gurmukhi'], p['standard_roman'],
                         p.get('freq', 1), float(p.get('confidence', 0.5)) * 0.6, 'llm'))
            existing.add(v)
    con.executemany('INSERT INTO variants VALUES(?,?,?,?,?,?)', rows)
    n = con.execute('SELECT count(*) FROM variants').fetchone()[0]
    con.execute("INSERT OR REPLACE INTO meta VALUES('variants', ?)", (str(n),))
    con.commit(); con.close()
    print(f'merged {len(rows)} new LLM variants | table total: {n}')

if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'prepare': prepare(sys.argv[2])
    elif cmd == 'status': status()
    elif cmd == 'merge': merge(sys.argv[2])
    else: print(__doc__)
