#!/usr/bin/env bash

# =============================================================================
# git-sidekick.sh - Asistente universal de Git para novatos
# Versión: 0.2.0
# Licencia: MIT
# =============================================================================

# --- Colores para mensajes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Variables de configuración ---
WORKLOG_FILE=".git-worklog.md"
CONTEXT_FILE=".git-sidekick-context"
SNAPSHOT_PREFIX="work"

# --- Configuración extensible por proyecto (.git-sidekickrc) ---
# Podés crear .git-sidekickrc en la raíz del repo para personalizar.
DEFAULT_BRANCH="main"      # rama principal
DEV_BRANCH="dev"           # rama de desarrollo
AUTO_STASH=true           # stash automático?
AUTO_PUSH=false            # push automático? (false = seguro)
CONFIRM_DESTRUCTIVE=true   # confirmación doble en reset --hard

load_config() {
    local rc_file=".git-sidekickrc"
    if [ -f "$rc_file" ]; then
        echo -e "${CYAN}⚙️  Cargo config: ${rc_file}${NC}"
        source "$rc_file" 2>/dev/null
    fi
}
load_config

DRY_RUN=false
simulate() {
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${BLUE}🔍 [SIMULACIÓN] $*${NC}"
        return 0
    fi
    return 1
}

# --- Funciones auxiliares (vacías) ---
check_git() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        return 0
    else
        echo -e "${RED}❌ No encontré un repositorio Git en esta carpeta.${NC}"
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

