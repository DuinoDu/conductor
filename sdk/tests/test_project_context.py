from __future__ import annotations

import subprocess
from pathlib import Path

import os
from conductor.context import ProjectContext


def _env():
    env = dict(**os.environ)
    env.update({"GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "test@example.com", "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "test@example.com"})
    return env


def init_repo(path: Path) -> None:
    env = _env()
    subprocess.run(["git", "init"], cwd=path, check=True, stdout=subprocess.PIPE, env=env)
    (path / "README.md").write_text("# Demo\n", encoding="utf-8")
    subprocess.run(["git", "add", "."], cwd=path, check=True, stdout=subprocess.PIPE, env=env)
    subprocess.run(["git", "commit", "-m", "init"], cwd=path, check=True, stdout=subprocess.PIPE, env=env)


def test_guess_repo_root(tmp_path):
    init_repo(tmp_path)
    ctx = ProjectContext(tmp_path)
    result = ctx.guess()
    assert result.repo_root == tmp_path.resolve()
    assert result.project_root == tmp_path.resolve()


def test_list_files_matches_git(tmp_path):
    init_repo(tmp_path)
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "main.py").write_text("print('hi')\n", encoding="utf-8")
    env = _env()
    subprocess.run(["git", "add", "."], cwd=tmp_path, check=True, stdout=subprocess.PIPE, env=env)
    files = ProjectContext(tmp_path).list_files()
    assert Path("README.md") in files
    assert Path("src/main.py") in files


def test_get_diff(tmp_path):
    init_repo(tmp_path)
    file_path = tmp_path / "README.md"
    file_path.write_text("# Demo!\n", encoding="utf-8")
    ctx = ProjectContext(tmp_path)
    diff = ctx.get_diff()
    assert "Demo" in diff
