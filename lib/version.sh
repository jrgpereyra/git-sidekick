#!/usr/bin/env bash
# =============================================================================
# lib/version.sh - Versión centralizada de git-sidekick
# Requiere: (ninguno)
# =============================================================================
# Flujo: carga VERSION desde la raíz del proyecto y expone SIDEKICK_VERSION.
# Si el archivo no existe o está vacío, conserva un fallback seguro.

SIDEKICK_VERSION="0.0.0-dev"

# --- FUNCIÓN: cargar_version ---
# PROPÓSITO: leer la versión única desde VERSION en la raíz del repo.
# PARÁMETROS: (ninguno).
# RETORNA: 0 (siempre); define/actualiza SIDEKICK_VERSION.
# POR QUÉ: evita versiones hardcodeadas y mantiene una sola fuente de verdad.
# NOTA: tolera espacios, saltos de línea y CRLF; si falla, usa el fallback.
cargar_version() {
    local version_file version
    version_file="${SIDEKICK_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)}/VERSION"

    if [ -r "$version_file" ]; then
        IFS= read -r version < "$version_file" || version=""
        version=$(printf '%s' "$version" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$version" ]; then
            SIDEKICK_VERSION="$version"
        fi
    fi
}

# --- FUNCIÓN: mostrar_version ---
# PROPÓSITO: imprimir la versión actual del script.
# PARÁMETROS: (ninguno).
# RETORNA: 0.
# POR QUÉ: permite consultar la versión sin abrir el menú interactivo.
mostrar_version() {
    printf 'git-sidekick v%s\n' "$SIDEKICK_VERSION"
}

cargar_version