# --- Función de inicialización automática ---
inicializar_repo() {
    local resp rama_default modo opcion plataforma nombre_repo
    local visibilidad tipo cli_cmd cli_info remote_url platform_info extra

    # Preguntar si inicializar
    read -p "📁 No encontré un repositorio Git en esta carpeta. ¿Querés inicializar uno ahora? [Enter=sí]: " resp
    if [ -n "$resp" ] && [ "$resp" != "s" ] && [ "$resp" != "S" ] && [ "$resp" != "y" ] && [ "$resp" != "Y" ]; then
        echo "Cancelado."
        return 1
    fi

    # Preguntar rama por defecto
    read -p "¿Rama por defecto? (main/master) [main]: " rama_default
    if [ -z "$rama_default" ]; then
        rama_default="main"
    fi

    # Inicializar repo
    if ! git init 2>/dev/null; then
        echo -e "${RED}❌ Error al inicializar el repositorio.${NC}"
        return 1
    fi
    git branch -M "$rama_default" 2>/dev/null
    COMMIT_INICIAL="❌"
    if git commit --allow-empty -m "Initial commit" 2>/dev/null; then
        COMMIT_INICIAL="✅"
    fi
    echo -e "${GREEN}✅ Repositorio Git inicializado.${NC}"

    # Preguntar local o remoto (lista numerada)
    echo ""
    echo -e "${CYAN}📋 Opciones de conexión:${NC}"
    echo "  1) Trabajar en local (sin remoto)"
    echo "  2) Conectar a un remoto (GitHub/GitLab/etc.)"
    local sel_modo
    read -p "Seleccioná una opción (1-2) [1]: " sel_modo
    if [ -z "$sel_modo" ]; then
        sel_modo=1
    fi

    if [ "$sel_modo" = "1" ]; then
        _mostrar_resumen_init "$rama_default" "" "" "" ""
        return 0
    elif [ "$sel_modo" != "2" ]; then
        echo -e "${RED}❌ Opción inválida.${NC}"
        _mostrar_resumen_init "$rama_default" "" "" "" ""
        return 0
    fi

    # Modo remoto: crear nuevo o usar existente (lista numerada)
    echo ""
    echo -e "${CYAN}📋 Tipo de remoto:${NC}"
    echo "  1) Crear repositorio nuevo"
    echo "  2) Usar repositorio existente"
    local sel_opcion
    read -p "Seleccioná una opción (1-2) [1]: " sel_opcion
    if [ -z "$sel_opcion" ]; then
        sel_opcion=1
    fi

    if [ "$sel_opcion" = "1" ]; then
        echo ""
        echo -e "${CYAN}📋 Plataformas disponibles:${NC}"
        echo "  1) GitHub (gh)"
        echo "  2) GitLab (glab)"
        echo "  3) Bitbucket"
        echo "  4) Otra"
        local sel_plataforma
        read -p "Seleccioná una plataforma (1-4) [1]: " sel_plataforma
        if [ -z "$sel_plataforma" ]; then
            sel_plataforma=1
        fi
        case "$sel_plataforma" in
            1) plataforma="github" ;;
            2) plataforma="gitlab" ;;
            3) plataforma="bitbucket" ;;
            4) read -p "Nombre de la plataforma: " plataforma
               if [ -z "$plataforma" ]; then
                   plataforma="otra"
               fi
               ;;
            *) echo -e "${RED}❌ Opción inválida.${NC}"; plataforma="github" ;;
        esac

        read -p "Nombre del repositorio: " nombre_repo
        if [ -z "$nombre_repo" ]; then
            echo -e "${RED}❌ Debés especificar un nombre para el repositorio.${NC}"
            platform_info="$plataforma"
            _mostrar_resumen_init "$rama_default" "" "$platform_info" "" "$nombre_repo (sin nombre)"
            return 0
        fi

        echo ""
        echo -e "${CYAN}📋 Visibilidad:${NC}"
        echo "  1) Público"
        echo "  2) Privado"
        local sel_vis
        read -p "Seleccioná una opción (1-2) [1]: " sel_vis
        if [ -z "$sel_vis" ] || [ "$sel_vis" = "1" ]; then
            visibilidad="public"
        else
            visibilidad="private"
        fi
        tipo="--public"
        if [ "$visibilidad" = "private" ]; then
            tipo="--private"
        fi

        # Detectar CLI según plataforma
        cli_cmd=""
        cli_info=""
        case "$plataforma" in
            github)
                if command -v gh >/dev/null 2>&1; then
                    cli_cmd="gh"
                    cli_info=$(gh --version 2>/dev/null | head -1)
                fi
                ;;
            gitlab)
                if command -v glab >/dev/null 2>&1; then
                    cli_cmd="glab"
                    cli_info=$(glab --version 2>/dev/null | head -1)
                fi
                ;;
        esac

        # Mostrar resumen de lo que se hará
        echo ""
        echo -e "${YELLOW}📋 Resumen de inicialización${NC}"
        echo "   📁 Repo local:      $(pwd)"
        echo "   🌿 Rama por defecto: $rama_default"
        echo "   🔗 Plataforma:      $plataforma"
        echo "   📦 Repositorio:     $nombre_repo"
        echo "   👁️ Visibilidad:     $visibilidad"
        if [ -n "$cli_info" ]; then
            echo "   🛠 CLI:            $cli_info"
        else
            echo "   🛠 CLI:            No detectada"
        fi
        echo ""

        # Confirmar
        local confirm
        read -p "¿Confirmar creación? [Enter=sí]: " confirm
        if [ -n "$confirm" ] && [ "$confirm" != "s" ] && [ "$confirm" != "S" ] && [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "Cancelado."
            platform_info="$plataforma"
            _mostrar_resumen_init "$rama_default" "" "$platform_info" "$cli_info" "$nombre_repo (cancelado)"
            return 0
        fi

        if [ -n "$cli_cmd" ]; then
            case "$plataforma" in
                github)
                    # Asegurar que hay al menos un commit para --push
                    if ! git log --quiet 2>/dev/null; then
                        git commit --allow-empty -m "Initial commit" 2>/dev/null
                    fi
                    if gh repo create "$nombre_repo" $tipo --source=. --remote=origin --push; then
                        remote_url=$(git remote get-url origin 2>/dev/null)
                        echo -e "${GREEN}✅ Repositorio creado y conectado.${NC}"
                    else
                        echo -e "${RED}❌ Error al crear el repositorio en GitHub.${NC}"
                        echo -e "${YELLOW}Instrucciones manuales:${NC}"
                        echo "  1. Crear repositorio '$nombre_repo' en GitHub (web)"
                        echo "  2. git remote add origin <url>"
                        echo "  3. git branch -M $rama_default"
                        echo "  4. git push -u origin $rama_default"
                    fi
                    ;;
                gitlab)
                    if glab repo create "$nombre_repo" --remote=origin --push; then
                        remote_url=$(git remote get-url origin 2>/dev/null)
                        echo -e "${GREEN}✅ Repositorio creado y conectado.${NC}"
                    else
                        echo -e "${RED}❌ Error al crear el repositorio en GitLab.${NC}"
                        echo "Instrucciones manuales:"
                        echo "  1. Crear repositorio '$nombre_repo' en GitLab (web)"
                        echo "  2. git remote add origin <url>"
                        echo "  3. git branch -M $rama_default"
                        echo "  4. git push -u origin $rama_default"
                    fi
                    ;;
                *)
                    echo -e "${YELLOW}⚠️ No hay CLI automática para $plataforma.${NC}"
                    echo "Instrucciones:"
                    echo "  1. Crear repositorio '$nombre_repo' en $plataforma (web)"
                    echo "  2. git remote add origin <url>"
                    echo "  3. git branch -M $rama_default"
                    echo "  4. git push -u origin $rama_default"
                    ;;
            esac
        else
            # No CLI detectada — instrucciones manuales + conexión manual
            echo -e "${YELLOW}⚠️ No encontré el CLI de $plataforma.${NC}"
            echo "Para conectar manualmente, ejecutá estos pasos:"
            echo "  1. Crear repositorio '$nombre_repo' en $plataforma (web)"
            echo "  2. git remote add origin <url-del-repo>"
            echo "  3. git branch -M $rama_default"
            echo "  4. git push -u origin $rama_default"
            echo ""

            local connectar
            read -p "¿Ya creaste el repo y querés que conecte el remoto? [Enter=sí]: " connectar
            if [ -z "$connectar" ] || [ "$connectar" = "s" ] || [ "$connectar" = "S" ] || [ "$connectar" = "y" ] || [ "$connectar" = "Y" ]; then
                read -p "URL del remote: " remote_url
                if [ -n "$remote_url" ]; then
                    git remote add origin "$remote_url"
                    git branch -M "$rama_default"
                    # Asegurar que hay al menos un commit para push
                    if ! git log --quiet 2>/dev/null; then
                        git commit --allow-empty -m "Initial commit" 2>/dev/null
                    fi
                    if git push -u origin "$rama_default"; then
                        echo -e "${GREEN}✅ Repositorio conectado a $remote_url${NC}"
                    else
                        echo -e "${RED}❌ Error al pushear.${NC}"
                    fi
                fi
            else
                echo "Podés conectarlo manualmente más tarde."
            fi
        fi
    elif [ "$sel_opcion" = "2" ]; then
        read -p "URL del remoto: " remote_url
        if [ -z "$remote_url" ]; then
            echo -e "${RED}❌ Debés especificar una URL.${NC}"
            platform_info="usar existente"
            _mostrar_resumen_init "$rama_default" "" "$platform_info" "" "Sin URL"
            return 0
        fi
        git remote add origin "$remote_url"
        git branch -M "$rama_default"
        # Asegurar que hay al menos un commit para push
        if ! git log --quiet 2>/dev/null; then
            git commit --allow-empty -m "Initial commit" 2>/dev/null
        fi
        if git push -u origin "$rama_default"; then
            echo -e "${GREEN}✅ Repositorio conectado a $remote_url${NC}"
        else
            echo -e "${RED}❌ Error al pushear.${NC}"
        fi
    fi

    # Mostrar resumen final
    platform_info="${platform_info:-$plataforma}"
    _mostrar_resumen_init "$rama_default" "$remote_url" "$platform_info" "$cli_info" "$extra"
    return 0
}

