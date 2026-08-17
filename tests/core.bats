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

# ── UX: ONBOARDING + DEV BRANCH CREATION ───────────────────

@test "gk init crea rama dev + onboarding coherente al menu" {
  local fresh_dir init_output
  fresh_dir="$(mktemp -d /tmp/bats-fresh-XXXXXX)"
  init_output=$( (cd "$fresh_dir" && printf '\n\n\n1\n' | "$GKS" 2>&1) || true )
  # La rama dev debe existir
  run git --git-dir="$fresh_dir/.git" show-ref --verify --quiet refs/heads/dev
  [ $status -eq 0 ]
  # Onboarding con labels EXACTOS del menú interactivo
  echo "$init_output" | grep -q "Primeros pasos"
  echo "$init_output" | grep -q "1) INICIAR sesión"
  echo "$init_output" | grep -q "3) CERRAR sesión"
  echo "$init_output" | grep -q "gk --dry-run"
  rm -rf "$fresh_dir"
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

# ── UX-3: MENU STATE + MICRO-HINTS ─────────────────────────

@test "menu muestra 'Sesión: inactiva' cuando no hay contexto" {
  output=$(printf "8\n" | "$GKS" 2>&1 || true)
  echo "$output" | grep -q "Sesión: inactiva"
  echo "$output" | grep -q "usá 's'"
}

@test "menu muestra 'Sesión: activa' cuando hay contexto guardado" {
  printf "rama=main\nfecha_inicio=2026-01-01_00-00\naccion=inicio\ntag_inicio=work/test\n" > .git-sidekick-context
  output=$(printf "8\n" | "$GKS" 2>&1 || true)
  echo "$output" | grep -q "Sesión: activa"
  echo "$output" | grep -q "en \[main\]"
}

@test "start_session incluye micro-hint de guidance" {
  output=$(printf '1\n1\ntest\ntest\nt8\n' | "$GKS" 2>&1 || true)
  echo "$output" | grep -q "SESIÓN INICIADA"
  echo "$output" | grep -q "💡"
  echo "$output" | grep -q "opción 3"
}

@test "start_session: Enter defaultea a dev (marca reco" {
  git branch dev
  output=$(printf '1\n\n\n8\n' | "$GKS" 2>&1 || true)
  echo "$output" | grep -q "🔹"
  echo "$output" | grep -q "SESIÓN INICIADA en \[dev\]"
}

@test "start_session: sin dev, Enter defaultea al primer branch" {
  output=$(printf '1\n\n\n8\n' | "$GKS" 2>&1 || true)
  ! echo "$output" | grep -q "🔹"
  echo "$output" | grep -q "SESIÓN INICIADA en \[main\]"
}

@test "init: check_git no duplica el mensaje con echo previo" {
  local fresh_dir init_output
  fresh_dir="$(mktemp -d /tmp/bats-fresh-XXXXXX)"
  init_output=$( (cd "$fresh_dir" && printf '\n\n\n1\n' | "$GKS" 2>&1) || true )
  ! echo "$init_output" | grep -q "❌ No encontré un repositorio Git"
  [ -d "$fresh_dir/.git" ]
  rm -rf "$fresh_dir"
}

@test "init: se queda en la rama dev despues de crearla" {
  local fresh_dir
  fresh_dir="$(mktemp -d /tmp/bats-fresh-XXXXXX)"
  (cd "$fresh_dir" && printf '\n\n\n1\n' | "$GKS" >/dev/null 2>&1 || true)
  cd "$fresh_dir"
  [ "$(git rev-parse --abbrev-ref HEAD)" = "dev" ]
  rm -rf "$fresh_dir"
}
