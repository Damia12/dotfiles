#!/usr/bin/env bash
# Instala, en un Fedora recien instalado, lo que esta configuracion de
# dotfiles da por sentado que ya existe. Correr esto ANTES de install.sh.
#
# No incluye tuckr (se instala via cargo en install.sh) ni fuentes Nerd Font
# (revisar Hooks/kitty/post.sh y descargar la que corresponda a mano).

set -euo pipefail

echo "Instalando paquetes base con dnf..."
sudo dnf install -y \
  zsh \
  kitty \
  neovim \
  git \
  git-delta \
  eza \
  bat \
  fzf \
  zoxide \
  vivid \
  cargo \
  nodejs \
  npm

if ! command -v yazi >/dev/null 2>&1; then
  echo "AVISO: 'yazi' no esta en los repos de dnf en muchas versiones de Fedora." >&2
  echo "       instalalo via 'cargo install --locked yazi-fm yazi-cli' o COPR." >&2
fi

echo "Instalando ccstatusline (npm global)..."
sudo npm install -g ccstatusline

echo ""
echo "Listo. Pasos manuales que este script no puede hacer:"
echo "  - Instalar la fuente 'JetBrainsMono Nerd Font Mono' (ver Hooks/kitty/post.sh)."
echo "  - Correr scripts/install.sh para desplegar los dotfiles con tuckr."