# --- Función helper: resumen de inicialización ---
_mostrar_resumen_init() {
    local rama="$1"
    local remote_url="$2"
    local platform_info="$3"
    local cli_info="$4"
    local extra="$5"

    echo ""
    echo -e "${CYAN}📋 Resumen de inicialización${NC}"
    echo "   📁 Repo local:      $(pwd)"
    echo "   🌿 Rama por defecto: $rama"
    echo "   📝 Commit inicial:  ${COMMIT_INICIAL:-✅} 'Initial commit'"
    if [ -n "$remote_url" ]; then
        echo "   🔗 Remoto:        $remote_url"
    else
        echo "   🔗 Remoto:        Sin remoto"
    fi
    if [ -n "$cli_info" ]; then
        echo "   🛠 CLI:           $cli_info"
    else
        echo "   🛠 CLI:           —"
    fi
    if [ -n "$platform_info" ]; then
        echo "   🌐 Plataforma:    $platform_info"
    fi
    if [ -n "$extra" ]; then
        echo "   ℹ️ $extra"
    fi
    echo -e "${GREEN}✅ Listo para trabajar.${NC}"
}

tiene_cambios() {
    if ! git diff --quiet 2>&1; then
        return 0
    elif ! git diff --cached --quiet 2>&1; then
        return 0
    else
        return 1
    fi
}
stash_auto() {
    if simulate "Hacer stash de cambios no commiteados (git stash)"; then
        return 0
    fi
    if ! tiene_cambios; then
        echo -e "${YELLOW}ℹ️ No hay cambios para stash.${NC}"
        return 0
    fi

    local respuesta
    read -p "¿Querés hacer stash de los cambios actuales? [Enter=sí]: " respuesta

    case "$respuesta" in
        ""|s|S|y|Y)
            if git stash push -m "Auto-stash antes de cambiar de rama"; then
                echo -e "${GREEN}✅ Cambios guardados en stash.${NC}"
                return 0
            else
                echo -e "${RED}❌ Error al hacer stash.${NC}"
                return 1
            fi
            ;;
        n|N)
            echo "Operación cancelada."
            return 1
            ;;
        *)
            echo "Operación cancelada."
            return 1
            ;;
    esac
}
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
# --- Función de info detallado ---
mostrar_info() {
    if ! check_git; then
        return 1
    fi

    echo -e "${BLUE}📋 Información del repositorio${NC}"
    echo "   📁 Proyecto:   $(pwd)"
    echo "   🌿 Rama:      $(git rev-parse --abbrev-ref HEAD)"

    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null)
    if [ -n "$remote_url" ]; then
        echo "   🔗 Remote:     $remote_url"
    else
        echo "   🔗 Remote:     Sin conectar"
    fi

    local rama
    rama=$(git rev-parse --abbrev-ref HEAD)
    if git rev-parse "${rama}@{upstream}" >/dev/null 2>&1; then
        local behind ahead
        behind=$(git rev-list --count HEAD.."${rama}@{upstream}" 2>/dev/null)
        ahead=$(git rev-list --count "${rama}@{upstream}"..HEAD 2>/dev/null)
        echo "   📤 Ahead:      ${ahead} commit(s) locales sin subir"
        echo "   📥 Behind:     ${behind} commit(s) remotos para descargar (git pull)"
    else
        echo "   📤 Ahead:      Sin seguimiento remoto"
        echo "   📥 Behind:     Sin seguimiento remoto"
    fi

    local ult_tag
    ult_tag=$(ultimo_tag)
    echo "   📸 Último tag:  ${ult_tag}"

    if [ -f "$CONTEXT_FILE" ]; then
        echo "   📌 Sesión:     Activa (hay contexto guardado)"
    else
        echo "   📌 Sesión:     Inactiva"
    fi

    if [ -f "$WORKLOG_FILE" ]; then
        local lineas
        lineas=$(grep -c '^## ' "$WORKLOG_FILE" 2>/dev/null || echo 0)
        echo "   📝 Bitácora:    ${lineas} sesion(es) registradas"
    fi

    echo ""
    git status --short 2>/dev/null | head -15
    local total_archivos
    total_archivos=$(git status --short 2>/dev/null | wc -l)
    if [ "$total_archivos" -gt 15 ]; then
        echo "... y $((total_archivos - 15)) archivo(s) más"
    fi

    echo ""
    echo -e "${CYAN}💡 Tips:${NC}"
    echo "   • 'gk start'  → Iniciar una sesión de trabajo"
    echo "   • 'gk close'  → Commitear + snapshot de cierre"
    echo "   • 'gk status' → Ver estado rápido"
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}   ⚠️ Recordá: estás en modo SIMULACIÓN.${NC}"
    fi
}

