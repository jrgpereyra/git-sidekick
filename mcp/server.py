#!/usr/bin/env python3
"""Servidor MCP de solo lectura para git-sidekick.

Transporte: stdio. No modifica repositorios, no usa shell y no ejecuta
git-sidekick.sh. Lee Git y los archivos de convención como texto plano.
"""

from __future__ import annotations

import sys
from pathlib import Path

# Cuando se ejecuta como script, permitir imports de los módulos locales.
sys.path.insert(0, str(Path(__file__).resolve().parent))

import models  # noqa: E402
import readonly  # noqa: E402
from mcp.server.fastmcp import FastMCP  # noqa: E402
from mcp.server.fastmcp.exceptions import ToolError  # noqa: E402
from mcp.types import ToolAnnotations  # noqa: E402

READ_ONLY = ToolAnnotations(
    readOnlyHint=True,
    destructiveHint=False,
    idempotentHint=True,
    openWorldHint=False,
)

mcp = FastMCP(
    "git-sidekick",
    instructions=(
        "Herramientas de solo lectura para inspeccionar un repositorio Git "
        "usando las convenciones de git-sidekick. No crea commits, tags ni "
        "ramas, y no modifica archivos."
    ),
    log_level="WARNING",
)


def _tool_call(function, *args, **kwargs):
    try:
        return function(*args, **kwargs)
    except readonly.SidekickError as exc:
        raise ToolError(exc.as_tool_message()) from exc


@mcp.tool(
    name="git_sidekick_status",
    title="Estado del repositorio",
    annotations=READ_ONLY,
)
def git_sidekick_status(
    repo_path: str | None = None,
    file_limit: int = readonly.DEFAULT_FILE_LIMIT,
) -> models.StatusResult:
    """Muestra rama, HEAD, upstream local, archivos con cambios y sesión activa.

    No hace fetch: ahead/behind se calculan contra las refs locales del upstream.
    """
    return _tool_call(readonly.get_status, repo_path, file_limit)


@mcp.tool(
    name="git_sidekick_info",
    title="Información del repositorio",
    annotations=READ_ONLY,
)
def git_sidekick_info(repo_path: str | None = None) -> models.InfoResult:
    """Resume repo, rama, remoto, configuración, sesión, worklog y snapshots."""
    return _tool_call(readonly.get_info, repo_path)


@mcp.tool(
    name="git_sidekick_list_branches",
    title="Ramas locales",
    annotations=READ_ONLY,
)
def git_sidekick_list_branches(repo_path: str | None = None) -> models.BranchListResult:
    """Lista ramas locales con actual, recomendada, upstream y ahead/behind local."""
    return _tool_call(readonly.list_branches, repo_path)


@mcp.tool(
    name="git_sidekick_list_snapshots",
    title="Snapshots",
    annotations=READ_ONLY,
)
def git_sidekick_list_snapshots(
    repo_path: str | None = None,
    limit: int = readonly.DEFAULT_SNAPSHOT_LIMIT,
) -> models.SnapshotListResult:
    """Lista los tags de snapshot del prefijo configurado, más recientes primero."""
    return _tool_call(readonly.list_snapshots, repo_path, limit)


if __name__ == "__main__":
    mcp.run()
