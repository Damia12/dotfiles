#Requires -Version 5.1
<#
    Instala, en un Windows recien instalado, lo que esta configuracion de
    dotfiles da por sentado que ya existe. Correr esto ANTES de install.ps1.

    Equivalente de scripts/bootstrap-fedora.sh, que hace lo mismo en Linux.

    No instala tuckr: eso es trabajo de install.ps1, igual que en Fedora.

    La lista de paquetes no es una suposicion: sale de leer que invoca
    Microsoft.PowerShell_profile.ps1, que pide .gitconfig y que necesita
    ccstatusline. Los Id de winget son los reales, verificados con
    `winget list` sobre una maquina que ya tenia todo funcionando.

    Uso:
      .\scripts\bootstrap-windows.ps1                 instala lo que falte y pregunta si desplegar
      .\scripts\bootstrap-windows.ps1 -Desplegar      idem, y lanza install.ps1 elevado sin preguntar
      .\scripts\bootstrap-windows.ps1 -DryRun         muestra el plan, no toca nada
      .\scripts\bootstrap-windows.ps1 -SinBuildTools  omite Visual Studio Build Tools

    En un Windows recien instalado no hace falta ni clonar a mano: ver
    scripts/init-windows.ps1, que instala git, clona y llama a este con -Desplegar.

    La primera vez, la Execution Policy (Restricted de fabrica) lo bloquea:
      powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-windows.ps1
    Despues ya no: el propio script deja RemoteSigned para el usuario.
#>

[CmdletBinding()]
param(
    [switch] $DryRun,
    [switch] $SinBuildTools,
    [switch] $Desplegar
)

$ErrorActionPreference = 'Stop'

function Write-Paso { param([string] $T) Write-Host "`n==> $T" -ForegroundColor Cyan }
function Write-Ok { param([string] $T) Write-Host "    OK    $T" -ForegroundColor Green }
function Write-Salta { param([string] $T) Write-Host "    YA    $T" -ForegroundColor DarkGray }
function Write-Aviso { param([string] $T) Write-Host "    AVISO $T" -ForegroundColor Yellow }
function Write-Falla { param([string] $T) Write-Host "    ERROR $T" -ForegroundColor Red }

if ($DryRun) {
    Write-Host "MODO DRY-RUN: no se instala ni se modifica nada." -ForegroundColor Magenta
}

# ---------------------------------------------------------------------------
# 0. winget
# ---------------------------------------------------------------------------
# Es el gestor con el que se instala todo lo de abajo. Viene de serie en
# Windows 11 y en Windows 10 desde 1809, pero puede faltar en imagenes viejas
# o recortadas, y entonces no hay nada que hacer desde aqui.

Write-Paso "Comprobando winget"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Falla "winget no esta disponible."
    Write-Host "          Instala 'Instalador de aplicaciones' desde Microsoft Store y repite."
    exit 1
}
Write-Ok "winget $(winget --version)"

# ---------------------------------------------------------------------------
# 0b. Execution Policy
# ---------------------------------------------------------------------------
# Windows cliente viene con Restricted: no ejecuta NINGUN .ps1, ni este. Por eso
# la primera vez se lanza con `-ExecutionPolicy Bypass` (solo vale para ese
# proceso). Aqui se deja RemoteSigned para el usuario, que es permanente, no
# pide administrador y permite scripts locales sin firmar. Si una directiva de
# empresa (GPO) la fija, no se puede cambiar y se avisa.

Write-Paso "Comprobando la Execution Policy"

$policyUsuario = Get-ExecutionPolicy -Scope CurrentUser
if ($policyUsuario -notin @('Undefined', 'Restricted')) {
    Write-Salta "ya es $policyUsuario para el usuario"
}
elseif ($DryRun) {
    Write-Host "    [dry-run] pondria RemoteSigned para el usuario actual (ahora: $policyUsuario)"
}
else {
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
        Write-Ok "RemoteSigned para el usuario actual"
    }
    catch {
        Write-Aviso "no se pudo cambiar (la fija una directiva?). Usa -ExecutionPolicy Bypass al lanzar scripts."
    }
}

