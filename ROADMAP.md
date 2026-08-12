# 🗺️ Hoja de ruta — git-sidekick v2.0

> **Objetivo:** Transformar `git-sidekick` de un script de asistencia básico en un asistente Git inteligente, natural de usar y adaptado a flujos de trabajo reales (Drupal/DDEV, equipos de IA, proyectos multi-entorno).

---

## 📋 Resumen

La v2 se centra en **4 pilares**:

| # | Pilar | Descripción breve |
|---|-------|-------------------|
| 1 | **Mensajes automáticos más humanos** | Generar descripciones del diff en español y bitácoras narrativas. |
| 2 | **Soporte para DDEV / Drupal** | Snapshots de base de datos y comandos contextuales. |
| 3 | **Configuración por proyecto** | Archivo `.git-sidekickrc` para personalizar el comportamiento. |
| 4 | **Mejoras de usabilidad** | Numeración en listas, autocompletado de ramas, modo `--dry-run`, errores más claros. |

---

## 1️⃣ Mensajes automáticos más humanos

### Problema actual
Los mensajes de commit y snapshots son genéricos (ej. `"Sesión en dev - 2026-08-12_02-53"`), lo que dificulta entender el historial sin leer código.

### Mejora propuesta
- **Descripción del diff en español:** analizar `git diff` y generar una descripción legible. Ejemplo:
  - `"Arreglar validación del formulario de login"` en lugar de `"Sesión en dev"`.
- **Bitácora narrativa:** generar un resumen en lenguaje natural de lo que se hizo en cada sesión, guardado en `.git-worklog.md` con formato de narración (quién, qué, por qué, cómo).

### Tareas concretas
- [ ] Integrar análisis de `git diff --stat` para sugerir títulos de commit.
- [ ] Agregar parser de diffs para detectar patrones comunes (agregar archivos, modificar funciones, corregir bugs).
- [ ] Generar resumen narrativo en español al cerrar sesión.
- [ ] Opción `--message` para que la IA o el usuario provea un mensaje personalizado.

### Prioridad
⭐⭐⭐ (Alta — impacta directamente la calidad del historial)

---

## 2️⃣ Soporte para DDEV / Drupal

### Problema actual
El script es genérico para cualquier repo Git. No tiene comandos contextuales para proyectos Drupal/DDEV.

### Mejora propuesta
- **Snapshots de base de datos:** integrar `ddev snapshot` / `ddev seq` para crear puntos de rescate de la BD antes de migraciones o cambios arriesgados.
- **Comandos contextuales:** detectar si el proyecto usa DDEV (presencia de `.ddev/config.yaml`) y ofrecer comandos adicionales:
  - `ddev-drush-status` — estado de la instalación Drupal.
  - `ddev-config-export` — exportar configuración antes de commitear.

### Tareas concretas
- [ ] Detectar proyecto DDEV/Drupal por `.ddev/config.yaml` o `docroot/sites/default/settings.php`.
- [ ] Agregar comando `snapshot-ddev` que combine tag de Git + snapshot de BD.
- [ ] Integrar `drush cex` automático antes del commit (similar al protocolo soberano).
- [ ] Comando `restore-ddev` para restaurar BD desde un snapshot de DDEV + tag de Git.

### Prioridad
⭐⭐ (Media-Alta — clave para equipos Drupal)

---

## 3️⃣ Configuración por proyecto (`.git-sidekickrc`)

### Problema actual
La configuración es estática dentro del script (prefijos de tags, nombres de ramas, etc.). No hay forma de personalizar por proyecto.

### Mejora propuesta
- **Archivo `.git-sidekickrc`** en la raíz del repo, con formato `key=value`:
  ```bash
  # .git-sidekickrc
  default_branch=main
  dev_branch=dev
  snapshot_prefix=work
  auto_stash=true
  auto_push=true
  worklog_file=.git-worklog.md
  ddev_enabled=true
  ```
- El script cargará este archivo si existe, permitiendo:
  - Definir ramas por defecto.
  - Personalizar prefijos de snapshots.
  - Habilitar/deshabilitar DDEV, stash automático, push automático.
  - Especificar nombre del archivo de bitácora.

### Tareas concretas
- [ ] Parser de `.git-sidekickrc` (formato `key=value`, con comentarios).
- [ ] Variables de configuración con valores por defecto.
- [ ] Cargar config al inicio del script (antes de cualquier acción).
- [ ] Archivo `.git-sidekickrc.example` como plantilla.

### Prioridad
⭐⭐⭐ (Alta — base para toda la personalización)

---

## 4️⃣ Mejoras de usabilidad

### 4.1 Numeración en listas
- **Problema:** Los snapshots y ramas se listan sin numerar, dificultando la selección en modo interactivo.
- **Solución:** Numerar automáticamente las opciones y permitir seleccionar por número.

### 4.2 Autocompletado de ramas
- **Problema:** El usuario debe escribir el nombre completo de la rama.
- **Solución:** Integrar bash-completion o fzf para autocompletar nombres de rama (ej. `<Tab>` o selección interactiva).

### 4.3 Modo `--dry-run`
- **Problema:** No hay forma de previsualizar lo que hará `start`, `close` o `merge` sin ejecutar.
- **Solución:** Bandera `--dry-run` que muestre los comandos que se ejecutarían sin aplicar cambios.

### 4.4 Mensajes de error más claros
- **Problema:** Algunos errores son crípticos (ej. `"Error al crear la rama"`).
- **Solución:** Mensajes descriptivos con contexto y sugerencias de solución. Ejemplo:
  - `"❌ No se pudo crear la rama 'feature-x' porque ya existe. Usá 'feature-x-v2' o cambiá de rama con 'dev'."`

### Tareas concretas
- [ ] Numerar listas de snapshots en `restore`, `clean` y `status`.
- [ ] Agregar completado de nombres de rama con `compgen` o `fzf`.
- [ ] Implementar `--dry-run` en todos los subcomandos.
- [ ] Reescribir todos los mensajes de error con contexto y sugerencias.

### Prioridad
⭐⭐ (Media — mejora la experiencia sin cambiar la lógica)

---

## 📅 Cronograma tentativo

| Fase | Contenido | Est. |
|------|-----------|------|
| **F1** | `.git-sidekickrc` + parser + ejemplos | 2 días |
| **F2** | Numeración, autocompletado, `--dry-run`, errores claros | 2 días |
| **F3** | Análisis de diff + mensajes en español + bitácora narrativa | 3 días |
| **F4** | Soporte DDEV/Drupal (snapshot BD, drush cex) | 3 días |
| **F5** | Tests (`bats-core`), integración y release v2.0.0 | 2 días |

**Total estimado:** ~12 días hábiles

---

## 🎯 Criterio de éxito

Al final de la v2, el usuario podrá:

1. Iniciar una sesión con `./git-sidekick.sh start` y recibir un mensaje humano describiendo el estado.
2. Usar `.git-sidekickrc` para configurar su flujo sin tocar el script.
3. Trabajar en un proyecto Drupal/DDEV con snapshots de BD automáticos.
4. Previsualizar cambios con `--dry-run` antes de ejecutar.
5. Cerrar la sesión y obtener un resumen narrativo en español de lo hecho.

---

## 📝 Notas

- Se mantiene compatibilidad con versiones anteriores (config por defecto idéntica).
- El modo interactivo sigue siendo la interfaz principal; los comandos directos siguen funcionando igual.
- Las mejoras de usabilidad (F2) son independientes y pueden entregarse antes de F3/F4.
