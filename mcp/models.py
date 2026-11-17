"""Modelos de entrada/salida del servidor MCP de git-sidekick."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

SERVER_VERSION = "0.1.0"


class ErrorInfo(BaseModel):
    code: str = Field(description="Código estable del error.")
    message: str = Field(description="Mensaje humano y corto.")
    hint: str | None = Field(default=None, description="Sugerencia para resolverlo.")


class FileChange(BaseModel):
    path: str = Field(description="Ruta reportada por Git.")
    kind: Literal[
        "modified",
        "added",
        "deleted",
        "renamed",
        "copied",
        "untracked",
        "conflict",
        "typechange",
        "other",
    ] = Field(description="Tipo de cambio en lenguaje simple.")
    index_status: str = Field(description="Estado en el índice (primera letra de Git).")
    worktree_status: str = Field(description="Estado en el árbol de trabajo (segunda letra).")
    staged: bool = Field(description="Si el cambio está preparado para commit.")
    untracked: bool = Field(description="Si el archivo es nuevo y no está trackeado.")
    renamed_from: str | None = Field(
        default=None, description="Ruta anterior cuando el archivo fue renombrado o copiado."
    )


class SessionInfo(BaseModel):
    active: bool = Field(description="Si existe un archivo de contexto de sesión.")
    branch: str | None = Field(default=None, description="Rama guardada en la sesión.")
    started_at: str | None = Field(default=None, description="Fecha de inicio guardada.")
    action: str | None = Field(default=None, description="Acción guardada en el contexto.")
    tag_inicio: str | None = Field(default=None, description="Snapshot de inicio de la sesión.")


class StatusData(BaseModel):
    branch: str | None = Field(description="Rama actual, o null si HEAD está detached.")
    head: str | None = Field(description="SHA corto de HEAD, o null si no hay commits.")
    detached: bool = Field(description="Si HEAD está detached.")
    upstream: str | None = Field(description="Upstream configurado para la rama actual.")
    ahead: int = Field(description="Commits locales sobre el upstream local.")
    behind: int = Field(description="Commits del upstream local que faltan.")
    dirty: bool = Field(description="Si hay cambios pendientes.")
    total_files: int = Field(description="Cantidad total de archivos con cambios.")
    files: list[FileChange] = Field(description="Archivos con cambios (puede estar truncado).")
    conflicts: int = Field(description="Cantidad de archivos en conflicto.")
    truncated: bool = Field(description="Si la lista de archivos quedó truncada.")
    session: SessionInfo = Field(description="Sesión de git-sidekick detectada en el repo.")


class RepoConfig(BaseModel):
    default_branch: str = Field(description="Rama principal configurada.")
    dev_branch: str = Field(description="Rama de desarrollo configurada.")
    snapshot_prefix: str = Field(description="Prefijo de tags de snapshot.")
    rc_loaded: bool = Field(description="Si se encontró y leyó .git-sidekickrc.")


class WorklogInfo(BaseModel):
    exists: bool = Field(description="Si existe .git-worklog.md.")
    sessions: int = Field(description="Cantidad de encabezados '## ' encontrados.")
    truncated: bool = Field(description="Si la lectura del worklog quedó truncada.")


class SnapshotSummary(BaseModel):
    tag: str = Field(description="Nombre del tag de snapshot.")
    date: str | None = Field(default=None, description="Fecha de creación del tag.")
    commit: str | None = Field(default=None, description="Commit apuntado por el tag.")
    subject: str | None = Field(default=None, description="Asunto del tag o del commit.")


class InfoData(BaseModel):
    repo_name: str = Field(description="Nombre de la carpeta raíz del repo.")
    branch: str | None = Field(description="Rama actual.")
    head: str | None = Field(description="SHA corto de HEAD.")
    detached: bool = Field(description="Si HEAD está detached.")
    remote: str | None = Field(description="URL del remoto origin, con credenciales redactadas.")
    config: RepoConfig = Field(description="Configuración leída de .git-sidekickrc.")
    last_snapshot: SnapshotSummary | None = Field(
        default=None, description="Snapshot más reciente."
    )
    snapshots_count: int = Field(description="Cantidad de snapshots existentes.")
    session: SessionInfo = Field(description="Sesión de git-sidekick detectada.")
    worklog: WorklogInfo = Field(description="Resumen de .git-worklog.md.")
    git_version: str | None = Field(default=None, description="Versión de Git detectada.")


class BranchInfo(BaseModel):
    name: str = Field(description="Nombre de la rama local.")
    current: bool = Field(description="Si es la rama actual.")
    recommended: bool = Field(description="Si coincide con dev_branch de la configuración.")
    upstream: str | None = Field(default=None, description="Upstream configurado.")
    ahead: int = Field(default=0, description="Commits locales sobre el upstream local.")
    behind: int = Field(default=0, description="Commits del upstream local que faltan.")
    last_commit_subject: str | None = Field(default=None, description="Asunto del último commit.")
    last_commit_date: str | None = Field(default=None, description="Fecha del último commit.")


class BranchListData(BaseModel):
    total: int = Field(description="Cantidad total de ramas locales.")
    truncated: bool = Field(description="Si la lista quedó truncada.")
    branches: list[BranchInfo] = Field(description="Ramas locales.")


class SnapshotListData(BaseModel):
    total: int = Field(description="Cantidad total de snapshots.")
    truncated: bool = Field(description="Si la lista quedó truncada.")
    snapshots: list[SnapshotSummary] = Field(description="Snapshots encontrados.")


class BaseResult(BaseModel):
    ok: Literal[True] = True
    version: str = Field(default=SERVER_VERSION, description="Versión del servidor MCP.")
    repo: str = Field(description="Ruta absoluta del repositorio consultado.")
    warnings: list[str] = Field(default_factory=list, description="Avisos no bloqueantes.")
    error: ErrorInfo | None = Field(default=None, description="Reservado para errores estructurados.")


class StatusResult(BaseResult):
    tool: Literal["git_sidekick_status"] = "git_sidekick_status"
    data: StatusData


class InfoResult(BaseResult):
    tool: Literal["git_sidekick_info"] = "git_sidekick_info"
    data: InfoData


class BranchListResult(BaseResult):
    tool: Literal["git_sidekick_list_branches"] = "git_sidekick_list_branches"
    data: BranchListData


class SnapshotListResult(BaseResult):
    tool: Literal["git_sidekick_list_snapshots"] = "git_sidekick_list_snapshots"
    data: SnapshotListData
