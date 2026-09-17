#Requires -Version 5.1
<#
    Despliega los dotfiles en Windows con tuckr.
    Equivalente de scripts/install.sh, que hace lo mismo en Linux.

    Por que existe una version .ps1 en vez de reusar install.sh:
    bash en Windows llega dentro de Git, y Git lo instala el paso 1
    (bootstrap-windows.ps1). El paso 2 no puede depender de algo que
    el paso 1 todavia no instalo. PowerShell si viene de fabrica.

    Lo que hace de mas respecto a install.sh, porque Windows lo necesita:
      1. comprueba el permiso para crear symlinks, que aqui exige ser
         administrador o tener el Modo Desarrollador activado;
      2. comprueba el linker de MSVC, sin el cual `cargo install tuckr`
         falla con un error de enlazado que no dice que falta;
      3. crea ~\.gitconfig.local ANTES de enlazar, leyendo nombre y email
         del .gitconfig actual (en Linux eso lo hace Hooks/git/post.sh
         despues de enlazar, pero ese hook no puede correr en Windows);
      4. comprueba conflictos previos, porque `tuckr set` sobre archivos
         reales que ya existen no es una operacion inocente.

    Uso:
      .\scripts\install.ps1              despliega
      .\scripts\install.ps1 -DryRun      muestra que haria, sin tocar nada
      .\scripts\install.ps1 -Force       despliega aunque haya conflictos

    Si la Execution Policy lo bloquea:
      powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
#>

[CmdletBinding()]
param(
    [switch] $DryRun,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

function Write-Paso { param([string] $Texto) Write-Host "`n==> $Texto" -ForegroundColor Cyan }
function Write-Ok { param([string] $Texto) Write-Host "    OK    $Texto" -ForegroundColor Green }
function Write-Aviso { param([string] $Texto) Write-Host "    AVISO $Texto" -ForegroundColor Yellow }
function Write-Falla { param([string] $Texto) Write-Host "    ERROR $Texto" -ForegroundColor Red }

function Test-Comando {
    param([string] $Nombre)
    return [bool] (Get-Command $Nombre -ErrorAction SilentlyContinue)
}

if ($DryRun) {
    Write-Host "MODO DRY-RUN: no se crea ni se modifica nada." -ForegroundColor Magenta
}

# ---------------------------------------------------------------------------
# 1. Permiso para crear symlinks
# ---------------------------------------------------------------------------
# tuckr despliega con enlaces simbolicos. Windows solo deja crearlos si el
# proceso es administrador o si el Modo Desarrollador esta activado. Sin eso
# `tuckr set` falla a mitad de camino y deja el despliegue incompleto.

Write-Paso "Comprobando permisos para crear symlinks"

$identidad = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identidad)
$esAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$modoDesarrollador = $false
try {
    $clave = Get-ItemProperty `
        -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
        -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction Stop
    $modoDesarrollador = ($clave.AllowDevelopmentWithoutDevLicense -eq 1)
}
catch {
    $modoDesarrollador = $false
}

if ($esAdmin) {
    Write-Ok "esta sesion es administrador"
}
elseif ($modoDesarrollador) {
    Write-Ok "Modo Desarrollador activado"
}
else {
    Write-Falla "no puedes crear symlinks: ni administrador ni Modo Desarrollador."
    Write-Host "          Cualquiera de estas dos lo arregla:"
    Write-Host "            - abrir PowerShell como administrador y repetir, o"
    Write-Host "            - Configuracion > Sistema > Para desarrolladores > Modo de desarrollador"
    if (-not $DryRun) { exit 1 }
    Write-Aviso "en dry-run sigo igual, para mostrarte el resto del plan."
}

# ---------------------------------------------------------------------------
# 2. tuckr disponible (y el toolchain para compilarlo, si falta)
# ---------------------------------------------------------------------------

Write-Paso "Comprobando tuckr"

if (Test-Comando 'tuckr') {
    Write-Ok "ya instalado en $((Get-Command tuckr).Source)"
}
else {
    Write-Aviso "no esta instalado, hay que compilarlo."

    if (-not (Test-Comando 'cargo')) {
        Write-Falla "falta 'cargo' (Rust). Instalalo con: winget install Rustlang.Rustup"
        exit 1
    }
    Write-Ok "cargo disponible"

    # tuckr no publica binarios: `cargo install` compila desde fuente, y en
    # Windows eso necesita el linker de MSVC. Sin el, cargo falla con un error
    # de enlazado que en ningun momento menciona que el problema es el linker.
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $rutaMsvc = $null
    if (Test-Path $vswhere) {
        $rutaMsvc = & $vswhere -products * `
            -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
            -property installationPath 2>$null
    }

    if ([string]::IsNullOrWhiteSpace($rutaMsvc)) {
        Write-Falla "falta el linker de MSVC - 'cargo install tuckr' fallaria con un error opaco."
        Write-Host "          Instalalo con (todo en una linea):"
        Write-Host '            winget install --id Microsoft.VisualStudio.2022.BuildTools -e --override "--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"'
        exit 1
    }
    Write-Ok "MSVC encontrado en $rutaMsvc"

    if ($DryRun) {
        Write-Host "    [dry-run] correria: cargo install tuckr"
    }
    else {
        Write-Host "    Compilando tuckr (tarda ~30 s)..."
        # Ojo: se compila desde PowerShell, no desde Git Bash. En Git Bash el
        # link.exe de GNU coreutils se antepone al de Microsoft y rompe el enlazado.
        cargo install tuckr
        if ($LASTEXITCODE -ne 0) {
            Write-Falla "'cargo install tuckr' fallo."
            exit 1
        }
    }
}

