#!/usr/bin/env bash
# =============================================================================
# lib/ddev.sh - Detección y comandos contextuales para DDEV
# Extraído de git-sidekick.sh para modularización (ROADMAP v2.0, Sesión 4)
# Requiere: lib/colors.sh (para say_* y variables de color)
# =============================================================================

# --- Detección de DDEV ---
# Devuelve 0 si el proyecto usa DDEV (existe .ddev/config.yaml).
ddev_detect() {
    if [ -f ".ddev/config.yaml" ]; then
        return 0
    fi
    return 1
}

# --- Snapshot de base de datos (stub) ---
ddev_snapshot() {
    say_warn "Snapshot DDEV no implementado."
    say_tip "Se integrará ddev snapshot / ddev seq en una futura sesión."
    return 0
}

# --- Restaurar base de datos (stub) ---
ddev_restore() {
    say_warn "Restore DDEV no implementado."
    say_tip "Se integrará ddev restore en una futura sesión."
    return 0
}
