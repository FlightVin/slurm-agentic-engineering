#!/usr/bin/env python3
"""Restore a project's working documents to the pristine slurm-agentic-engineering templates.

Safe by construction:
  * DRY RUN unless --apply is given; the plan is printed either way.
  * Writes ONLY the explicit allowlist below. Everything else -- code, git history, the ledger
    (state/LEDGER.jsonl), results/, log/, exp/, inv/, the harness itself -- is never opened for writing.
  * Backs up every file it is about to overwrite to <workspace>/.reset-backups/<UTC stamp>/<path>.
  * Idempotent: a file already identical to its template is left alone (no backup, no write), so
    a second run is a no-op. Works from a dirty git tree (it never runs git).
  * Refuses symlinks and any destination that resolves outside the target/workspace.

Modes:
  default          reset every allowlisted document to its template (with backup)
  --missing-only   only create documents that do not exist yet (what `ae init` runs)
Create-only files (never overwritten, even without --missing-only): <workspace>/config.sh from
config.example.sh, and <target>/CLAUDE.md pointing at agent.md.

Usage:
  python3 scripts/reset_project.py --target /path/to/project            # dry run
  python3 scripts/reset_project.py --target /path/to/project --apply    # do it
  python3 scripts/reset_project.py --target . --workspace ./slurm-agentic-engineering --apply --missing-only
"""
import argparse
import datetime as dt
import filecmp
import os
import shutil
import sys

HARNESS = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
TEMPLATES = os.path.join(HARNESS, "templates", "project")

# workspace-relative documents that a reset restores to their template
RESET_ALLOWLIST = (
    "PROJECT.md",
    "cluster/CARD.md",
    "cluster/BABEL.md",
    "state/STATE.md",
    "state/CHECKLIST.md",
    "state/FINDINGS.md",
    "state/DECISIONS.md",
    "state/IMPLEMENTATION-LOG.md",
)
# workspace directories that must exist (created empty; never emptied)
WORKSPACE_DIRS = ("state", "exp", "inv", "results", "log", "cluster")
# paths a reset must never write, whatever the arguments (defence in depth)
PROTECTED = ("state/LEDGER.jsonl", "results", "log", "exp", "inv", ".git")


def inside(path, root):
    path, root = os.path.realpath(path), os.path.realpath(root)
    return path == root or path.startswith(root + os.sep)


def protected(rel):
    rel = rel.replace(os.sep, "/")
    return any(rel == p or rel.startswith(p + "/") for p in PROTECTED)


class Plan:
    def __init__(self, apply, backup_root):
        self.apply, self.backup_root, self.actions, self.errors = apply, backup_root, [], []

    def note(self, kind, path, why=""):
        self.actions.append((kind, path, why))

    def write(self, src, dst, root, rel, overwrite):
        if protected(rel):
            self.errors.append(f"refusing protected path {rel}")
            return
        if os.path.islink(dst):
            self.errors.append(f"refusing symlink {dst}")
            return
        if not inside(os.path.dirname(dst) or ".", root):
            self.errors.append(f"refusing {dst}: outside {root}")
            return
        if os.path.exists(dst):
            if filecmp.cmp(src, dst, shallow=False):
                self.note("unchanged", dst)
                return
            if not overwrite:
                self.note("keep", dst, "exists; create-only / --missing-only")
                return
            bak = os.path.join(self.backup_root, rel)
            self.note("reset", dst, f"backup -> {bak}")
            if self.apply:
                os.makedirs(os.path.dirname(bak), exist_ok=True)
                shutil.copy2(dst, bak)
                shutil.copyfile(src, dst)
        else:
            self.note("create", dst)
            if self.apply:
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copyfile(src, dst)

    def mkdir(self, path):
        if os.path.isdir(path):
            return
        self.note("mkdir", path)
        if self.apply:
            os.makedirs(path, exist_ok=True)


