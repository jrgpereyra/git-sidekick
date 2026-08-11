# git-sidekick

**Asistente universal de Git para novatos.**  
Open source (MIT) – diseñado para ser usado con o sin asistentes de IA.

---

## Tabla de contenido

- [¿Qué es?](#qué-es)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Uso básico](#uso-básico)
  - [Modo interactivo (menú)](#modo-interactivo)
  - [Comandos directos](#comandos-directos)
- [Flujo de trabajo recomendado](#flujo-de-trabajo-recomendado)
- [Integración con asistentes de IA](#integración-con-asistentes-de-ia)
- [Contribuciones](#contribuciones)
- [Licencia](#licencia)

---

## ¿Qué es?

`git-sidekick` es un script Bash que **simplifica el uso de Git** para personas que recién empiezan. En lugar de recordar comandos complejos, usás un menú interactivo o le pedís a un asistente de IA que ejecute las acciones por vos.

### Características principales

- ✅ **Modo interactivo:** menú con números, fácil de navegar.
- ✅ **Comandos directos:** `start`, `close`, `status`, `restore`, `snapshot`, `clean`.
- ✅ **Sesiones de trabajo:** guarda contexto (rama, fecha, checkpoint) para no perder el hilo.
- ✅ **Checkpoints (snapshots):** marcadores con `git tag` para volver a estados anteriores.
- ✅ **Bitácora automática:** registra en `.git-worklog.md` qué hiciste en cada sesión.
- ✅ **Stash automático:** al cambiar de rama, guarda cambios sin commit.
- ✅ **Seguridad:** confirmaciones antes de acciones peligrosas (merge, restore, limpieza).
- ✅ **Integración con IA:** podés usar lenguaje natural con PI, OpenCode o DeepSeek.