#!/usr/bin/env bash
# =============================================================================
# lib/colors.sh - Definiciones de colores y helpers de mensajería
# Extraído de git-sidekick.sh para modularización (ROADMAP v2.0, Sesión 1)
# =============================================================================

# --- Colores para mensajes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Helpers de mensajería amigable (novatos) ---
# Estas funciones están disponibles globalmente tras sourcear este módulo.
say_success()  { echo -e "${GREEN}✅ $*${NC}"; }
say_error()    { echo -e "${RED}❌ $*${NC}"; }
say_warn()     { echo -e "${YELLOW}⚠️  $*${NC}"; }
say_info()     { echo -e "${CYAN}ℹ️  $*${NC}"; }
say_tip()      { echo -e "${BLUE}💡 $*${NC}"; }
say_progress() { echo -e "${YELLOW}⏳ $*...${NC}"; }
