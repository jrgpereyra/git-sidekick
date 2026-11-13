#!/usr/bin/env bash
# =============================================================================
# lib/ui.sh - Funciones de interfaz de usuario y manejo de entrada
# Extraído de git-sidekick.sh para modularización (ROADMAP v2.0, Sesión 2)
# Requiere: lib/colors.sh (para say_* y variables de color)
#           lib/config.sh (para DEFAULT_BRANCH, DEV_BRANCH, CONTEXT_FILE, etc.)
# =============================================================================
# Flujo: UI del agente. simulate() gatea dry-run; mostrar_onboarding() guía a
# novatos; _mostrar_resumen_init() imprime el resumen de init; mostrar_menu()
# es el loop interactivo persistente; mostrar_ayuda() imprime la ayuda.

# --- Flag de simulación ---
DRY_RUN=false

# --- Helpers de pantalla y pausa (solo TTY) ---
# --- FUNCIÓN: clear_screen ---
# PROPÓSITO: limpiar la terminal en las transiciones de menú sin romper pipes/tests.
# PARÁMETROS: (ninguno).
# RETORNA: 0 (siempre).
# POR QUÉ: `clear` sólo tiene sentido en una terminal; en tests la salida se captura.
# NOTA: SIDEKICK_NO_CLEAR=1 desactiva la limpieza (útil para depurar).
clear_screen() {
    [ -t 1 ] || return 0
    [ "${SIDEKICK_NO_CLEAR:-0}" = "1" ] && return 0
    clear 2>/dev/null || printf '\033[2J\033[H'
}

# --- FUNCIÓN: pausa ---
# PROPÓSITO: pausar para que el usuario lea el resultado antes de limpiar pantalla.
# PARÁMETROS: (ninguno; lee una línea de stdin).
# RETORNA: 0 (siempre).
# POR QUÉ: con `clear` en cada transición, sin pausa el resultado se perdería.
# NOTA: sólo pausa en TTY; con stdin por pipe (tests) retorna sin consumir líneas.
pausa() {
    [ -t 0 ] || return 0
    [ "${SIDEKICK_NO_PAUSE:-0}" = "1" ] && return 0
    read -r -p "⏎ Enter para continuar..." _
}

# --- Simulación / Dry-run ---
# --- FUNCIÓN: simulate ---
# PROPÓSITO: en modo --dry-run, anunciar y retornar true (SIMULAR) efectos secundarios.
# PARÁMETROS: $1 = descripción legible del efecto a simular.
# RETORNA: 0 (true) si simuló, 1 (false) en modo real (caller ejecuta de verdad).
# POR QUÉ: centraliza el gate DRY_RUN para que ningún comando dependa de la flag.
# NOTA: los callers usan `if simulate "..."; then return; fi` para cortar en dry-run.
simulate() {
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${BLUE}🔍 [SIMULACIÓN] $*${NC}"
        return 0
    fi
    return 1
}

# --- Onboarding TUI: guía visual para novatos recién iniciados ---
# --- FUNCIÓN: mostrar_onboarding ---
# PROPÓSITO: guía visual de bienvenida (solo para repos recién inicializados).
# PARÁMETROS: (ninguno).
# RETORNA: 0.
# POR QUÉ: evita ruido: se muestra UNA vez al finalizar una init nueva, no cada vez.
# NOTA: usa caja dibujada (┌┐│└) para una presentación amistosa en terminal.
mostrar_onboarding() {
    local sep
    sep=$(printf '%*s' 42 '' | tr ' ' '─')
    echo ""
    printf '┌─%s┐\n' "$sep"
    echo "│ 🎮 Primeros pasos con git-sidekick"
    printf '├─%s┤\n' "$sep"
    echo "│ "
    echo "│  Desde el menú interactivo:"
    echo "│    1) INICIAR sesión   (atajo: s)"
    echo "│    2) CERRAR sesión    (atajo: c) → guardar cambios + snapshot"
    echo "│    3) PUBLICAR ${DEV_BRANCH} a ${DEFAULT_BRANCH}"
    echo "│    4) EXTRAS  (atajo: e) → ver estado / crear snapshot / restaurar"
    echo "│    5) SALIR            (atajo: q)"
    echo "│ "
    echo "│  Desde la terminal:"
    echo "│    gk start  ·  gk close  ·  gk info"
    echo "│    gk --dry-run  ←  simulá antes de usar"
    echo "│ "
    printf '└─%s┘\n' "$sep"
}

# --- Función helper: resumen de inicialización ---
# --- FUNCIÓN: _mostrar_resumen_init ---
# PROPÓSITO: imprimir el resumen final de la inicialización del repo.
# PARÁMETROS: $1=rama, $2=remote_url, $3=platform_info, $4=cli_info, $5=extra.
# RETORNA: 0.
# POR QUÉ: consolida en un vistazo estado rama/remote/plataforma tras la init.
# NOTA: el guion bajo (_) marca helper interno (no debe llamarse directamente).
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
    if git show-ref --verify --quiet "refs/heads/$DEV_BRANCH" 2>/dev/null; then
        echo "   🌿 Rama $DEV_BRANCH:     ✅ creada"
    fi
    say_success "Repo listo para trabajar ✓"
    echo ""
    mostrar_onboarding
}

