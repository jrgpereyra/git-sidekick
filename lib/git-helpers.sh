#!/usr/bin/env bash
# =============================================================================
# lib/git-helpers.sh - Funciones auxiliares de Git (consultas/operaciones)
# Extraído de git-sidekick.sh para modularización (ROADMAP v2.0, Sesión 2)
# Requiere: lib/colors.sh (para say_* y variables de color)
#           lib/config.sh (para DEFAULT_BRANCH y DEV_BRANCH)
# =============================================================================
# Flujo: introspección git + presentación de errores. check_git/tiene_cambios para
# guardas; listar_ramas/disponibles/timestamp para info; say_git_error para errores.

# --- Listado reutilizable de ramas (para errores amigables) ---
# --- FUNCIÓN: listar_ramas_disponibles ---
# PROPÓSITO: imprimir ramas locales numeradas (N) con marca de actual y recomendada.
# PARÁMETROS: (ninguno; lee `git branch`).
# RETORNA: 0 (siempre); escribe la lista a stdout.
# POR QUÉ: guía al novato a elegir sin teclear nombres (evita errores de tipeo).
listar_ramas_disponibles() {
    echo -e "${BLUE}📋 Ramas disponibles:${NC}"
    local r _i=1 _actual
    _actual=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    while IFS= read -r r; do
        [ -z "$r" ] && continue
        if [ "$r" = "$_actual" ]; then
            echo "  $_i) $r ✓ (actual)"
        else
            echo "  $_i) $r"
        fi
        _i=$((_i + 1))
    done < <(git branch --format='%(refname:short)' --sort=-committerdate 2>/dev/null)
    echo "  0) Crear nueva rama..."
}

# --- Error contextual: interpreta el error de git y sugiere solución ---
# --- FUNCIÓN: say_git_error ---
# PROPÓSITO: interpretar la salida de error de git y proponer una reparación.
# PARÁMETROS: $1 = stderr/captura de error de git.
# RETORNA: 0 (siempre); escribe error (❌) + tip (💡) a stdout.
# POR QUÉ: los errores crudos de git son crípticos para novatos (ver AGENTS.md).
# NOTA: mapea mensajes conocidos (conflictos, sin upstream...) a ayudas concretas.
say_git_error() {
    local err="$1"
    case "$err" in
        *pathspec*|*"no such branch"*|*"not found"*|*"no existe"*|*"No such"*|*"not a git repository"*)
            if [[ "$err" == *"not a git repository"* ]] || [[ "$err" == *"No es un repositorio"* ]]; then
                say_error "Esta carpeta no es un repositorio Git."
                say_tip "Inicializá uno corriendo: gk (o 'git init')"
            else
                say_error "La rama solicitada no existe."
                say_tip "Acá las ramas que tenés:"
                listar_ramas_disponibles
            fi
            ;;
        *[Cc]onflict*)
            say_warn "Hubo conflictos de merge."
            say_tip "Abrí los archivos marcados con '<<<<<<<', resolvé, luego: git add . && git commit"
            ;;
        *)
            say_error "git devolvió un error."
            say_tip "Consultá el detalle técnico: $err"
            ;;
    esac
}

