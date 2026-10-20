#!/usr/bin/env python3
"""Offline tests for scripts/reset_project.py (stdlib only): python3 tests/test_reset_project.py"""
import contextlib
import io
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HARNESS, "scripts"))
import reset_project as RP  # noqa: E402

DOCS = RP.RESET_ALLOWLIST


def read(path, mode="r"):
    with open(path, mode) as f:
        return f.read()


def run(*args):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        code = RP.main(list(args))
    return code, buf.getvalue()


def snapshot(root):
    out = {}
    for d, _, files in os.walk(root):
        if os.sep + ".git" in d + os.sep:
            continue
        for f in files:
            p = os.path.join(d, f)
            out[os.path.relpath(p, root)] = read(p, "rb")
    return out


class ResetProjectTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.target = os.path.join(self.tmp.name, "proj")
        self.ws = os.path.join(self.target, "slurm-agentic-engineering")
        os.makedirs(self.target)

    def tearDown(self):
        self.tmp.cleanup()

    def ws_path(self, rel):
        return os.path.join(self.ws, rel)

    def test_dry_run_writes_nothing(self):
        before = snapshot(self.tmp.name)
        code, out = run("--target", self.target)
        self.assertEqual(code, 0, out)
        self.assertIn("DRY RUN", out)
        self.assertEqual(snapshot(self.tmp.name), before)
        self.assertFalse(os.path.exists(self.ws))

    def test_init_creates_everything_then_is_idempotent(self):
        code, out = run("--target", self.target, "--apply", "--missing-only")
        self.assertEqual(code, 0, out)
        for rel in DOCS:
            self.assertTrue(os.path.isfile(self.ws_path(rel)), rel)
        for d in RP.WORKSPACE_DIRS:
            self.assertTrue(os.path.isdir(self.ws_path(d)), d)
        self.assertTrue(os.path.isfile(self.ws_path("config.sh")))
        claude = read(os.path.join(self.target, "CLAUDE.md"))
        self.assertIn("agent.md", claude)
        snap = snapshot(self.tmp.name)
        code, out = run("--target", self.target, "--apply")          # full reset, nothing differs
        self.assertEqual(code, 0, out)
        self.assertEqual(snapshot(self.tmp.name), snap)              # byte-identical: no-op
        self.assertFalse(os.path.exists(self.ws_path(".reset-backups")))

    def test_reset_backs_up_and_restores(self):
        run("--target", self.target, "--apply")
        edited = b"# STATE\nproject-specific content\n"
        with open(self.ws_path("state/STATE.md"), "wb") as f:
            f.write(edited)
        code, out = run("--target", self.target)                      # dry run reports, does not write
        self.assertEqual(code, 0, out)
        self.assertIn("reset", out)
        self.assertEqual(read(self.ws_path("state/STATE.md"), "rb"), edited)
        code, out = run("--target", self.target, "--apply")
        self.assertEqual(code, 0, out)
        tpl = read(os.path.join(RP.TEMPLATES, "state/STATE.md"), "rb")
        self.assertEqual(read(self.ws_path("state/STATE.md"), "rb"), tpl)
        backups = os.listdir(self.ws_path(".reset-backups"))
        self.assertEqual(len(backups), 1)
        bak = os.path.join(self.ws_path(".reset-backups"), backups[0], "state/STATE.md")
        self.assertEqual(read(bak, "rb"), edited)
        code, out = run("--target", self.target, "--apply")          # repeat: nothing left to do
        self.assertEqual(code, 0, out)
        self.assertEqual(len(os.listdir(self.ws_path(".reset-backups"))), 1)

    def test_missing_only_never_overwrites(self):
        run("--target", self.target, "--apply")
        with open(self.ws_path("PROJECT.md"), "w") as f:
            f.write("mine\n")
        code, out = run("--target", self.target, "--apply", "--missing-only")
        self.assertEqual(code, 0, out)
        self.assertEqual(read(self.ws_path("PROJECT.md")), "mine\n")

    def test_protected_paths_and_config_untouched(self):
        run("--target", self.target, "--apply")
        keep = {
            "state/LEDGER.jsonl": '{"expid":"x","jobid":"1"}\n',
            "results/x/summary.json": "{}\n",
            "exp/x.sh": "#!/bin/bash\n",
            "inv/x/brief.md": "brief\n",
            "log/2026-01.md": "log\n",
            "config.sh": 'AE_HOST="mine"\n',
        }
        for rel, text in keep.items():
            os.makedirs(os.path.dirname(self.ws_path(rel)), exist_ok=True)
            with open(self.ws_path(rel), "w") as f:
                f.write(text)
        for rel in DOCS:
            with open(self.ws_path(rel), "a") as f:
                f.write("\nedited\n")
        code, out = run("--target", self.target, "--apply")
        self.assertEqual(code, 0, out)
        for rel, text in keep.items():
            self.assertEqual(read(self.ws_path(rel)), text, rel)

    def test_existing_claude_md_is_kept(self):
        with open(os.path.join(self.target, "CLAUDE.md"), "w") as f:
            f.write("# my own instructions\n")
        code, out = run("--target", self.target, "--apply")
        self.assertEqual(code, 0, out)
        self.assertEqual(read(os.path.join(self.target, "CLAUDE.md")), "# my own instructions\n")
        self.assertIn("agent.md", out)                                # tells you the line to add

    def test_refuses_symlink(self):
        run("--target", self.target, "--apply")
        outside = os.path.join(self.tmp.name, "outside.md")
        with open(outside, "w") as f:
            f.write("do not touch\n")
        os.remove(self.ws_path("state/STATE.md"))
        os.symlink(outside, self.ws_path("state/STATE.md"))
        code, out = run("--target", self.target, "--apply")
        self.assertEqual(code, 2, out)
        self.assertEqual(read(outside), "do not touch\n")

    def test_missing_target(self):
        code, out = run("--target", os.path.join(self.tmp.name, "nope"))
        self.assertEqual(code, 2, out)

    def test_dirty_git_repo_untouched(self):
        def git(*a):
            return subprocess.run(["git", "-C", self.target, *a], capture_output=True, text=True, check=True).stdout
        git("init", "-q")
        git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "init")
        with open(os.path.join(self.target, "code.py"), "w") as f:
            f.write("print(1)\n")                                     # dirty, untracked
        head = git("rev-parse", "HEAD")
        code, out = run("--target", self.target, "--apply")
        self.assertEqual(code, 0, out)
        self.assertEqual(git("rev-parse", "HEAD"), head)
        self.assertEqual(read(os.path.join(self.target, "code.py")), "print(1)\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
