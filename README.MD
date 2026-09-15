# dotfiles

Configuración de terminal para Windows y Linux. [Tuckr](https://github.com/RaphGL/Tuckr).

## Recuperar una máquina desde cero

### Windows

En la PowerShell que trae Windows, sin instalar nada antes:

```powershell
irm https://raw.githubusercontent.com/Damia12/dotfiles/main/scripts/init-windows.ps1 | iex
```

Instala git, clona el repo, instala todo lo que la terminal necesita y despliega la
configuración. Pide una confirmación de administrador (UAC) y tu nombre y email para git.

Para ver qué haría sin tocar nada:

```powershell
$env:DOTFILES_DRYRUN = 1; irm https://raw.githubusercontent.com/Damia12/dotfiles/main/scripts/init-windows.ps1 | iex
```

### Linux

```bash
curl -fsSL https://raw.githubusercontent.com/Damia12/dotfiles/main/scripts/init-fedora.sh | bash
```

Instala git, clona el repo, instala todo lo que la terminal necesita y despliega la
configuración. Pide la contraseña de `sudo` y tu nombre y email para git.

Para ver qué haría sin tocar nada:

```bash
curl -fsSL https://raw.githubusercontent.com/Damia12/dotfiles/main/scripts/init-fedora.sh | DOTFILES_DRYRUN=1 bash
```