# El PATH de este proceso puede ser mas viejo que el del registro (si algo se
# instalo despues de abrir esta terminal). Se refresca antes de comprobar que
# hay, para no reinstalar algo que en realidad ya esta.
$env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('PATH', 'User')

# ---------------------------------------------------------------------------
# 1. Paquetes de winget
# ---------------------------------------------------------------------------
# El campo 'Por' documenta por que esta cada uno: sin eso, en seis meses nadie
# recuerda si alguno se puede quitar. Los Id son exactos y se instalan con -e
# (match exacto) para no traer un paquete parecido por error.
#
# 'Cmd', 'Fuente' y 'Ruta' son la segunda prueba de presencia. Mirar solo
# `winget list` no alcanza: lo que se instalo por fuera de winget (un .exe
# bajado a mano, un instalador propio) no aparece ahi, y el script lo volveria
# a instalar creando un duplicado. Con esto, si la herramienta ya responde o
# ya esta en disco, se respeta venga de donde venga.

$paquetes = @(
    @{ Id = 'Microsoft.PowerShell';         Cmd = 'pwsh';       Por = 'el perfil vive en Documents\PowerShell, que es pwsh 7; Windows solo trae la 5.1' }
    @{ Id = 'Git.Git';                      Cmd = 'git';        Por = 'git, y las herramientas GNU de usr\bin que el perfil agrega al PATH de la sesion' }
    @{ Id = 'DEVCOM.JetBrainsMonoNerdFont'; Fuente = 'JetBrainsMono'; Por = 'sin ella los glifos del prompt y de la statusline salen rotos' }
    @{ Id = 'JanDeDobbeleer.OhMyPosh';      Cmd = 'oh-my-posh'; Por = 'el prompt (seccion 2 del perfil)' }
    @{ Id = 'ajeetdsouza.zoxide';           Cmd = 'zoxide';     Por = 'navegacion por frecuencia, reemplaza cd (seccion 4)' }
    @{ Id = 'eza-community.eza';            Cmd = 'eza';        Por = 'ls, ll, la y tree del perfil' }
    @{ Id = 'sharkdp.fd';                   Cmd = 'fd';         Por = 'la funcion fz y el widget Alt+T' }
    @{ Id = 'junegunn.fzf';                 Cmd = 'fzf';        Por = 'widgets Ctrl+R y Alt+T, y la funcion fz' }
    @{ Id = 'sharkdp.bat';                  Cmd = 'bat';        Por = 'preview con color dentro de fz' }
    @{ Id = 'Neovim.Neovim';                Cmd = 'nvim';       Por = 'EDITOR por defecto y el alias vim' }
    @{ Id = '7zip.7zip';                    Cmd = '7z';         Por = 'la funcion zip del perfil llama a 7z' }
    @{ Id = 'gerardog.gsudo';               Cmd = 'gsudo';      Por = 'el alias sudo del perfil' }
    @{ Id = 'dandavison.delta';             Cmd = 'delta';      Por = 'pager de git (.gitconfig)' }
    @{ Id = 'Microsoft.VisualStudioCode';   Cmd = 'code';       Por = 'mergetool de git (.gitconfig)' }
    @{ Id = 'OpenJS.NodeJS.22';             Cmd = 'node';       Por = 'node y npm, necesarios para ccstatusline' }
    @{ Id = 'Anthropic.ClaudeCode';         Cmd = 'claude';     Por = 'Claude Code CLI (NO la app de escritorio, que es Anthropic.Claude)' }
    @{ Id = 'Python.Python.3.12';           Cmd = 'python';     Por = 'la funcion gallery del perfil' }
    @{ Id = 'Rustlang.Rustup';              Cmd = 'cargo';      Por = 'cargo, con el que install.ps1 compila tuckr' }
    @{ Id = 'Devolutions.UniGetUI';         Ruta = "$env:LOCALAPPDATA\UniGetUI"; Por = 'interfaz grafica de gestores de paquetes' }
)