mostrar_estado() {
    git fetch --all --prune > /dev/null 2>&1

    local rama
    rama=$(git rev-parse --abbrev-ref HEAD)

    echo -e "📍 Rama actual: ${YELLOW}[${rama}]${NC}"

    if git rev-parse "${rama}@{upstream}" >/dev/null 2>&1; then
        local behind ahead
        behind=$(git rev-list --count HEAD.."${rama}@{upstream}" 2>/dev/null)
        ahead=$(git rev-list --count "${rama}@{upstream}"..HEAD 2>/dev/null)

        if [ "$behind" -gt 0 ] 2>/dev/null; then
            echo -e "📥 Hay $behind commits remotos no descargados. Para traerlos: git pull"
        fi

        if [ "$ahead" -gt 0 ] 2>/dev/null; then
            echo -e "📤 Hay $ahead commits locales no subidos. Para subirlos: git push"
        fi
    else
        echo "ℹ️ La rama '${rama}' no tiene seguimiento remoto."
    fi

    echo ""
    git status --short
}

# --- Funciones de bitácora ---
log_work() {
    local bloque="$1"
    if [ ! -f "$WORKLOG_FILE" ]; then
        echo -e "# Bitácora de trabajo\n" > "$WORKLOG_FILE"
    fi
    echo "$bloque" >> "$WORKLOG_FILE"
}
guardar_contexto() {
    local rama="$1"
    local accion="$2"
    local tag="$3"
    local fecha_inicio
    fecha_inicio=$(date +%F_%H-%M)
    {
        echo "rama=${rama}"
        echo "fecha_inicio=${fecha_inicio}"
        echo "accion=${accion}"
        echo "tag_inicio=${tag}"
    } > "$CONTEXT_FILE"
}
leer_contexto() {
    if [ -f "$CONTEXT_FILE" ]; then
        local rama="" fecha_inicio="" accion="" tag_inicio=""
        while IFS='=' read -r key value; do
            case "$key" in
                rama) rama="$value" ;;
                fecha_inicio) fecha_inicio="$value" ;;
                accion) accion="$value" ;;
                tag_inicio) tag_inicio="$value" ;;
            esac
        done < "$CONTEXT_FILE"
        echo -e "${CYAN}📌 Sesión previa: [${rama}] ${accion} (${fecha_inicio})${NC}"
    else
        echo "📌 Sin sesión previa registrada."
    fi
}
limpiar_contexto() {
    if [ -f "$CONTEXT_FILE" ]; then
        rm -f "$CONTEXT_FILE"
    fi
}

