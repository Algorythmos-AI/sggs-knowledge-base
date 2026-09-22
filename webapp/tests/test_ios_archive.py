"""The iOS DB-pair invariant: the DB on disk must hash to its manifest, and nothing — a failed build,
a killed TestFlight archive — may leave the developer's ios/Resources pair (or any tracked file)
changed. Run with the webapp suite; the archive harness stubs Xcode, so it runs on Linux CI too."""
import hashlib, json, os, re, shutil, signal, sqlite3, stat, subprocess, sys, tempfile, time, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))
import build_ios_db  # noqa: E402
import check_ios_db_pair as pair  # noqa: E402

SCRIPT = ROOT / "ios" / "tools" / "testflight_archive.sh"
PROJECT_YML = ROOT / "ios" / "App" / "project.yml"
RES = ROOT / "ios" / "Resources"
BUILD_DIR = ROOT / "ios" / "App" / "build"


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _fake_db(path, payload=b"x"):
    Path(path).write_bytes(b"SQLite format 3\x00" + b"\x00" * 84 + payload)


def _write_manifest(path, db_path, profile="personal"):
    Path(path).write_text(json.dumps({"db_sha256": _sha(db_path), "profile": profile}) + "\n")


class PairCheck(unittest.TestCase):
    def setUp(self):
        self.d = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.d)
        self.db, self.m = self.d / "sggs-ios.sqlite", self.d / "sggs-ios.manifest.json"
        _fake_db(self.db)
        _write_manifest(self.m, self.db)

    def test_matching_pair_is_clean(self):
        self.assertEqual(pair.check(str(self.m), str(self.db)), ([], []))
        self.assertEqual(pair.main([str(self.m)]), 0)     # db path derived from the manifest stem

    def test_wrong_db_is_hard(self):                      # the TestFlight-clobber / branch-switch case
        _fake_db(self.db, b"another build")
        hard, _ = pair.check(str(self.m), str(self.db))
        self.assertEqual(len(hard), 1)
        self.assertIn("!= manifest db_sha256", hard[0])
        self.assertEqual(pair.main([str(self.m), str(self.db)]), 1)

    def test_missing_db_is_hard(self):
        self.db.unlink()
        self.assertIn("DB missing", pair.check(str(self.m), str(self.db))[0][0])

    def test_lfs_pointer_is_hard(self):
        self.db.write_text("version https://git-lfs.github.com/spec/v1\n")
        self.assertIn("not a SQLite file", pair.check(str(self.m), str(self.db))[0][0])

    def test_wrong_profile_is_hard(self):
        _write_manifest(self.m, self.db, profile="public")
        self.assertIn('profile is "public"', pair.check(str(self.m), str(self.db))[0][0])
        self.assertEqual(pair.check(str(self.m), str(self.db), "public"), ([], []))

    def test_unreadable_manifest_is_hard(self):
        self.m.write_text("{not json")
        self.assertIn("unreadable", pair.check(str(self.m), str(self.db))[0][0])

    def test_check_never_writes(self):
        before = {p.name: (_sha(p), p.stat().st_mtime_ns) for p in self.d.iterdir()}
        pair.check(str(self.m), str(self.db))
        self.assertEqual(before, {p.name: (_sha(p), p.stat().st_mtime_ns) for p in self.d.iterdir()})


class AtomicBuild(unittest.TestCase):
    def test_failed_build_leaves_the_old_pair_untouched(self):
        d = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, d)
        src, dest, m = d / "src.sqlite", d / "sggs-ios.sqlite", d / "sggs-ios.manifest.json"
        con = sqlite3.connect(src)                        # a DB that cannot pass the 60,658-line proof
        con.execute("CREATE TABLE lines(id INTEGER PRIMARY KEY, ang INT, gurmukhi TEXT)")
        con.execute("CREATE VIRTUAL TABLE fts USING fts5(text)")
        con.execute("INSERT INTO lines VALUES (1, 1, 'x')")
        con.commit(); con.close()
        _fake_db(dest, b"the good dev DB")
        _write_manifest(m, dest)
        before = (_sha(dest), _sha(m))
        with self.assertRaises(AssertionError):
            build_ios_db.main(["--profile", "personal", str(src), str(dest)])
        self.assertEqual(before, (_sha(dest), _sha(m)))
        self.assertEqual(sorted(p.name for p in d.iterdir()),
                         ["sggs-ios.manifest.json", "sggs-ios.sqlite", "src.sqlite"])   # no .tmp left


