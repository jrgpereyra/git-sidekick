"""Tests unitarios de la capa read-only."""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "mcp"))

import models  # noqa: E402
import readonly  # noqa: E402
from helpers import commit_file, git, init_repo, write_file  # noqa: E402

ENV_KEYS = ("GIT_SIDEKICK_REPO", "GIT_SIDEKICK_ALLOWED_ROOTS")


class ReadonlyTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory(prefix="sidekick-mcp-")
        self.tmp = Path(self._tmp.name)
        self.repo = init_repo(self.tmp / "repo")

        self._saved_env = {key: os.environ.get(key) for key in ENV_KEYS}
        for key in ENV_KEYS:
            os.environ.pop(key, None)

    def tearDown(self) -> None:
        for key, value in self._saved_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        self._tmp.cleanup()

    def assert_error(self, code: str, function, *args, **kwargs) -> None:
        with self.assertRaises(readonly.SidekickError) as context:
            function(*args, **kwargs)
        self.assertEqual(context.exception.code, code)

    def test_resuelve_repo_desde_subdirectorio(self) -> None:
        subdir = self.repo / "carpeta" / "interna"
        subdir.mkdir(parents=True)

        result = readonly.get_status(str(subdir))

        self.assertEqual(result.repo, str(self.repo.resolve()))
        self.assertEqual(result.data.branch, "main")

    def test_status_limpio_sucio_y_staged(self) -> None:
        clean = readonly.get_status(str(self.repo))
        self.assertFalse(clean.data.dirty)
        self.assertEqual(clean.data.total_files, 0)

        write_file(self.repo / "nuevo.txt", "contenido")
        dirty = readonly.get_status(str(self.repo))
        self.assertTrue(dirty.data.dirty)
        self.assertEqual(dirty.data.total_files, 1)
        self.assertEqual(dirty.data.files[0].kind, "untracked")
        self.assertTrue(dirty.data.files[0].untracked)
        self.assertFalse(dirty.data.files[0].staged)

        git(self.repo, "add", "nuevo.txt")
        staged = readonly.get_status(str(self.repo))
        self.assertEqual(staged.data.files[0].kind, "added")
        self.assertTrue(staged.data.files[0].staged)

        git(self.repo, "commit", "-q", "-m", "agrega nuevo")
        write_file(self.repo / "nuevo.txt", "cambiado")
        modified = readonly.get_status(str(self.repo))
        self.assertEqual(modified.data.files[0].kind, "modified")
        self.assertFalse(modified.data.files[0].staged)

    def test_status_renombre_con_espacios_y_acentos(self) -> None:
        old = self.repo / "nombre viejo.txt"
        commit_file(self.repo, "nombre viejo.txt", "contenido", "base")
        git(self.repo, "mv", "nombre viejo.txt", "informe año.txt")

        result = readonly.get_status(str(self.repo))
        renamed = next(item for item in result.data.files if item.kind == "renamed")

        self.assertEqual(renamed.path, "informe año.txt")
        self.assertEqual(renamed.renamed_from, "nombre viejo.txt")
        self.assertEqual(old.name, "nombre viejo.txt")

    def test_status_repo_sin_commits(self) -> None:
        empty = init_repo(self.tmp / "empty", commit=False)

        result = readonly.get_status(str(empty))

        self.assertIsNone(result.data.head)
        self.assertFalse(result.data.detached)
        self.assertFalse(result.data.dirty)

    def test_status_detached_head(self) -> None:
        git(self.repo, "checkout", "-q", "--detach", "HEAD")

        result = readonly.get_status(str(self.repo))

        self.assertTrue(result.data.detached)
        self.assertIsNone(result.data.branch)
        self.assertIsNotNone(result.data.head)

    def test_status_sin_remoto(self) -> None:
        result = readonly.get_status(str(self.repo))

        self.assertIsNone(result.data.upstream)
        self.assertEqual(result.data.ahead, 0)
        self.assertEqual(result.data.behind, 0)

    def test_status_con_upstream_adelantado(self) -> None:
        remote = self.tmp / "remote.git"
        git(self.tmp, "init", "--bare", "-q", str(remote))
        git(self.repo, "remote", "add", "origin", str(remote))
        git(self.repo, "push", "-q", "-u", "origin", "main")

        commit_file(self.repo, "a.txt", "a", "commit local")

        result = readonly.get_status(str(self.repo))
        self.assertEqual(result.data.upstream, "origin/main")
        self.assertEqual(result.data.ahead, 1)
        self.assertEqual(result.data.behind, 0)

    def test_status_conflicto(self) -> None:
        git(self.repo, "checkout", "-q", "-b", "otra")
        commit_file(self.repo, "conflicto.txt", "version otra", "otra")
        git(self.repo, "checkout", "-q", "main")
        commit_file(self.repo, "conflicto.txt", "version main", "main")
        git(self.repo, "merge", "otra", check=False)

        result = readonly.get_status(str(self.repo))

        self.assertEqual(result.data.conflicts, 1)
        self.assertEqual(result.data.files[0].kind, "conflict")

    def test_conflictos_se_cuentan_aunque_la_lista_se_trunca(self) -> None:
        git(self.repo, "checkout", "-q", "-b", "otra")
        commit_file(self.repo, "conflicto.txt", "version otra", "otra")
        git(self.repo, "checkout", "-q", "main")
        commit_file(self.repo, "conflicto.txt", "version main", "main")
        git(self.repo, "merge", "otra", check=False)
        for index in range(3):
            write_file(self.repo / f"nuevo-{index}.txt", "x")

        result = readonly.get_status(str(self.repo), file_limit=1)

        self.assertTrue(result.data.truncated)
        self.assertEqual(result.data.conflicts, 1)

    def test_config_es_texto_plano_y_no_ejecuta(self) -> None:
        marker = self.tmp / "pwned"
        write_file(
            self.repo / ".git-sidekickrc",
            "\n".join(
                [
                    "# configuración de prueba",
                    "  dev_branch = qa # rama de pruebas  ",
                    f"default_branch=$(touch {marker})",
                    "snapshot_prefix=save",
                    "clave_desconocida=ignorada",
                ]
            ),
        )

        config, warnings = readonly.parse_config(self.repo)

        self.assertFalse(marker.exists())
        self.assertEqual(config.dev_branch, "qa")
        self.assertEqual(config.default_branch, f"$(touch {marker})")
        self.assertEqual(config.snapshot_prefix, "save")
        self.assertTrue(config.rc_loaded)
        self.assertEqual(warnings, [])

    def test_contexto_y_worklog(self) -> None:
        write_file(
            self.repo / ".git-sidekick-context",
            "\n".join(
                [
                    "rama=dev",
                    "fecha_inicio=2026-11-17_10-00",
                    "accion=inicio",
                    "tag_inicio=work/2026-11-17_10-00",
                ]
            ),
        )
        write_file(
            self.repo / ".git-worklog.md",
            "# Bitácora de trabajo\n\n## Sesión 1\n- algo\n\n## Sesión 2\n- otra cosa\n",
        )

        result = readonly.get_info(str(self.repo))

        self.assertTrue(result.data.session.active)
        self.assertEqual(result.data.session.branch, "dev")
        self.assertEqual(result.data.session.started_at, "2026-11-17_10-00")
        self.assertEqual(result.data.worklog.sessions, 2)
        self.assertTrue(result.data.worklog.exists)

    def test_lista_snapshots(self) -> None:
        git(self.repo, "tag", "work/2026-01-01_10-00")
        git(self.repo, "tag", "work/2026-01-02_10-00")
        git(self.repo, "tag", "otro/ignorado")

        result = readonly.list_snapshots(str(self.repo))

        self.assertEqual(result.data.total, 2)
        self.assertFalse(result.data.truncated)
        self.assertEqual(
            {item.tag for item in result.data.snapshots},
            {"work/2026-01-01_10-00", "work/2026-01-02_10-00"},
        )
        self.assertTrue(all(item.commit for item in result.data.snapshots))

    def test_lista_ramas_marca_actual_y_recomendada(self) -> None:
        git(self.repo, "branch", "dev")

        result = readonly.list_branches(str(self.repo))

        main = next(item for item in result.data.branches if item.name == "main")
        dev = next(item for item in result.data.branches if item.name == "dev")
        self.assertTrue(main.current)
        self.assertFalse(main.recommended)
        self.assertTrue(dev.recommended)
        self.assertFalse(dev.current)

    def test_info_redacta_credenciales_del_remoto(self) -> None:
        git(
            self.repo,
            "remote",
            "add",
            "origin",
            "https://usuario:secreto@example.com/repo.git",
        )

        result = readonly.get_info(str(self.repo))

        self.assertEqual(result.data.remote, "https://***@example.com/repo.git")
        self.assertNotIn("secreto", result.model_dump_json())

    def test_allowlist_es_opcional_pero_se_respeta(self) -> None:
        other = self.tmp / "otro"
        other.mkdir()
        self.assertEqual(readonly.get_status(str(self.repo)).data.branch, "main")

        with patch.dict(os.environ, {"GIT_SIDEKICK_ALLOWED_ROOTS": str(other)}):
            self.assert_error(
                "REPO_NOT_ALLOWED", readonly.get_status, str(self.repo)
            )

    def test_timeout_de_git(self) -> None:
        fake_bin = self.tmp / "bin"
        fake_bin.mkdir()
        fake_git = fake_bin / "git"
        write_file(fake_git, "#!/bin/sh\nsleep 2\n")
        fake_git.chmod(0o755)

        with patch.dict(os.environ, {"PATH": f"{fake_bin}{os.pathsep}{os.environ['PATH']}"}):
            with self.assertRaises(readonly.SidekickError) as context:
                readonly.run_git(self.repo, "status", timeout=0.05)

        self.assertEqual(context.exception.code, "GIT_TIMEOUT")

    def test_limite_invalido(self) -> None:
        self.assert_error("INVALID_ARG", readonly.get_status, str(self.repo), 0)

    def test_salida_sin_ansi(self) -> None:
        write_file(self.repo / "nuevo.txt", "x")
        result = readonly.get_status(str(self.repo))

        self.assertNotIn("\x1b", result.model_dump_json())

    def test_las_cuatro_tools_no_escriben(self) -> None:
        write_file(self.repo / "pendiente.txt", "sin guardar")
        git(self.repo, "tag", "work/2026-01-01_10-00")
        git(self.repo, "branch", "dev")

        before_status = git(self.repo, "status", "--porcelain").stdout
        before_tags = git(self.repo, "tag", "--list").stdout
        before_branches = git(self.repo, "branch", "--list").stdout
        before_head = git(self.repo, "rev-parse", "HEAD").stdout

        readonly.get_status(str(self.repo))
        readonly.get_info(str(self.repo))
        readonly.list_branches(str(self.repo))
        readonly.list_snapshots(str(self.repo))

        self.assertEqual(git(self.repo, "status", "--porcelain").stdout, before_status)
        self.assertEqual(git(self.repo, "tag", "--list").stdout, before_tags)
        self.assertEqual(git(self.repo, "branch", "--list").stdout, before_branches)
        self.assertEqual(git(self.repo, "rev-parse", "HEAD").stdout, before_head)
        self.assertFalse((self.repo / ".git" / "index.lock").exists())


if __name__ == "__main__":
    unittest.main()
