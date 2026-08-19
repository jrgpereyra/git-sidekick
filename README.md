# 🧠 git-sidekick — Tu asistente de Git para tu agente IA

> **Olvidate de aprender Git. Tu agente de IA lo maneja por vos.**

---

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-0.3.0-orange.svg)
![Hecho con](https://img.shields.io/badge/hecho%20con-Bash-4979e0.svg)
![Tests](https://img.shields.io/badge/tests-27%2F27-brightgreen.svg)

---

## 📦 Instalación (en serio, ni vos lo hacés)

Tu agente ejecuta un `curl` y ya está. Vos ni te enterás.

```bash
curl -fsSL https://raw.githubusercontent.com/jrgpereyra/git-sidekick/main/git-sidekick.sh -o git-sidekick.sh && chmod +x git-sidekick.sh
```

---

## 💬 Un ejemplo de cómo es trabajar así

**Tú:** "Iniciá sesión en dev."

**Agente:** `gk start` → Sesión iniciada en rama `dev`. ¡Listo para trabajar!

**Tú:** *(cambiás un par de archivos, editás, probás.)*

**Tú:** "Hacé un snapshot de rescate, por las dudas."

**Agente:** `gk snapshot` → Punto de rescate guardado. No se te va a ir nada.

**Tú:** "Cerrá la sesión y guardá lo que hice."

**Agente:** `gk close` → 3 archivos commiteados. Snapshot de cierre guardado. ¡Listo!

---

## 🚀 Lo que podés decirle a su agente

- *"Iniciá sesión en dev con la etiqueta carrito"* → arranca una sesión nueva
- *"Hacé un snapshot de rescate"* → punto de seguridad sin salir del flujo
- *"Cerrá la sesión con mensaje fix: validación"* → commitea y guarda todo
- *"Mergeá feature-carrito en main"* → fusiona con protección
- *"¿En qué estado está todo?"* → te lo cuenta sin rodeos

No necesitás memorizar comandos. Hablabas en español y el agente lo traduce a Git.

P.D. 📖 ¿Te quedaste con ganas de más? La documentación completa con todos los comandos, ejemplos y configuraciones avanzadas está en [`DOCS.md`](DOCS.md).

---

<p align="center">
  <sub>© 2026 Jorge Pereyra · Hecho con ❤️ en Bash · <a href="https://github.com/jrgpereyra/git-sidekick">Ver en GitHub</a></sub>
</p>
