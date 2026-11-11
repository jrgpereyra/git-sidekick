# 📚 git-sidekick — Documentación Técnica

> **Referencia completa para usuarios curiosos y avanzados.**  
> Este es el manual detallado. Si llegaste acá por primera vez, empezá por el [README.md](README.md).

---

## 📋 Índice

- [Características](#características)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Inicialización automática de repositorios](#inicialización-automática-de-repositorios)
- [Alias para uso rápido](#alias-para-uso-rápido)
- [Configuración por proyecto](#configuración-por-proyecto-git-sidekickrc)
- [Modo seguro (--dry-run)](#modo-seguro--dry-run)
- [Uso básico](#uso-básico)
  - [Modo interactivo](#modo-interactivo)
  - [Comandos directos](#comandos-directos)
- [Flujo de trabajo recomendado](#flujo-de-trabajo-recomendado)
- [Comandos disponibles](#comandos-disponibles)
- [Merge protegido: garantías de seguridad](#merge-protegido-garantías-de-seguridad)
- [Uso con asistentes de IA](#uso-con-asistentes-de-ia)
- [Ejemplos de terminal](#ejemplos-de-terminal)
- [Testing](#testing)

---

## Características

- 📋 **Menú interactivo** y **comandos directos** (`start`, `close`, `status`, `restore`, `snapshot`, `clean`, …).
- 📸 **Snapshots con tags de Git** como puntos de control (p. ej. `work/2026-08-11_14-30-login`).
- 📦 **Stash automático** al cambiar de rama para no perder cambios sin commitear.
- 🔀 **Merge protegido**: verificación remota (`fetch` + upstream), stash seguro con untracked, aborto atómico y trap de limpieza.
- 📝 **Bitácora automática** en Markdown (`.git-worklog.md`) que registra cada sesión.
- ⏪ **Restauración** a puntos anteriores con `git reset --hard` a un snapshot.
- 🧹 **Limpieza inteligente** de snapshots antiguos (mantiene los recientes y un por semana).
- 💡 **Sugerencia de mensajes de commit** para sesiones de cierre.
- 🤖 **Listo para asistentes de IA**: usá lenguaje natural y delegá las tareas a Pi, OpenCode o DeepSeek.
- 🚀 **Inicialización automática de repositorios** (local/remoto, con GitHub, agnóstico de nube).

---

## Requisitos

| Herramienta | Versión mínima |
|-------------|----------------|
| **Bash**    | 4.0+           |
| **Git**     | 2.0+           |

> En Linux ya viene todo incluido. En macOS, **macOS 12+ incluye Bash 3.2**; se recomienda instalar Bash 5+ vía `brew install bash`.

---

## Instalación

### Opción 1 — Instalación rápida vía curl

Ideal para desplegar en cualquier proyecto con un solo comando:

```bash
curl -fsSL https://raw.githubusercontent.com/jrgpereyra/git-sidekick/main/git-sidekick.sh -o git-sidekick.sh && chmod +x git-sidekick.sh
```

### Opción 2 — Clonar el repositorio (recomendado para desarrollo)

```bash
git clone https://github.com/jrgpereyra/git-sidekick.git
cd git-sidekick
chmod +x git-sidekick.sh
```

### Opción 3 — Comando global `git-sidekick`

Copiá el script a un directorio del `PATH`:

```bash
mkdir -p ~/scripts
cp "$PWD/git-sidekick.sh" ~/scripts/git-sidekick
echo 'export PATH="$HOME/scripts:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

A partir de ahí podés invocar `git-sidekick` desde cualquier directorio que contenga un repo Git.

---

## 🚀 Inicialización automática de repositorios

> **Nueva en v0.2.0**

Si ejecutás `git-sidekick` en una carpeta **sin repositorio Git**, el script detecta la situación y le propone al usuario inicializar uno de forma interactiva.

### Flujo

```
📁 No encontré un repositorio Git en esta carpeta. ¿Querés inicializar uno ahora? [Enter=sí]:
  ↳ Enter/s → git init
  ↳ n → Cancelado.

¿Rama por defecto? (main/master) [main]:
  ↳ Enter → main (o el nombre que ingresés)

¿Querés trabajar solo en local o conectarlo a un remoto? (local/remoto) [local]:
  ↳ local → ✅ Listo
  ↳ remoto → ¿Crear nuevo o usar existente? (crear/usar) [crear]:
    ↳ crear → Plataforma (github/gitlab/bitbucket/otro) [github]
    ↳ usar → Ingresar URL del remoto directamente
```

### Características

- **Detección automática de CLI**: si tenés `gh` (GitHub CLI) o `glab` (GitLab CLI) instalado, el script crea el repo y lo conecta con un solo comando.
- **Instrucciones paso a paso**: si la CLI no está instalada, muestra instrucciones manuales y permite conectar el remoto ingresando la URL.
- **Rama por defecto configurable**: elegís `main` o `master` al momento de la inicialización.
- **Resumen final**: al finalizar, muestra un resumen con la ruta, rama, remoto y CLI detectada.

### Comando `info` (v0.3.0)

Muestra un **resumen completo** del estado del repositorio: rama actual, remote, estado del remoto en lenguaje natural, último snapshot, estado de sesión y la bitácora:

```bash
./git-sidekick.sh info
```

---

## 🚀 Alias para uso rápido

Instalá un alias de una sola palabra para invocar el script sin escribir la ruta completa cada vez:

```bash
./git-sidekick.sh --install-alias
```

El comando:
- crea `~/.bash_aliases` (con encabezado) si no existe.
- agrega o actualiza la línea `alias gk="/ruta/absoluta/git-sidekick.sh"`.
- si el alias ya existe, te pregunta si querés sobrescribir.
- al final indica `source ~/.bashrc` para recargar la configuración.

Ejemplos de uso:

```bash
gk start                  # iniciar sesión
gk info                   # mostrar información del repositorio
gk close                  # cerrar sesión
gk status                 # ver estado de la rama
gk merge feat main 1      # merge protegido nivel 1
gk help                   # esta ayuda
```

> El alias apunta a la ruta absoluta del script en el momento de la instalación; si el script lo movés o renombrás, volvé a correr `--install-alias` para actualizarlo.

## Configuración por proyecto (`.git-sidekickrc`)

> **Nuevo en v0.3.0**

Personalizá el comportamiento de git-sidekick **por proyecto** creando un archivo `.git-sidekickrc` en la raíz del repo. Usá formato `key=value`:

```bash
# .git-sidekickrc
# Copiá .git-sidekickrc.example y ajustá según tu proyecto

default_branch=main          # rama principal (main / master)
dev_branch=dev               # rama de desarrollo
snapshot_prefix=work         # prefijo para tags de snapshot
auto_stash=true              # ¿stash automático (con untracked) antes de un merge?
auto_push=false              # ¿subir a la nube al cerrar? (false = seguro)
confirm_destructive=true     # ¿confirmación doble antes de reset --hard?
```

### Opciones disponibles

| Opción | Default | Descripción |
|--------|---------|-------------|
| `default_branch` | `main` | Nombre de la rama principal. |
| `dev_branch` | `dev` | Nombre de la rama de desarrollo. |
| `auto_stash` | `true` | Stash automático (con `-u`) antes de un merge; `false` aborta si el árbol está sucio. |
| `auto_push` | `false` | Push a la nube al cerrar sesión. |
| `confirm_destructive` | `true` | Confirmación doble antes de `reset --hard`. |
| `snapshot_prefix` | `work` | Prefijo para los tags de snapshot. |
| `worklog_file` | `.git-worklog.md` | Nombre del archivo de bitácora. |

> 💡 `.git-sidekickrc` está en el `.gitignore` por defecto. Si querés versionarlo para compartir con tu equipo, ejecutá `git add -f .git-sidekickrc`.

## Modo seguro (`--dry-run`)

> **Nuevo en v0.3.0**

El flag **`--dry-run`** te permite ver **qué haría** el script **sin ejecutar nada**. Ideal para novatos que quieren entender antes de aplicar:

```bash
gk start --dry-run          # Muestra el plan: stash, checkpoint, snapshot
gk close --dry-run          # Muestra: commit, snapshot, push
gk merge a b 1 --dry-run    # Muestra: commits a fusionar + confirmación
gk restore tag --dry-run    # Muestra: qué snapshot se restauraría
```

Ejemplo de salida:
```
$ gk start --dry-run
🔍 [SIMULACIÓN] Activado: los comandos se muestran pero no se ejecutan.
   💡 Sacá --dry-run para ejecutar de verdad.
🔍 [SIMULACIÓN] Iniciar sesión: stash + checkpoint + snapshot
   └─ No se crea el snapshot, no se hace stash.
   └─ Usá 'gk start' sin --dry-run para ejecutar.
```

---

## Uso básico

### Modo interactivo

Ejecutalo sin argumentos y navegá el menú con números:

```bash
./git-sidekick.sh
```

> **Atajos rápidos en modo interactivo:** `s` iniciar sesión | `c` cerrar sesión | `e` extras | `q` salir; el menú principal tiene 5 opciones (`1-5`) y las herramientas viven en Extras.

```
------------------------------------------------
🎮 git-sidekick v0.4.0
📍 Rama actual: → main
------------------------------------------------
1) INICIAR sesión        (atajo: s)
2) CERRAR sesión         (atajo: c)
3) PUBLICAR dev a main     (dev → main)  [nivel 2]
4) EXTRAS / HERRAMIENTAS (atajo: e)
5) SALIR                 (atajo: q)
------------------------------------------------
Opción (1-5) [s/c/e/q]:
```

### Submenú Extras / Herramientas

La opción `4) EXTRAS / HERRAMIENTAS` agrupa las herramientas secundarias:

```
------------------------------------------------
🛠️  EXTRAS / HERRAMIENTAS
------------------------------------------------
1) VER ESTADO
2) RESTAURAR punto
3) SNAPSHOT (rescate)
4) LIMPIAR snapshots
5) ACTUALIZAR dev con main (main → dev)  [nivel 1]
6) FUSIONAR personalizado
7) AYUDA
0) VOLVER al menú principal
------------------------------------------------
Opción (0-7): [o "0) VOLVER al menú principal"]
```

### Comandos directos

```bash
./git-sidekick.sh start      # Iniciar sesión de trabajo
./git-sidekick.sh close      # Cerrar sesión y commitear
./git-sidekick.sh status     # Ver estado de la rama
./git-sidekick.sh restore    # Restaurar a un snapshot
./git-sidekick.sh snapshot   # Crear un snapshot rápido
./git-sidekick.sh clean      # Limpiar snapshots viejos
./git-sidekick.sh merge <origen> <destino> <nivel>  # Merge protegido (1=simple, 2=estricto)
./git-sidekick.sh help       # Mostrar ayuda
./git-sidekick.sh info      # Mostrar información detallada del repositorio
./git-sidekick.sh --install-alias     # Instalar alias gk
```

---

## Flujo de trabajo recomendado

Trabajás con una **sesión**: cada vez que empezás una tarea, iniciás; cuando la terminás, la cerrás. El script gestiona stash, checkpoints y la bitácora por vos.

> 💡 **Antes de empezar:** si la carpeta no es un repo Git, `git-sidekick` lo inicializa **automáticamente** al entrar (o ejecutá `git-sidekick info` para crearlo). Una vez listo el repo, iniciá sesión:

```bash
# 1️⃣ Empezar a trabajar en una rama nueva
./git-sidekick.sh start
# → 📋 Ramas disponibles:
#    1) dev *
#    2) main
#    0) Crear nueva rama...
# → Seleccioná una rama (0-2) [1]: 1
# → "¿Etiqueta para la sesión? (opcional): arreglo-login"
# → crea el branch 'dev', hace un checkpoint y un snapshot work/2026-08-11_14-30-arreglo-login