# --- Funciones auxiliares (vacías) ---
# --- FUNCIÓN: check_git ---
# PROPÓSITO: verificar que el cwd esté dentro de un repo git válido.
# PARÁMETROS: (ninguno).
# RETORNA: 0 si hay repo (cwd o padre), 1 si no (avisa al usuario).
# POR QUÉ: soporta subdirectorios donde .git vive en un padre del cwd.
# NOTA: si .git está en un padre distinto al cwd, ADVIERTE (evita mezclar proyectos).
check_git() {
    local git_dir resp
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [ -n "$git_dir" ]; then
        # Verificar si el .git está EN EL DIRECTORIO ACTUAL (no en un padre)
        local git_dir_real pwd_real
        git_dir_real=$(realpath "$git_dir" 2>/dev/null)
        pwd_real=$(realpath "$PWD" 2>/dev/null)

        if [[ "$git_dir_real" == "$pwd_real/.git" ]] || [[ "$git_dir_real" == "$pwd_real" ]]; then
            return 0  # .git está aquí → OK
        else
            # .git está en un padre → ADVERTIR
            say_warn "Hay un repositorio Git en una carpeta padre ($git_dir_real)"
            say_warn "   Esto mezclaría tus archivos con ese repo."
            read -r -p "¿Querés crear un repo NUEVO independiente AQUÍ? [Enter=sí]: " resp
            if [ -z "$resp" ] || [ "$resp" = "s" ] || [ "$resp" = "S" ] || [ "$resp" = "y" ] || [ "$resp" = "Y" ]; then
                inicializar_repo
                return $?
            else
                say_info "Usando repo padre. Tené cuidado: verás archivos de toda la carpeta padre."
                return 0
            fi
        fi
    else
        # No hay repo en ningún lado → ofrecer crear
        say_warn "✗ No hay un repositorio Git en esta carpeta."
        say_info "Voy a ayudarte a inicializar uno desde cero."
        inicializar_repo
        local result=$?
        if [ $result -ne 0 ]; then
            return 1
        fi
        # Verificar que el repo se creó correctamente
        if ! git rev-parse --git-dir > /dev/null 2>&1; then
            echo -e "${RED}❌ No se pudo inicializar el repositorio. Abortando.${NC}"
            return 1
        fi
        return 0
    fi
}

# --- Función para detectar cambios pendientes ---
# --- FUNCIÓN: tiene_cambios ---
# PROPÓSITO: detectar si el working tree tiene cambios staged/unstaged o no trackeados.
# PARÁMETROS: (ninguno).
# RETORNA: 0 si hay cambios, 1 si el árbol está limpio.
# POR QUÉ: `git status --porcelain` da salida estable y parseable (no depende de locale).
# NOTA: --porcelain garantiza formato estable entre versiones de git.
tiene_cambios() {
    if ! git diff --quiet 2>&1; then
        return 0
    elif ! git diff --cached --quiet 2>&1; then
        return 0
    else
        return 1
    fi
}

# --- Detección amplia de árbol sucio (incluye untracked) ---
# --- FUNCIÓN: arbol_sucio ---
# PROPÓSITO: detectar cambios staged, unstaged o archivos no rastreados.
# PARÁMETROS: (ninguno).
# RETORNA: 0 si hay algo que `git stash -u` movería, 1 si el árbol está limpio.
# POR QUÉ: tiene_cambios ignora untracked; el merge necesita ver todo para decidir
#   si debe stashear antes de cambiar de rama.
# NOTA: --porcelain respeta .gitignore y da salida estable entre versiones.
arbol_sucio() {
    [ -n "$(git status --porcelain 2>/dev/null)" ]
}

# --- Conteo de archivos con cambios sin guardar (excluye el contexto de sesión) ---
# --- FUNCIÓN: contar_cambios_sin_guardar ---
# PROPÓSITO: contar archivos modificados, staged o no rastreados que close podría guardar.
# PARÁMETROS: (ninguno; usa CONTEXT_FILE de config.sh).
# RETORNA: 0 (siempre); imprime un número entero (0 si no hay cambios).
# POR QUÉ: el menú muestra un resumen pasivo y close evita pedir commit si no hay nada.
# NOTA: excluye CONTEXT_FILE porque es estado local de la sesión, no trabajo a versionar.
contar_cambios_sin_guardar() {
    local total=0 linea xy ruta _origen

    while IFS= read -r -d '' linea; do
        [ -z "$linea" ] && continue
        xy="${linea:0:2}"
        ruta="${linea:3}"
        _origen=""
        case "$xy" in
            R*|C*) IFS= read -r -d '' _origen || _origen="" ;;
        esac
        if [ "$ruta" = "$CONTEXT_FILE" ] || [ "$_origen" = "$CONTEXT_FILE" ]; then
            continue
        fi
        total=$((total + 1))
    done < <(git -c core.quotePath=false status --porcelain -z 2>/dev/null)

    printf '%s\n' "$total"
}