# --- Funciones de snapshots ---
crear_snapshot() {
    local etiqueta="$1"
    local prefijo="${2:-work}"
    local fecha
    fecha=$(date +%Y-%m-%d_%H-%M)
    local etiqueta_limpia=""
    if [ -n "$etiqueta" ]; then
        etiqueta_limpia=$(echo "$etiqueta" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
    fi
    local nombre
    if [ -n "$etiqueta_limpia" ]; then
        nombre="${prefijo}/${fecha}-${etiqueta_limpia}"
    else
        nombre="${prefijo}/${fecha}"
    fi
    if simulate "Crear snapshot (git tag $nombre)"; then
        echo -e "${BLUE}   └─ Tag que crearía: ${nombre}${NC}"
        return 0
    fi
    if git tag "$nombre" -m "Snapshot: ${etiqueta:-sin-etiqueta}"; then
        echo -e "${GREEN}✅ Snapshot creado: $nombre${NC}"
        return 0
    else
        echo -e "${RED}❌ Error al crear snapshot${NC}"
        return 1
    fi
}
listar_snapshots() {
    local tags
    tags=$(git tag --list 'work/*' --sort=-creatordate)
    if [ -z "$tags" ]; then
        echo "No hay snapshots"
        return 0
    fi
    while IFS= read -r tag; do
        [ -z "$tag" ] && continue
        local fecha_tag
        fecha_tag=$(git log -1 --format=%ai "$tag" 2>/dev/null | cut -d' ' -f1)
        echo "$tag  ($fecha_tag)"
    done <<< "$tags"
}
restaurar_snapshot() {
    local tags=() tag _i _fecha_tag
    _i=1
    echo -e "${CYAN}📋 Snapshots disponibles:${NC}"
    while IFS= read -r tag; do
        [ -z "$tag" ] && continue
        _fecha_tag=$(git log -1 --format=%ai "$tag" 2>/dev/null | cut -d' ' -f1)
        echo "  $_i) $tag  ($_fecha_tag)"
        tags+=("$tag")
        _i=$((_i+1))
    done < <(git tag --list 'work/*' --sort=-creatordate)

    if [ "${#tags[@]}" -eq 0 ]; then
        echo "No hay snapshots"
        return 0
    fi

    local seleccion
    read -p "Seleccioná un snapshot (1-${#tags[@]}) [Enter=Cancelar]: " seleccion
    if [ -z "$seleccion" ]; then
        echo "Operación cancelada."
        return 1
    fi

    if ! [[ "$seleccion" =~ ^[0-9]+$ ]] || [ "$seleccion" -lt 1 ] || [ "$seleccion" -gt "${#tags[@]}" ]; then
        echo -e "${RED}❌ Selección inválida.${NC}"
        return 1
    fi

    tag="${tags[$((seleccion-1))]}"
    local confirm
    read -p "¿Confirmar restauración a ${tag}? [Enter=sí]: " confirm
    if [ -n "$confirm" ] && [ "$confirm" != "s" ] && [ "$confirm" != "S" ] && [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Operación cancelada."
        return 1
    fi
    echo -e "${YELLOW}⚠️ Se perderán todos los cambios no guardados.${NC}"
    if git reset --hard "$tag"; then
        echo -e "${GREEN}✅ Restaurado a $tag${NC}"
        return 0
    else
        echo -e "${RED}❌ Error al restaurar el snapshot.${NC}"
        return 1
    fi
}
limpiar_snapshots() {
    local tags
    tags=$(git tag --list 'work/*' --sort=-creatordate)
    if [ -z "$tags" ]; then
        echo "No hay snapshots"
        return 0
    fi

    local hoy_segundos
    hoy_segundos=$(date +%s)
    local a_borrar=()
    local semanas_vistas=()

    local tag fecha_tag segundos_tag edad_dias semana encontrada s i confirm
    while IFS= read -r tag; do
        [ -z "$tag" ] && continue
        fecha_tag=$(git log -1 --format=%ai "$tag" 2>/dev/null | cut -d' ' -f1)
        segundos_tag=$(date -d "$fecha_tag" +%s 2>/dev/null)
        [ -z "$segundos_tag" ] && continue
        edad_dias=$(( (hoy_segundos - segundos_tag) / 86400 ))
        if [ "$edad_dias" -le 7 ]; then
            :
        elif [ "$edad_dias" -le 30 ]; then
            semana=$(date -d "$fecha_tag" +%Y-W%V 2>/dev/null)
            encontrada=0
            for s in "${semanas_vistas[@]}"; do
                if [ "$s" = "$semana" ]; then
                    encontrada=1
                    break
                fi
            done
            if [ "$encontrada" -eq 0 ]; then
                semanas_vistas+=("$semana")
            else
                a_borrar+=("$tag")
            fi
        else
            a_borrar+=("$tag")
        fi
    done <<< "$tags"

    if [ "${#a_borrar[@]}" -eq 0 ]; then
        echo "No hay snapshots para limpiar."
        return 0
    fi

    echo -e "${YELLOW}Tags a eliminar:${NC}"
    for i in "${a_borrar[@]}"; do
        echo "  $i"
    done
    echo ""
    read -p "¿Confirmar eliminación? [Enter=sí]: " confirm
    if [ -n "$confirm" ] && [ "$confirm" != "s" ] && [ "$confirm" != "S" ] && [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Operación cancelada."
        return 1
    fi
    for i in "${a_borrar[@]}"; do
        git tag -d "$i"
        echo "Eliminado: $i"
    done
    echo -e "${GREEN}✅ Limpieza completada.${NC}"
    return 0
}

# --- Funciones de flujo principal ---
start_session() {
    if simulate "Iniciar sesión: stash + checkpoint + snapshot"; then
        echo -e "${BLUE}   └─ No se crea el snapshot, no se hace stash.${NC}"
        echo -e "${BLUE}   └─ Usá 'gk start' sin --dry-run para ejecutar.${NC}"
        return 0
    fi
    if ! check_git; then
        return 1
    fi

    mostrar_estado

    local rama_actual
    rama_actual=$(git rev-parse --abbrev-ref HEAD)

    # Listar ramas disponibles numeradas
    echo -e "${CYAN}📋 Ramas disponibles:${NC}"
    local ramas=() _i=1 _r
    while IFS= read -r _r; do
        [ -z "$_r" ] && continue
        if [ "$_r" = "$rama_actual" ]; then
            echo "  $_i) $_r *"
        else
            echo "  $_i) $_r"
        fi
        ramas+=("$_r")
        _i=$((_i+1))
    done < <(git branch --format='%(refname:short)')
    echo "  0) Crear nueva rama..."

    local seleccion
    read -p "Seleccioná una rama (0-${#ramas[@]}) [1]: " seleccion
    if [ -z "$seleccion" ]; then
        seleccion=1
    fi

    local rama
    if [ "$seleccion" = "0" ]; then
        read -p "Nombre de la nueva rama: " rama
        if [ -z "$rama" ]; then
            echo -e "${RED}❌ Debés especificar un nombre.${NC}"
            return 1
        fi
        if ! git checkout -b "$rama" 2>/dev/null; then
            echo -e "${RED}❌ Error al crear la rama '$rama'.${NC}"
            return 1
        fi
    else
        if ! [[ "$seleccion" =~ ^[0-9]+$ ]] || [ "$seleccion" -lt 1 ] || [ "$seleccion" -gt "${#ramas[@]}" ]; then
            echo -e "${RED}❌ Selección inválida.${NC}"
            return 1
        fi
        rama="${ramas[$((seleccion-1))]}"
        if [ "$rama" = "$rama_actual" ]; then
            :
        else
            if ! cambiar_rama "$rama"; then
                return 1
            fi
        fi
    fi

    local etiqueta
    read -p "¿Etiqueta para la sesión? (opcional): " etiqueta

    if tiene_cambios; then
        local fecha_tag
        fecha_tag=$(date +%F_%H-%M)
        git add . 2>/dev/null
        git commit -m "Checkpoint inicio - ${etiqueta:-sin-etiqueta} - ${fecha_tag}" 2>/dev/null
    fi

    local snapshot_out snapshot_tag
    snapshot_out=$(crear_snapshot "$etiqueta")
    snapshot_tag=$(echo "$snapshot_out" | sed 's/\x1b\[[0-9;]*m//g' | sed -n 's/.*Snapshot creado: //p')

    if [ -n "$snapshot_tag" ]; then
        guardar_contexto "$rama" "inicio" "$snapshot_tag"
        echo -e "${GREEN}✅ SESIÓN INICIADA en [${rama}]${NC}"
        echo -e "${GREEN}   Tag creado: ${snapshot_tag}${NC}"
    else
        echo -e "${RED}❌ Error al crear el snapshot de inicio.${NC}"
        return 1
    fi
}
close_session() {
    if simulate "Cerrar sesión: exportar config + commit + snapshot + (push opcional)"; then
        echo -e "${BLUE}   └─ No se commitea ni sube nada.${NC}"
        echo -e "${BLUE}   └─ Usá 'gk close' sin --dry-run para ejecutar.${NC}"
        return 0
    fi
    if ! check_git; then
        return 1
    fi

    local rama
    rama=$(git rev-parse --abbrev-ref HEAD)

    mostrar_estado

    leer_contexto

    local fecha
    fecha=$(date +%F_%H-%M)
    local mensaje_sugerido="Sesión en ${rama} - ${fecha}"
    local mensaje
    read -p "Mensaje de commit [Enter para usar sugerido: 'Sesión en <rama> - <fecha>']: " mensaje
    if [ -z "$mensaje" ]; then
        mensaje="$mensaje_sugerido"
    fi

    git add . 2>/dev/null
    if tiene_cambios; then
        git commit -m "$mensaje" 2>/dev/null
    else
        echo "No hay cambios para commitear."
    fi

    local etiqueta
    read -p "¿Etiqueta para snapshot de cierre? (opcional): " etiqueta

    local snapshot_out snapshot_tag
    snapshot_out=$(crear_snapshot "$etiqueta")
    snapshot_tag=$(echo "$snapshot_out" | sed 's/\x1b\[[0-9;]*m//g' | sed -n 's/.*Snapshot creado: //p')

    local archivos_mod
    archivos_mod=$(git diff --name-only HEAD~1 HEAD 2>/dev/null)

    local block=""
    block+="## Cierre de sesión - ${fecha}"$'\n'
    block+="- Rama: ${rama}"$'\n'
    block+="- Mensaje de commit: ${mensaje}"$'\n'
    block+="- Snapshot: ${snapshot_tag:-N/A}"$'\n'
    block+="- Archivos modificados:"$'\n'
    if [ -n "$archivos_mod" ]; then
        block+="$archivos_mod"$'\n'
    else
        block+="  (ninguno)"$'\n'
    fi

    log_work "$block"

    local push_confirm
    read -p "¿Subir cambios a la nube? [Enter=sí]: " push_confirm
    if [ -z "$push_confirm" ] || [ "$push_confirm" = "s" ] || [ "$push_confirm" = "S" ] || [ "$push_confirm" = "y" ] || [ "$push_confirm" = "Y" ]; then
        git push origin "$rama" 2>/dev/null
    fi

    limpiar_contexto
    echo -e "${GREEN}✅ SESIÓN CERRADA. Todo guardado.${NC}"
}
cambiar_rama() {
    local target_branch="$1"

    if [ -z "$target_branch" ]; then
        echo -e "${RED}❌ Debés especificar el nombre de la rama.${NC}"
        return 1
    fi

    if ! git show-ref --verify --quiet "refs/heads/$target_branch"; then
        echo -e "${RED}❌ La rama '$target_branch' no existe localmente.${NC}"
        return 1
    fi

    if tiene_cambios; then
        if ! stash_auto; then
            return 1
        fi
    fi

    if ! git checkout "$target_branch"; then
        echo -e "${RED}❌ Error al cambiar de rama a '$target_branch'.${NC}"
        return 1
    fi

    echo -e "${GREEN}✅ Cambiado a rama '$target_branch'.${NC}"
    return 0
}
merge_protegido() {
    local origen="$1"
    local destino="$2"
    local nivel="${3:-}"
    local confirmacion

    if [ "$nivel" != "1" ] && [ "$nivel" != "2" ]; then
        echo -e "${RED}❌ Nivel de protección inválido. Use 1 (simple) o 2 (estricto).${NC}"
        return 1
    fi

    local rama_original
    rama_original=$(git rev-parse --abbrev-ref HEAD)

    if simulate "Merge protegido: $origen → $destino (nivel $nivel) — nada se modifica"; then
        echo -e "${BLUE}   └─ No se hace merge ni stash.${NC}"
        return 0
    fi

    if ! git show-ref --verify --quiet "refs/heads/$origen"; then
        echo -e "${RED}❌ La rama '$origen' no existe localmente.${NC}"
        return 1
    fi
    if ! git show-ref --verify --quiet "refs/heads/$destino"; then
        echo -e "${RED}❌ La rama '$destino' no existe localmente.${NC}"
        return 1
    fi

    # --- Resumen visual + confirmación única (aplica al menú y al CLI) ---
    echo -e "${YELLOW}⚠️ Vas a fusionar '$origen' → '$destino' con protección nivel $nivel.${NC}"
    if [ "$nivel" = "2" ]; then
        echo -e "${YELLOW}- Se hará un snapshot de seguridad en '$destino' antes del merge.${NC}"
    fi
    echo -e "${CYAN}📋 Commits a fusionar ($origen → $destino):${NC}"
    git log --oneline "${destino}..${origen}" | head -30
    read -p "¿Confirmar? [Enter=sí]: " confirmacion
    if [ "$confirmacion" = "n" ] || [ "$confirmacion" = "N" ]; then
        echo -e "${YELLOW}Operación cancelada. Volviendo a '$rama_original'.${NC}"
        git checkout "$rama_original" 2>/dev/null
        return 1
    fi

    # Asegurarse de estar en la rama destino (usar cambiar_rama)
    if [ "$(git rev-parse --abbrev-ref HEAD)" != "$destino" ]; then
        if ! cambiar_rama "$destino"; then
            return 1
        fi
    fi

    # Snapshot de seguridad (nivel 2), después de confirmar y antes del merge
    if [ "$nivel" = "2" ]; then
        local out tag_guardia
        out=$(crear_snapshot "pre-merge-de-${origen}-a-${destino}" work)
        tag_guardia=$(echo "$out" | sed 's/\x1b\[[0-9;]*m//g' | sed -n 's/.*Snapshot creado: //p')
        if [ -n "$tag_guardia" ]; then
            echo -e "${YELLOW}🛡️ Snapshot de seguridad creado: ${tag_guardia}${NC}"
        else
            echo -e "${RED}❌ No se pudo crear el snapshot de seguridad.${NC}"
            return 1
        fi
    fi

    if git merge "$origen" --no-edit; then
        echo -e "${GREEN}✅ Merge completado sin conflictos.${NC}"
    else
        echo -e "${RED}❌ Hubo conflictos. Resolvelos manualmente y luego ejecutá: git merge --continue${NC}"
        return 1
    fi

    if [ "$nivel" = "2" ]; then
        local conf
        read -p "¿Querés subir los cambios de '$destino' a la nube? [Enter=sí]: " conf
        if [ -z "$conf" ] || [ "$conf" = "s" ] || [ "$conf" = "S" ] || [ "$conf" = "y" ] || [ "$conf" = "Y" ]; then
            if git push origin "$destino"; then
                echo -e "${GREEN}✅ '$destino' subido a la nube.${NC}"
            else
                echo -e "${RED}❌ Error al subir '$destino' a la nube.${NC}"
            fi
        fi
    fi

    local conf2
    read -p "¿Volver a la rama original '$rama_original'? [Enter=sí]: " conf2
    if [ -z "$conf2" ] || [ "$conf2" = "s" ] || [ "$conf2" = "S" ] || [ "$conf2" = "y" ] || [ "$conf2" = "Y" ]; then
        cambiar_rama "$rama_original" 2>/dev/null
    fi

    echo -e "${GREEN}✅ Merge $origen → $destino completado.${NC}"
    return 0
}

# --- Función de ayuda ---
mostrar_ayuda() {
    echo "========================================="
    echo -e "${CYAN}📘 git-sidekick - Asistente de Git${NC}"
    echo "========================================="
    echo "Comandos disponibles:"
    echo "  start    - Iniciar sesión (lista ramas numeradas)"
    echo "  close    - Cerrar sesión"
    echo "  status   - Ver estado"
    echo "  restore  - Restaurar punto"
    echo "  snapshot - Rescate rápido"
    echo "  clean    - Limpiar viejos"
    echo "  merge    - Merge protegido (origen destino nivel)"
    echo "    uso:    merge <origen> <destino> <1|2>"
    echo "  --install-alias - Instala el alias 'gk' en ~/.bash_aliases"
    echo "  help     - Esta ayuda"
    echo "  info     - Muestra información detallada del repositorio"
    echo "Todos los comandos aceptan --dry-run para simular sin ejecutar."
    echo "Ejemplo:  gk start --dry-run"
    echo ""
    echo "Atajes: s=start, c=close, q=salir (modo interactivo)"
    echo "Sin argumentos: modo interactivo"
    echo "========================================="
}

# --- Menú principal ---
mostrar_menu() {
    local _rama_actual
    _rama_actual=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    echo "------------------------------------------------"
    echo -e "${BLUE}🎮 git-sidekick v0.2.0${NC}"
    if [ -n "$_rama_actual" ]; then
        echo -e "${YELLOW}📍 Rama actual: → $_rama_actual${NC}"
    fi
    echo "------------------------------------------------"
    echo "1) INICIAR sesión        (atajo: s)"
    echo "2) VER ESTADO"
    echo "3) CERRAR sesión         (atajo: c)"
    echo "4) RESTAURAR punto"
    echo "5) SNAPSHOT (rescate)"
    echo "6) LIMPIAR snapshots"
    echo "7) AYUDA"
    echo "8) SALIR                 (atajo: q)"
    echo "9) ACTUALIZAR dev con main (main → dev)  [nivel 1]"
    echo "10) PUBLICAR dev a main    (dev → main)  [nivel 2]"
    echo "11) FUSIONAR personalizado"
    echo "------------------------------------------------"
    read -p "Opción (1-11) [s/c/q]: " opt
    case $opt in
        1|[sS]) start_session ;;
        2) mostrar_estado ;;
        3|[cC]) close_session ;;
        4) restaurar_snapshot ;;
        5) crear_snapshot ;;
        6) limpiar_snapshots ;;
        7) mostrar_ayuda ;;
        8|[qQ]) echo "👋 Saliendo." ;;
        9) merge_protegido "main" "dev" "1" ;;
        10) merge_protegido "dev" "main" "2" ;;
        11)
            local _ramas=() _i=1 _actual _r _num_o _num_d _niv_m _orig_m _dest_m
            _actual=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
            echo -e "${BLUE}📋 Ramas disponibles:${NC}"
            while IFS= read -r _r; do
                [ -z "$_r" ] && continue
                if [ "$_r" = "$_actual" ]; then
                    echo "  $_i) $_r *"
                else
                    echo "  $_i) $_r"
                fi
                _ramas+=("$_r"); _i=$((_i+1))
            done < <(git for-each-ref --format='%(refname:short)' refs/heads/)
            read -p "Número de rama origen: " _num_o
            read -p "Número de rama destino: " _num_d
            read -p "Nivel de protección (1/2): " _niv_m
            _orig_m="${_ramas[$((_num_o-1))]}"
            _dest_m="${_ramas[$((_num_d-1))]}"
            merge_protegido "$_orig_m" "$_dest_m" "$_niv_m"
            ;;
        *) echo -e "${RED}❌ Opción no válida${NC}" ;;
    esac
}