# 2️⃣ Hacés tus cambios normalmente...

# 3️⃣ Cambiás de rama (se stashean los cambios si no comiteaste)
./git-sidekick.sh            # menú → opción 1) para otra sesión
#    ó, si el asistente lo sugiere:
#    "iniciá sesión en main" → cambia a main guardando cambios

# 4️⃣ Terminaste: cerrás la sesión
./git-sidekick.sh close
# → "Mensaje de commit [Enter para usar sugerido: 'Sesión en dev - 2026-08-11_14-30']:"
# → "¿Etiqueta para snapshot de cierre? (opcional): "
# → "¿Subir cambios a la nube? [Enter=sí]: "
# → crea snapshot de cierre y actualiza .git-worklog.md

# 5️⃣ Si algo salió mal, restaurás
./git-sidekick.sh restore     # elegís el snapshot al que querés volver
```

---

## Comandos disponibles

| Comando  | Acción                                                                 |
|----------|------------------------------------------------------------------------|
| `start`  | Inicia una sesión: stash, checkpoint, snapshot y guarda contexto.     |
| `close`  | Commitea, crea snapshot de cierre, bitacorea y pucha (opcional).      |
| `status` | Muestra rama, estado del remoto y archivos con cambios en lenguaje natural. |
| `restore`| Lista snapshots y restaura eligiendo uno con `git reset --hard`.      |
| `snapshot`| Crea un snapshot rápido sin abrir sesión (punto de rescate).          |
| `clean`  | Borra snapshots antiguos con confirmación previa.                     |
| `merge <origen> <destino> <nivel>` | Fusiona ramas con preflight remoto, stash seguro y aborto atómico (1=simple, 2=estricto). |
| `help`   | Muestra la ayuda del script.                                            |
| `--install-alias` | Instala el alias `gk` en ~/.bash_aliases.                      |
| `info`   | Muestra rama, remote, estado del remoto, último snapshot y bitácora.  |
| `--dry-run` | Flag: simula cualquier comando sin ejecutarlo (preview seguro).  |
| (nada)   | Abre el menú interactivo.                                              |

---

## Merge protegido: garantías de seguridad

`merge_protegido` aplica una secuencia de controles antes y durante cada fusión:

1. **Preflight remoto**
   - Ejecuta `git fetch --all --prune`.
   - Verifica que origen y destino tengan upstream configurado.
   - Si no hay red, advierte y pide **confirmación explícita** para continuar.
   - Si una rama está **detrás de su remoto**, aborta: primero hay que hacer `git pull --ff-only`.

2. **Árbol de trabajo seguro**
   - Si hay cambios (tracked, staged o untracked), los guarda con `git stash push --include-untracked`.
   - Registra el SHA del stash y lo restaura al terminar; solo lo elimina si aplicó limpio.
   - Con `auto_stash=false`, aborta ante un árbol sucio.
   - Si la restauración conflictúa, **el stash se conserva** para no perder trabajo.

3. **Aborto atómico**
   - Registra la rama original y vuelve a ella pase lo que pase.
   - Ante conflicto ejecuta `git merge --abort` y restaura el árbol previo.
   - Un `trap` en `EXIT/INT/TERM/HUP` repite la limpieza ante `Ctrl+C`, cierre de terminal o fallo inesperado.

4. **Push posterior**
   - El nivel 2 ofrece subir el destino después del merge.
   - Si el push falla, el merge local se conserva y se muestran los pasos para reintentar.

Además se valida que origen y destino sean distintos, que no haya otro merge/rebase en curso y que el destino no esté abierto en otra worktree.

---

## Uso con asistentes de IA

<div align="center" style="border: 2px solid #6c5ce7; border-radius: 10px; padding: 16px; margin: 16px 0;">
  <strong>🤖 Esta sección es una prioridad del proyecto.</strong><br>
  Cualquier persona — incluso sin conocimientos de Git — puede trabajar delegando estas tareas a un asistente de IA. <code>git-sidekick</code> expone una interfaz predecible (comandos directos + salidas consistentes) para que los asistentes <strong>Pi</strong>, <strong>OpenCode</strong> y <strong>DeepSeek</strong> la invoquen con lenguaje natural.
</div>

### ¿Por qué es ideal para IA?

- 📟 **Salidas consistentes y parseables**, con íconos y colores.
- 🧩 **Una acción por comando**: cada comando corresponde a un paso del flujo de trabajo.
- 🗂️ **Contexto persistente** en `.git-sidekick-context` para que el asistente sepa en qué sesión está.
- 📋 **Bitácora** en `.git-worklog.md` que la IA puede leer para reconstruir el historial.

### Ejemplos de interacción (lenguaje natural → comando)

| Pedís al asistente… | Lo que hace el asistente |
|----------------------|---------------------------|
| _"Iniciá sesión en dev con etiqueta arreglo-login"_ | `./git-sidekick.sh start` → rama `dev`, checkpoint, snapshot `work/...-arreglo-login` |
| _"Cambiá a la rama main"_ | `./git-sidekick.sh start` → rama `main` (stash automático si hay cambios) |
| _"Creá un snapshot rápido de rescate"_ | `./git-sidekick.sh snapshot` |
| _"Restaurá al último snapshot"_ | `./git-sidekick.sh restore` |
| _"Cerrá la sesión con mensaje fix: validación del formulario"_ | `./git-sidekick.sh close` → commitea con ese mensaje, crea snapshot de cierre |
| _"Limpiá snapshots viejos"_ | `./git-sidekick.sh clean` |
| _"Mergeá feature-login en main con protección estricta"_ | `./git-sidekick.sh merge feature-login main 2` → preflight remoto, snapshot de seguridad, stash seguro, aborto ante conflicto y push |
| _"¿En qué estado está todo?"_ | `./git-sidekick.sh status` |

### Ejemplo de sesión asistida

```
Usuario: iniciá sesión en feature/carrito de compras
IA:      ejecuto ./git-sidekick.sh start
Script:  📍 Rama actual: [main]
         📋 Ramas disponibles:
           1) develop
           2) main *
           0) Crear nueva rama...
         Seleccioná una rama (0-2): 0
         Nombre de la nueva rama: feature/carrito
         ¿Etiqueta para la sesión? (opcional): carrito
         ✅ SESIÓN INICIADA en [feature/carrito]
            Tag creado: work/2026-08-11_14-30-carrito

