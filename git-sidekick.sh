#!/usr/bin/env bash

# =============================================================================
# git-sidekick.sh - Asistente universal de Git para novatos
# Versión: 0.3.0
# Licencia: MIT
# =============================================================================

# --- Validación temprana: git es un requisito duro ---
if ! command -v git >/dev/null 2>&1; then
    echo -e "\033[0;31m❌ git no está instalado.\033[0m"
    echo -e "\033[0;34m💡 Instalá git:\033[0m"
    echo -e "  - Linux (apt):  sudo apt install git"
    echo -e "  - macOS (brew): brew install git"
    echo -e "  - Windows:      winget install Git.Git"
    echo -e "  - O visitá:     https://git-scm.com/downloads"
    exit 1
fi

# --- Cargar módulos externos (colores y configuración) ---
# shellcheck source=lib/colors.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/colors.sh"
# shellcheck source=lib/config.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/config.sh"

# shellcheck source=lib/git-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/git-helpers.sh"
# shellcheck source=lib/ui.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/ui.sh"

# shellcheck source=lib/workflow.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/workflow.sh"

# shellcheck source=lib/plugins.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/plugins.sh"
# shellcheck source=lib/ddev.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/ddev.sh"

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
