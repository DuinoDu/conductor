from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Optional


@dataclass
class GuessResult:
    project_root: Path
    repo_root: Path | None


class ProjectContext:
    """
    Provides read-only helpers for inspecting the current project workspace.
    """

    def __init__(self, path: str | Path | None = None) -> None:
        self.path = Path(path or os.getcwd()).resolve()

    def guess(self) -> GuessResult:
        repo_root = self._git_root(self.path)
        return GuessResult(project_root=self.path, repo_root=repo_root)

    def list_files(self, relative_to_repo: bool = True) -> list[Path]:
        result = self.guess()

        if result.repo_root:
            files = self._git_list_files(result.repo_root)
            return files if relative_to_repo else [result.repo_root / f for f in files]

        return sorted(
            (p.relative_to(result.project_root) for p in result.project_root.rglob("*") if p.is_file()),
            key=str,
        )

    def read_file(self, relative_path: Path) -> str:
        result = self.guess()
        target = (result.repo_root or result.project_root) / relative_path
        return target.read_text(encoding="utf-8")

    def get_diff(self, staged: bool = False) -> str:
        result = self.guess()
        if not result.repo_root:
            return ""
        flags = ["--staged"] if staged else []
        return self._run(["git", "diff", *flags], cwd=result.repo_root)

    def _git_root(self, start: Path) -> Path | None:
        try:
            output = self._run(["git", "rev-parse", "--show-toplevel"], cwd=start, check=True)
            return Path(output.strip())
        except subprocess.CalledProcessError:
            return None

    def _git_list_files(self, repo_root: Path) -> list[Path]:
        output = self._run(["git", "ls-files"], cwd=repo_root, check=True)
        return [Path(line) for line in output.splitlines() if line.strip()]

    def _run(
        self,
        cmd: list[str],
        *,
        cwd: Path,
        check: bool = False,
    ) -> str:
        proc = subprocess.run(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if check and proc.returncode != 0:
            raise subprocess.CalledProcessError(proc.returncode, cmd, proc.stdout, proc.stderr)
        return proc.stdout