# cargo instala en ~\.cargo\bin, que puede no estar en el PATH de esta sesion.
$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
if ((Test-Path $cargoBin) -and ($env:PATH -notlike "*$cargoBin*")) {
    $env:PATH = "$cargoBin;$env:PATH"
    Write-Ok "anadido $cargoBin al PATH de esta sesion"
}

# ---------------------------------------------------------------------------
# 3. ~\.gitconfig.local (lo que Hooks/git/post.sh hace en Linux)
# ---------------------------------------------------------------------------
# El .gitconfig del repo es portable: no lleva [user], autocrlf ni [credential].
# Eso vive en ~\.gitconfig.local, que el .gitconfig incluye al final y nunca se
# versiona. En Linux lo crea el hook de git despues de enlazar; en Windows ese
# hook no puede correr (tuckr lo lanza con `cmd /c`, ver Hooks/git/post.sh), asi
# que se hace aqui, y ademas ANTES de enlazar: si tuckr reemplaza el .gitconfig
# actual sin que el .local exista, git se queda sin nombre ni email.
#
# Ventaja sobre el hook: no hace falta preguntar. El .gitconfig actual ya tiene
# los datos y se leen de ahi. Solo se pregunta en una maquina nueva donde no
# haya nada, igual que en Linux.

Write-Paso "Preparando ~\.gitconfig.local"

$gitLocal = Join-Path $env:USERPROFILE '.gitconfig.local'

if (Test-Path $gitLocal) {
    Write-Ok "ya existe, no se toca"
}
elseif (-not (Test-Comando 'git')) {
    Write-Aviso "git no esta en el PATH, no puedo leer la config actual. Crea $gitLocal a mano."
}
else {
    # Se lee del .gitconfig actual ANTES de que tuckr lo reemplace por el enlace.
    $gitNombre   = (git config --global user.name 2>$null)
    $gitEmail    = (git config --global user.email 2>$null)
    $gitAutocrlf = (git config --global core.autocrlf 2>$null)
    $gitCred     = (git config --global credential.helper 2>$null)

    if ([string]::IsNullOrWhiteSpace($gitNombre) -or [string]::IsNullOrWhiteSpace($gitEmail)) {
        if ($DryRun) {
            Write-Host "    [dry-run] no hay nombre/email en el .gitconfig actual: los preguntaria"
            $gitNombre = '<nombre>'
            $gitEmail = '<email>'
        }
        else {
            Write-Host "    No hay nombre/email de git configurados. Los armamos ahora."
            $gitNombre = Read-Host "    Nombre para git"
            $gitEmail = Read-Host "    Email para git"
        }
    }
    else {
        Write-Ok "leidos del .gitconfig actual: $gitNombre <$gitEmail>"
    }

    # Valores por defecto de Windows si el .gitconfig actual no los tenia.
    if ([string]::IsNullOrWhiteSpace($gitAutocrlf)) { $gitAutocrlf = 'true' }
    if ([string]::IsNullOrWhiteSpace($gitCred)) { $gitCred = 'manager' }

    $contenidoLocal = @"
[user]
    name = $gitNombre
    email = $gitEmail
[core]
    autocrlf = $gitAutocrlf
[credential]
    helper = $gitCred
"@

    if ($DryRun) {
        Write-Host "    [dry-run] crearia $gitLocal con:"
        $contenidoLocal -split "`n" | ForEach-Object { Write-Host "        $_" }
    }
    else {
        # UTF-8 sin BOM: git no entiende el BOM que Set-Content pone en 5.1.
        [IO.File]::WriteAllText($gitLocal, $contenidoLocal + "`n", (New-Object Text.UTF8Encoding $false))
        Write-Ok "creado $gitLocal"
    }
}

