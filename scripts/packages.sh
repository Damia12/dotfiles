#!/usr/bin/env bash
# Inventario de software instalado "a mano" con el tiempo, fuera de lo que
# bootstrap-fedora.sh instala a proposito. Equivalente Linux del
# `winget export -o packages.json` que ya se usa del lado Windows.
#
# Uso: scripts/packages.sh > scripts/packages-snapshot.txt
# Se vuelve obsoleto con el tiempo -- regenerar antes de confiar en el.

set -euo pipefail

echo "# Paquetes dnf instalados explicitamente ($(date +%F))"
dnf repoquery --userinstalled 2>/dev/null

echo ""
echo "# Flatpak"
command -v flatpak >/dev/null 2>&1 && flatpak list --app || echo "(flatpak no instalado)"

echo ""
echo "# Snap"
command -v snap >/dev/null 2>&1 && snap list || echo "(snap no instalado)"

echo ""
echo "# Binarios de cargo"
command -v cargo >/dev/null 2>&1 && cargo install --list || echo "(cargo no instalado)"

echo ""
echo "# Paquetes globales de npm"
command -v npm >/dev/null 2>&1 && npm list -g --depth=0 || echo "(npm no instalado)"

echo ""
echo "# Paquetes de pip (usuario)"
command -v pip >/dev/null 2>&1 && pip list --user || echo "(pip no instalado)"

echo ""
echo "# Extensiones de VS Code"
command -v code >/dev/null 2>&1 && code --list-extensions || echo "(code no instalado)"
