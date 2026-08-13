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

    # Preguntar local o remoto
    read -p "¿Querés trabajar solo en local o conectarlo a un remoto? (local/remoto) [local]: " modo
    if [ -z "$modo" ]; then
        modo="local"
    fi

    if [ "$modo" = "local" ]; then
        _mostrar_resumen_init "$rama_default" "" "" "" ""
        return 0
    fi

    # Modo remoto: crear nuevo o usar existente
    read -p "¿Querés crear un repositorio nuevo o usar uno existente? (crear/usar) [crear]: " opcion
    if [ -z "$opcion" ]; then
        opcion="crear"
    fi

    if [ "$opcion" = "crear" ]; then
        read -p "Plataforma (github/gitlab/bitbucket/otro) [github]: " plataforma
        if [ -z "$plataforma" ]; then
            plataforma="github"
        fi

        read -p "Nombre del repositorio: " nombre_repo
        if [ -z "$nombre_repo" ]; then
            echo -e "${RED}❌ Debés especificar un nombre para el repositorio.${NC}"
            platform_info="$plataforma"
            _mostrar_resumen_init "$rama_default" "" "$platform_info" "" "$nombre_repo (sin nombre)"
            return 0
        fi

        read -p "¿Público o privado? (public/private) [public]: " visibilidad
        if [ -z "$visibilidad" ]; then
            visibilidad="public"
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
    elif [ "$opcion" = "usar" ]; then
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
    listar_snapshots
    local tag
    read -p "Ingrese el tag a restaurar (Enter para cancelar): " tag
    if [ -z "$tag" ]; then
        echo "Operación cancelada."
        return 1
    fi
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
    if ! check_git; then
        return 1
    fi

    mostrar_estado

    local rama_actual
    rama_actual=$(git rev-parse --abbrev-ref HEAD)

    local respuesta_rama
    read -p "¿En qué rama vas a trabajar? (main/dev/actual) [actual]: " respuesta_rama

    local rama
    if [ -z "$respuesta_rama" ]; then
        rama="$rama_actual"
    else
        rama="$respuesta_rama"
    fi

    if [ "$rama" = "$rama_actual" ]; then
        :
    elif git show-ref --verify --quiet "refs/heads/$rama"; then
        if ! cambiar_rama "$rama"; then
            return 1
        fi
    else
        if ! git checkout -b "$rama" 2>/dev/null; then
            echo -e "${RED}❌ Error al crear la rama '$rama'.${NC}"
            return 1
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
    echo "  start    - Iniciar sesión"
    echo "  close    - Cerrar sesión"
    echo "  status   - Ver estado"
    echo "  restore  - Restaurar punto"
    echo "  snapshot - Rescate rápido"
    echo "  clean    - Limpiar viejos"
    echo "  merge    - Merge protegido (origen destino nivel)"
    echo "    uso:    merge <origen> <destino> <1|2>"
    echo "  --install-alias - Instala el alias 'gk' en ~/.bash_aliases"
    echo "  help     - Esta ayuda"
    echo "  info     - Inicializa repo + conexión remota si no existe"
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
    if [ $# -gt 0 ]; then
        case $1 in
            start) start_session ;;
            close) close_session ;;
            status) mostrar_estado ;;
            restore) restaurar_snapshot ;;
            snapshot) crear_snapshot ;;
            clean) limpiar_snapshots ;;
            merge) shift; merge_protegido "$@" ;;
            info) check_git && echo "📁 Repositorio: $(pwd)" && echo "🌿 Rama: $(git rev-parse --abbrev-ref HEAD)" ;;
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
