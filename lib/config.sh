#!/usr/bin/env bash
# =============================================================================
# lib/config.sh - Variables de configuración y parser de .git-sidekickrc
# Extraído de git-sidekick.sh para modularización (ROADMAP v2.0, Sesión 1)
# Requiere: lib/colors.sh (sourceado antes, para mensajes de status)
# =============================================================================
# Flujo: define defaults globales (DEV_BRANCH, WORKLOG_FILE, etc.) y parsea
# .git-sidekickrc/.env con case-insensitive. Se sourcea tras colors, antes del resto.

# --- Variables de configuración (defaults) ---
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

# --- Parser de .git-sidekickrc ---
# --- FUNCIÓN: load_config ---
# PROPÓSITO: cargar .git-sidekickrc y .env, normalizando claves a minúsculas.
# PARÁMETROS: (ninguno; lee $GIT_SIDEKICK_DIR/.git-sidekickrc y .env del cwd).
# RETORNA: 0 siempre; define vars globales (DEV_BRANCH, GIT_SIDEKICK_DIR, DRY_RUN...).
# POR QUÉ: .env sobre-escribe a .git-sidekickrc (overrides por entorno, convención 12-factor).
# NOTA: las claves se lower-casean para que Dev_Branch == dev_branch.
load_config() {
    local rc_file=".git-sidekickrc"
    if [ -f "$rc_file" ]; then
        echo -e "${CYAN}⚙️  Cargo config: ${rc_file}${NC}"
        local key value key_lower
        while IFS='=' read -r key value; do
            [ -z "$key" ] && continue
            case "$key" in \#*) continue ;; esac
            key="${key// /}"
            value="${value%%#*}"
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            key_lower=$(echo "$key" | tr '[:upper:]' '[:lower:]')
            # shellcheck disable=SC2034 # AUTO_STASH/AUTO_PUSH/CONFIRM_DESTRUCTIVE: vars de config, no usadas aún en el código
            case "$key_lower" in
                default_branch)       DEFAULT_BRANCH="$value"       ;;
                dev_branch)           DEV_BRANCH="$value"           ;;
                snapshot_prefix)      SNAPSHOT_PREFIX="$value"      ;;
                auto_stash)           AUTO_STASH="$value"           ;;
                auto_push)            AUTO_PUSH="$value"            ;;
                confirm_destructive) CONFIRM_DESTRUCTIVE="$value"   ;;
                worklog_file)         WORKLOG_FILE="$value"         ;;
                context_file)         CONTEXT_FILE="$value"         ;;
            esac
        done < "$rc_file"
    fi
}

# Cargar config inmediatamente al sourcear (equivalente al behavior original)
load_config
