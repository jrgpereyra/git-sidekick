#!/usr/bin/env bash
# =============================================================================
# lib/plugins.sh - Sistema base de plugins
# Extraído de git-sidekick.sh para modularización (ROADMAP v2.0, Sesión 4)
# Requiere: lib/colors.sh (para say_* y variables de color)
# =============================================================================

# --- Archivos/carpetas que identifican un tipo de proyecto ---
# Usados por plugin_detect() para decidir si hay un plugin aplicable.
PLUGIN_CONFIG_FILES=(
    "package.json"
    "composer.json"
    ".ddev/config.yaml"
    "astro.config.mjs"
    "astro.config.ts"
    "next.config.js"
    "next.config.mjs"
    "nuxt.config.ts"
    "svelte.config.js"
    "drupal"
    "docroot/sites/default/settings.php"
)

# --- Detección de plugins ---
# Devuelve 0 si existe algún archivo de configuración de proyecto conocido.
plugin_detect() {
    local file
    for file in "${PLUGIN_CONFIG_FILES[@]}"; do
        if [ -e "$file" ]; then
            return 0
        fi
    done
    return 1
}

# --- Setup de plugins (stub) ---
plugin_setup() {
    say_warn "Plugins no implementados aún."
    say_tip "Este hook se disparará cuando se añadan plugins en futuras sesiones."
    return 0
}

# --- Hook: antes de commitear (stub) ---
plugin_pre_commit() {
    say_warn "Plugin pre-commit no implementado."
    return 0
}

# --- Hook: después de merge (stub) ---
plugin_post_merge() {
    say_warn "Plugin post-merge no implementado."
    return 0
}
