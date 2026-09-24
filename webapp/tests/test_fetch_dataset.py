"""scripts/data/fetch_dataset.py — the platform obtains its database only through the pin.

Offline: the network layer is replaced by an in-memory body, so these run anywhere.
"""
import hashlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("fetch_dataset", ROOT / "scripts/data/fetch_dataset.py")
fd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fd)

BODY = b"SQLite format 3\x00" + bytes(range(256)) * 64


def _lock(body=BODY, **over):
    lock = {"repository": "Algorythmos-AI/sggs-data", "commit": "a" * 40, "dataset_version": "1.0.0",
            "database": {"path": "db/sggs.sqlite", "sha256": hashlib.sha256(body).hexdigest(),
                         "size": len(body)}}
    lock["database"].update(over)
    return lock


class _Resp(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *a):
        self.close()


def _serve(body):
    """Patch the two network touch points: the LFS batch call and the object download."""
    return mock.patch.multiple(fd, _download_href=mock.Mock(return_value=("https://x/obj", {})),
                               _open=mock.Mock(side_effect=lambda *a, **k: _Resp(body)))


class TestLock(unittest.TestCase):
    def test_committed_lock_is_well_formed_and_agrees_with_the_repository(self):
        lock = fd.load_lock()
        self.assertEqual(lock["repository"], "Algorythmos-AI/sggs-data")
        self.assertEqual(fd.check_repo(lock), [])

    def test_malformed_lock_is_refused(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "lock.json"
            for bad in ({**_lock(), "commit": "abc"}, _lock(sha256="short"), _lock(size=0),
                        {**_lock(), "repository": "no-slash"}):
                p.write_text(json.dumps(bad))
                with self.assertRaises(SystemExit):
                    fd.load_lock(p)

    def test_check_repo_reports_a_disagreeing_contract_meta(self):
        problems = fd.check_repo(_lock(sha256="0" * 64))
        self.assertTrue(any("contract/_meta.json" in p for p in problems), problems)


class TestFetch(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.dest = self.dir / "db" / "sggs.sqlite"

    def tearDown(self):
        self.tmp.cleanup()

    def _leftovers(self):
        return [p.name for p in self.dir.rglob("*.part")]

    def test_downloads_verifies_and_installs(self):
        with _serve(BODY):
            self.assertEqual(fd.fetch(_lock(), self.dest, None), "downloaded")
        self.assertEqual(self.dest.read_bytes(), BODY)
        self.assertEqual(self._leftovers(), [])

    def test_second_run_is_a_no_op(self):
        self.dest.parent.mkdir(parents=True)
        self.dest.write_bytes(BODY)
        with _serve(b"never read"):
            self.assertEqual(fd.fetch(_lock(), self.dest, None), "already installed")

    def test_cache_hit_installs_without_network(self):
        cache = self.dir / "cache"
        cache.mkdir()
        (cache / _lock()["database"]["sha256"]).write_bytes(BODY)
        with mock.patch.object(fd, "_download_href", side_effect=AssertionError("network used")):
            self.assertEqual(fd.fetch(_lock(), self.dest, cache), "from cache")
        self.assertEqual(self.dest.read_bytes(), BODY)

    def test_corrupt_cache_entry_is_replaced_not_trusted(self):
        cache = self.dir / "cache"
        cache.mkdir()
        (cache / _lock()["database"]["sha256"]).write_bytes(b"bit rot")
        with _serve(BODY):
            self.assertEqual(fd.fetch(_lock(), self.dest, cache), "downloaded")
        self.assertEqual(self.dest.read_bytes(), BODY)

    def test_wrong_bytes_never_replace_a_good_database(self):
        self.dest.parent.mkdir(parents=True)
        self.dest.write_bytes(b"previous good database")
        tampered = BODY[:-1] + b"\x01"
        with _serve(tampered), self.assertRaises(SystemExit):
            fd.fetch(_lock(), self.dest, None)
        self.assertEqual(self.dest.read_bytes(), b"previous good database")
        self.assertEqual(self._leftovers(), [])

    def test_oversized_or_truncated_download_is_refused(self):
        for body in (BODY + b"extra", BODY[:100]):
            with self.subTest(size=len(body)), _serve(body), self.assertRaises(SystemExit):
                fd.fetch(_lock(), self.dest, None)
            self.assertFalse(self.dest.exists())
            self.assertEqual(self._leftovers(), [])


class TestCheckPin(unittest.TestCase):
    def _pointer(self, oid, size):
        return f"version https://git-lfs.github.com/spec/v1\noid sha256:{oid}\nsize {size}\n".encode()

    def test_pointer_naming_the_pin_passes(self):
        lock = _lock()
        with mock.patch.object(fd, "_open", return_value=_Resp(
                self._pointer(lock["database"]["sha256"], lock["database"]["size"]))):
            fd.check_pin(lock)

    def test_pointer_naming_another_object_fails(self):
        lock = _lock()
        with mock.patch.object(fd, "_open", return_value=_Resp(self._pointer("b" * 64, 5))), \
                self.assertRaises(SystemExit):
            fd.check_pin(lock)


if __name__ == "__main__":
    unittest.main()
