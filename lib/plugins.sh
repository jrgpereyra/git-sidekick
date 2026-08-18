#!/usr/bin/env bash
# =============================================================================
# lib/plugins.sh - Sistema base de plugins
# Extraído de git-sidekick.sh para modularización (ROADMAP v2.0, Sesión 4)
# Requiere: lib/colors.sh (para say_* y variables de color)
# =============================================================================
# Flujo: puntos de extensión del sistema. plugin_detect() detecta plugins y los
# hooks (setup/pre_commit/post_merge) son stubs para extensiones futuras.

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
# --- FUNCIÓN: plugin_detect ---
# PROPÓSITO: detectar archivos de configuración de plugins conocidos en el proyecto.
# PARÁMETROS: (ninguno; escanea cwd y archivos CONFIGURABLE_*).
# RETORNA: 0 si existe alguno (imprime cuál), 1 si ninguno.
# POR QUÉ: los hooks plugin sólo aportan valor si el proyecto usa plugins.
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
# --- FUNCIÓN: plugin_setup ---
# PROPÓSITO: hook de setup de plugins (stub, extensión futura).
# PARÁMETROS: (ninguno por ahora).
# RETORNA: 0.
# POR QUÉ: stub → no hace nada; punto de extensión para plugins reales.
# NOTA: los stubs retornan 0 para que el workflow principal no se rompa sin plugins.
plugin_setup() {
    say_warn "Plugins no implementados aún."
    say_tip "Este hook se disparará cuando se añadan plugins en futuras sesiones."
    return 0
}

# --- Hook: antes de commitear (stub) ---
# --- FUNCIÓN: plugin_pre_commit ---
# PROPÓSITO: hook antes de commitear (stub: lint/validaciones futuras).
# PARÁMETROS: (ninguno por ahora).
# RETORNA: 0.
# POR QUÉ: stub → permite encadenar checks sin tocar la lógica de commit actual.
plugin_pre_commit() {
    say_warn "Plugin pre-commit no implementado."
    return 0
}

# --- Hook: después de merge (stub) ---
# --- FUNCIÓN: plugin_post_merge ---
# PROPÓSITO: hook después de merge (stub: migraciones/cacheo futuro).
# PARÁMETROS: (ninguno por ahora).
# RETORNA: 0.
# POR QUÉ: stub → punto de extensión; el merge ya terminó, aquí se post-procesa.
plugin_post_merge() {
    say_warn "Plugin post-merge no implementado."
    return 0
}
