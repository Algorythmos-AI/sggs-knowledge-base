# SGGS Knowledge Base — backend API image.
# serve.py is Python-stdlib only (no pip deps); Debian's SQLite ships FTS5 + bm25(), which the
# search/analytics endpoints require. Build context is the REPO ROOT (see note below), because
# serve.py opens ../db/sggs.sqlite relative to webapp/.
#
#   docker build -f webapp/Dockerfile -t sggs-backend .   # run from the repo root
#
FROM python:3.12-slim

WORKDIR /app

# Copy the pieces the server needs, preserving the repo layout serve.py expects
# (webapp/ next to db/). db/sggs.sqlite is a Git-LFS object — the build context must contain
# the REAL ~109 MB file, not the LFS pointer. Run `git lfs pull` before building, or enable
# LFS checkout on the build host.
COPY webapp/ ./webapp/
COPY db/sggs.sqlite ./db/sggs.sqlite

# Fail the build loudly if an LFS *pointer* slipped in instead of the real database.
# Exact 16-byte magic check via the image's own Python (avoids grep's ambiguous binary/NUL
# handling — a real SQLite file starts with b"SQLite format 3\x00").
RUN python -c "import sys; ok=open('db/sggs.sqlite','rb').read(16)==b'SQLite format 3\x00'; sys.exit(0 if ok else 'ERROR: db/sggs.sqlite is a Git-LFS pointer, not the real DB. Run `git lfs pull` before building.')"

WORKDIR /app/webapp

# Bake the source commit into the image so /api/health.commit is always the built SHA
# (Render passes RENDER_GIT_COMMIT to Docker builds as a build arg; empty elsewhere ->
# serve.py reports 'unknown'). Deploy verification polls this value.
ARG RENDER_GIT_COMMIT=""
ENV SGGS_COMMIT=${RENDER_GIT_COMMIT}

# The host injects $PORT; serve.py honours it (falls back to 7777). Never open a browser here.
ENV SGGS_OPEN_BROWSER=0
EXPOSE 7777

# Lightweight liveness probe — /api/meta is cached and instant (unlike /api/health, which runs a
# full integrity + verification pass). Requires a shell for $PORT expansion.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD python -c "import os,urllib.request as u; u.urlopen(f\"http://127.0.0.1:{os.environ.get('PORT','7777')}/readyz\").read()" || exit 1

CMD ["python", "serve.py"]
