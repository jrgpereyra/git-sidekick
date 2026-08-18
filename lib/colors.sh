#!/usr/bin/env bash
# =============================================================================
# lib/colors.sh - Definiciones de colores y helpers de mensajería
# Extraído de git-sidekick.sh para modularización (ROADMAP v2.0, Sesión 1)
# =============================================================================
# Flujo: base del sourceo. Define variables de color (RED/GREEN/YELLOW/BLUE/CYAN/NC)
# y los helpers say_* de mensajería. Se sourcea PRIMERO, antes que el resto de módulos.

# --- Colores para mensajes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Helpers de mensajería amigable (novatos) ---
# Estas funciones están disponibles globalmente tras sourcear este módulo.
# --- FUNCIÓN: say_success ---
# PROPÓSITO: imprimir un mensaje de éxito (texto en color verde).
# PARÁMETROS: $* = texto del mensaje (único arg pasado a echo -e).
# RETORNA: 0 (siempre); escribe a stdout.
# POR QUÉ: $NC resetea el color justo después del mensaje (scope aislado).
say_success()  { echo -e "${GREEN}✅ $*${NC}"; }
# --- FUNCIÓN: say_error ---
# PROPÓSITO: imprimir un error amigable (texto en color rojo).
# PARÁMETROS: $* = texto del mensaje.
# RETORNA: 0 (siempre); escribe a stdout.
# POR QUÉ: reemplaza a dejar que git muestre errores crípticos (ver AGENTS.md).
say_error()    { echo -e "${RED}❌ $*${NC}"; }
# --- FUNCIÓN: say_warn ---
# PROPÓSITO: imprimir un aviso (color amarillo) que no interrumpe el fluidad.
# PARÁMETROS: $* = texto del mensaje.
# RETORNA: 0; escribe a stdout.
# POR QUÉ: amarillo para precauciones no bloqueantes (ej: "modo simulación").
say_warn()     { echo -e "${YELLOW}⚠️  $*${NC}"; }
# --- FUNCIÓN: say_info ---
# PROPÓSITO: imprimir información neutral (color cian).
# PARÁMETROS: $* = texto del mensaje.
# RETORNA: 0; escribe a stdout.
# POR QUÉ: cian para datos de contexto (estado, tags) sin carga emocional.
say_info()     { echo -e "${CYAN}ℹ️  $*${NC}"; }
# --- FUNCIÓN: say_tip ---
# PROPÓSITO: imprimir una sugerencia accionable (color azul).
# PARÁMETROS: $* = texto del tip.
# RETORNA: 0; escribe a stdout.
# POR QUÉ: azul indica el siguiente paso natural tras un comando.
say_tip()      { echo -e "${BLUE}💡 $*${NC}"; }
# --- FUNCIÓN: say_progress ---
# PROPÓSITO: imprimir que una operación está en curso (color amarillo).
# PARÁMETROS: $* = texto de la operación (se le anexa "..." al final).
# RETORNA: 0; escribe a stdout.
# POR QUÉ: el sufijo "..." comunica que el proceso sigue activo.
say_progress() { echo -e "${YELLOW}⏳ $*...${NC}"; }