function Test-YaPresente {
    param([hashtable] $Paquete, [string] $ListaWinget)

    if ($ListaWinget -match [regex]::Escape($Paquete.Id)) {
        return 'winget lo lista'
    }
    if ($Paquete.ContainsKey('Cmd') -and (Get-Command $Paquete.Cmd -ErrorAction SilentlyContinue)) {
        return "'$($Paquete.Cmd)' ya responde (instalado por fuera de winget)"
    }
    if ($Paquete.ContainsKey('Ruta') -and (Test-Path $Paquete.Ruta)) {
        return "ya existe $($Paquete.Ruta)"
    }
    if ($Paquete.ContainsKey('Fuente')) {
        $dirs = @("$env:WINDIR\Fonts", "$env:LOCALAPPDATA\Microsoft\Windows\Fonts")
        foreach ($d in $dirs) {
            if (Test-Path $d) {
                $hit = Get-ChildItem $d -Filter "*$($Paquete.Fuente)*" -ErrorAction SilentlyContinue |
                       Select-Object -First 1
                if ($hit) { return "la fuente ya esta instalada" }
            }
        }
    }
    return $null
}

Write-Paso "Instalando paquetes ($($paquetes.Count) en la lista)"

# Una sola consulta en vez de una por paquete: `winget list` tarda varios
# segundos, y repetirlo 19 veces convierte el script en una espera larga.
$instalados = (winget list 2>$null | Out-String)

foreach ($p in $paquetes) {
    $presente = Test-YaPresente -Paquete $p -ListaWinget $instalados
    if ($presente) {
        Write-Salta "$($p.Id)  ($presente)"
        continue
    }

    if ($DryRun) {
        Write-Host "    [dry-run] instalaria $($p.Id)"
        Write-Host "              porque: $($p.Por)" -ForegroundColor DarkGray
        continue
    }

    Write-Host "    Instalando $($p.Id)..."
    winget install --id $p.Id -e --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Ok $p.Id
    }
    else {
        Write-Aviso "$($p.Id) termino con codigo $LASTEXITCODE - revisalo a mano."
    }
}

# ---------------------------------------------------------------------------
# 2. Visual Studio Build Tools (solo si falta)
# ---------------------------------------------------------------------------
# tuckr no publica binarios: install.ps1 lo compila con cargo, y en Windows
# eso necesita el linker de MSVC. Son varios GB, asi que primero se mira si ya
# hay un Visual Studio con el workload de C++ y solo se instala si no lo hay.

Write-Paso "Comprobando el linker de MSVC (para compilar tuckr)"

