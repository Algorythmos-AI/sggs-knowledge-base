# SGGS Knowledge Base — Web App

## Run it (no installation needed)

**Easiest:** double-click `Start SGGS App.command` in the `SGGS-KnowledgeBase` folder.
(First time, macOS may ask you to allow it: right-click → Open.)

Or from Terminal:

```bash
cd ~/ppt-universe/SGGS-KnowledgeBase/webapp
python3 serve.py
```

Your browser opens `http://localhost:7777` automatically (or open it yourself).
Stop with `Ctrl-C`. Different port: `SGGS_PORT=8000 python3 serve.py`.

Uses only the Python standard library + the prebuilt `db/sggs.sqlite`. Nothing to install, nothing leaves your computer.

## What you can do

| Mode | Example | What it does |
|---|---|---|
| Auto | `ਨਾਮੁ ਜਪਿ` | Detects script & intent, picks the right search |
| Gurmukhi | `ਸੋਚੈ ਸੋਚਿ` | Whole-word full-text search of the scripture |
| Roman | `sat naam karataa`, `waheguru`, `satgur kirpa` | Searches the transliteration; spelling-tolerant (w/v, aa/a, oo/u…) |
| First letters | `ਧ ਧ ਰ ਗ` or `dh dh r g` | Finds a line by its word-initials |
| Theme | `haumai`, `hukam`, `naam` | 54 curated concepts → every line containing their verified Gurmukhi terms |

Plus: read any Ang (1–1430), browse Raags/Banis, click any line to see its full shabad with the ਰਹਾਉ highlighted, a random-shabad button, **Verify quote** mode (checks any claimed line against the canonical corpus, `@ang` optional), and an **English layer** (Dr. Sant Singh Khalsa, via BaniDB — labeled, never scripture) on Japji + liturgy, Sukhmani Sahib, and Anand Sahib. Health self-test: `http://localhost:7777/api/health`.

## Fidelity rules

- The Gurmukhi shown is **verbatim** from your PDF edition (after the proven visual→logical Unicode correction), always with its **Ang**.
- Transliteration is a **mechanical reading aid**, clearly separated — it is not the scripture.
- The app retrieves; it never paraphrases or interprets.

## API (for your own scripts)

`/api/search?q=…&mode=auto|gurmukhi|roman|first|theme&limit=50&offset=0` · `/api/ang/N` · `/api/shabad/ID` · `/api/word/?w=ਸ਼ਬਦ` · `/api/random` · `/api/meta`