# --- Función de ayuda ---
# --- FUNCIÓN: mostrar_ayuda ---
# PROPÓSITO: imprimir la ayuda/usage de git-sidekick (comandos y flags).
# PARÁMETROS: (ninguno).
# RETORNA: 0.
# POR QUÉ: fuente única de verdad para el uso (invocado por --help y comandos desconocidos).
mostrar_ayuda() {
    echo "========================================="
    echo -e "${CYAN}📘 git-sidekick - Asistente de Git${NC}"
    echo "========================================="
    echo "Comandos disponibles:"
    echo "  start    - Iniciar sesión (lista ramas numeradas)"
    echo "  close    - Cerrar sesión"
    echo "  status   - Ver estado"
    echo "  restore  - Restaurar un snapshot"
    echo "  snapshot - Crear un snapshot"
    echo "  clean    - Limpiar snapshots viejos"
    echo "  merge    - Fusionar ramas con protección"
    echo "    uso:    merge <origen> <destino> <1|2>"
    echo "            1 = simple · 2 = estricto"
    echo "  --install-alias - Instala el alias 'gk' en ~/.bash_aliases"
    echo "  help     - Esta ayuda"
    echo "  info     - Muestra información detallada del repositorio"
    echo "Todos los comandos aceptan --dry-run para simular sin ejecutar."
    echo "Ejemplo:  gk start --dry-run"
    echo ""
    echo "Menú interactivo (sin argumentos):"
    echo "  1) INICIAR sesión   (s)"
    echo "  2) CERRAR sesión    (c)"
    echo "  3) PUBLICAR ${DEV_BRANCH} a ${DEFAULT_BRANCH}"
    echo "  4) EXTRAS           (e) → ver estado, crear snapshot, restaurar, limpiar, fusionar, ayuda"
    echo "  5) SALIR            (q)"
    echo "========================================="
}

# --- Alerta de publicaciones pendientes (dev adelantada respecto de main) ---
# --- FUNCIÓN: mostrar_alerta_publicaciones_pendientes ---
# PROPÓSITO: avisar cuántos commits de DEV_BRANCH faltan publicar en DEFAULT_BRANCH.
# PARÁMETROS: $1 = contexto opcional ("menu" por defecto, o "cierre").
# RETORNA: 0 (siempre); imprime aviso + tip sólo si hay commits pendientes.
# POR QUÉ: evita que el novato olvide correr la opción 3 (PUBLICAR) al terminar.
# NOTA: en "cierre" distingue si la sesión quedó en DEV_BRANCH o en otra rama.
mostrar_alerta_publicaciones_pendientes() {
    local contexto="${1:-menu}" pendientes

    pendientes=$(contar_commits_sin_publicar)
    case "$pendientes" in
        ''|*[!0-9]*) pendientes=0 ;;
    esac
    [ "$pendientes" -gt 0 ] || return 0

    if [ "$contexto" = "cierre" ] && [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" = "$DEV_BRANCH" ]; then
        say_warn "Tus cambios quedaron en ${DEV_BRANCH}: hay ${pendientes} cambio(s) sin publicar en ${DEFAULT_BRANCH}."
        say_tip "Para publicarlos, elegí la opción 3 (PUBLICAR ${DEV_BRANCH} a ${DEFAULT_BRANCH})."
    elif [ "$contexto" = "cierre" ]; then
        say_warn "Hay ${pendientes} cambio(s) en ${DEV_BRANCH} sin publicar en ${DEFAULT_BRANCH}."
        say_tip "Para publicarlos, elegí la opción 3 (PUBLICAR ${DEV_BRANCH} a ${DEFAULT_BRANCH})."
    else
        say_warn "Tenés ${pendientes} cambio(s) en ${DEV_BRANCH} sin publicar en ${DEFAULT_BRANCH}."
        say_tip "Cuando termines, elegí la opción 3 (PUBLICAR ${DEV_BRANCH} a ${DEFAULT_BRANCH})."
    fi
}