# --- Conteo de commits pendientes de publicar ---
# --- FUNCIÓN: contar_commits_sin_publicar ---
# PROPÓSITO: contar cuántos commits tiene DEV_BRANCH que aún no están en DEFAULT_BRANCH.
# PARÁMETROS: (ninguno; usa DEFAULT_BRANCH y DEV_BRANCH de config.sh).
# RETORNA: 0 (siempre); imprime un número entero (0 si no se puede calcular).
# POR QUÉ: el menú y el cierre avisan al novato cuando falta PUBLICAR dev → main.
# NOTA: ramas ausentes, configuración vacía o salida inválida se tratan como 0.
contar_commits_sin_publicar() {
    local pendientes

    if [ -z "$DEV_BRANCH" ] || [ -z "$DEFAULT_BRANCH" ] || [ "$DEV_BRANCH" = "$DEFAULT_BRANCH" ]; then
        printf '0\n'
        return 0
    fi
    if ! git show-ref --verify --quiet "refs/heads/$DEV_BRANCH" 2>/dev/null; then
        printf '0\n'
        return 0
    fi
    if ! git show-ref --verify --quiet "refs/heads/$DEFAULT_BRANCH" 2>/dev/null; then
        printf '0\n'
        return 0
    fi

    pendientes=$(git rev-list --count "${DEFAULT_BRANCH}..${DEV_BRANCH}" 2>/dev/null)
    case "$pendientes" in
        ''|*[!0-9]*) pendientes=0 ;;
    esac
    printf '%s\n' "$pendientes"
}

# --- Detección de rama ocupada por otra worktree ---
# --- FUNCIÓN: rama_en_otra_worktree ---
# PROPÓSITO: saber si una rama está checked-out en una worktree distinta a la actual.
# PARÁMETROS: $1 = nombre de rama.
# RETORNA: 0 si está en otra worktree, 1 si no.
# POR QUÉ: git no permite hacer checkout de una rama ya usada por otra worktree.
# NOTA: parsea `git worktree list --porcelain` (bloques worktree/branch).
rama_en_otra_worktree() {
    local rama="$1" toplevel path branch _wt_line
    toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
    while IFS= read -r _wt_line; do
        case "$_wt_line" in
            "worktree "*) path="${_wt_line#worktree }" ;;
            "branch refs/heads/"*)
                branch="${_wt_line#branch refs/heads/}"
                if [ "$branch" = "$rama" ] && [ "$path" != "$toplevel" ]; then
                    return 0
                fi
                ;;
        esac
    done < <(git worktree list --porcelain 2>/dev/null)
    return 1
}

# --- Último commit y tag (para info/status) ---
# --- FUNCIÓN: ultimo_commit ---
# PROPÓSITO: devolver el abreviatado del último commit (o "sin commits").
# PARÁMETROS: (ninguno; lee HEAD).
# RETORNA: 0; imprime el hash abreviado por stdout.
# POR QUÉ: --short (--abbrev-commit) por legibilidad en pantalla.
ultimo_commit() {
    local resultado
    resultado=$(git log -1 --oneline --format="%h %s (%cr)" 2>/dev/null)
    if [ -z "$resultado" ]; then
        echo "Sin commits"
    else
        echo "$resultado"
    fi
}
# --- FUNCIÓN: ultimo_tag ---
# PROPÓSITO: devolver el tag más reciente (o "N/A").
# PARÁMETROS: (ninguno).
# RETORNA: 0; imprime el tag por stdout.
# POR QUÉ: `git describe --tags` resuelve el último; fallback "N/A" si no hay commits.
# NOTA: usado en info/status para ubicar rápidamente el snapshot de referencia.
ultimo_tag() {
    local tag
    tag=$(git tag --list 'work/*' --sort=-creatordate | head -1)
    if [ -z "$tag" ]; then
        echo "Sin snapshots"
    else
        echo "$tag"
    fi
}
