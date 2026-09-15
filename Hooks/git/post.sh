#!/usr/bin/env bash
# Corre despues de desplegar el grupo "git" (via `tuckr set git`).
# Crea ~/.gitconfig.local si falta (nunca se versiona, ver .gitconfig:38-39)
# y avisa si faltan los binarios que .gitconfig da por sentado.
#
# SOLO SIRVE EN LINUX, aunque el grupo "git" sea de ambos sistemas. En Windows,
# Tuckr lanza los hooks con `cmd /c`, y un .sh se abre en una ventana de Git
# Bash aparte: Tuckr no espera, no ve si fallo y reporta exito siempre. No
# confiar en este hook alli. En Windows lo hace scripts/install.ps1 (paso 3),
# ANTES de enlazar y leyendo nombre/email del .gitconfig actual, sin preguntar.
# Ademas de [user], el .local de Windows lleva autocrlf y credential.helper.
# No se separa en git_linux/git_windows a proposito: Tuckr busca
# Configs/<nombre-literal> (dotfiles.rs:449), y con Hooks/git_windows un
# `tuckr set git` dejaria de symlinkear Configs/git.

set -euo pipefail

LOCAL_CONFIG="$HOME/.gitconfig.local"

if [[ ! -f "$LOCAL_CONFIG" ]]; then
  if [[ -t 0 ]]; then
    echo "No existe $LOCAL_CONFIG (nombre/email de git) — lo armamos ahora."
    read -rp "Nombre para git: " git_name
    read -rp "Email para git: " git_email

    cat > "$LOCAL_CONFIG" <<EOF
[user]
    name = $git_name
    email = $git_email
EOF
    chmod 600 "$LOCAL_CONFIG"
    echo "Creado $LOCAL_CONFIG"
  else
    echo "AVISO: falta $LOCAL_CONFIG y no hay terminal interactiva para preguntar." >&2
    echo "       Corre 'tuckr set git' desde una terminal, o crealo a mano." >&2
  fi
fi

for bin in delta code; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "AVISO: '$bin' no esta instalado — .gitconfig lo usa (pager/mergetool)." >&2
  fi
done
