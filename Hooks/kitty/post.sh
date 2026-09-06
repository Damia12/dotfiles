#!/usr/bin/env bash
# Corre despues de desplegar el grupo "kitty" (via `tuckr set kitty`).
# kitty.conf pide JetBrainsMono Nerd Font Mono (kitty.conf:5) — sin ella,
# todos los glifos de la statusline y del tema se ven mal, no es solo un icono.

set -euo pipefail

if command -v fc-list >/dev/null 2>&1; then
  if ! fc-list | grep -qi "jetbrainsmono nerd font mono"; then
    echo "AVISO: no se encontro 'JetBrainsMono Nerd Font Mono' instalada." >&2
    echo "       kitty.conf la pide como font_family — instalala antes de abrir kitty." >&2
  fi
else
  echo "AVISO: 'fc-list' no esta disponible, no pude verificar la fuente." >&2
fi