Usuario: terminé, cerrá la sesión con mensaje "feat: carrito funcional" y subí
IA:      ejecuto ./git-sidekick.sh close
Script:  📍 Rama actual: [feature/carrito]
         📌 Sesión previa: [feature/carrito] inicio (2026-08-11_14-30)
         Mensaje de commit [Enter para usar sugerido: 'Sesión en feature/carrito - 2026-08-11_14-30']: feat: carrito funcional
         ¿Etiqueta para snapshot de cierre? (opcional): carrito-listo
         ✅ Snapshot creado: work/2026-08-11_14-35-carrito-listo
         ¿Subir cambios a la nube? [Enter=sí]: s
         ✅ SESIÓN CERRADA. Todo guardado.
```

> 💡 **Tip de equipo:** podés compartir el `.git-worklog.md` generado para que todos vean el historial de sesiones, incluso quienes no usan terminal.

---

## Ejemplos de terminal

### Snapshot rápido

```bash
$ ./git-sidekick.sh snapshot mi-fix-bug
✅ Snapshot creado: work/2026-08-11_15-02-mi-fix-bug
```

### Estado de la rama

```bash
$ ./git-sidekick.sh status
📍 Estás trabajando en la rama: [dev]
ℹ️ Tu rama está sincronizada con el servidor.

