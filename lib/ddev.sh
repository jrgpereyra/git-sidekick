#!/usr/bin/env bash
# =============================================================================
# lib/ddev.sh - Detección y comandos contextuales para DDEV
# Extraído de git-sidekick.sh para modularización (ROADMAP v2.0, Sesión 4)
# Requiere: lib/colors.sh (para say_* y variables de color)
# =============================================================================
# Flujo: integración DDEV. ddev_detect() localiza proyectos DDEV y los hooks
# (snapshot/restore) son stubs para snapshots de base de datos futuros.

# --- Detección de DDEV ---
# --- FUNCIÓN: ddev_detect ---
# PROPÓSITO: detectar si el proyecto usa DDEV (.ddev/config.yaml en cwd o padre).
# PARÁMETROS: (ninguno).
# RETORNA: 0 si usa DDEV, 1 si no.
# POR QUÉ: subir a padres soporta proyectos DDEV en subcarpetas.
ddev_detect() {
    if [ -f ".ddev/config.yaml" ]; then
        return 0
    fi
    return 1
}

# --- Snapshot de base de datos (stub) ---
# --- FUNCIÓN: ddev_snapshot ---
# PROPÓSITO: snapshot de base de datos vía DDEV (stub, extensión futura).
# PARÁMETROS: (ninguno por ahora).
# RETORNA: 0.
# POR QUÉ: stub → no ejecuta nada; punto de extensión para snapshots de DB.
# NOTA: stubs retornan 0 para no interrumpir el workflow de sesiones.
ddev_snapshot() {
    say_warn "Snapshot DDEV no implementado."
    say_tip "Se integrará ddev snapshot / ddev seq en una futura sesión."
    return 0
}

# --- Restaurar base de datos (stub) ---
# --- FUNCIÓN: ddev_restore ---
# PROPÓSITO: restaurar base de datos vía DDEV (stub, extensión futura).
# PARÁMETROS: (ninguno por ahora).
# RETORNA: 0.
# POR QUÉ: stub → punto de extensión; el snapshot previo lo crea crear_snapshot.
ddev_restore() {
    say_warn "Restore DDEV no implementado."
    say_tip "Se integrará ddev restore en una futura sesión."
    return 0
}