# --- Punto de entrada ---
# --- Instalación de alias ---
install_alias() {
    local script_path alias_file alias_line existing resp tmp
    # Ruta absoluta del script (realpath > readlink > fallback sobre $0)
    if command -v realpath >/dev/null 2>&1; then
        script_path=$(realpath "$0" 2>/dev/null)
    fi
    if [ -z "$script_path" ]; then
        script_path=$(readlink -f "$0" 2>/dev/null)
    fi
    if [ -z "$script_path" ]; then
        case "$0" in
            /*) script_path="$0" ;;
            *)  script_path="$PWD/$0" ;;
        esac
        [ -x "$script_path" ] || script_path="$PWD/git-sidekick.sh"
    fi

    alias_file="$HOME/.bash_aliases"
    alias_line="alias gk=\"$script_path\""

    # Crear el archivo si no existe
    if [ ! -f "$alias_file" ]; then
        mkdir -p "$(dirname "$alias_file")"
        cat > "$alias_file" <<'EOF'
# ~/.bash_aliases - alias personalizados
# Este archivo es cargado por ~/.bashrc
# (creado automáticamente por git-sidekick)
EOF
        echo -e "${GREEN}✅ Creado $alias_file${NC}"
    fi

    # ¿El alias 'gk' ya existe? -> preguntar antes de sobrescribir
    if existing=$(grep -n '^alias gk=' "$alias_file" 2>/dev/null) && [ -n "$existing" ]; then
        echo -e "${YELLOW}⚠️ El alias 'gk' ya existe en $alias_file:${NC}"
        echo "    $existing"
        read -p "¿Sobrescribir? [Enter=sí/n]" resp
        case "$resp" in
            n|N|no|No)
                echo -e "${YELLOW}Cancelado. El alias no se modificó.${NC}"
                return 1
                ;;
        esac
        # Reemplazar la línea existente (portable, sin sed -i)
        tmp=$(mktemp)
        grep -v '^alias gk=' "$alias_file" > "$tmp"
        printf '%s\n' "$alias_line" >> "$tmp"
        mv "$tmp" "$alias_file"
    else
        printf '%s\n' "$alias_line" >> "$alias_file"
    fi

    echo -e "${GREEN}✅ Alias 'gk' instalado en $alias_file:${NC}"
    echo "    $alias_line"
    echo ""
    echo -e "${CYAN}Recargá tu shell para usarlo:${NC}"
    echo "    source ~/.bashrc"
    echo "Ejemplo:  gk start"
    return 0
}

main() {
    # Detectar flag --dry-run (simulación) antes del subcomando
    local filtered_args=()
    local arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run|--dry) DRY_RUN=true ;;
            *) filtered_args+=("$arg") ;;
        esac
    done
    set -- "${filtered_args[@]}"

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${BLUE}🔍 [SIMULACIÓN] Activado: los comandos se muestran pero no se ejecutan.${NC}"
        echo -e "${BLUE}   💡 Sacá --dry-run para ejecutar de verdad.${NC}"
    fi

    if [ $# -gt 0 ]; then
        case $1 in
            start) start_session ;;
            close) close_session ;;
            status) mostrar_estado ;;
            restore) restaurar_snapshot ;;
            snapshot) crear_snapshot ;;
            clean) limpiar_snapshots ;;
            merge) shift; merge_protegido "$@" ;;
            info) mostrar_info ;;
            --install-alias) install_alias ;;
            help|--help|-h) mostrar_ayuda ;;
            *) echo -e "${RED}❌ Comando desconocido: $1${NC}"; mostrar_ayuda ;;
        esac
    else
        if ! check_git; then
            return 1
        fi
        mostrar_menu
    fi
}
main "$@"