📋 Archivos detectados con cambios:
- src/app.js (Modificado — tenés cambios sin guardar)
- docs/nuevo.md (Nuevo — archivo recién creado)

💡 Recomendación:
Cuando termines, elegí "2) CERRAR sesión" para guardar tus cambios. Si querés un punto de rescate antes, entrá a "4) EXTRAS" y creá un snapshot.
```

> 💡 Si necesitás ver los códigos originales de Git (` M`, `??`), usá `SIDEKICK_STATUS_RAW=1 ./git-sidekick.sh status`.

#### Salida conversacional por defecto (v0.4.0)

Desde v0.4.0, `status` muestra el estado en lenguaje natural: explica la rama, la relación con el servidor, qué pasó con cada archivo y cuál es el siguiente paso recomendado. La variable `SIDEKICK_STATUS_RAW=1` queda como mecanismo de escape para recuperar la salida cruda de Git cuando necesites los códigos originales.

### Restaurar un snapshot

```bash
$ ./git-sidekick.sh restore
work/2026-08-11_15-02-mi-fix-bug            (2026-08-11)
work/2026-08-11_14-35-carrito-listo         (2026-08-11)
Ingrese el tag a restaurar (Enter para cancelar): work/2026-08-11_15-02-mi-fix-bug
⚠️ Se perderán todos los cambios no guardados.
¿Confirmar restauración a work/2026-08-11_15-02-mi-fix-bug? [Enter=sí]:
✅ Restaurado a work/2026-08-11_15-02-mi-fix-bug
```

---

## Testing

```bash
bats tests/core.bats      # suite completa (47 tests)
./git-sidekick.sh --dry-run    # simular antes de un cambio grande
```

- Tests en `tests/core.bats`: **47/47 passing**.
- Cubren dry-run, configuración, info, snapshots, workflow `start`/`close` y el merge endurecido (preflight remoto, stash con untracked, conflicto atómico, worktree ocupada y push fallido).
- `--dry-run` corta toda ejecución antes de prompts → ideal para safe-checks.
- `.git-sidekick-context` nunca debe commitearse (está en `.gitignore`).

---

## Volver al inicio

¿Buscás la versión corta y amigable? → [README.md](README.md) | [Ver en GitHub](https://github.com/jrgpereyra/git-sidekick)
