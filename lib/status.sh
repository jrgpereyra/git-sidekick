#!/usr/bin/env bash
# =============================================================================
# lib/status.sh - Render conversacional del estado de Git (novatos)
# Requiere: lib/colors.sh (say_* y colores), lib/config.sh (CONTEXT_FILE)
#           y lib/git-helpers.sh (contar_cambios_sin_guardar, cargado antes del menú)
# =============================================================================
# Flujo: traduce `git status --porcelain` a lenguaje natural, describe el estado
# remoto y recomienda el siguiente paso del menú. No muestra códigos XY salvo
# que SIDEKICK_STATUS_RAW=1.

# --- Datos del remoto (salida por variables globales) ---
# --- FUNCIÓN: _status_remoto_datos ---
# PROPÓSITO: calcular remoto/upstream y ahead/behind para una rama.
# PARÁMETROS: $1 = rama (opcional; si falta, se detecta desde HEAD).
# RETORNA: 0; setea _STATUS_RAMA, _STATUS_TIENE_REMOTO, _STATUS_TIENE_UPSTREAM,
#          _STATUS_AHEAD y _STATUS_BEHIND.
# POR QUÉ: describir el estado y recomendar el siguiente paso comparten estos datos.
_status_remoto_datos() {
    local rama="${1:-}"
    _STATUS_RAMA="$rama"
    _STATUS_TIENE_REMOTO=0
    _STATUS_TIENE_UPSTREAM=0
    _STATUS_AHEAD=0
    _STATUS_BEHIND=0

    if [ -z "$rama" ]; then
        rama=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        _STATUS_RAMA="$rama"
    fi
    [ -z "$rama" ] && return 0

    if [ -n "$(git remote get-url origin 2>/dev/null)" ]; then
        _STATUS_TIENE_REMOTO=1
    fi

    if [ "$rama" != "HEAD" ] && git rev-parse "${rama}@{upstream}" >/dev/null 2>&1; then
        _STATUS_TIENE_UPSTREAM=1
        _STATUS_BEHIND=$(git rev-list --count HEAD.."${rama}@{upstream}" 2>/dev/null)
        _STATUS_AHEAD=$(git rev-list --count "${rama}@{upstream}"..HEAD 2>/dev/null)
        [ -z "$_STATUS_BEHIND" ] && _STATUS_BEHIND=0
        [ -z "$_STATUS_AHEAD" ] && _STATUS_AHEAD=0
    fi
}

# --- FUNCIÓN: describir_estado_remoto ---
# PROPÓSITO: devolver una frase humana sobre la relación con el servidor.
# PARÁMETROS: $1 = rama actual.
# RETORNA: 0; imprime la frase por stdout.
# POR QUÉ: reemplaza "Ahead/Behind" y los hints crudos de git pull/push.
describir_estado_remoto() {
    _status_remoto_datos "$1"

    if [ -z "$_STATUS_RAMA" ] || [ "$_STATUS_RAMA" = "HEAD" ]; then
        printf '%s\n' "Estás en una versión específica del proyecto, no en una rama con nombre."
        return 0
    fi

    if [ "$_STATUS_TIENE_UPSTREAM" -eq 1 ]; then
        if [ "$_STATUS_BEHIND" -gt 0 ] && [ "$_STATUS_AHEAD" -gt 0 ]; then
            printf 'Tenés %s cambio(s) para subir y %s cambio(s) nuevos en el servidor.\n' \
                "$_STATUS_AHEAD" "$_STATUS_BEHIND"
        elif [ "$_STATUS_BEHIND" -gt 0 ]; then
            printf 'Hay %s cambio(s) nuevos en el servidor que todavía no descargaste.\n' \
                "$_STATUS_BEHIND"
        elif [ "$_STATUS_AHEAD" -gt 0 ]; then
            printf 'Tenés %s cambio(s) locales que todavía no subiste.\n' \
                "$_STATUS_AHEAD"
        else
            printf '%s\n' "Tu rama está sincronizada con el servidor."
        fi
    elif [ "$_STATUS_TIENE_REMOTO" -eq 1 ]; then
        printf '%s\n' "Esta rama solo existe en tu computadora; todavía no se subió al servidor."
    else
        printf '%s\n' "Esta rama solo existe en tu computadora (no hay servidor conectado)."
    fi
}

