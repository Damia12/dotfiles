#!/usr/bin/env bash
# Instala, en un Fedora recien instalado, lo que esta configuracion de
# dotfiles da por sentado que ya existe. Correr esto ANTES de install.sh.
#
# No incluye tuckr (se instala via cargo en install.sh) ni fuentes Nerd Font
# (revisar Hooks/kitty_linux/post.sh y descargar la que corresponda a mano).

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
  npm \
  gh

# gh no es por la CLI de GitHub en si: es porque `gh auth login` deja a git
# recordando tus credenciales para push por HTTPS. Sin eso, Fedora pide usuario
# y token en CADA push, porque no trae gestor de credenciales de serie (Windows
# si: Git Credential Manager viene con Git for Windows).

if ! command -v yazi >/dev/null 2>&1; then
  echo "AVISO: 'yazi' no esta en los repos de dnf en muchas versiones de Fedora." >&2
  echo "       instalalo via 'cargo install --locked yazi-fm yazi-cli' o COPR." >&2
fi

echo "Instalando ccstatusline (npm global)..."
sudo npm install -g ccstatusline

echo ""
echo "Listo. Pasos manuales que este script no puede hacer:"
echo "  - Instalar la fuente 'JetBrainsMono Nerd Font Mono' (ver Hooks/kitty_linux/post.sh)."
echo "  - Correr scripts/install.sh para desplegar los dotfiles con tuckr"
echo "    (si llegaste aqui por init-fedora.sh, lo lanza solo a continuacion)."
echo "  - Autenticarte, porque es tu identidad y no se puede automatizar:"
echo "      gh auth login      -> abre el navegador y deja git recordando tus credenciales"
echo "      claude login"
