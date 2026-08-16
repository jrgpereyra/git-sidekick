# AGENTS.md — Git-Sidekick

> **IMPORTANTE UX**: Este proyecto está pensado para **novatos**. Cada decisión de
> output debe pasar por el filtro: *"¿Un novato entendería esto sin ayuda?"*
> Si un mensaje es críptico → falla la regla.

## 🎯 Propósito
`git-sidekick.sh` es un **asistente universal de Git** (no depende de lenguaje
de proyecto). Orquesta `git` existente con un flujo: `start → trabajás → close`,
plus snapshots de rescate y merges protegidos.

## 📏 Convenciones de código

### Mensajería siempre usando helpers (`say_*`)
| Helper | Uso | Emoji |
|---|---|---|
| `say_success "msg"` | Operación completada | ✅ |
| `say_error "msg"` | Algo falló | ❌ |
| `say_warn "msg"` | Aviso / precaución | ⚠️ |
| `say_info "msg"` | Información contextual | ℹ️ |
| `say_tip "msg"` | Sugerencia accionable | 💡 |
| `say_progress "msg"` | Operación en curso | ⏳ |

**NUNCA** usar `echo -e "${RED}..."` inline ni dejar que `git` muestre errores
crípticos. Siempre envolver con `say_git_error "$err_out"`.

### Errores: "qué pasó + cómo arreglar"
```bash
# MAL:
echo -e "${RED}❌ Error.${NC}"

# BIEN:
say_error "No pude cambiar a la rama 'foo'."
say_tip "Las ramas que tenés:"
listar_ramas_disponibles
```

### Menus y labels coherentes
- El menú interactivo usa `1) INICIAR sesión (s)` etc.
- Los mensajes de onboarding/hints deben referirse a los **mismos labels**
  (`INICIAR sesión`, `CERRAR sesión`, `SNAPSHOT`), nunca a `gk start` como si
  fuera obvio. El novato ve números y atajos.

### Micro-hints después de cada comando
Cada comando que produce éxito **debe** incluir un `say_tip` con el siguiente
paso natural. Ej: `start` → "Cerrás con 'c' (opción 3)".

## 🧪 Testing
```bash
bats tests/core.bats      # suite completa (20+ tests)
./git-sidekick.sh --dry-run    # simular antes de un cambio grande
```
- Tests en `tests/core.bats`.
- `--dry-run` corta toda ejecución antes de prompts → ideal para safe-checks.
- `.git-sidekick-context` nunca debe commitearse (está en `.gitignore`).

## 🚀 Workflow de desarrollo
1. Editar `git-sidekick.sh` en rama `dev`.
2. Correr `bats tests/core.bats` → 100% verde.
3. Testear en un project real con `--dry-run` primero.
4. Commit a `dev`.
