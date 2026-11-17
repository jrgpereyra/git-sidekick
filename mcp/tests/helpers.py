"""Utilidades para crear repositorios Git temporales en los tests."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path


def git(cwd: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.update(
        {
            "GIT_OPTIONAL_LOCKS": "0",
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_AUTHOR_NAME": "Test User",
            "GIT_AUTHOR_EMAIL": "test@example.com",
            "GIT_COMMITTER_NAME": "Test User",
            "GIT_COMMITTER_EMAIL": "test@example.com",
        }
    )
    proc = subprocess.run(
        ["git", "--no-optional-locks", *args],
        cwd=str(cwd),
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    if check and proc.returncode != 0:
        raise AssertionError(
            f"git {' '.join(args)} falló en {cwd}: {proc.stderr or proc.stdout}"
        )
    return proc


def init_repo(path: Path, commit: bool = True) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    git(path, "init", "-q")
    git(path, "config", "user.email", "test@example.com")
    git(path, "config", "user.name", "Test User")
    git(path, "checkout", "-q", "-b", "main")
    if commit:
        git(path, "commit", "-q", "--allow-empty", "-m", "Initial commit")
    return path


def write_file(path: Path, content: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def commit_file(repo: Path, name: str, content: str, message: str = "cambio") -> None:
    write_file(repo / name, content)
    git(repo, "add", name)
    git(repo, "commit", "-q", "-m", message)
