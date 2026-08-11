#!/usr/bin/env bash

# =============================================================================
# git-sidekick.sh - Asistente universal de Git para novatos
# Versión: 0.1.0 (esqueleto inicial)
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
        echo -e "${RED}❌ No estás en un repositorio Git.${NC}"
        return 1
    fi
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

    if [ "$nivel" = "2" ]; then
        if ! cambiar_rama "$destino"; then
            return 1
        fi
        local out tag_guardia
        out=$(crear_snapshot "pre-merge-de-${origen}-a-${destino}" work)
        tag_guardia=$(echo "$out" | sed 's/\x1b\[[0-9;]*m//g' | sed -n 's/.*Snapshot creado: //p')
        if [ -n "$tag_guardia" ]; then
            echo -e "${YELLOW}🛡️ Snapshot de seguridad creado: ${tag_guardia}${NC}"
        else
            echo -e "${RED}❌ No se pudo crear el snapshot de seguridad.${NC}"
            return 1
        fi
        echo -e "${CYAN}📋 Commits a fusionar ($origen → $destino):${NC}"
        git log --oneline "${destino}..${origen}" | head -30
        read -p "⚠️ ¿Estás seguro de que querés mergear $origen → $destino? [Enter=sí]: " confirmacion
        if [ "$confirmacion" = "n" ] || [ "$confirmacion" = "N" ]; then
            echo "Operación cancelada. Volviendo a '$rama_original'."
            git checkout "$rama_original" 2>/dev/null
            return 1
        fi
        read -p "⚠️ ¿REALMENTE seguro? Esta acción no se puede deshacer fácilmente. [Enter=sí]: " confirmacion
        if [ "$confirmacion" = "n" ] || [ "$confirmacion" = "N" ]; then
            echo "Operación cancelada. Volviendo a '$rama_original'."
            git checkout "$rama_original" 2>/dev/null
            return 1
        fi
    else
        read -p "¿Querés mergear $origen → $destino? [Enter=sí]: " confirmacion
        if [ "$confirmacion" = "n" ] || [ "$confirmacion" = "N" ]; then
            echo "Operación cancelada."
            git checkout "$rama_original" 2>/dev/null
            return 1
        fi
    fi

    if [ "$(git rev-parse --abbrev-ref HEAD)" != "$destino" ]; then
        if ! cambiar_rama "$destino"; then
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
    echo "  help     - Esta ayuda"
    echo ""
    echo "Sin argumentos: modo interactivo"
    echo "========================================="
}

# --- Menú principal ---
mostrar_menu() {
    echo "------------------------------------------------"
    echo -e "${BLUE}🎮 git-sidekick v0.1.0${NC}"
    echo "------------------------------------------------"
    echo "1) INICIAR sesión"
    echo "2) VER ESTADO"
    echo "3) CERRAR sesión"
    echo "4) RESTAURAR punto"
    echo "5) SNAPSHOT (rescate)"
    echo "6) LIMPIAR snapshots"
    echo "7) AYUDA"
    echo "8) SALIR"
    echo "9) FUSIONAR (merge protegido)"
    echo "------------------------------------------------"
    read -p "Opción (1-9): " opt
    case $opt in
        1) start_session ;;
        2) mostrar_estado ;;
        3) close_session ;;
        4) restaurar_snapshot ;;
        5) crear_snapshot ;;
        6) limpiar_snapshots ;;
        7) mostrar_ayuda ;;
        8) echo "👋 Saliendo." ;;
        9)
            local _m_origen _m_destino _m_nivel
            read -p "Rama origen: " _m_origen
            read -p "Rama destino: " _m_destino
            read -p "Nivel de protección (1/2): " _m_nivel
            merge_protegido "$_m_origen" "$_m_destino" "$_m_nivel"
            ;;
        *) echo -e "${RED}❌ Opción no válida${NC}" ;;
    esac
}

# --- Punto de entrada ---
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
            help|--help|-h) mostrar_ayuda ;;
            *) echo -e "${RED}❌ Comando desconocido: $1${NC}"; mostrar_ayuda ;;
        esac
    else
        mostrar_menu
    fi
}
main "$@"