# --- Menú principal (loop persistente) ---
# --- FUNCIÓN: mostrar_menu ---
# PROPÓSITO: mostrar el menú interactivo (1-5) y ejecutar la opción elegida en loop.
# PARÁMETROS: (ninguno; interacción vía read -r -p).
# RETORNA: 0 al salir (opción 5/q); caso contrario el código de la sub-acción elegida.
# POR QUÉ: loop persistente → el usuario navega sin salir y volver a invocar.
# NOTA: read -r evita mangling de backslashes; -p deja el prompt en la misma línea.
mostrar_menu() {
    while true; do
        local _rama_actual opt
        clear_screen
        _rama_actual=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        echo "------------------------------------------------"
        echo -e "${BLUE}🎮 git-sidekick v0.4.0${NC}"
        if [ -n "$_rama_actual" ]; then
            echo -e "${YELLOW}📍 Rama actual: → $_rama_actual${NC}"
        fi
        if [ -f "$CONTEXT_FILE" ]; then
            local _ctx_rama
            _ctx_rama=$(grep '^rama=' "$CONTEXT_FILE" 2>/dev/null | cut -d= -f2-)
            say_success "Sesión: activa en [${_ctx_rama}]"
        else
            say_warn "Sesión: inactiva — usá 's' (opción 1) para INICIAR"
        fi
        mostrar_alerta_publicaciones_pendientes
        mostrar_resumen_cambios_menu
        echo "------------------------------------------------"
        echo "1) INICIAR sesión        (atajo: s)"
        echo "2) CERRAR sesión         (atajo: c)"
        echo "3) PUBLICAR ${DEV_BRANCH} a ${DEFAULT_BRANCH}"
        echo "4) EXTRAS / HERRAMIENTAS (atajo: e)"
        echo "5) SALIR                 (atajo: q)"
        echo "------------------------------------------------"
        read -r -p "Opción (1-5) [s/c/e/q]: " opt || break
        case $opt in
            1|[sS])
                clear_screen
                start_session
                pausa
                ;;
            2|[cC])
                clear_screen
                close_session
                pausa
                ;;
            3)
                clear_screen
                merge_protegido "${DEV_BRANCH}" "${DEFAULT_BRANCH}" "2"
                pausa
                ;;
            4|[eE])
                mostrar_menu_extras
                ;;
            5|[qQ])
                echo "👋 Saliendo."
                break
                ;;
            *) echo -e "${RED}❌ Opción no válida${NC}" ;;
        esac
    done
}

# --- FUNCIÓN: fusionar_personalizado ---
# PROPÓSITO: elegir origen, destino y nivel por número y lanzar merge_protegido.
# PARÁMETROS: (ninguno; interacción vía read -r -p).
# RETORNA: 0 si delega el merge; 1 si la selección es inválida.
# POR QUÉ: aísla la lógica del menú y permite reutilizarla sin duplicar código.
# NOTA: los números elegidos se validan antes de indexar el array de ramas.
fusionar_personalizado() {
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

    read -r -p "Número de rama origen: " _num_o
    read -r -p "Número de rama destino: " _num_d
    read -r -p "Nivel de protección (1/2): " _niv_m

    if ! [[ "$_num_o" =~ ^[0-9]+$ ]] || [ "$_num_o" -lt 1 ] || [ "$_num_o" -gt "${#_ramas[@]}" ]; then
        say_error "Número de rama origen inválido."
        return 1
    fi
    if ! [[ "$_num_d" =~ ^[0-9]+$ ]] || [ "$_num_d" -lt 1 ] || [ "$_num_d" -gt "${#_ramas[@]}" ]; then
        say_error "Número de rama destino inválido."
        return 1
    fi
    if [ "$_niv_m" != "1" ] && [ "$_niv_m" != "2" ]; then
        say_error "Nivel de protección inválido. Usá 1 (simple) o 2 (estricto)."
        return 1
    fi

    _orig_m="${_ramas[$((_num_o-1))]}"
    _dest_m="${_ramas[$((_num_d-1))]}"
    merge_protegido "$_orig_m" "$_dest_m" "$_niv_m"
}

# --- Menú secundario de herramientas ---
# --- FUNCIÓN: mostrar_menu_extras ---
# PROPÓSITO: agrupar las herramientas secundarias en un submenú con retorno.
# PARÁMETROS: (ninguno; interacción vía read -r -p).
# RETORNA: 0 al volver al menú principal (opción 0).
# POR QUÉ: mantiene el menú principal en 5 opciones sin perder funcionalidad.
# NOTA: conserva los labels con DEV_BRANCH/DEFAULT_BRANCH para config y tests.
mostrar_menu_extras() {
    while true; do
        local opt
        clear_screen
        echo "------------------------------------------------"
        echo -e "${BLUE}🛠️  EXTRAS / HERRAMIENTAS${NC}"
        echo "------------------------------------------------"
        echo "1) Ver estado"
        echo "2) Restaurar snapshot"
        echo "3) Crear snapshot"
        echo "4) Limpiar snapshots"
        echo "5) Actualizar ${DEV_BRANCH} desde ${DEFAULT_BRANCH}"
        echo "6) Fusionar ramas manualmente"
        echo "7) Ayuda"
        echo "0) Volver al menú principal"
        echo "------------------------------------------------"
        read -r -p "Opción (0-7): " opt || break
        case $opt in
            1)
                clear_screen
                mostrar_estado
                pausa
                ;;
            2)
                clear_screen
                restaurar_snapshot
                pausa
                ;;
            3)
                clear_screen
                crear_snapshot
                pausa
                ;;
            4)
                clear_screen
                limpiar_snapshots
                pausa
                ;;
            5)
                clear_screen
                merge_protegido "${DEFAULT_BRANCH}" "${DEV_BRANCH}" "1"
                pausa
                ;;
            6)
                clear_screen
                fusionar_personalizado
                pausa
                ;;
            7)
                clear_screen
                mostrar_ayuda
                pausa
                ;;
            0)
                break
                ;;
            *) echo -e "${RED}❌ Opción no válida${NC}" ;;
        esac
    done
}
