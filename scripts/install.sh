#!/usr/bin/env bash
# Bootstrap de dotfiles en una maquina que ya tiene las dependencias
# instaladas (ver bootstrap-fedora.sh si es una maquina realmente nueva).
#
# Instala tuckr si falta y despliega todos los grupos con `set`,
# para que corran los hooks de Hooks/*/post.sh de una.

set -euo pipefail

if ! command -v tuckr >/dev/null 2>&1; then
  if ! command -v cargo >/dev/null 2>&1; then
    echo "Falta 'cargo' (Rust) — instalalo primero (ver bootstrap-fedora.sh)." >&2
    exit 1
  fi
  echo "Instalando tuckr..."
  cargo install tuckr
fi

export PATH="$HOME/.cargo/bin:$PATH"

echo "Desplegando dotfiles con tuckr..."
tuckr set \*

echo "Listo. Corre 'tuckr status' para confirmar."