class SpecShape(unittest.TestCase):
    """The archive rewrites exactly three project.yml lines; fail here, not mid-release, if they move."""
    def test_project_yml_has_the_three_lines_the_archive_rewrites(self):
        text = PROJECT_YML.read_text()
        for pattern in (r"^name: SGGS$", r"path: \.\./Resources/sggs-ios\.sqlite$",
                        r"path: \.\./Resources/sggs-ios\.manifest\.json$"):
            self.assertEqual(len(re.findall(pattern, text, re.M)), 1, pattern)

    def test_script_runs_no_tree_changing_git_command(self):
        code = "\n".join(l for l in SCRIPT.read_text().splitlines() if not l.lstrip().startswith("#"))
        self.assertIsNone(re.search(r"\bgit\s+(checkout|restore|stash|reset|add|clean|commit)\b", code))
        self.assertNotIn("ios/Resources/sggs-ios", code)  # cwd is the repo root: the dev pair is never addressed
        self.assertNotIn("RES_DIR", code)


XCODEGEN_STUB = """#!/bin/bash
# stands in for XcodeGen: emit a pbxproj naming what the spec bundles
while [ $# -gt 0 ]; do case "$1" in --spec) SPEC="$2"; shift;; --project) OUT="$2"; shift;; esac; shift; done
NAME=$(sed -n 's/^name: //p' "$SPEC" | head -1)
mkdir -p "$OUT/$NAME.xcodeproj"
{ grep 'sggs-ios' "$SPEC"; echo "sggs-ios.sqlite in Resources"; } > "$OUT/$NAME.xcodeproj/project.pbxproj"
"""

XCODEBUILD_STUB = """#!/bin/bash
# stands in for Xcode: reports a version, does nothing else
if [ "$1" = "-version" ]; then echo "Xcode {version}"; echo "Build version STUB"; fi
exit 0
"""


@unittest.skipUnless(shutil.which("bash") and (ROOT / "db" / "sggs.sqlite").is_file()
                     and (ROOT / "db" / "sggs.sqlite").read_bytes()[:15] == b"SQLite format 3",
                     "needs bash and the real db/sggs.sqlite (git lfs pull)")