def claude_pointer(target):
    """Project-root CLAUDE.md text with the real relative path to agent.md."""
    agent = os.path.join(HARNESS, "agent.md")
    rel = os.path.relpath(agent, target).replace(os.sep, "/")
    if rel.startswith(".."):            # harness outside the project: an absolute import is clearer
        rel = agent
    text = open(os.path.join(TEMPLATES, "CLAUDE.md")).read()
    return text.replace("slurm-agentic-engineering/agent.md", rel), rel


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--target", required=True, help="project root (the git repo the harness serves)")
    ap.add_argument("--workspace", default=None,
                    help="workspace directory (default: <target>/slurm-agentic-engineering)")
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="print the plan only (default)")
    mode.add_argument("--apply", action="store_true", help="perform the plan")
    ap.add_argument("--missing-only", action="store_true", help="only create documents that do not exist")
    ap.add_argument("--no-config", action="store_true", help="do not create config.sh")
    ap.add_argument("--no-claude-md", action="store_true", help="do not create the project-root CLAUDE.md")
    a = ap.parse_args(argv)

    target = os.path.realpath(a.target)
    if not os.path.isdir(target):
        print(f"reset_project: target {target} is not a directory", file=sys.stderr)
        return 2
    workspace = os.path.realpath(a.workspace or os.path.join(target, "slurm-agentic-engineering"))
    if not os.path.isdir(TEMPLATES):
        print(f"reset_project: templates missing at {TEMPLATES}", file=sys.stderr)
        return 2
    if os.path.realpath(workspace) == os.path.realpath(TEMPLATES) or inside(workspace, os.path.join(HARNESS, "templates")):
        print("reset_project: the workspace must not be inside the harness templates/", file=sys.stderr)
        return 2

    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    plan = Plan(a.apply, os.path.join(workspace, ".reset-backups", stamp))

    plan.mkdir(workspace)
    for d in WORKSPACE_DIRS:
        plan.mkdir(os.path.join(workspace, d))
    for rel in RESET_ALLOWLIST:
        plan.write(os.path.join(TEMPLATES, rel), os.path.join(workspace, rel), workspace, rel,
                   overwrite=not a.missing_only)
    if not a.no_config:
        plan.write(os.path.join(HARNESS, "config.example.sh"), os.path.join(workspace, "config.sh"),
                   workspace, "config.sh", overwrite=False)

    claude_note = None
    if not a.no_claude_md:
        text, rel = claude_pointer(target)
        dst = os.path.join(target, "CLAUDE.md")
        if os.path.islink(dst):
            plan.errors.append(f"refusing symlink {dst}")
        elif os.path.exists(dst):
            if "agent.md" in open(dst, errors="replace").read():
                plan.note("unchanged", dst, "already points at agent.md")
            else:
                plan.note("keep", dst, "exists; add this line yourself:")
                claude_note = f"    @{rel}"
        else:
            plan.note("create", dst, f"points at @{rel}")
            if a.apply:
                with open(dst, "w") as f:
                    f.write(text)

    verb = "APPLY" if a.apply else "DRY RUN (nothing written; add --apply)"
    print(f"reset_project: {verb}")
    print(f"  target:    {target}")
    print(f"  workspace: {workspace}")
    print(f"  mode:      {'create missing only' if a.missing_only else 'reset allowlisted documents'}")
    def shown(path):    # relative inside the project, absolute outside it (no ../../.. chains)
        return os.path.relpath(path, target) if inside(path, target) else path
    for kind, path, why in plan.actions:
        print(f"  {kind:9} {shown(path)}{('  (' + why + ')') if why else ''}")
    if claude_note:
        print(claude_note)
    if any(k == "reset" for k, _, _ in plan.actions):
        print(f"  backups:   {shown(plan.backup_root)}" + ("" if a.apply else " (would be written)"))
    if os.path.isdir(os.path.join(target, ".git")):
        print("  note:      git is never run; a dirty project tree is fine and stays as it was")
    for e in plan.errors:
        print(f"  ERROR     {e}", file=sys.stderr)
    return 2 if plan.errors else 0


if __name__ == "__main__":
    sys.exit(main())
