# git-sidekick

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-0.1.0-orange.svg)
![Hecho con](https://img.shields.io/badge/hecho%20con-Bash-4979e0.svg)

> **Asistente universal de Git para novatos.**  
> Un script **Bash** que simplifica tu flujo de trabajo con Git mediante un menú interactivo y comandos directos. Ideal para quienes arrancan y para equipos que trabajan con asistentes de IA.

---

## Tabla de contenidos

- [Características](#características)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Alias para uso rápido](#alias-para-uso-rápido)
- [Uso básico](#uso-básico)
  - [Modo interactivo](#modo-interactivo)
  - [Comandos directos](#comandos-directos)
- [Flujo de trabajo recomendado](#flujo-de-trabajo-recomendado)
- [Comandos disponibles](#comandos-disponibles)
- [Uso con asistentes de IA](#uso-con-asistentes-de-ia)
- [Ejemplos de terminal](#ejemplos-de-terminal)
- [Contribuciones](#contribuciones)
- [Licencia](#licencia)

---

## Características

- 📋 **Menú interactivo** y **comandos directos** (`start`, `close`, `status`, `restore`, `snapshot`, `clean`, …).
- 📸 **Snapshots con tags de Git** como puntos de control (p. ej. `work/2026-08-11_14-30-login`).
- 📦 **Stash automático** al cambiar de rama para no perder cambios sin commitear.
- 📝 **Bitácora automática** en Markdown (`.git-worklog.md`) que registra cada sesión.
- ⏪ **Restauración** a puntos anteriores con `git reset --hard` a un snapshot.
- 🧹 **Limpieza inteligente** de snapshots antiguos (mantiene los recientes y un por semana).
- 💡 **Sugerencia de mensajes de commit** para sesiones de cierre.
- 🤖 **Listo para asistentes de IA**: usá lenguaje natural y delegá las tareas a Pi, OpenCode o DeepSeek.

---

## Requisitos

| Herramienta | Versión mínima |
|-------------|----------------|
| **Bash**    | 4.0+           |
| **Git**     | 2.0+           |

> En Linux ya viene todo incluido. En macOS, **macOS 12+ incluye Bash 3.2**; se recomienda instalar Bash 5+ vía `brew install bash`.

---

## Instalación

1. Cloná el repositorio:

```bash
git clone https://github.com/jrgpereyra/git-sidekick.git
cd git-sidekick
```

2. Dale permiso de ejecución:

```bash
chmod +x git-sidekick.sh
```

3. *(Opcional)* Agregalo al `PATH` para usarlo desde cualquier carpeta:

```bash
ln -s "$PWD/git-sidekick.sh" /usr/local/bin/git-sidekick
```

> A partir de ahí podés invocar `git-sidekick` desde cualquier directorio que contenga un repo Git.

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
gk close                  # cerrar sesión
gk status                 # ver estado de la rama
gk merge feat main 1      # merge protegido nivel 1
gk help                   # esta ayuda
```

> El alias apunta a la ruta absoluta del script en el momento de la instalación; si el script lo movés o renombrás, volvé a correr `--install-alias` para actualizarlo.

## Uso básico

### Modo interactivo

Ejecutalo sin argumentos y navegá el menú con números:

```bash
./git-sidekick.sh
```

> **Ataques rápidos en modo interactivo:** `s` iniciar sesión | `c` cerrar sesión | `q` salir; opciones 9/10/11 para merges preconfigurados y uno personalizado.


```
------------------------------------------------
🎮 git-sidekick v0.1.0
📍 Rama actual: → main
------------------------------------------------
1) INICIAR sesión        (atajo: s)
2) VER ESTADO
3) CERRAR sesión         (atajo: c)
4) RESTAURAR punto
5) SNAPSHOT (rescate)
6) LIMPIAR snapshots
7) AYUDA
8) SALIR                 (atajo: q)
9) ACTUALIZAR dev con main (main → dev)  [nivel 1]
10) PUBLICAR dev a main    (dev → main)  [nivel 2]
11) FUSIONAR personalizado
------------------------------------------------
Opción (1-11) [s/c/q]:
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
```

---

## Flujo de trabajo recomendado

Trabajás con una **sesión**: cada vez que empezás una tarea, iniciás; cuando la terminás, la cerrás. El script gestiona stash, checkpoints y la bitácora por vos.

```bash
# 1️⃣ Empezar a trabajar en una rama nueva
./git-sidekick.sh start
# → "¿En qué rama vas a trabajar? (main/dev/actual) [actual]: dev"
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
| `status` | Muestra rama, ahead/behind del upstream y archivos modificados.       |
| `restore`| Lista snapshots y restaura eligiendo uno con `git reset --hard`.      |
| `snapshot`| Crea un snapshot rápido sin abrir sesión (punto de rescate).          |
| `clean`  | Borra snapshots antiguos con confirmación previa.                     |
| `merge`  | Mergea origen → destino con protección (nivel 1 o 2). |
| `help`   | Muestra la ayuda del script.                                            |
| (nada)   | Abre el menú interactivo.                                              |

