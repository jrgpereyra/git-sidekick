#!/usr/bin/env bash
# =============================================================================
# lib/git-helpers.sh - Funciones auxiliares de Git (consultas/operaciones)
# Extraído de git-sidekick.sh para modularización (ROADMAP v2.0, Sesión 2)
# Requiere: lib/colors.sh (para say_* y variables de color)
# =============================================================================

# --- Listado reutilizable de ramas (para errores amigables) ---
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
            read -p "¿Querés crear un repo NUEVO independiente AQUÍ? [Enter=sí]: " resp
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
tiene_cambios() {
    if ! git diff --quiet 2>&1; then
        return 0
    elif ! git diff --cached --quiet 2>&1; then
        return 0
    else
        return 1
    fi
}

# --- Último commit y tag (para info/status) ---
ultimo_commit() {
    local resultado
    resultado=$(git log -1 --oneline --format="%h %s (%cr)" 2>/dev/null)
    if [ -z "$resultado" ]; then
        echo "Sin commits"
    else
        echo "$resultado"
    fi
}
ultimo_tag() {
    local tag
    tag=$(git tag --list 'work/*' --sort=-creatordate | head -1)
    if [ -z "$tag" ]; then
        echo "Sin snapshots"
    else
        echo "$tag"
    fi
}
