#!/usr/bin/env bash
# Corre despues de desplegar el grupo "zsh" (via `tuckr set zsh`).
# Ofrece poner zsh como shell por defecto si todavia no lo es.
# Pide confirmacion explicita: cambiar la shell de login no se hace sin avisar.

set -euo pipefail

ZSH_PATH="$(command -v zsh || true)"

if [[ -z "$ZSH_PATH" ]]; then
  echo "AVISO: no se encontro 'zsh' instalado, no puedo configurarlo como shell." >&2
  exit 0
fi

if [[ "$SHELL" == "$ZSH_PATH" ]]; then
  exit 0
fi

if [[ -t 0 ]]; then
  read -rp "Tu shell por defecto no es zsh ($SHELL). ¿Poner zsh como shell por defecto? [y/N] " resp
  if [[ "$resp" =~ ^[Yy]$ ]]; then
    chsh -s "$ZSH_PATH"
    echo "Listo — cerra sesion y volve a entrar para que tome efecto."
  fi
else
  echo "AVISO: tu shell por defecto no es zsh ($SHELL). Corre 'chsh -s $ZSH_PATH' a mano si queres cambiarlo." >&2
fi
