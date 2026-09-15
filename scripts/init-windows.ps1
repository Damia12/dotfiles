<#
    Arranque desde cero en un Windows recien instalado. Un solo comando, pegado
    en la PowerShell que trae Windows (no hace falta instalar nada antes):

      irm https://raw.githubusercontent.com/Damia12/dotfiles/main/scripts/init-windows.ps1 | iex

    Hace solo lo minimo para que el resto lo hagan los scripts del repo:
      1. instala git con winget: es lo unico que no se puede clonar sin git;
      2. clona el repo en la ruta exacta que tuckr espera (%APPDATA%\dotfiles);
      3. lanza bootstrap-windows.ps1 -Desplegar, que instala todo lo demas y
         encadena install.ps1 en una PowerShell elevada.

    Lo que queda para la persona: aceptar un aviso de UAC, escribir nombre y
    email para git, y al final `claude login` y autenticarse en GitHub.

    Por que `irm | iex` y no "descarga este .ps1 y ejecutalo": la Execution
    Policy de fabrica (Restricted) no deja ejecutar archivos .ps1, pero si
    texto via iex. El bootstrap deja RemoteSigned, asi que solo pasa una vez.
    Es el mismo patron que usan scoop y chocolatey. Ejecuta codigo de este repo
    publico: si no confias en el, lee el script antes de pegarlo.

    Todo va dentro de `& { }` para no dejar variables ni funciones en la sesion
    del usuario despues de correr.

    Para probar sin instalar ni clonar nada:
      $env:DOTFILES_DRYRUN = 1; irm <url> | iex
#>

& {
    $ErrorActionPreference = 'Stop'

    $repoUrl = 'https://github.com/Damia12/dotfiles.git'
    $repoDir = Join-Path $env:APPDATA 'dotfiles'
    $dryRun = [bool] $env:DOTFILES_DRYRUN

    function Write-Paso { param([string] $T) Write-Host "`n==> $T" -ForegroundColor Cyan }
    function Write-Ok { param([string] $T) Write-Host "    OK    $T" -ForegroundColor Green }
    function Write-Salta { param([string] $T) Write-Host "    YA    $T" -ForegroundColor DarkGray }
    function Write-Falla { param([string] $T) Write-Host "    ERROR $T" -ForegroundColor Red }

    function Update-PathDesdeRegistro {
        # Lo recien instalado escribe su ruta en el registro, no en este proceso.
        $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                    [Environment]::GetEnvironmentVariable('PATH', 'User')
    }

    Write-Host "dotfiles: arranque en Windows limpio" -ForegroundColor White
    if ($dryRun) {
        Write-Host "MODO DRY-RUN: no se instala, no se clona, no se modifica nada." -ForegroundColor Magenta
    }

    # --- 1. winget: el gestor con el que se instala todo
    Write-Paso "Comprobando winget"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Falla "winget no esta disponible. Instala 'Instalador de aplicaciones' desde Microsoft Store y repite."
        return
    }
    Write-Ok "winget $(winget --version)"

    # --- 2. git: sin el no se puede clonar
    Write-Paso "Comprobando git"
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Salta "git $((git --version) -replace 'git version ', '')"
    }
    elseif ($dryRun) {
        Write-Host "    [dry-run] instalaria Git.Git"
    }
    else {
        winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
        Update-PathDesdeRegistro
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Falla "git no responde tras instalarlo. Abre una PowerShell nueva y repite el comando."
            return
        }
        Write-Ok "git instalado"
    }

    # --- 3. clonar en la ruta exacta que tuckr espera
    Write-Paso "Comprobando el repo en $repoDir"
    if (Test-Path (Join-Path $repoDir '.git')) {
        Write-Salta "ya esta clonado"
    }
    elseif ($dryRun) {
        Write-Host "    [dry-run] clonaria $repoUrl"
    }
    else {
        git clone $repoUrl $repoDir
        if ($LASTEXITCODE -ne 0) {
            Write-Falla "git clone fallo."
            return
        }
        Write-Ok "clonado"
    }

    # --- 4. el resto lo hace el bootstrap del repo
    Write-Paso "Lanzando bootstrap-windows.ps1 -Desplegar"
    $bootstrap = Join-Path $repoDir 'scripts\bootstrap-windows.ps1'
    if (-not (Test-Path $bootstrap)) {
        Write-Falla "no existe $bootstrap"
        return
    }

    # -ExecutionPolicy Bypass porque en una maquina nueva la policy es Restricted
    # y este es justo el script que la arregla para las siguientes veces.
    $argumentos = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $bootstrap, '-Desplegar')
    if ($dryRun) { $argumentos += '-DryRun' }
    & powershell @argumentos
}
