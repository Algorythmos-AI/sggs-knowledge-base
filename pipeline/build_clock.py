# -*- coding: utf-8 -*-
"""One clock for every timestamp the pipeline writes into the database.

Reproducible builds need identical bytes from identical inputs, so wall-clock
stamps (meta.built, analytics_meta.*_built, sources.ingest_date,
timing_migrations.applied_at) must not vary between runs. When
SOURCE_DATE_EPOCH is set (https://reproducible-builds.org/specs/source-date-epoch/)
every stamp derives from it, in UTC; rebuild_all.sh sets it to the HEAD commit
time. Unset, the local wall clock is used (ad-hoc runs of a single builder).
Stdlib only; Python 3.9+.
"""
import os
import time


def build_struct():
    """time.struct_time of the build instant (UTC when SOURCE_DATE_EPOCH is set)."""
    epoch = os.environ.get('SOURCE_DATE_EPOCH')
    if epoch:
        return time.gmtime(int(epoch))
    return time.localtime()


def stamp(fmt='%Y-%m-%d'):
    """strftime of the build instant."""
    return time.strftime(fmt, build_struct())
