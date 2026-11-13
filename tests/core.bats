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

crear_dev_adelantada() {
  git checkout -q -b dev
  echo "cambio dev" > dev.txt
  git add dev.txt
  git commit -q -m "cambio en dev"
  git checkout -q main
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

@test "menu opción 3 publica dev en main (no dev en dev)" {
  # Preparar un commit exclusivo de dev
  git checkout -q -b dev
  echo "cambio dev" > dev.txt
  git add dev.txt
  git commit -q -m "cambio en dev"
  git checkout -q main
  # y un commit exclusivo de main → el merge no es fast-forward
  echo "cambio main" > main.txt
  git add main.txt
  git commit -q -m "cambio en main"

  # 8 → confirmar merge → no push → volver a la rama original → salir
  output=$(printf '3\n\nn\n\n5\n' | "$GKS" 2>&1 || true)

  echo "$output" | grep -q "(dev → main)"
  echo "$output" | grep -q "Merge dev → main completado"
  # main debe haber recibido el archivo creado en dev
  git cat-file -e main:dev.txt
  # y debe existir un merge commit en main
  [ "$(git log --merges --oneline main | wc -l)" -ge 1 ]
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
  run bash -c "printf '4\n0\n5\n' | $GKS"
  echo "$output" | grep -q "Actualizar develop"
  echo "$output" | grep -q "PUBLICAR develop"
}

@test "git-sidekickrc: uppercase DEV_BRANCH también funciona" {
  echo "DEV_BRANCH=staging" > .git-sidekickrc
  run bash -c "printf '4\n0\n5\n' | $GKS"
  echo "$output" | grep -q "Actualizar staging"
}

@test "git-sidekickrc: espacios y comment inline se ignoran" {
  printf '  dev_branch = qa # rama de pruebas  \n' > .git-sidekickrc
  run bash -c "printf '4\n0\n5\n' | $GKS"
  echo "$output" | grep -q "Actualizar qa"
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
  printf '\n\n\nn\n' | "$GKS" close >/dev/null 2>&1

  # 2 tags: inicio + cierre
  [ "$(git tag --list 'work/*' | wc -l)" -eq 2 ]
  # context file limpio
  [ ! -f ".git-sidekick-context" ]
  # archivos commiteados
  git log --oneline | grep -q "cambio de prueba\|Sesión\|prueba"
}

@test "start + close sin cambios también funciona" {
  printf '1\ntest-vacio\n' | "$GKS" start >/dev/null 2>&1
  printf '\nn\n' | "$GKS" close >/dev/null 2>&1
  [ ! -f ".git-sidekick-context" ]
  [ "$(git tag --list 'work/*' | wc -l)" -eq 2 ]
}

# ── CONTEXT FILE NO COMMITEADO ────────────────────────────

@test "context file no se comitea (ignorado del commit)" {
  printf '1\ntest\n' | "$GKS" start >/dev/null 2>&1
  printf '\nn\n' | "$GKS" close >/dev/null 2>&1
  # El context file no debe aparecer en el historial de commits
  ! git log -p --all 2>/dev/null | grep -q "git-sidekick-context"
}

# ── UX: ONBOARDING + DEV BRANCH CREATION ───────────────────

@test "gk init crea rama dev + onboarding coherente al menu" {
  local fresh_dir init_output
  fresh_dir="$(mktemp -d /tmp/bats-fresh-XXXXXX)"
  init_output=$( (cd "$fresh_dir" && printf '\n\n\n1\n5\n' | "$GKS" 2>&1) || true )
  # La rama dev debe existir
  run git --git-dir="$fresh_dir/.git" show-ref --verify --quiet refs/heads/dev
  [ $status -eq 0 ]
  # Onboarding con labels EXACTOS del menú interactivo
  echo "$init_output" | grep -q "Primeros pasos"
  echo "$init_output" | grep -q "1) INICIAR sesión"
  echo "$init_output" | grep -q "2) CERRAR sesión"
  echo "$init_output" | grep -q "guardar cambios + snapshot"
  echo "$init_output" | grep -q "crear snapshot"
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
  output=$(printf "11\n" | "$GKS" 2>&1 || true)
  echo "$output" | grep -q "Sesión: inactiva"
  echo "$output" | grep -q "usá 's'"
}

@test "menu muestra 'Sesión: activa' cuando hay contexto guardado" {
  printf "rama=main\nfecha_inicio=2026-01-01_00-00\naccion=inicio\ntag_inicio=work/test\n" > .git-sidekick-context
  output=$(printf "11\n" | "$GKS" 2>&1 || true)
  echo "$output" | grep -q "Sesión: activa"
  echo "$output" | grep -q "en \[main\]"
}

@test "start_session incluye micro-hint de guidance" {
  output=$(printf '1\n1\ntest\n5\n' | "$GKS" 2>&1 || true)
  echo "$output" | grep -q "SESIÓN INICIADA"
  echo "$output" | grep -q "💡"
  echo "$output" | grep -q "opción 2"
}

@test "start_session: Enter defaultea a dev (marca reco" {
  git branch dev
  output=$(printf '1\n\n\n5\n' | "$GKS" 2>&1 || true)
  echo "$output" | grep -q "🔹"
  echo "$output" | grep -q "SESIÓN INICIADA en \[dev\]"
}

@test "start_session: sin dev, Enter defaultea al primer branch" {
  output=$(printf '1\n\n\n5\n' | "$GKS" 2>&1 || true)
  ! echo "$output" | grep -q "🔹"
  echo "$output" | grep -q "SESIÓN INICIADA en \[main\]"
}

@test "init: check_git no duplica el mensaje con echo previo" {
  local fresh_dir init_output
  fresh_dir="$(mktemp -d /tmp/bats-fresh-XXXXXX)"
  init_output=$( (cd "$fresh_dir" && printf '\n\n\n1\n5\n' | "$GKS" 2>&1) || true )
  ! echo "$init_output" | grep -q "❌ No encontré un repositorio Git"
  [ -d "$fresh_dir/.git" ]
  rm -rf "$fresh_dir"
}

@test "init: se queda en la rama dev despues de crearla" {
  local fresh_dir
  fresh_dir="$(mktemp -d /tmp/bats-fresh-XXXXXX)"
  (cd "$fresh_dir" && printf '\n\n\n1\n5\n' | "$GKS" >/dev/null 2>&1 || true)
  cd "$fresh_dir"
  [ "$(git rev-parse --abbrev-ref HEAD)" = "dev" ]
  rm -rf "$fresh_dir"
}

# ── MERGE ENDURECIDO ────────────────────────────────────────

@test "merge aborta si el destino está detrás de su remoto" {
  remote_dir="$(mktemp -d /tmp/bats-remote-XXXXXX)"
  git init -q --bare "$remote_dir"
  git remote add origin "$remote_dir"
  git push -q -u origin main

  git checkout -q -b dev
  echo "dev" > dev.txt
  git add dev.txt
  git commit -q -m "commit dev"

  # Avanzar main en el remoto desde otro clon
  other_dir="$(mktemp -d /tmp/bats-other-XXXXXX)"
  git clone -q -b main "$remote_dir" "$other_dir"
  git -C "$other_dir" config user.email "other@test.com"
  git -C "$other_dir" config user.name "Other"
  echo "remoto" > "$other_dir/remoto.txt"
  git -C "$other_dir" add remoto.txt
  git -C "$other_dir" commit -q -m "avance remoto"
  git -C "$other_dir" push -q origin main

  git checkout -q main
  before=$(git rev-parse main)

  # dev no tiene upstream (Enter para continuar); main está behind → aborta
  run bash -c "printf '\n' | '$GKS' merge dev main 2"

  [ "$status" -ne 0 ]
  echo "$output" | grep -q "detrás"
  [ "$(git rev-parse main)" = "$before" ]
  [ ! -f dev.txt ]

  rm -rf "$remote_dir" "$other_dir"
}

@test "merge con árbol sucio guarda y restaura tracked + untracked" {
  git checkout -q -b dev
  echo "dev" > dev.txt
  git add dev.txt
  git commit -q -m "commit dev"
  git checkout -q main
  echo "main" > main.txt
  git add main.txt
  git commit -q -m "commit main"

  echo "mod local" >> main.txt
  echo "nuevo local" > local.txt

  run bash -c "printf '\nn\n\n' | '$GKS' merge dev main 2"

  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Merge dev → main completado"
  echo "$output" | grep -q "¡Todo listo! Tus cambios pendientes están de vuelta. Podés seguir trabajando."
  ! echo "$output" | grep -q "fueron restaurados"
  [ -f local.txt ]
  grep -q "nuevo local" local.txt
  grep -q "mod local" main.txt
  [ -z "$(git stash list)" ]
}

@test "merge con conflicto: aborta, vuelve a la rama original y restaura stash" {
  git checkout -q -b dev
  echo "version dev" > conflicto.txt
  git add conflicto.txt
  git commit -q -m "dev conflicto"
  git checkout -q main
  echo "version main" > conflicto.txt
  git add conflicto.txt
  git commit -q -m "main conflicto"

  echo "local" > local.txt

  run bash -c "printf '\n' | '$GKS' merge dev main 2"

  [ "$status" -ne 0 ]
  echo "$output" | grep -q "conflict"
  [ "$(git rev-parse --abbrev-ref HEAD)" = "main" ]
  [ ! -f .git/MERGE_HEAD ]
  [ -f local.txt ]
  grep -q "local" local.txt
  [ -z "$(git stash list)" ]
  grep -q "version main" conflicto.txt
}

@test "merge rechaza origen y destino iguales" {
  run "$GKS" merge main main 2

  [ "$status" -ne 0 ]
  echo "$output" | grep -q "misma rama"
}

@test "merge con AUTO_STASH=false aborta ante árbol sucio sin tocar nada" {
  git checkout -q -b dev
  echo "dev" > dev.txt
  git add dev.txt
  git commit -q -m "commit dev"
  git checkout -q main

  echo "AUTO_STASH=false" > .git-sidekickrc
  echo "local" > local.txt

  run bash -c "printf '\n' | '$GKS' merge dev main 2"

  [ "$status" -ne 0 ]
  echo "$output" | grep -q "AUTO_STASH=false"
  [ ! -f dev.txt ]
  [ -z "$(git stash list)" ]
}

@test "merge aborta si el destino está abierto en otra worktree" {
  git checkout -q -b dev
  wt_base="$(mktemp -d /tmp/bats-wt-XXXXXX)"
  wt="$wt_base/main-wt"
  git worktree add -q "$wt" main

  run bash -c "printf '\n\nn\n\n' | '$GKS' merge dev main 2"

  [ "$status" -ne 0 ]
  echo "$output" | grep -q "otra worktree"

  git worktree remove --force "$wt" 2>/dev/null || true
  rm -rf "$wt_base"
}

@test "merge conserva el merge local si el push falla" {
  git checkout -q -b dev
  echo "dev" > dev.txt
  git add dev.txt
  git commit -q -m "commit dev"
  git checkout -q main
  echo "main" > main.txt
  git add main.txt
  git commit -q -m "commit main"

  git remote add origin "$test_dir/remoto-inexistente.git"

  # fetch falla → continuar; confirmar; push (Enter, falla); volver
  run bash -c "printf '\n\n\n\n' | '$GKS' merge dev main 2"

  [ "$status" -ne 0 ]
  echo "$output" | grep -q "quedó guardado localmente"
  [ "$(git log --merges --oneline main | wc -l)" -ge 1 ]
  git cat-file -e main:dev.txt
}

@test "merge advierte si una rama no tiene upstream y permite continuar" {
  remote_dir="$(mktemp -d /tmp/bats-remote-XXXXXX)"
  git init -q --bare "$remote_dir"
  git remote add origin "$remote_dir"
  git push -q -u origin main

  git checkout -q -b dev
  echo "dev" > dev.txt
  git add dev.txt
  git commit -q -m "commit dev"
  git checkout -q main

  # dev sin upstream → Enter para continuar; confirmar; no push; volver
  run bash -c "printf '\n\nn\n\n' | '$GKS' merge dev main 2"

  [ "$status" -eq 0 ]
  echo "$output" | grep -q "no tiene seguimiento remoto"
  echo "$output" | grep -q "Merge dev → main completado"

  rm -rf "$remote_dir"
}

@test "menú principal muestra las 5 opciones refactorizadas" {
  output=$(printf '5\n' | "$GKS" 2>&1 || true)
  echo "$output" | grep -q "1) INICIAR sesión"
  echo "$output" | grep -q "2) CERRAR sesión"
  echo "$output" | grep -q "3) PUBLICAR dev a main"
  echo "$output" | grep -q "4) EXTRAS / HERRAMIENTAS"
  echo "$output" | grep -q "5) SALIR"
  echo "$output" | grep -q "gk start"
  echo "$output" | grep -q "gk close"
  echo "$output" | grep -q "gk merge dev main 2"
  local version
  version=$(cat "$(dirname "$GKS")/VERSION")
  echo "$output" | grep -q "git-sidekick v${version}"
  version_output=$("$GKS" --version 2>&1 || true)
  echo "$version_output" | grep -q "git-sidekick v${version}"
  ! echo "$output" | grep -q "Opción (1-11)"
  ! echo "$output" | grep -q "\[nivel"
}

@test "submenú Extras abre con 4 y vuelve al menú principal con 0" {
  output=$(printf '4\n2\n0\n5\n' | "$GKS" 2>&1 || true)
  echo "$output" | grep -q "EXTRAS / HERRAMIENTAS"
  echo "$output" | grep -q "1) Ver estado"
  echo "$output" | grep -q "2) Ver info completa"
  echo "$output" | grep -q "3) Restaurar snapshot"
  echo "$output" | grep -q "4) Crear snapshot"
  echo "$output" | grep -q "Actualizar dev desde main"
  echo "$output" | grep -q "Fusionar ramas manualmente"
  echo "$output" | grep -q "gk status"
  echo "$output" | grep -q "gk info"
  echo "$output" | grep -q "gk restore"
  echo "$output" | grep -q "gk snapshot"
  echo "$output" | grep -q "gk clean"
  echo "$output" | grep -q "gk merge main dev 1"
  echo "$output" | grep -q "gk merge <origen> <destino> <1|2>"
  echo "$output" | grep -q "gk help"
  echo "$output" | grep -q "Información del repositorio"
  echo "$output" | grep -q "SALIR"
  ! echo "$output" | grep -q "\[nivel"
}

@test "ayuda unifica terminología snapshot y quita jerga de rescate" {
  output=$("$GKS" help 2>&1 || true)
  echo "$output" | grep -q "Crear un snapshot"
  echo "$output" | grep -q "Restaurar un snapshot"
  echo "$output" | grep -q "Limpiar snapshots viejos"
  echo "$output" | grep -q "1 = simple · 2 = estricto"
  ! echo "$output" | grep -q "Rescate rápido"
}

# ── PUBLICACIONES PENDIENTES (UX) ───────────────────────────

@test "menú avisa cuando dev tiene commits sin publicar" {
  crear_dev_adelantada
  output=$(printf '5\n' | "$GKS" 2>&1 || true)
  echo "$output" | grep -q "sin publicar en main"
  echo "$output" | grep -q "1 cambio(s)"
  echo "$output" | grep -q "opción 3"
}

@test "menú no avisa cuando dev y main están al día" {
  git branch dev
  output=$(printf '5\n' | "$GKS" 2>&1 || true)
  ! echo "$output" | grep -q "sin publicar"
}

@test "menú no falla si no existe la rama dev" {
  output=$(printf '5\n' | "$GKS" 2>&1 || true)
  echo "$output" | grep -q "1) INICIAR sesión"
  ! echo "$output" | grep -q "sin publicar"
  ! grep -qi "fatal:" <<< "$output"
}

@test "alerta respeta DEV_BRANCH configurada" {
  echo "dev_branch=develop" > .git-sidekickrc
  git checkout -q -b develop
  echo "cambio develop" > develop.txt
  git add develop.txt
  git commit -q -m "cambio en develop"
  git checkout -q main

  output=$(printf '5\n' | "$GKS" 2>&1 || true)
  echo "$output" | grep -q "en develop sin publicar en main"
  echo "$output" | grep -q "PUBLICAR develop a main"
}

@test "close recuerda publicar cuando la sesión quedó en dev" {
  git checkout -q -b dev
  echo "cambio dev" > dev.txt
  git add dev.txt
  git commit -q -m "cambio en dev"

  output=$(printf '\nn\n' | "$GKS" close 2>&1 || true)
  echo "$output" | grep -q "Tus cambios quedaron en dev"
  echo "$output" | grep -q "sin publicar en main"
  echo "$output" | grep -q "opción 3 (PUBLICAR dev a main)"
}

@test "close no recuerda publicar si no hay pendientes" {
  output=$(printf '\nn\n' | "$GKS" close 2>&1 || true)
  ! echo "$output" | grep -q "sin publicar"
}

@test "close desde otra rama no dice que los cambios quedaron en dev" {
  crear_dev_adelantada
  output=$(printf '\nn\n' | "$GKS" close 2>&1 || true)
  echo "$output" | grep -q "Hay 1 cambio(s) en dev sin publicar en main"
  ! echo "$output" | grep -q "Tus cambios quedaron en dev"
}

# ── MENÚ PASIVO Y CIERRE NO COERCITIVO ──────────────────────

@test "menú con cambios muestra resumen y permite abrir Extras sin commit" {
  echo "pendiente" > pendiente.txt

  output=$(printf '4\n0\n5\n' | "$GKS" 2>&1 || true)

  echo "$output" | grep -q "archivo(s) con cambios sin guardar"
  echo "$output" | grep -q "pendiente.txt (Nuevo — archivo recién creado)"
  echo "$output" | grep -Fq "[2] para cerrar sesión · [4] para ver detalle."
  ! grep -Fq "Para guardarlos, elegí" <<< "$output"
  echo "$output" | grep -q "EXTRAS / HERRAMIENTAS"
  ! echo "$output" | grep -q "Mensaje de commit"
  [ -n "$(git status --porcelain pendiente.txt)" ]
}

@test "menú con cambios permite salir sin commitear" {
  echo "pendiente" > pendiente.txt
  before=$(git rev-parse HEAD)

  output=$(printf '5\n' | "$GKS" 2>&1 || true)

  echo "$output" | grep -q "archivo(s) con cambios sin guardar"
  [ "$(git rev-parse HEAD)" = "$before" ]
  [ -n "$(git status --porcelain pendiente.txt)" ]
}

@test "close con cambios permite cancelar y volver al menú" {
  echo "pendiente" > pendiente.txt
  before=$(git rev-parse HEAD)

  output=$(printf '2\n4\n5\n' | "$GKS" 2>&1 || true)

  echo "$output" | grep -q "Vas a guardar 1 archivo(s) con cambios"
  echo "$output" | grep -q "No se guardó nada"
  [ "$(git rev-parse HEAD)" = "$before" ]
  [ -n "$(git status --porcelain pendiente.txt)" ]
}

@test "close sin cambios no pide mensaje de commit" {
  output=$(printf '\nn\n' | "$GKS" close 2>&1 || true)

  echo "$output" | grep -q "No hay cambios para guardar"
  ! echo "$output" | grep -q "Mensaje de commit"
}

@test "close con cambios pide confirmación y mensaje de commit" {
  echo "pendiente" > pendiente.txt

  output=$(printf '\nprueba commit\n\nn\n' | "$GKS" close 2>&1 || true)

  echo "$output" | grep -q "Vas a guardar 1 archivo(s) con cambios"
  git log --oneline | grep -q "prueba commit"
  [ -z "$(git status --porcelain pendiente.txt)" ]
}

# ── STATUS CONVERSACIONAL ───────────────────────────────────

@test "status muestra la estructura conversacional completa" {
  run "$GKS" status
  [ "$status" -eq 0 ]
  echo "$output" | grep -Fq "📍 Estás trabajando en la rama:"
  echo "$output" | grep -Fq "[main]"
  echo "$output" | grep -q "ℹ️"
  echo "$output" | grep -Fq "📋 Archivos detectados con cambios:"
  echo "$output" | grep -Fq "💡 Recomendación:"
}

@test "status no muestra códigos ni comandos crudos de git" {
  printf 'base\n' > seguimiento.txt
  git add seguimiento.txt
  git commit -q -m "base"
  printf 'cambio\n' > seguimiento.txt
  printf 'nuevo\n' > nuevo.txt

  run "$GKS" status
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -Fq "??"
  ! echo "$output" | grep -Fq "[ M]"
  ! echo "$output" | grep -Fq "git add"
  ! echo "$output" | grep -Fq "git commit"
}

@test "status traduce modificados, nuevos y eliminados" {
  printf 'base\n' > modificado.txt
  printf 'base\n' > eliminado.txt
  git add modificado.txt eliminado.txt
  git commit -q -m "base"
  printf 'cambio\n' > modificado.txt
  rm eliminado.txt
  printf 'nuevo\n' > nuevo.txt

  run "$GKS" status
  [ "$status" -eq 0 ]
  echo "$output" | grep -Fq "modificado.txt (Modificado — tenés cambios sin guardar)"
  echo "$output" | grep -Fq "nuevo.txt (Nuevo — archivo recién creado)"
  echo "$output" | grep -Fq "eliminado.txt (Eliminado — archivo borrado)"
}

@test "status traduce archivos en conflicto" {
  printf 'base\n' > conflicto.txt
  git add conflicto.txt
  git commit -q -m "base"
  git checkout -q -b otra
  printf 'otra\n' > conflicto.txt
  git commit -qam "otra"
  git checkout -q main
  printf 'main\n' > conflicto.txt
  git commit -qam "main"
  git merge otra >/dev/null 2>&1 || true

  run "$GKS" status
  [ "$status" -eq 0 ]
  echo "$output" | grep -Fq "conflicto.txt (Conflicto — requiere resolución)"
  echo "$output" | grep -Fq "Abrí cada archivo marcado como conflicto"
}

@test "SIDEKICK_STATUS_RAW=1 muestra el status --short original" {
  printf 'base\n' > rastreado.txt
  git add rastreado.txt
  git commit -q -m "base"
  printf 'cambio\n' > rastreado.txt
  printf 'nuevo\n' > nuevo.txt

  run env SIDEKICK_STATUS_RAW=1 "$GKS" status
  [ "$status" -eq 0 ]
  echo "$output" | grep -Fq " M rastreado.txt"
  echo "$output" | grep -Fq "?? nuevo.txt"
  ! echo "$output" | grep -Fq "(Nuevo — archivo recién creado)"
  echo "$output" | grep -Fq "💡 Recomendación:"
}

@test "status sin remoto explica que la rama es solo local" {
  run "$GKS" status
  [ "$status" -eq 0 ]
  echo "$output" | grep -Fq "Esta rama solo existe en tu computadora (no hay servidor conectado)."
}

@test "status con remoto al día reporta rama sincronizada" {
  local remote_dir
  remote_dir=$(mktemp -d /tmp/bats-remote-XXXXXX)
  git init --bare -q "$remote_dir"
  git remote add origin "$remote_dir"
  git push -q -u origin main

  run "$GKS" status
  [ "$status" -eq 0 ]
  echo "$output" | grep -Fq "Tu rama está sincronizada con el servidor."

  rm -rf "$remote_dir"
}

@test "status conserva rutas con espacios y acentos" {
  printf 'contenido\n' > "informe año.txt"

  run "$GKS" status
  [ "$status" -eq 0 ]
  echo "$output" | grep -Fq "informe año.txt (Nuevo — archivo recién creado)"
}

@test "status muestra el nombre viejo y el nuevo en renombrados" {
  printf 'contenido\n' > "nombre viejo.txt"
  git add "nombre viejo.txt"
  git commit -q -m "base"
  git mv "nombre viejo.txt" "nombre nuevo.txt"

  run "$GKS" status
  [ "$status" -eq 0 ]
  echo "$output" | grep -Fq "nombre nuevo.txt (Renombrado — antes se llamaba 'nombre viejo.txt')"
}