# --- FUNCIÓN: describir_archivo ---
# PROPÓSITO: traducir el código XY de porcelain a una descripción conversacional.
# PARÁMETROS: $1 = código XY, $2 = ruta reportada por Git.
# RETORNA: 0; imprime "ruta (Etiqueta — explicación)".
# POR QUÉ: el novato necesita entender qué pasó, no memorizar letras de Git.
describir_archivo() {
    local xy="$1" ruta="$2" viejo nuevo

    case "$xy" in
        UU|AA|DD|AU|UA|DU|UD)
            printf '%s (Conflicto — requiere resolución)\n' "$ruta"
            ;;
        '??')
            printf '%s (Nuevo — archivo recién creado)\n' "$ruta"
            ;;
        'M ')
            printf '%s (Modificado — listo para guardar)\n' "$ruta"
            ;;
        ' M')
            printf '%s (Modificado — tenés cambios sin guardar)\n' "$ruta"
            ;;
        'MM')
            printf '%s (Modificado — parte lista para guardar y parte sin guardar)\n' "$ruta"
            ;;
        'A ')
            printf '%s (Nuevo — listo para guardar)\n' "$ruta"
            ;;
        'AM')
            printf '%s (Nuevo — con cambios posteriores sin guardar)\n' "$ruta"
            ;;
        'AD')
            printf '%s (Nuevo — se borró después de agregarlo)\n' "$ruta"
            ;;
        'D ')
            printf '%s (Eliminado — listo para guardar)\n' "$ruta"
            ;;
        ' D')
            printf '%s (Eliminado — archivo borrado)\n' "$ruta"
            ;;
        R*|C*)
            viejo="${ruta%% -> *}"
            nuevo="${ruta#* -> }"
            if [ "$viejo" = "$nuevo" ]; then
                if [ "${xy:0:1}" = "R" ]; then
                    printf '%s (Renombrado — revisá el nombre anterior)\n' "$ruta"
                else
                    printf '%s (Copiado — revisá el archivo original)\n' "$ruta"
                fi
            elif [ "${xy:0:1}" = "R" ]; then
                printf '%s (Renombrado — antes se llamaba '\''%s'\'')\n' "$nuevo" "$viejo"
            else
                printf '%s (Copiado — a partir de '\''%s'\'')\n' "$nuevo" "$viejo"
            fi
            ;;
        'T '|' T')
            printf '%s (Cambió el tipo de archivo — revisalo)\n' "$ruta"
            ;;
        *)
            printf '%s (Estado especial — revisá este archivo con cuidado)\n' "$ruta"
            ;;
    esac
}

# --- FUNCIÓN: _status_imprimir_grupo ---
# PROPÓSITO: imprimir un grupo de bullets respetando el tope configurado.
# PARÁMETROS: $1 = color; $2..N = líneas ya traducidas.
# RETORNA: 0; incrementa _STATUS_IMPRESOS.
_status_imprimir_grupo() {
    local color="$1" item
    shift
    for item in "$@"; do
        [ "$_STATUS_IMPRESOS" -ge "$_STATUS_LIMITE" ] && return 0
        printf -- '- %b%s%b\n' "$color" "$item" "$NC"
        _STATUS_IMPRESOS=$((_STATUS_IMPRESOS + 1))
    done
}