class ArchiveLeavesNoTrace(unittest.TestCase):
    XCODE = "26.5"

    def setUp(self):
        self.stubs = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.stubs)
        for name, body in (("uname", "#!/bin/bash\necho Darwin\n"), ("xcodebuild", XCODEBUILD_STUB.format(version=self.XCODE)),
                           ("xcodegen", XCODEGEN_STUB)):
            p = self.stubs / name
            p.write_text(body)
            p.chmod(p.stat().st_mode | stat.S_IXUSR)
        version = re.search(r'MARKETING_VERSION:\s*"([^"]+)"', PROJECT_YML.read_text()).group(1)
        build = subprocess.run([sys.executable, str(ROOT / "ios/tools/testflight_ledger.py"), "next", version],
                               capture_output=True, text=True, check=True).stdout.split()[-1]
        self.stage = BUILD_DIR / f"stage-{version}-{build}"
        self.lock = BUILD_DIR / ".archive.lock"
        self.env = dict(os.environ, PATH=f"{self.stubs}{os.pathsep}{os.environ['PATH']}",
                        SGGS_TEAM_ID="TESTSTUB00", SGGS_BUILD_NUMBER=build, SGGS_ARCHIVE_DRY_RUN="1")
        for k in ("SGGS_UPLOAD", "SGGS_DB_PROFILE", "SGGS_ASC_KEY_PATH", "SGGS_ASC_KEY_ID", "SGGS_ASC_ISSUER_ID"):
            self.env.pop(k, None)
        if self.lock.exists():
            self.skipTest("an archive is running in this checkout")
        self.addCleanup(self._tidy)

    def _tidy(self):
        for p in (self.stage / "sggs-ios.sqlite", self.stage / "sggs-ios.sqlite.tmp",
                  self.stage / "sggs-ios.manifest.json", self.stage / "sggs-ios.manifest.json.tmp",
                  self.lock / "pid"):
            if p.exists():
                p.unlink()
        for d in (self.stage, self.lock):
            if d.is_dir():
                d.rmdir()

    def _snapshot(self):
        files = {p.name: _sha(p) for p in sorted(RES.iterdir()) if p.is_file()}
        status = subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain"],
                                capture_output=True, text=True, check=True).stdout
        return files, status

    def test_killed_then_rerun_archive_never_touches_the_dev_pair(self):
        before = self._snapshot()

        # 1. SIGKILL the whole process group mid-build: no trap runs, so a stale lock is left behind.
        proc = subprocess.Popen(["bash", str(SCRIPT)], env=self.env, start_new_session=True,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        deadline = time.time() + 180
        while time.time() < deadline and proc.poll() is None and not (self.stage / "sggs-ios.sqlite.tmp").exists():
            time.sleep(0.02)
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait()
            self.assertTrue(self.lock.is_dir(), "a SIGKILLed run should leave its lock")
        else:                                             # finished before we could kill it: fake the stale lock
            dead = subprocess.Popen(["true"]); dead.wait()
            self.lock.mkdir(parents=True, exist_ok=True)
            (self.lock / "pid").write_text(str(dead.pid))
        self.assertEqual(before, self._snapshot(), "a killed archive changed ios/Resources or git status")

        # 2. The next run reclaims the lock, stages + gates the PUBLIC artifact, and cleans up after itself.
        run = subprocess.run(["bash", str(SCRIPT)], env=self.env, capture_output=True, text=True, timeout=900)
        self.assertEqual(run.returncode, 0, run.stdout[-3000:] + run.stderr[-3000:])
        self.assertIn("reclaiming stale lock", run.stdout)
        self.assertIn("RELEASE GATE: OK", run.stdout)
        self.assertIn("DRY RUN", run.stdout)
        self.assertEqual(json.loads((self.stage / "sggs-ios.manifest.json").read_text())["profile"], "public")
        self.assertFalse((self.stage / "sggs-ios.sqlite").exists(), "staged DB should be removed on exit")
        self.assertFalse(self.lock.exists())
        self.assertEqual([], [p.name for p in (ROOT / "ios" / "App").glob("SGGS-TestFlight*")])
        self.assertEqual(before, self._snapshot(), "the archive changed ios/Resources or git status")


class ReleaseChannelGate(ArchiveLeavesNoTrace):
    """The channel is declared up front, and `appstore` is refused without the signed review."""

    test_killed_then_rerun_archive_never_touches_the_dev_pair = None   # covered by the parent class

    def _run(self, **env):
        return subprocess.run(["bash", str(SCRIPT)], env=dict(self.env, **env),
                              capture_output=True, text=True, timeout=900)

    def test_unknown_channel_is_refused_before_any_work(self):
        run = self._run(SGGS_RELEASE_CHANNEL="production")
        self.assertNotEqual(run.returncode, 0)
        self.assertIn("SGGS_RELEASE_CHANNEL must be testflight or appstore", run.stderr)
        self.assertFalse(self.stage.exists())

    def test_testflight_channel_is_the_default_and_passes_the_gate(self):
        run = self._run()
        self.assertEqual(run.returncode, 0, run.stdout[-2000:] + run.stderr[-2000:])
        self.assertIn("channel testflight", run.stdout)

    def test_appstore_channel_follows_the_attestation(self):
        signed = re.search(r"(?m)^REVIEWED:\s*true\s*$", (RES / "NITNEM-REVIEW.md").read_text())
        labelled_off = re.search(r"(?m)^\s*static let extraTextReviewed = true\s*$",
                                 (ROOT / "ios/App/Sources/Data/NitnemSchedule.swift").read_text())
        run = self._run(SGGS_RELEASE_CHANNEL="appstore")
        if signed and labelled_off:
            self.assertEqual(run.returncode, 0, run.stdout[-2000:] + run.stderr[-2000:])
        else:                                   # today: unsigned → an App Store build cannot be made at all
            self.assertNotEqual(run.returncode, 0)
            self.assertRegex(run.stdout + run.stderr, r"NOT yet scholar-reviewed|extraTextReviewed is not true")
        self.assertFalse((self.stage / "sggs-ios.sqlite").exists(), "staged DB should be removed on exit")


class OldXcodeIsRefused(ArchiveLeavesNoTrace):
    XCODE = "16.4"
    test_killed_then_rerun_archive_never_touches_the_dev_pair = None

    def test_archive_refuses_an_sdk_apple_will_reject(self):
        run = subprocess.run(["bash", str(SCRIPT)], env=self.env, capture_output=True, text=True, timeout=120)
        self.assertNotEqual(run.returncode, 0)
        self.assertIn("App Store Connect requires Xcode 26+", run.stderr)


class GithubRepoDefault(unittest.TestCase):
    def test_archive_defaults_github_repository_from_remote(self):
        code = SCRIPT.read_text()
        self.assertIn("git remote get-url origin", code,
                      "testflight_archive.sh must default GITHUB_REPOSITORY from the remote for local runs")


class UploadProvenance(unittest.TestCase):
    """Static: an upload must refuse a dirty tree, an off-trunk commit and a red commit."""

    def test_upload_gates_are_hard_failures(self):
        code = SCRIPT.read_text()
        self.assertIn('[ "$UPLOAD" = 1 ] && fail "uncommitted changes in shipping sources', code)
        self.assertIn("git merge-base --is-ancestor HEAD origin/integration", code)
        self.assertIn("scripts/ci/wait_for_checks.py", code)
        self.assertIn("--extra parity app", code)


if __name__ == "__main__":
    unittest.main()