# ---------------------------------------------------------------------------
# 4. Conflictos previos
# ---------------------------------------------------------------------------
# Un grupo "en conflicto" es uno cuyo destino ya tiene un archivo real. Pasa
# siempre la primera vez, porque las configs se copiaron al repo DESDE la
# maquina y los originales siguen en su sitio. Desplegar encima sin mirar es
# justo lo que no queremos.

Write-Paso "Comprobando conflictos"

$salidaStatus = (& tuckr status 2>&1 | Out-String)
$statusFallo = ($LASTEXITCODE -ne 0)

Write-Host $salidaStatus

if ($statusFallo -and -not $Force) {
    Write-Falla "hay grupos en conflicto (ver la tabla de arriba)."
    Write-Host "          El destino ya tiene archivos reales que el enlace reemplazaria. Opciones:"
    Write-Host "            - repetir con -Force: reemplaza esos archivos por enlaces al repo."
    Write-Host "              Seguro si son copias de lo que hay en el repo. El .gitconfig.local ya"
    Write-Host "              quedo listo arriba, asi que git no pierde tu nombre ni tu email."
    Write-Host "            - mover los originales a mano y repetir."
    Write-Host "          Evita 'tuckr set --adopt': copia tus archivos AL repo, con tu email dentro."
    if (-not $DryRun) { exit 1 }
    Write-Aviso "en dry-run sigo igual, para mostrarte el resto del plan."
}
elseif ($statusFallo) {
    Write-Aviso "hay conflictos, pero -Force esta activo: sigo adelante."
}
else {
    Write-Ok "sin conflictos"
}

# ---------------------------------------------------------------------------
# 5. Desplegar
# ---------------------------------------------------------------------------
# `tuckr set` despliega y ademas corre los hooks del grupo. El comodin va
# entre comillas para que lo interprete tuckr y no PowerShell.
#
# -Force tiene que llegar hasta tuckr como --force: sin el, tuckr se niega a
# reemplazar un archivo que ya existe y no despliega NADA (y marca todos los
# hooks como fallidos). El -Force del script sirve para dos cosas: seguir pese
# al aviso de conflictos, y decirle a tuckr que si puede pisar.

Write-Paso "Desplegando dotfiles"

$argsTuckr = @('set', '*')
if ($Force) { $argsTuckr += '--force' }

if ($DryRun) {
    Write-Host "    [dry-run] correria: tuckr $($argsTuckr -join ' ')"
    Write-Host "`nDry-run terminado. Nada fue modificado." -ForegroundColor Magenta
    exit 0
}

tuckr @argsTuckr
if ($LASTEXITCODE -ne 0) {
    Write-Falla "'tuckr set' termino con errores."
    exit 1
}

Write-Host "`nListo. Corre 'tuckr status' para confirmar." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 6. Lo que no se puede automatizar
# ---------------------------------------------------------------------------
# Todo lo de abajo es autenticarse en un servicio externo. Automatizarlo
# significaria guardar un token o una clave privada en el repo, y eso es lo
# unico que este repo prohibe. Se recuerda aqui, al final, que es cuando toca.

# $gitEmail solo existe si el paso 3 lo leyo; si el .local ya estaba, se lee de ahi.
$emailSsh = git config --global user.email 2>$null
if ([string]::IsNullOrWhiteSpace($emailSsh)) { $emailSsh = 'tu@email' }

Write-Host ""
Write-Host "Queda a mano (es tu identidad, no se puede automatizar):" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Claude Code:"
Write-Host "       claude login"
Write-Host ""
Write-Host "  2. GitHub, para poder hacer push. Elige una:"
Write-Host "     a) HTTPS, sin configurar nada: al primer 'git push', Git Credential Manager"
Write-Host "        abre el navegador, te autenticas y guarda el token. El remoto ya es HTTPS"
Write-Host "        si clonaste con init-windows.ps1."
Write-Host "     b) SSH, si la prefieres:"
Write-Host "          ssh-keygen -t ed25519 -C `"$emailSsh`""
Write-Host "          Get-Content `$env:USERPROFILE\.ssh\id_ed25519.pub | Set-Clipboard"
Write-Host "        pega la clave en https://github.com/settings/keys y cambia el remoto:"
Write-Host "          git -C `$env:APPDATA\dotfiles remote set-url origin git@github.com:Damia12/dotfiles.git"
Write-Host ""
Write-Host "  3. Abre una terminal nueva: el perfil de PowerShell recien enlazado carga al arrancar."
