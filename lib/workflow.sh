#!/usr/bin/env bash
# =============================================================================
# lib/workflow.sh - Funciones de lógica de negocio (workflows)
# Extraído de git-sidekick.sh para modularización (ROADMAP v2.0, Sesión 3)
# Requiere: lib/colors.sh, lib/config.sh, lib/git-helpers.sh, lib/ui.sh
# =============================================================================

# --- Función de inicialización automática ---
# shellcheck disable=SC2034 # COMMIT_INICIAL se asigna aquí y se lee en _mostrar_resumen_init (lib/ui.sh)
inicializar_repo() {
    local resp rama_default plataforma nombre_repo
    local visibilidad tipo cli_cmd cli_info remote_url platform_info extra

    # Preguntar si inicializar
    read -p "¿Querés inicializar uno ahora? [Enter=sí]: " resp
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
    say_success "Repositorio Git inicializado ✓"

    # --- Crear rama de desarrollo opcional (UX-2: que exista para merges 9/10) ---
    local dev_resp
    read -p "¿Crear también la rama de desarrollo '$DEV_BRANCH'? [Enter=sí]: " dev_resp
    if [ -z "$dev_resp" ] || [ "$dev_resp" = "s" ] || [ "$dev_resp" = "S" ] || [ "$dev_resp" = "y" ] || [ "$dev_resp" = "Y" ]; then
        if git show-ref --verify --quiet "refs/heads/$DEV_BRANCH" 2>/dev/null; then
            say_info "La rama '$DEV_BRANCH' ya existe."
        elif git checkout -b "$DEV_BRANCH" "$rama_default" 2>/dev/null; then
            say_success "Rama '$DEV_BRANCH' creada. Ya estás en ella ✓"
        else
            say_warn "No se pudo crear la rama '$DEV_BRANCH'."
        fi
        git checkout "$DEV_BRANCH" 2>/dev/null
    fi
    echo ""

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
                say_success "Cambios guardados en stash ✓"
                return 0
            else
                say_error "No pude hacer stash."
                say_tip "Probá manualmente: git stash push -m 'antes-de-cambiar'"
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
    say_tip "Iniciá sesión con 's' (opción 1) o creá un snapshot de rescate con '5'."
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
        local rama="" fecha_inicio="" accion=""
        while IFS='=' read -r key value; do
            case "$key" in
                rama) rama="$value" ;;
                fecha_inicio) fecha_inicio="$value" ;;
                accion) accion="$value" ;;
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
        say_success "Snapshot creado: $nombre ✓"
        say_tip "Restaurá con 'gk restore' (opción 4) si lo necesitás."
        return 0
    else
        say_error "No pude crear el tag '$nombre'."
        say_tip "Verificá que el nombre no esté repetido y que tengas permisos"
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
        say_success "Restaurado a $tag ✓"
        say_tip "Volvé a iniciar sesión con 's' (opción 1), o revisá con 'gk info'."
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
    say_success "Limpieza completada ✓"
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
    local ramas=() _i=1 _r _dev_idx=""
    while IFS= read -r _r; do
        [ -z "$_r" ] && continue
        local _marker=""
        if [ "$_r" = "$rama_actual" ]; then
            _marker=" *"
        fi
        if [ "$_r" = "$DEV_BRANCH" ]; then
            _dev_idx=$_i
            [ -z "$_marker" ] && _marker=" 🔹 (recomendado)"
        fi
        echo "  $_i) $_r$_marker"
        ramas+=("$_r")
        _i=$((_i+1))
    done < <(git branch --format='%(refname:short)')
    echo "  0) Crear nueva rama..."

    local _default=${_dev_idx:-1}
    local seleccion
    read -p "Seleccioná una rama (0-${#ramas[@]}) [$_default]: " seleccion
    if [ -z "$seleccion" ]; then
        seleccion=$_default
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
        git reset -q HEAD -- "$CONTEXT_FILE" 2>/dev/null || true
        git commit -m "Checkpoint inicio - ${etiqueta:-sin-etiqueta} - ${fecha_tag}" 2>/dev/null
    fi

    local snapshot_out snapshot_tag
    snapshot_out=$(crear_snapshot "$etiqueta")
    snapshot_tag=$(echo "$snapshot_out" | sed 's/\x1b\[[0-9;]*m//g' | sed -n 's/.*Snapshot creado: //p')

    if [ -n "$snapshot_tag" ]; then
        guardar_contexto "$rama" "inicio" "$snapshot_tag"
        say_success "SESIÓN INICIADA en [${rama}] ✓"
        say_info "Tag de inicio: ${snapshot_tag}"
        say_tip "Editá, agregá y commiteá. Cerrás con 'c' (opción 3)."
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
    git reset -q HEAD -- "$CONTEXT_FILE" 2>/dev/null || true
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
    say_success "SESIÓN CERRADA. Todo guardado ✓"
    say_tip "Iniciá otra con 's' (opción 1), o restaurá un point con '4'."
}
cambiar_rama() {
    local target_branch="$1"

    if [ -z "$target_branch" ]; then
        say_error "Debés especificar el nombre de la rama."
        say_tip "Ej: 'gk start' (opción 0) para crear una rama nueva"
        return 1
    fi

    if ! git show-ref --verify --quiet "refs/heads/$target_branch"; then
        say_error "La rama '$target_branch' no existe localmente."
        say_tip "Acá las ramas que tenés:"
        listar_ramas_disponibles
        return 1
    fi

    if tiene_cambios; then
        if ! stash_auto; then
            return 1
        fi
    fi

    local err_out
    if err_out=$(git checkout "$target_branch" 2>&1); then
        say_success "Cambiado a rama '$target_branch' ✓"
        say_tip "Iniciá sesión con 's' (opción 1) o creá un snapshot con '5'."
        return 0
    else
        say_git_error "$err_out"
        return 1
    fi
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
        say_error "La rama '$origen' no existe localmente."
        say_tip "Listá las ramas disponibles:"
        listar_ramas_disponibles
        return 1
    fi
    if ! git show-ref --verify --quiet "refs/heads/$destino"; then
        say_error "La rama '$destino' no existe localmente."
        say_tip "Listá las ramas disponibles:"
        listar_ramas_disponibles
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
        out=$(crear_snapshot "pre-merge-de-${origen}-a-${destino}" "$SNAPSHOT_PREFIX")
        tag_guardia=$(echo "$out" | sed 's/\x1b\[[0-9;]*m//g' | sed -n 's/.*Snapshot creado: //p')
        if [ -n "$tag_guardia" ]; then
            echo -e "${YELLOW}🛡️ Snapshot de seguridad creado: ${tag_guardia}${NC}"
        else
            echo -e "${RED}❌ No se pudo crear el snapshot de seguridad.${NC}"
            return 1
        fi
    fi

    local merge_out
    if merge_out=$(git merge "$origen" --no-edit 2>&1); then
        say_success "Merge completado sin conflictos ✓"
    else
        say_git_error "$merge_out"
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

    say_success "Merge $origen → $destino completado ✓"
    say_tip "Verificá con 'gk info', o seguí trabajando / cerrá con 'c' (opción 3)."
    return 0
}
