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

@test "git-sidekickrc: dev_branch=develop reflejado en el menu" {
  echo "dev_branch=develop" > .git-sidekickrc
  git branch develop 2>/dev/null
  run bash -c "printf '8\n' | $GKS"
  echo "$output" | grep -q "ACTUALIZAR develop"
  echo "$output" | grep -q "PUBLICAR develop"
}

@test "git-sidekickrc: uppercase DEV_BRANCH también funciona" {
  echo "DEV_BRANCH=staging" > .git-sidekickrc
  run bash -c "printf '8\n' | $GKS"
  echo "$output" | grep -q "ACTUALIZAR staging"
}

@test "git-sidekickrc: espacios y comment inline se ignoran" {
  printf '  dev_branch = qa # rama de pruebas  \n' > .git-sidekickrc
  run bash -c "printf '8\n' | $GKS"
  echo "$output" | grep -q "ACTUALIZAR qa"
  ! grep -q "qa # rama" <<< "$output"
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

# ── FRIENDLY ERROR MESSAGES ─────────────────────────────────

@test "merge con rama inexistente: error amigable sin pathspec" {
  output=$(printf 'n\n' | "$GKS" merge main dev 1 2>&1 || true)
  echo "$output" | grep -q "❌"
  echo "$output" | grep -q "💡"
  echo "$output" | grep -q "📋 Ramas disponibles"
  echo "$output" | grep -q "no existe localmente"
  ! grep -q "pathspec" <<< "$output"
}

@test "merge con rama origen inexistente: también error amigable" {
  output=$(printf 'n\n' | "$GKS" merge nonexistent main 1 2>&1 || true)
  echo "$output" | grep -q "no existe localmente"
  echo "$output" | grep -q "📋 Ramas disponibles"
}

@test "snapshot: mensaje de éxito con emoji" {
  output=$("$GKS" snapshot 2>&1)
  echo "$output" | grep -q "✅.*Snapshot creado"
}

@test "snapshot con --dry-run no crea tags (mensajería SIMULACIÓN)" {
  output=$("$GKS" snapshot --dry-run 2>&1)
  echo "$output" | grep -q "SIMULACIÓN"
  ! grep -q "Snapshot creado: work" <<< "$output"
}
