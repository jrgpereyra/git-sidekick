#!/usr/bin/env bash
# =============================================================================
# lib/ui.sh - Funciones de interfaz de usuario y manejo de entrada
# Extraído de git-sidekick.sh para modularización (ROADMAP v2.0, Sesión 2)
# Requiere: lib/colors.sh (para say_* y variables de color)
#           lib/config.sh (para DEFAULT_BRANCH, DEV_BRANCH, CONTEXT_FILE, etc.)
# =============================================================================

# --- Flag de simulación ---
DRY_RUN=false

# --- Simulación / Dry-run ---
simulate() {
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${BLUE}🔍 [SIMULACIÓN] $*${NC}"
        return 0
    fi
    return 1
}

# --- Onboarding TUI: guía visual para novatos recién iniciados ---
# Se muestra al finalizar la inicialización, solo para repos nuevos.
mostrar_onboarding() {
    local sep
    sep=$(printf '%*s' 42 '' | tr ' ' '─')
    echo ""
    printf '┌─%s┐\n' "$sep"
    echo "│ 🎮 Primeros pasos con git-sidekick"
    printf '├─%s┤\n' "$sep"
    echo "│ "
    echo "│  Desde el menú interactivo:"
    echo "│    1) INICIAR sesión  (atajo: s)"
    echo "│    3) CERRAR sesión  (atajo: c) → commitear + tag"
    echo "│    5) SNAPSHOT (rescate)"
    echo "│ "
    echo "│  Desde la terminal:"
    echo "│    gk start  ·  gk close  ·  gk info"
    echo "│    gk --dry-run  ←  simulá antes de usar"
    echo "│ "
    printf '└─%s┘\n' "$sep"
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
    if git show-ref --verify --quiet "refs/heads/$DEV_BRANCH" 2>/dev/null; then
        echo "   🌿 Rama $DEV_BRANCH:     ✅ creada"
    fi
    say_success "Repo listo para trabajar ✓"
    echo ""
    mostrar_onboarding
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

# --- Menú principal (loop persistente) ---
mostrar_menu() {
    while true; do
        local _rama_actual opt
        _rama_actual=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        echo "------------------------------------------------"
        echo -e "${BLUE}🎮 git-sidekick v0.3.0${NC}"
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
        echo "------------------------------------------------"
        echo "1) INICIAR sesión        (atajo: s)"
        echo "2) VER ESTADO"
        echo "3) CERRAR sesión         (atajo: c)"
        echo "4) RESTAURAR punto"
        echo "5) SNAPSHOT (rescate)"
        echo "6) LIMPIAR snapshots"
        echo "7) ACTUALIZAR ${DEV_BRANCH} con ${DEFAULT_BRANCH} (${DEFAULT_BRANCH} → ${DEV_BRANCH})  [nivel 1]"
        echo "8) PUBLICAR ${DEV_BRANCH} a ${DEFAULT_BRANCH} (${DEV_BRANCH} → ${DEV_BRANCH})  [nivel 2]"
        echo "9) FUSIONAR personalizado"
        echo "10) AYUDA"
        echo "11) SALIR                 (atajo: q)"
        echo "------------------------------------------------"
        read -r -p "Opción (1-11) [s/c/q]: " opt
        case $opt in
            1|[sS]) start_session ;;
            2) mostrar_estado ;;
            3|[cC]) close_session ;;
            4) restaurar_snapshot ;;
            5) crear_snapshot ;;
            6) limpiar_snapshots ;;
            7) merge_protegido "${DEFAULT_BRANCH}" "${DEV_BRANCH}" "1" ;;
            8) merge_protegido "${DEV_BRANCH}" "${DEV_BRANCH}" "2" ;;
            9)
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
                _orig_m="${_ramas[$((_num_o-1))]}"
                _dest_m="${_ramas[$((_num_d-1))]}"
                merge_protegido "$_orig_m" "$_dest_m" "$_niv_m"
                ;;
            10) mostrar_ayuda ;;
            11|[qQ])
                echo "👋 Saliendo."
                break
                ;;
            *) echo -e "${RED}❌ Opción no válida${NC}" ;;
        esac
    done
}