# --- FUNCIÓN: renderizar_archivos_git ---
# PROPÓSITO: imprimir el bloque de archivos con cambios en lenguaje natural.
# PARÁMETROS: $1 = límite de líneas (default 20).
# RETORNA: 0; setea _STATUS_TOTAL y _STATUS_CONFLICTOS.
# POR QUÉ: centraliza el parseo de porcelain y el modo RAW para status e info.
renderizar_archivos_git() {
    local limite="${1:-20}"
    case "$limite" in
        ''|*[!0-9]*|0) limite=20 ;;
    esac

    local conflictos=() pendientes=() nuevos=() eliminados=() listos=()
    local linea xy ruta origen

    while IFS= read -r -d '' linea; do
        [ -z "$linea" ] && continue
        xy="${linea:0:2}"
        ruta="${linea:3}"
        origen=""
        case "$xy" in
            R*|C*)
                IFS= read -r -d '' origen || origen=""
                [ -n "$origen" ] && ruta="${origen} -> ${ruta}"
                ;;
        esac
        case "$xy" in
            UU|AA|DD|AU|UA|DU|UD)
                conflictos+=("$(describir_archivo "$xy" "$ruta")")
                ;;
            '??')
                nuevos+=("$(describir_archivo "$xy" "$ruta")")
                ;;
            'A '|'AM'|'AD')
                nuevos+=("$(describir_archivo "$xy" "$ruta")")
                ;;
            'D '|' D'|'MD'|'DM'|'TD'|'DT')
                eliminados+=("$(describir_archivo "$xy" "$ruta")")
                ;;
            'R '|'RM'|'RD'|'C '|'CM'|'CD')
                listos+=("$(describir_archivo "$xy" "$ruta")")
                ;;
            *)
                pendientes+=("$(describir_archivo "$xy" "$ruta")")
                ;;
        esac
    done < <(git -c core.quotePath=false status --porcelain -z 2>/dev/null)

    _STATUS_CONFLICTOS=${#conflictos[@]}
    _STATUS_TOTAL=$(( ${#conflictos[@]} + ${#pendientes[@]} + ${#nuevos[@]} + ${#eliminados[@]} + ${#listos[@]} ))

    echo -e "${CYAN}📋 Archivos detectados con cambios:${NC}"

    if [ "${SIDEKICK_STATUS_RAW:-0}" = "1" ]; then
        git status --short 2>/dev/null
        return 0
    fi

    if [ "$_STATUS_TOTAL" -eq 0 ]; then
        echo "- Ninguno. Tu carpeta de trabajo está limpia."
        return 0
    fi

    _STATUS_LIMITE="$limite"
    _STATUS_IMPRESOS=0
    _status_imprimir_grupo "$RED" "${conflictos[@]}"
    _status_imprimir_grupo "$YELLOW" "${pendientes[@]}"
    _status_imprimir_grupo "$CYAN" "${nuevos[@]}"
    _status_imprimir_grupo "$YELLOW" "${eliminados[@]}"
    _status_imprimir_grupo "$GREEN" "${listos[@]}"

    if [ "$_STATUS_TOTAL" -gt "$_STATUS_IMPRESOS" ]; then
        echo "... y $((_STATUS_TOTAL - _STATUS_IMPRESOS)) archivo(s) más"
    fi
}

# --- FUNCIÓN: mostrar_resumen_cambios_menu ---
# PROPÓSITO: mostrar un resumen pasivo de cambios pendientes en el menú principal.
# PARÁMETROS: $1 = máximo de archivos a listar (default 3).
# RETORNA: 0 (siempre); imprime estado + hasta N archivos, sin prompts ni commits.
# POR QUÉ: el novato ve qué falta guardar sin que el menú lo obligue a commitear.
# NOTA: sólo lee `git status` local (sin fetch) y excluye CONTEXT_FILE.
mostrar_resumen_cambios_menu() {
    local limite="${1:-3}" total mostrados=0 linea xy ruta origen

    case "$limite" in
        ''|*[!0-9]*|0) limite=3 ;;
    esac

    total=$(contar_cambios_sin_guardar)
    case "$total" in
        ''|*[!0-9]*) total=0 ;;
    esac

    if [ "$total" -eq 0 ]; then
        say_info "Sin cambios pendientes."
        return 0
    fi

    say_warn "${total} archivo(s) con cambios sin guardar."

    while IFS= read -r -d '' linea; do
        [ -z "$linea" ] && continue
        xy="${linea:0:2}"
        ruta="${linea:3}"
        origen=""
        case "$xy" in
            R*|C*) IFS= read -r -d '' origen || origen="" ;;
        esac
        if [ "$ruta" = "$CONTEXT_FILE" ] || [ "$origen" = "$CONTEXT_FILE" ]; then
            continue
        fi
        [ "$mostrados" -ge "$limite" ] && continue
        case "$xy" in
            R*|C*) [ -n "$origen" ] && ruta="${origen} -> ${ruta}" ;;
        esac
        printf -- '- %s\n' "$(describir_archivo "$xy" "$ruta")"
        mostrados=$((mostrados + 1))
    done < <(git -c core.quotePath=false status --porcelain -z 2>/dev/null)

    if [ "$total" -gt "$mostrados" ]; then
        echo "... y $((total - mostrados)) archivo(s) más"
    fi
    say_tip "[2] para cerrar sesión · [4] para ver detalle."
}

