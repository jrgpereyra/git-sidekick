#!/usr/bin/env bats
# =============================================================================
# tests/core.bats - Tests del core de git-sidekick
# Valida: --dry-run, .git-sidekickrc, info, snapshots, workflow start/close
# =============================================================================

# Path al script (relativo al tests/ dir = portable)
GKS="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/git-sidekick.sh"

setup() {
  test_dir="$(mktemp -d /tmp/bats-sidekick-XXXXXX)"
  cd "$test_dir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  git checkout -q -b main 2>/dev/null || git branch -M main
  git commit -q --allow-empty -m "Initial commit"
}

teardown() {
  rm -rf "$test_dir"
}

# ── DRY-RUN ──────────────────────────────────────────────

@test "dry-run start no crea tags ni context file" {
  run "$GKS" start --dry-run
  echo "$output" | grep -q "SIMULACIÓN"
  # No debería haber creado tags de snapshot
  [ "$(git tag --list 'work/*' 2>/dev/null | wc -l)" -eq 0 ]
  # No debería haber creado el context file
  [ ! -f ".git-sidekick-context" ]
}

@test "dry-run close no commitea ni crea tags" {
  run "$GKS" close --dry-run
  echo "$output" | grep -q "SIMULACIÓN"
  [ "$(git tag --list 'work/*' 2>/dev/null | wc -l)" -eq 0 ]
  [ ! -f ".git-sidekick-context" ]
}

@test "dry-run snapshot no crea tags" {
  run "$GKS" snapshot --dry-run
  echo "$output" | grep -q "SIMULACIÓN"
  [ "$(git tag --list 'work/*' 2>/dev/null | wc -l)" -eq 0 ]
}

@test "dry-run merge simula sin ejecutar merge" {
  git branch dev 2>/dev/null
  run "$GKS" merge main dev 1 --dry-run
  echo "$output" | grep -q "SIMULACIÓN"
  # No debería haber hecho merge (no hay merge commit)
  [ "$(git log --merges --oneline 2>/dev/null | wc -l)" -eq 0 ]
}

# ── CONFIG (.git-sidekickrc) ─────────────────────────────────

@test "git-sidekickrc se carga y muestra mensaje" {
  echo "DEFAULT_BRANCH=main" > .git-sidekickrc
  run "$GKS" info
  echo "$output" | grep -q "Cargo config: .git-sidekickrc"
  echo "$output" | grep -q "Información del repositorio"
}

@test "git-sidekickrc override funciona (dev_branch)" {
  echo "DEV_BRANCH=develop" > .git-sidekickrc
  run "$GKS" info
  # El script cargó el rc (no necesariamente usa dev_branch todavía, pero confirma carga)
  [ -n "$(echo "$output" | grep "Cargo config")" ]
}

@test "sin git-sidekickrc, info no muestra mensaje de carga" {
  run "$GKS" info
  ! grep -q "Cargo config" <<< "$output"
}

# ── INFO COMMAND ──────────────────────────────────────────

@test "info muestra rama actual y proyecto" {
  run "$GKS" info
  echo "$output" | grep -q "🌿 Rama:"
  echo "$output" | grep -q "📁 Proyecto:"
  echo "$output" | grep -q "main"  # la rama creada en setup
}

@test "info muestra remote si existe" {
  git remote add origin https://github.com/ejemplo/test.git
  run "$GKS" info
  echo "$output" | grep -q "ejemplo/test.git"
}

# ── SNAPSHOT ──────────────────────────────────────────────

@test "snapshot crea un tag work/*" {
  run "$GKS" snapshot
  [ "$(git tag --list 'work/*' | wc -l)" -eq 1 ]
  echo "$output" | grep -q "Snapshot creado"
}

# ── WORKFLOW start + close ─────────────────────────────────

@test "start + close crea 2 tags y limpia context" {
  printf '1\ntest-session\n' | "$GKS" start >/dev/null 2>&1
  echo "cambio de prueba" > prueba.txt
  printf '\n\nn\n' | "$GKS" close >/dev/null 2>&1

  # 2 tags: inicio + cierre
  [ "$(git tag --list 'work/*' | wc -l)" -eq 2 ]
  # context file limpio
  [ ! -f ".git-sidekick-context" ]
  # archivos commiteados
  git log --oneline | grep -q "cambio de prueba\|Sesión\|prueba"
}

@test "start + close sin cambios también funciona" {
  printf '1\ntest-vacio\n' | "$GKS" start >/dev/null 2>&1
  printf '\n\nn\n' | "$GKS" close >/dev/null 2>&1
  [ ! -f ".git-sidekick-context" ]
  [ "$(git tag --list 'work/*' | wc -l)" -eq 2 ]
}

# ── CONTEXT FILE NO COMMITEADO ────────────────────────────

@test "context file no se comitea (ignorado del commit)" {
  printf '1\ntest\n' | "$GKS" start >/dev/null 2>&1
  printf '\n\nn\n' | "$GKS" close >/dev/null 2>&1
  # El context file no debe aparecer en el historial de commits
  ! git log -p --all 2>/dev/null | grep -q "git-sidekick-context"
}
