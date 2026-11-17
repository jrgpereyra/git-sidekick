"""Lectura de solo lectura para el servidor MCP de git-sidekick.

No ejecuta git-sidekick.sh: lee Git y los archivos de convención como texto
plano. Nunca usa shell, eval, source ni expansión de variables.
"""

from __future__ import annotations

import os
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

import models

DEFAULT_TIMEOUT = 5.0
DEFAULT_FILE_LIMIT = 200
MAX_FILE_LIMIT = 1000
DEFAULT_SNAPSHOT_LIMIT = 50
MAX_SNAPSHOT_LIMIT = 500
MAX_BRANCHES = 500
MAX_RC_BYTES = 64 * 1024
MAX_CONTEXT_BYTES = 64 * 1024
MAX_WORKLOG_BYTES = 2 * 1024 * 1024

CONFLICT_CODES = {"DD", "AU", "UD", "UA", "DU", "AA", "UU"}
SNAPSHOT_PREFIX_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9._-]+)*$")


class SidekickError(Exception):
    """Error controlado con código estable para las tools MCP."""

    def __init__(self, code: str, message: str, hint: str | None = None) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.hint = hint

    def as_tool_message(self) -> str:
        text = f"[{self.code}] {self.message}"
        if self.hint:
            text += f" {self.hint}"
        return text


@dataclass(frozen=True)
class GitOutput:
    returncode: int
    stdout: str
    stderr: str


def _git_env() -> dict[str, str]:
    env = os.environ.copy()
    env.update(
        {
            "GIT_OPTIONAL_LOCKS": "0",
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_PAGER": "cat",
            "PAGER": "cat",
        }
    )
    return env


def redact_text(text: str) -> str:
    """Oculta credenciales embebidas en URLs HTTP(S)."""
    return re.sub(r"(https?://)[^/@\s]+@", r"\1***@", text)