# --- FUNCIÓN: recomendar_siguiente_paso ---
# PROPÓSITO: orientar al novato según conflictos, remoto y archivos pendientes.
# PARÁMETROS: $1 = cantidad de conflictos, $2 = total de archivos con cambios.
# RETORNA: 0; imprime una recomendación por stdout.
# POR QUÉ: siempre ofrece una acción concreta usando los labels del menú.
recomendar_siguiente_paso() {
    local num_conflictos="${1:-0}" num_total="${2:-0}"
    case "$num_conflictos" in ''|*[!0-9]*) num_conflictos=0 ;; esac
    case "$num_total" in ''|*[!0-9]*) num_total=0 ;; esac
    _status_remoto_datos ""

    if [ "$num_conflictos" -gt 0 ]; then
        printf '%s\n' "Abrí cada archivo marcado como conflicto, resolvé las diferencias y después elegí \"2) CERRAR sesión\" para guardar la versión final."
    elif [ "$_STATUS_BEHIND" -gt 0 ]; then
        printf '%s\n' "Hay cambios nuevos en el servidor. Antes de seguir trabajando, actualizá tu copia; si no sabés cómo, pedí ayuda."
        if [ "$num_total" -gt 0 ]; then
            printf '%s\n' "Después, elegí \"2) CERRAR sesión\" para guardar tus cambios."
        fi
    elif [ "$num_total" -gt 0 ]; then
        printf '%s\n' "Cuando termines, elegí \"2) CERRAR sesión\" para guardar tus cambios. Si querés crear un snapshot antes, entrá a \"4) EXTRAS\" y elegí \"3) Crear snapshot\"."
    elif [ -f "${CONTEXT_FILE:-}" ]; then
        printf '%s\n' "No hay cambios pendientes y tu sesión está activa. Cuando termines, elegí \"2) CERRAR sesión\"."
    else
        printf '%s\n' "No hay cambios pendientes. Elegí \"1) INICIAR sesión\" para empezar a trabajar o \"4) EXTRAS\" para crear un snapshot."
    fi
}

# --- FUNCIÓN: mostrar_estado_conversacional ---
# PROPÓSITO: imprimir rama, estado remoto, archivos y recomendación en 3 bloques.
# PARÁMETROS: (ninguno; lee el estado actual de Git).
# RETORNA: 0.
# POR QUÉ: es la salida completa de `gk status` para usuarios novatos.
mostrar_estado_conversacional() {
    local rama
    rama=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    [ -z "$rama" ] && rama="(sin rama)"

    echo -e "📍 Estás trabajando en la rama: ${YELLOW}[${rama}]${NC}"
    say_info "$(describir_estado_remoto "$rama")"
    echo ""
    renderizar_archivos_git 20
    echo ""
    echo -e "${CYAN}💡 Recomendación:${NC}"
    recomendar_siguiente_paso "$_STATUS_CONFLICTOS" "$_STATUS_TOTAL"
}