---

## Uso con asistentes de IA <a href="https://github.com/jrgpereyra/git-sidekick"></a>

<div align="center" style="border: 2px solid #6c5ce5; border-radius: 10px; padding: 16px; margin: 16px 0;">
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
| _"Mergeá feature-login en main con protección estricta"_ | `./git-sidekick.sh merge feature-login main 2` → snapshot de seguridad, confirma doble, mergea y pucha |
| _"¿En qué estado está todo?"_ | `./git-sidekick.sh status` |

### Ejemplo de sesión asistida

```
Usuario: iniciá sesión en feature/carrito de compras
IA:      ejecuto ./git-sidekick.sh start
Script:  📍 Rama actual: [main]
         ¿En qué rama vas a trabajar? (main/dev/actual) [actual]: feature/carrito
         ¿Etiqueta para la sesión? (opcional): carrito
         ✅ SESIÓN INICIADA en [feature/carrito]
            Tag creado: work/2026-08-11_14-30-carrito

Usuario: terminé, cerrá la sesión con mensaje "feat: carrito funcional" y subí
IA:      ejecuto ./git-sidekick.sh close
Script:  📍 Rama actual: [feature/carrito]
         📌 Sesión previa: [feature/carrito] inicio (2026-08-11_14-30)
         Mensaje de commit [Enter para usar sugerido: 'Sesión en feature/carrito - 2026-08-11_14-35']: feat: carrito funcional
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
📍 Rama actual: [dev]
📥 Hay 2 commits remotos no descargados. Para traerlos: git pull
📤 Hay 1 commits locales no subidos. Para subirlos: git push

 M src/app.js
?? docs/nuevo.md
```

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

## Contribuciones

¡Las contribuciones son bienvenidas! 🙌

1. Hacé un **fork** y una rama nueva: `git checkout -b feat/mejora-x`.
2. Implementá tu cambio.
3. Abrí un **Pull Request** describiendo el cambio.

### Áreas de mejora sugeridas

- 🐳 **Soporte DDEV**: comandos contextuales para entornos DDEV (snapshot de DB, etc.).
- 🔁 **CI/CD**: publicación automática de releases y generación de tags.
- 🌍 **Internacionalización**: i18n (ES/EN) de los mensajes.
- 🧪 **Tests**: suite de tests en Bash con `bats-core`.
- 🛡️ **Hooks**: integración con `pre-commit` / `commit-msg`.
- 📊 **Reportes**: generación de reportes de productividad por desarrollador.

> Seguimos el plan de trabajo **Protocolo Soberano** (id10) para gestión de sesiones y versiones.

---

## Licencia

Este proyecto está bajo la licencia **MIT**.  
Vea el archivo [LICENSE](https://github.com/jrgpereyra/git-sidekick/blob/main/LICENSE).

```
MIT License

Copyright (c) 2026 Jorge Pereyra

Se concede permiso, gratuitamente, a cualquier persona que obtenga una copia
de este software y los archivos de documentación asociados...
```
## Cambio de prueba en el repo real