def run_git(
    repo: Path,
    *args: str,
    timeout: float = DEFAULT_TIMEOUT,
    check: bool = True,
) -> GitOutput:
    """Ejecuta Git sin shell y con locks opcionales desactivados."""
    command = ["git", "--no-optional-locks", *args]
    try:
        proc = subprocess.run(
            command,
            cwd=str(repo),
            env=_git_env(),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
    except FileNotFoundError as exc:
        raise SidekickError(
            "GIT_NOT_FOUND",
            "No encontré el comando 'git'.",
            "Instalá Git y volvé a intentar.",
        ) from exc
    except subprocess.TimeoutExpired as exc:
        raise SidekickError(
            "GIT_TIMEOUT",
            "Git tardó demasiado en responder.",
            "Revisá el repositorio o aumentá el timeout del servidor.",
        ) from exc

    stdout = proc.stdout.decode("utf-8", "replace")
    stderr = redact_text(proc.stderr.decode("utf-8", "replace")).strip()
    if check and proc.returncode != 0:
        detail = stderr or f"código de salida {proc.returncode}"
        raise SidekickError(
            "GIT_FAILED",
            f"Git falló al ejecutar '{' '.join(command)}'.",
            f"Detalle: {detail}",
        )
    return GitOutput(proc.returncode, stdout, stderr)


def resolve_repo(repo_path: str | None = None) -> Path:
    """Resuelve el repo: argumento, variable de entorno o directorio actual."""
    raw = repo_path or os.environ.get("GIT_SIDEKICK_REPO") or os.getcwd()
    try:
        candidate = Path(raw).expanduser().resolve(strict=True)
    except (OSError, RuntimeError) as exc:
        raise SidekickError(
            "NOT_A_REPO",
            f"La ruta '{raw}' no existe o no se puede leer.",
            "Pasá una ruta válida a un repositorio Git.",
        ) from exc

    if not candidate.is_dir():
        raise SidekickError(
            "NOT_A_REPO",
            f"La ruta '{candidate}' no es una carpeta.",
            "Pasá la raíz de un repositorio Git o un subdirectorio.",
        )

    result = run_git(candidate, "rev-parse", "--show-toplevel", check=False)
    top_text = result.stdout.strip()
    if result.returncode != 0 or not top_text:
        raise SidekickError(
            "NOT_A_REPO",
            f"La carpeta '{candidate}' no es un repositorio Git.",
            "Entrá al repo o pasá su ruta con repo_path.",
        )

    try:
        top = Path(top_text).resolve(strict=True)
    except (OSError, RuntimeError) as exc:
        raise SidekickError(
            "NOT_A_REPO",
            "No pude resolver la raíz del repositorio.",
            "Revisá que el repositorio no tenga enlaces rotos.",
        ) from exc

    allowed = os.environ.get("GIT_SIDEKICK_ALLOWED_ROOTS", "").strip()
    if allowed:
        roots: list[Path] = []
        for part in allowed.split(os.pathsep):
            if not part.strip():
                continue
            try:
                roots.append(Path(part).expanduser().resolve(strict=True))
            except (OSError, RuntimeError):
                continue
        if not roots or not any(top == root or root in top.parents for root in roots):
            raise SidekickError(
                "REPO_NOT_ALLOWED",
                f"El repositorio '{top}' no está dentro de las rutas permitidas.",
                "Ajustá GIT_SIDEKICK_ALLOWED_ROOTS o quitá la variable.",
            )

    return top


def _read_plain_text(repo: Path, name: str, limit: int) -> tuple[str | None, bool, bool]:
    """Lee un archivo conocido del repo como texto plano, sin ejecutarlo.

    Retorna (texto, truncado, existe). Si el archivo es un symlink que sale del
    repo, se ignora.
    """
    path = repo / name
    if not path.exists():
        return None, False, False

    try:
        resolved = path.resolve(strict=True)
    except (OSError, RuntimeError):
        return None, False, True

    if resolved != repo and repo not in resolved.parents:
        return None, False, True
    if not resolved.is_file():
        return None, False, True

    try:
        with resolved.open("rb") as handle:
            data = handle.read(limit + 1)
    except OSError:
        return None, False, True

    truncated = len(data) > limit
    return data[:limit].decode("utf-8", "replace"), truncated, True


def parse_config(repo: Path) -> tuple[models.RepoConfig, list[str]]:
    """Lee .git-sidekickrc como clave=valor. No ejecuta ni evalúa valores."""
    text, truncated, exists = _read_plain_text(repo, ".git-sidekickrc", MAX_RC_BYTES)
    warnings: list[str] = []
    if truncated:
        warnings.append("'.git-sidekickrc' es muy grande; se leyó solo el comienzo.")

    config = models.RepoConfig(
        default_branch="main",
        dev_branch="dev",
        snapshot_prefix="work",
        rc_loaded=text is not None,
    )
    if text is None:
        return config, warnings

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip().lower()
        value = value.split("#", 1)[0].strip()
        if not value:
            continue
        if key == "default_branch":
            config.default_branch = value
        elif key == "dev_branch":
            config.dev_branch = value
        elif key == "snapshot_prefix":
            if SNAPSHOT_PREFIX_RE.match(value) and ".." not in value:
                config.snapshot_prefix = value.rstrip("/")
            else:
                warnings.append(
                    f"El snapshot_prefix '{value}' no es válido; se usó 'work'."
                )
    return config, warnings


def parse_context(repo: Path) -> tuple[models.SessionInfo, list[str]]:
    """Lee .git-sidekick-context como clave=valor, sin ejecutarlo."""
    text, truncated, _exists = _read_plain_text(repo, ".git-sidekick-context", MAX_CONTEXT_BYTES)
    warnings: list[str] = []
    if truncated:
        warnings.append("'.git-sidekick-context' es muy grande; se leyó solo el comienzo.")

    session = models.SessionInfo(active=text is not None)
    if text is None:
        return session, warnings

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip().lower()
        value = value.strip()
        if key == "rama":
            session.branch = value or None
        elif key == "fecha_inicio":
            session.started_at = value or None
        elif key == "accion":
            session.action = value or None
        elif key == "tag_inicio":
            session.tag_inicio = value or None
    return session, warnings


def read_worklog(repo: Path) -> tuple[models.WorklogInfo, list[str]]:
    """Cuenta encabezados '## ' de .git-worklog.md sin interpretar el contenido."""
    text, truncated, exists = _read_plain_text(repo, ".git-worklog.md", MAX_WORKLOG_BYTES)
    warnings: list[str] = []
    if truncated:
        warnings.append("'.git-worklog.md' es muy grande; el conteo puede ser parcial.")
    sessions = 0
    if text is not None:
        sessions = sum(1 for line in text.splitlines() if line.startswith("## "))
    return models.WorklogInfo(exists=exists, sessions=sessions, truncated=truncated), warnings


def _head_info(repo: Path) -> tuple[str | None, str | None, bool]:
    branch_out = run_git(repo, "symbolic-ref", "--quiet", "--short", "HEAD", check=False)
    branch = branch_out.stdout.strip() or None

    head_out = run_git(repo, "rev-parse", "--short", "HEAD", check=False)
    head = head_out.stdout.strip() or None

    detached = branch is None and head is not None
    return branch, head, detached


def _upstream_info(repo: Path) -> tuple[str | None, int, int]:
    upstream_out = run_git(
        repo,
        "rev-parse",
        "--abbrev-ref",
        "--symbolic-full-name",
        "@{upstream}",
        check=False,
    )
    upstream = upstream_out.stdout.strip() or None
    if not upstream:
        return None, 0, 0

    behind_out = run_git(repo, "rev-list", "--count", f"HEAD..{upstream}", check=False)
    ahead_out = run_git(repo, "rev-list", "--count", f"{upstream}..HEAD", check=False)
    behind = _to_int(behind_out.stdout)
    ahead = _to_int(ahead_out.stdout)
    return upstream, ahead, behind


def _to_int(value: str) -> int:
    try:
        return int(value.strip())
    except (TypeError, ValueError):
        return 0


def _classify_change(xy: str) -> str:
    if xy in CONFLICT_CODES:
        return "conflict"
    if xy == "??":
        return "untracked"
    if xy[0] == "R":
        return "renamed"
    if xy[0] == "C":
        return "copied"
    if xy[0] == "A":
        return "added"
    if xy[0] == "D" or xy[1] == "D":
        return "deleted"
    if xy[0] == "T" or xy[1] == "T":
        return "typechange"
    if xy[0] == "?" or xy[1] == "?":
        return "untracked"
    return "modified"


def _parse_status_files(stdout: str) -> list[models.FileChange]:
    records = stdout.split("\0")
    files: list[models.FileChange] = []
    index = 0
    while index < len(records):
        record = records[index]
        if not record:
            index += 1
            continue
        if len(record) < 3:
            index += 1
            continue

        xy = record[:2]
        path = record[3:]
        renamed_from = None
        if xy[0] in ("R", "C") and index + 1 < len(records):
            candidate = records[index + 1]
            if candidate:
                renamed_from = candidate
                index += 1

        files.append(
            models.FileChange(
                path=path,
                kind=_classify_change(xy),
                index_status=xy[0],
                worktree_status=xy[1],
                staged=xy[0] not in (" ", "?", "!"),
                untracked=xy == "??",
                renamed_from=renamed_from,
            )
        )
        index += 1
    return files


def _valid_limit(value: int | None, default: int, maximum: int, name: str) -> int:
    if value is None:
        return default
    if isinstance(value, bool) or not isinstance(value, int):
        raise SidekickError("INVALID_ARG", f"'{name}' debe ser un entero.")
    if value < 1:
        raise SidekickError("INVALID_ARG", f"'{name}' debe ser mayor o igual a 1.")
    return min(value, maximum)


def get_status(repo_path: str | None = None, file_limit: int = DEFAULT_FILE_LIMIT) -> models.StatusResult:
    """Devuelve rama, remoto local, archivos y sesión."""
    repo = resolve_repo(repo_path)
    limit = _valid_limit(file_limit, DEFAULT_FILE_LIMIT, MAX_FILE_LIMIT, "file_limit")

    branch, head, detached = _head_info(repo)
    upstream, ahead, behind = _upstream_info(repo)
    status_out = run_git(
        repo,
        "status",
        "--porcelain=v1",
        "-z",
        "--untracked-files=all",
    )
    all_files = _parse_status_files(status_out.stdout)
    warnings: list[str] = []
    session, session_warnings = parse_context(repo)
    warnings.extend(session_warnings)

    total_files = len(all_files)
    truncated = total_files > limit
    files = all_files[:limit]
    if truncated:
        warnings.append(f"Se muestran {limit} de {total_files} archivos con cambios.")

    data = models.StatusData(
        branch=branch,
        head=head,
        detached=detached,
        upstream=upstream,
        ahead=ahead,
        behind=behind,
        dirty=total_files > 0,
        total_files=total_files,
        files=files,
        conflicts=sum(1 for item in all_files if item.kind == "conflict"),
        truncated=truncated,
        session=session,
    )
    return models.StatusResult(repo=str(repo), warnings=warnings, data=data)


def _snapshot_list(
    repo: Path, config: models.RepoConfig, limit: int, *, warn_truncated: bool = True
) -> tuple[models.SnapshotListData, list[str]]:
    pattern = f"refs/tags/{config.snapshot_prefix}/"
    result = run_git(
        repo,
        "for-each-ref",
        "--sort=-creatordate",
        "--format=%(refname:short)%00%(creatordate:iso8601)%00%(objectname:short)%00%(contents:subject)",
        pattern,
    )

    snapshots: list[models.SnapshotSummary] = []
    for line in result.stdout.split("\n"):
        if not line:
            continue
        parts = line.split("\0")
        if len(parts) < 4:
            continue
        tag = parts[0].strip()
        if not tag.startswith(f"{config.snapshot_prefix}/"):
            continue
        snapshots.append(
            models.SnapshotSummary(
                tag=tag,
                date=parts[1].strip() or None,
                commit=parts[2].strip() or None,
                subject=parts[3].strip() or None,
            )
        )

    total = len(snapshots)
    truncated = total > limit
    warnings: list[str] = []
    if truncated and warn_truncated:
        warnings.append(f"Se muestran {limit} de {total} snapshots.")
    return models.SnapshotListData(
        total=total, truncated=truncated, snapshots=snapshots[:limit]
    ), warnings


def list_snapshots(
    repo_path: str | None = None, limit: int = DEFAULT_SNAPSHOT_LIMIT
) -> models.SnapshotListResult:
    """Lista tags de snapshot del prefijo configurado."""
    repo = resolve_repo(repo_path)
    max_limit = _valid_limit(limit, DEFAULT_SNAPSHOT_LIMIT, MAX_SNAPSHOT_LIMIT, "limit")
    config, config_warnings = parse_config(repo)
    data, warnings = _snapshot_list(repo, config, max_limit)
    return models.SnapshotListResult(
        repo=str(repo), warnings=[*config_warnings, *warnings], data=data
    )


def _git_version(repo: Path) -> str | None:
    result = run_git(repo, "--version", check=False)
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def get_info(repo_path: str | None = None) -> models.InfoResult:
    """Devuelve un resumen del repo y de la convención de git-sidekick."""
    repo = resolve_repo(repo_path)
    config, config_warnings = parse_config(repo)
    session, session_warnings = parse_context(repo)
    worklog, worklog_warnings = read_worklog(repo)
    snapshots, snapshot_warnings = _snapshot_list(
        repo, config, 1, warn_truncated=False
    )

    remote_out = run_git(repo, "remote", "get-url", "origin", check=False)
    remote = remote_out.stdout.strip() or None
    if remote:
        remote = redact_text(remote)

    branch, head, detached = _head_info(repo)
    data = models.InfoData(
        repo_name=repo.name,
        branch=branch,
        head=head,
        detached=detached,
        remote=remote,
        config=config,
        last_snapshot=snapshots.snapshots[0] if snapshots.snapshots else None,
        snapshots_count=snapshots.total,
        session=session,
        worklog=worklog,
        git_version=_git_version(repo),
    )
    return models.InfoResult(
        repo=str(repo),
        warnings=[
            *config_warnings,
            *session_warnings,
            *worklog_warnings,
            *snapshot_warnings,
        ],
        data=data,
    )


def _branch_origin(repo: Path, branch: str, upstream: str | None) -> tuple[int, int]:
    if not upstream:
        return 0, 0
    behind_out = run_git(repo, "rev-list", "--count", f"{branch}..{upstream}", check=False)
    ahead_out = run_git(repo, "rev-list", "--count", f"{upstream}..{branch}", check=False)
    return _to_int(ahead_out.stdout), _to_int(behind_out.stdout)


def list_branches(repo_path: str | None = None) -> models.BranchListResult:
    """Lista ramas locales con su relación con el upstream local."""
    repo = resolve_repo(repo_path)
    config, config_warnings = parse_config(repo)

    result = run_git(
        repo,
        "for-each-ref",
        "--format=%(refname:short)%00%(upstream:short)%00%(HEAD)%00%(committerdate:iso8601)%00%(subject)",
        "refs/heads/",
    )

    branches: list[models.BranchInfo] = []
    for line in result.stdout.split("\n"):
        if not line:
            continue
        parts = line.split("\0")
        if len(parts) < 5:
            continue
        name = parts[0].strip()
        if not name:
            continue
        upstream = parts[1].strip() or None
        current = parts[2].strip() == "*"
        ahead, behind = _branch_origin(repo, name, upstream)
        branches.append(
            models.BranchInfo(
                name=name,
                current=current,
                recommended=name == config.dev_branch,
                upstream=upstream,
                ahead=ahead,
                behind=behind,
                last_commit_subject=parts[4].strip() or None,
                last_commit_date=parts[3].strip() or None,
            )
        )

    branches.sort(key=lambda item: (not item.current, not item.recommended, item.name.lower()))
    total = len(branches)
    truncated = total > MAX_BRANCHES
    warnings = list(config_warnings)
    if truncated:
        warnings.append(f"Se muestran {MAX_BRANCHES} de {total} ramas.")

    data = models.BranchListData(
        total=total, truncated=truncated, branches=branches[:MAX_BRANCHES]
    )
    return models.BranchListResult(repo=str(repo), warnings=warnings, data=data)
