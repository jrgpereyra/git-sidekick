# git-sidekick MCP (solo lectura)

Servidor MCP en Python para que un agente consulte un repositorio Git usando las
convenciones de `git-sidekick`, sin modificar nada.

- Transporte: **stdio**.
- Solo lectura: no crea commits, ramas ni tags; no hace push ni fetch.
- No ejecuta `git-sidekick.sh` ni usa shell.
- No reemplaza el uso humano de `gk`: el menú y el CLI siguen igual.

## Requisitos

- Python 3.10 o superior.
- Git instalado.

## Instalación

```bash
cd mcp
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

El venv queda en `mcp/.venv` y está ignorado por Git.

## Ejecución

```bash
mcp/.venv/bin/python mcp/server.py
```

El servidor habla MCP por stdin/stdout. No imprime texto humano en stdout.

## Configuración en un cliente MCP

Ejemplo genérico:

```json
{
  "mcpServers": {
    "git-sidekick": {
      "command": "/ruta/a/git-sidekick/mcp/.venv/bin/python",
      "args": ["/ruta/a/git-sidekick/mcp/server.py"],
      "env": {
        "GIT_SIDEKICK_REPO": "/ruta/al/repositorio"
      }
    }
  }
}
```

Adaptá el formato al cliente que uses (OpenCode, Pi, Claude Desktop, etc.).
`GIT_SIDEKICK_REPO` es opcional: si no está, se usa el directorio actual.

## Tools

| Tool | Qué devuelve |
|---|---|
| `git_sidekick_status` | Rama, HEAD, upstream local, ahead/behind, archivos, conflictos y sesión |
| `git_sidekick_info` | Repo, rama, remoto, configuración, último snapshot, sesión y worklog |
| `git_sidekick_list_branches` | Ramas locales, actual, recomendada, upstream y ahead/behind |
| `git_sidekick_list_snapshots` | Tags de snapshot del prefijo configurado |

Todas aceptan `repo_path` opcional. `git_sidekick_status` acepta `file_limit`
(por defecto 200) y `git_sidekick_list_snapshots` acepta `limit` (por defecto 50).

## Resolución del repositorio

Orden:

1. `repo_path` de la tool.
2. Variable `GIT_SIDEKICK_REPO`.
3. Directorio de trabajo actual.

Se acepta la raíz del repo o un subdirectorio; el servidor normaliza al
`git rev-parse --show-toplevel`. No hay rechazos estrictos por subdirectorios.

Si querés limitar el acceso, definí `GIT_SIDEKICK_ALLOWED_ROOTS` con una lista de
rutas separadas por `:`. Si la variable no existe, no se aplica allowlist.

## Archivos que lee como texto plano

- `.git-sidekickrc`: solo `default_branch`, `dev_branch` y `snapshot_prefix`.
- `.git-sidekick-context`: `rama`, `fecha_inicio`, `accion`, `tag_inicio`.
- `.git-worklog.md`: cuenta líneas que empiezan con `## `.

Nunca se hace `source`, `eval`, `bash -c` ni expansión de variables sobre estos
archivos. Los valores se tratan como texto literal. Si un archivo es un symlink
que sale del repositorio, se ignora.

## Qué calcula el servidor por su cuenta

| Dato | Servidor MCP | `gk` |
|---|---|---|
| Rama y HEAD | Git directo | Git directo |
| Ahead/behind | Refs locales, **sin fetch** | `gk status` hace fetch; puede estar más actualizado |
| Archivos y conflictos | `git status --porcelain` | Lo traduce a lenguaje humano |
| Sesión | Lee `.git-sidekick-context` | La escribe y la limpia |
| Snapshots | Tags del prefijo configurado | Los crea y restaura |
| Bitácora | Cuenta encabezados `## ` | La escribe al cerrar sesión |
| Ramas configuradas | Lee `.git-sidekickrc` como texto | Lo carga con su parser |
| Recomendación conversacional | No la genera; devuelve datos crudos | La genera |
| Inicialización automática | Nunca inicializa | Puede ofrecerla |

Consecuencia importante: para el agente, `ahead/behind` refleja lo último que
Git conoce localmente. Si necesita datos frescos del servidor, primero hay que
hacer `git fetch` desde el flujo humano u otra herramienta.

## Seguridad y límites

- Sin shell: los comandos Git se ejecutan con una lista de argumentos.
- Solo comandos de lectura.
- `GIT_OPTIONAL_LOCKS=0` y `--no-optional-locks` para no tocar el index.
- `GIT_TERMINAL_PROMPT=0` para no quedar esperando credenciales.
- Sin red: no se ejecuta `fetch`, `pull`, `push` ni `clone`.
- Timeout de 5 segundos por comando.
- Límites de lectura: 64 KB para `.git-sidekickrc` y `.git-sidekick-context`; 2 MB para `.git-worklog.md`.
- Listas de archivos, ramas y snapshots con truncado explícito.
- URLs HTTP(S) con credenciales se devuelven redactadas.
- Logs del servidor solo por stderr; stdout queda para el protocolo MCP.
- No hay locks porque todas las operaciones son de lectura.

## Tests

```bash
mcp/.venv/bin/python -m py_compile mcp/*.py mcp/tests/*.py
mcp/.venv/bin/python -m unittest discover -s mcp/tests -v

bats tests/core.bats
shellcheck git-sidekick.sh lib/*.sh
```

Los tests cubren repo limpio/sucio, sin commits, detached HEAD, sin remoto,
subdirectorios, renombres con acentos, conflictos, worklog, snapshots,
redacción de credenciales, allowlist opcional, timeout y verificación de que
las cuatro tools no escriben en el repositorio.

## Fuera de alcance en esta versión

- Escrituras y mutaciones.
- Motor de planes o confirmaciones.
- `git fetch` o datos remotos frescos.
- Resources, prompts y transporte HTTP.
