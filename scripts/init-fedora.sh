#!/usr/bin/env bash
# Arranque desde cero en un Fedora recien instalado. Un solo comando:
#
#   curl -fsSL https://raw.githubusercontent.com/Damia12/dotfiles/main/scripts/init-fedora.sh | bash
#
# Equivalente de scripts/init-windows.ps1. Hace solo lo minimo para que el
# resto lo hagan los scripts del repo:
#   1. instala git si falta (dnf): sin git no se puede clonar;
#   2. clona el repo en ~/.config/dotfiles, la ruta que tuckr espera;
#   3. lanza bootstrap-fedora.sh (instala programas) y luego install.sh
#      (despliega la configuracion).
#
# Con `curl | bash` la entrada estandar del script es la tuberia, no el
# teclado: sudo no podria pedir la contrasena ni el hook de git preguntar
# nombre y email. Por eso lo primero que hace es reconectar stdin a la
# terminal. Windows no lo necesita porque `iex` no tiene ese problema.
#
# Para ver que haria sin ejecutar nada:
#   curl -fsSL <url> | DOTFILES_DRYRUN=1 bash

set -euo pipefail

# Si stdin no es la terminal (curl | bash) pero hay una terminal disponible,
# reconectar. Se comprueba antes con un `:` porque un `exec` cuya redireccion
# falla mata al shell aunque lleve `|| true`; y sin terminal (un proceso en
# segundo plano) se sigue con lo que haya.
if [[ ! -t 0 ]] && { : < /dev/tty; } 2>/dev/null; then
  exec < /dev/tty
fi

REPO_URL="https://github.com/Damia12/dotfiles.git"
REPO_DIR="$HOME/.config/dotfiles"
DRY="${DOTFILES_DRYRUN:-}"

paso() { printf '\n==> %s\n' "$1"; }
ok()   { printf '    OK    %s\n' "$1"; }
ya()   { printf '    YA    %s\n' "$1"; }

echo "dotfiles: arranque en Fedora limpio"
if [[ -n "$DRY" ]]; then
  echo "MODO DRY-RUN: no se instala, no se clona, no se modifica nada."
fi

# --- 1. git: sin el no se puede clonar
paso "Comprobando git"
if command -v git >/dev/null 2>&1; then
  ya "git $(git --version | sed 's/^git version //')"
elif [[ -n "$DRY" ]]; then
  echo "    [dry-run] instalaria git con dnf"
else
  sudo dnf install -y git
  ok "git instalado"
fi

# --- 2. clonar en la ruta exacta que tuckr espera
paso "Comprobando el repo en $REPO_DIR"
if [[ -d "$REPO_DIR/.git" ]]; then
  ya "ya esta clonado"
elif [[ -n "$DRY" ]]; then
  echo "    [dry-run] clonaria $REPO_URL"
else
  git clone "$REPO_URL" "$REPO_DIR"
  ok "clonado"
fi

# --- 3. el resto lo hacen los scripts del repo
paso "Lanzando bootstrap-fedora.sh y despues install.sh"
if [[ -n "$DRY" ]]; then
  echo "    [dry-run] correria: $REPO_DIR/scripts/bootstrap-fedora.sh"
  echo "    [dry-run] correria: $REPO_DIR/scripts/install.sh"
  echo
  echo "Dry-run terminado. Nada fue modificado."
  exit 0
fi

"$REPO_DIR/scripts/bootstrap-fedora.sh"
"$REPO_DIR/scripts/install.sh"