if ($SinBuildTools) {
    Write-Salta "omitido por -SinBuildTools"
}
else {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $rutaMsvc = $null
    if (Test-Path $vswhere) {
        $rutaMsvc = & $vswhere -products * `
            -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
            -property installationPath 2>$null
    }

    if (-not [string]::IsNullOrWhiteSpace($rutaMsvc)) {
        Write-Salta "MSVC ya esta en $rutaMsvc"
    }
    elseif ($DryRun) {
        Write-Host "    [dry-run] instalaria Microsoft.VisualStudio.2022.BuildTools (varios GB)"
    }
    else {
        Write-Aviso "falta MSVC. Son varios GB y tarda; sin el, install.ps1 no puede compilar tuckr."
        winget install --id Microsoft.VisualStudio.2022.BuildTools -e `
            --accept-package-agreements --accept-source-agreements `
            --override '--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
        if ($LASTEXITCODE -eq 0) { Write-Ok "Build Tools instalado" }
        else { Write-Aviso "Build Tools termino con codigo $LASTEXITCODE" }
    }
}

# ---------------------------------------------------------------------------
# 3. Paquetes que no vienen de winget
# ---------------------------------------------------------------------------
# gallery-dl se instala SIN --user a proposito: asi cae en Python3xx\Scripts,
# que el instalador de Python ya puso en el PATH. Con --user iria a
# %APPDATA%\Python\...\Scripts, que no esta, y habria que agregarlo.

Write-Paso "Instalando paquetes de npm y pip"

# El PATH de este proceso no ve lo recien instalado: se refresca leyendo el
# registro, que es donde los instaladores acaban de escribir.
$env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('PATH', 'User')

if (Get-Command ccstatusline -ErrorAction SilentlyContinue) {
    Write-Salta "ccstatusline (ya responde)"
}
elseif ($DryRun) {
    Write-Host "    [dry-run] correria: npm install -g ccstatusline"
}
elseif (Get-Command npm -ErrorAction SilentlyContinue) {
    npm install -g ccstatusline
    if ($LASTEXITCODE -eq 0) { Write-Ok "ccstatusline" } else { Write-Aviso "npm fallo" }
}
else {
    Write-Aviso "npm no responde todavia - abre una terminal nueva y corre: npm install -g ccstatusline"
}

if (Get-Command gallery-dl -ErrorAction SilentlyContinue) {
    Write-Salta "gallery-dl (ya responde)"
}
elseif ($DryRun) {
    Write-Host "    [dry-run] correria: pip install gallery-dl"
}
elseif (Get-Command pip -ErrorAction SilentlyContinue) {
    # Sin --user a proposito: asi cae en Python3xx\Scripts, que ya esta en el PATH.
    pip install gallery-dl
    if ($LASTEXITCODE -eq 0) { Write-Ok "gallery-dl" } else { Write-Aviso "pip fallo" }
}
else {
    Write-Aviso "pip no responde todavia - abre una terminal nueva y corre: pip install gallery-dl"
}

# ---------------------------------------------------------------------------
# 4. PATH: agregar solo lo que instalamos y no quedo accesible
# ---------------------------------------------------------------------------
# Casi todos los instaladores registran su propia carpeta. En vez de llevar una
# lista fija de rutas (que envejece mal cuando un instalador cambia de sitio),
# se comprueba que cada comando responda y solo se agrega la carpeta de los que
# no responden.
#
# Dos reglas duras:
#   - nunca `setx`: trunca el valor a 1024 caracteres y destroza el PATH;
#   - nunca agregar Git\usr\bin, que trae link.exe, find.exe y sort.exe de GNU
#     y pisa a los de Windows (ese link.exe rompe `cargo install` con un error
#     de enlazado que no explica nada). El perfil lo agrega solo a su sesion,
#     que es donde corresponde.

function Add-RutaAlPathDeUsuario {
    param([string] $Ruta)

    $actual = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $normalizada = $Ruta.TrimEnd('\')
    $existentes = $actual -split ';' | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }

    if ($existentes -contains $normalizada) {
        Write-Salta "$Ruta ya estaba en el PATH"
        return
    }
    if ($DryRun) {
        Write-Host "    [dry-run] agregaria al PATH de usuario: $Ruta"
        return
    }

    [Environment]::SetEnvironmentVariable('PATH', "$actual;$normalizada", 'User')
    $env:PATH = "$env:PATH;$normalizada"
    Write-Ok "agregado al PATH: $Ruta"
}

Write-Paso "Comprobando que cada herramienta responda"

# comando -> carpetas donde buscarlo si no responde
$candidatos = @{
    'claude'       = @("$env:USERPROFILE\.local\bin")
    'ccstatusline' = @("$env:APPDATA\npm")
    'cargo'        = @("$env:USERPROFILE\.cargo\bin")
    'gallery-dl'   = @("$env:APPDATA\Python\Scripts")
}

$comandos = @('pwsh', 'git', 'oh-my-posh', 'zoxide', 'eza', 'fd', 'fzf', 'bat',
              'nvim', '7z', 'gsudo', 'delta', 'code', 'node', 'npm',
              'claude', 'python', 'pip', 'cargo', 'ccstatusline', 'gallery-dl')

$faltan = @()
foreach ($c in $comandos) {
    if (Get-Command $c -ErrorAction SilentlyContinue) {
        Write-Ok $c
        continue
    }

    $resuelto = $false
    if ($candidatos.ContainsKey($c)) {
        foreach ($dir in $candidatos[$c]) {
            if (Test-Path $dir) {
                $exe = Get-ChildItem $dir -Filter "$c.*" -ErrorAction SilentlyContinue |
                       Select-Object -First 1
                if ($exe) {
                    Add-RutaAlPathDeUsuario $dir
                    $resuelto = $true
                    break
                }
            }
        }
    }

    if (-not $resuelto) {
        Write-Aviso "$c no responde"
        $faltan += $c
    }
}

# ---------------------------------------------------------------------------
# 5. Revision del PATH (informativa: no se toca nada)
# ---------------------------------------------------------------------------
# Limpiar un PATH automaticamente es de las cosas que, si se equivocan, dejan
# la sesion sin encontrar sus propios programas. Se reporta y decide la persona.

Write-Paso "Revisando el PATH de usuario (solo informativo)"

$pathUsuario = [Environment]::GetEnvironmentVariable('PATH', 'User')
$entradas = $pathUsuario -split ';' | Where-Object { $_ }

$duplicados = $entradas | ForEach-Object { $_.TrimEnd('\').ToLower() } |
              Group-Object | Where-Object { $_.Count -gt 1 }
foreach ($d in $duplicados) {
    Write-Aviso "repetida $($d.Count) veces: $($d.Name)"
}

foreach ($e in $entradas) {
    if (-not (Test-Path $e)) {
        Write-Aviso "no existe: $e"
    }
    elseif (-not (Get-Item $e -ErrorAction SilentlyContinue).PSIsContainer) {
        Write-Aviso "es un archivo, no una carpeta: $e"
    }
}

Write-Host "    Longitud del PATH de usuario: $($pathUsuario.Length) caracteres"
if ($pathUsuario.Length -gt 1800) {
    Write-Aviso "se acerca al limite practico (~2047). Conviene depurarlo a mano."
}

# ---------------------------------------------------------------------------
# 6. Cierre
# ---------------------------------------------------------------------------

Write-Paso "Listo"

if ($faltan.Count -gt 0 -and -not $DryRun) {
    Write-Aviso "sin resolver: $($faltan -join ', ')"
    Write-Host "          Suele bastar con abrir una terminal nueva (el PATH se recarga al arrancar)."
}

# ---------------------------------------------------------------------------
# 7. Encadenar el despliegue (paso 2) sin cambiar de terminal
# ---------------------------------------------------------------------------
# install.ps1 necesita administrador para crear symlinks. En vez de pedir "abre
# otra terminal como admin y corre esto", se lanza desde aqui en una PowerShell
# elevada: Windows pide confirmacion (UAC) una vez y listo. Con -NoExit la
# ventana queda abierta para que se vea el resultado; por eso no se espera.
#
# Con -Desplegar (lo que pasa init-windows.ps1) no pregunta. Sin el, pregunta,
# porque desplegar sobre una maquina que ya tenia configs es decision de quien
# la usa.

$installPs1 = Join-Path $PSScriptRoot 'install.ps1'

if ($DryRun) {
    if ($Desplegar) {
        Write-Host "    [dry-run] lanzaria install.ps1 en una PowerShell elevada (UAC)"
    }
    else {
        Write-Host "    [dry-run] preguntaria si desplegar ahora con install.ps1"
    }
    Write-Host "`nDry-run terminado. Nada fue modificado." -ForegroundColor Magenta
    exit 0
}

$lanzar = $Desplegar
if (-not $Desplegar) {
    Write-Host ""
    $resp = Read-Host "Desplegar los dotfiles ahora con install.ps1? Windows pedira confirmacion de administrador. [s/N]"
    $lanzar = ($resp -match '^[sS]')
}

if ($lanzar) {
    # pwsh si el bootstrap lo acaba de instalar (el PATH ya se refresco); si no, la 5.1.
    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
    Write-Host "    Lanzando install.ps1 elevado con $shell. Acepta el aviso de Windows (UAC)."
    Start-Process $shell -Verb RunAs -ArgumentList @(
        '-NoExit', '-ExecutionPolicy', 'Bypass', '-File', "`"$installPs1`""
    )
    Write-Host "    El resultado aparece en la ventana nueva."
}
else {
    Write-Host ""
    Write-Host "Cuando quieras desplegar:" -ForegroundColor Yellow
    Write-Host "  - Abre PowerShell como administrador (o activa el Modo Desarrollador) y corre:"
    Write-Host "      $installPs1"
    Write-Host "  - Si esta terminal es vieja, abre una nueva para que el PATH se recargue."
}
