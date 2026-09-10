#Requires -Version 5.1
<#
    Despliega los dotfiles en Windows con tuckr.
    Equivalente de scripts/install.sh, que hace lo mismo en Linux.

    Por que existe una version .ps1 en vez de reusar install.sh:
    bash en Windows llega dentro de Git, y Git lo instala el paso 1
    (bootstrap-windows.ps1). El paso 2 no puede depender de algo que
    el paso 1 todavia no instalo. PowerShell si viene de fabrica.

    Las tres comprobaciones que install.sh no necesita en Linux:
      1. el linker de MSVC, sin el cual `cargo install tuckr` falla
         con un error de enlazado que no dice que falta;
      2. permiso para crear symlinks, que en Windows exige ser
         administrador o tener el Modo Desarrollador activado;
      3. conflictos previos, porque `tuckr set` sobre archivos reales
         que ya existen no es una operacion inocente.

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

function Write-Paso    { param([string] $Texto) Write-Host "`n==> $Texto" -ForegroundColor Cyan }
function Write-Ok      { param([string] $Texto) Write-Host "    OK    $Texto" -ForegroundColor Green }
function Write-Aviso   { param([string] $Texto) Write-Host "    AVISO $Texto" -ForegroundColor Yellow }
function Write-Falla   { param([string] $Texto) Write-Host "    ERROR $Texto" -ForegroundColor Red }

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
} catch {
    $modoDesarrollador = $false
}

if ($esAdmin) {
    Write-Ok "esta sesion es administrador"
} elseif ($modoDesarrollador) {
    Write-Ok "Modo Desarrollador activado"
} else {
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
} else {
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
        Write-Falla "falta el linker de MSVC — 'cargo install tuckr' fallaria con un error opaco."
        Write-Host "          Instalalo con (todo en una linea):"
        Write-Host '            winget install --id Microsoft.VisualStudio.2022.BuildTools -e --override "--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"'
        exit 1
    }
    Write-Ok "MSVC encontrado en $rutaMsvc"

    if ($DryRun) {
        Write-Host "    [dry-run] correria: cargo install tuckr"
    } else {
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
# 3. Conflictos previos
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
    Write-Host "          El destino ya tiene archivos reales. Opciones:"
    Write-Host "            - 'tuckr set <grupo> --adopt' para que tuckr absorba al repo el archivo actual"
    Write-Host "            - mover los originales a mano y repetir"
    Write-Host "            - repetir con -Force si sabes lo que haces"
    if (-not $DryRun) { exit 1 }
    Write-Aviso "en dry-run sigo igual, para mostrarte el resto del plan."
} elseif ($statusFallo) {
    Write-Aviso "hay conflictos, pero -Force esta activo: sigo adelante."
} else {
    Write-Ok "sin conflictos"
}

# ---------------------------------------------------------------------------
# 4. Desplegar
# ---------------------------------------------------------------------------
# `tuckr set` despliega y ademas corre los hooks del grupo. El comodin va
# entre comillas para que lo interprete tuckr y no PowerShell.

Write-Paso "Desplegando dotfiles"

if ($DryRun) {
    Write-Host "    [dry-run] correria: tuckr set '*'"
    Write-Host "`nDry-run terminado. Nada fue modificado." -ForegroundColor Magenta
    exit 0
}

tuckr set '*'
if ($LASTEXITCODE -ne 0) {
    Write-Falla "'tuckr set' termino con errores."
    exit 1
}

Write-Host "`nListo. Corre 'tuckr status' para confirmar." -ForegroundColor Green
