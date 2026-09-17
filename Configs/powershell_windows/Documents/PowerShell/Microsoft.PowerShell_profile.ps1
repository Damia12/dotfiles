# =============================================================================
# 0. CODIFICACIÓN DE CONSOLA (Fix para símbolos "?" en fzf, bat, eza, oh-my-posh)
# =============================================================================
# fzf/bat/eza escriben en UTF-8 sin importar la code page activa; si la consola
# no está en 65001, Windows Terminal decodifica mal esos bytes y muestra "?".
# PowerShell 7.4+ tiene además un bug conocido donde el prompt de oh-my-posh
# (íconos/símbolos en ciertos rangos Unicode) sale mal codificado a menos que
# se fuerce también el InputEncoding de la consola, no solo el OutputEncoding.
$OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
chcp 65001 > $null

# =============================================================================
# 0.1 MODO ESTRICTO
# =============================================================================
# Convierte en error inmediato leer una variable no inicializada (en vez de
# devolver $null en silencio) y otras fallas típicas de escritura descuidada.
# Atrapa a tiempo bugs como usar $A cuando el parametro declarado es $All.
Set-StrictMode -Version Latest

# =============================================================================
# 1. VARIABLES DE ENTORNO
# =============================================================================
$env:EDITOR = 'nvim'

# Expone las herramientas GNU reales que trae Git for Windows (grep, sed, awk,
# find, xargs, diff, etc.) con la misma sintaxis exacta que en Linux — evita
# tener que reescribir cada una como función que traduzca a cmdlets nativos.
$GitUsrBin = 'C:\Program Files\Git\usr\bin'
if ((Test-Path $GitUsrBin) -and ($env:PATH -notlike "*$GitUsrBin*")) {
    $env:PATH = "$GitUsrBin;$env:PATH"
}

# =============================================================================
# 2. CONFIGURACIÓN DEL PROMPT (Oh My Posh - Carga desde caché)
# =============================================================================
# oh-my-posh init lanza un proceso externo y parsea el .toml CADA VEZ que abres
# una terminal, aunque el archivo no haya cambiado desde la última vez. En vez
# de eso, guardamos el resultado una sola vez en un .ps1 y solo lo leemos
# (dot-source) — evita el costo de crear el proceso en cada arranque.
# Si editas oh-my-posh.toml, corre el bloque de regeneración de abajo.
Remove-Item env:POSH_THEME -ErrorAction SilentlyContinue
$ThemePath = "$HOME\.config\oh-my-posh\oh-my-posh.toml"
$OhMyPoshCache = "$env:LOCALAPPDATA\ohmyposh_init.ps1"

# Regenera el caché automáticamente solo si el .toml es más reciente que el
# caché (es decir, lo editaste desde la última vez que se generó). Comparar
# una fecha de archivo cuesta ~1ms — nada comparado con relanzar oh-my-posh.exe.
#
# El .toml es un enlace simbólico al repo de dotfiles (tuckr lo despliega así).
# La fecha de un enlace es la de su creación y NO cambia al editar el archivo
# real: hay que mirar la del destino, o el caché nunca se regeneraría después
# de un cambio y el prompt se quedaría en la versión vieja.
$NeedsRegen = -not (Test-Path $OhMyPoshCache)
if (-not $NeedsRegen -and (Test-Path $ThemePath)) {
    $ThemeItem = Get-Item $ThemePath
    if ($ThemeItem.LinkType) { $ThemeItem = $ThemeItem.ResolveLinkTarget($true) }
    $NeedsRegen = $ThemeItem.LastWriteTime -gt (Get-Item $OhMyPoshCache).LastWriteTime
}

if ($NeedsRegen -and (Test-Path $ThemePath)) {
    oh-my-posh init pwsh --config $ThemePath | Out-File $OhMyPoshCache -Encoding utf8
}
if (Test-Path $OhMyPoshCache) {
    . $OhMyPoshCache
}

# =============================================================================
# 3. MÓDULOS DE COMPLEMENTO
# =============================================================================
# Terminal-Icons desactivado: agregaba ~278ms al arranque y lag al correr
# Get-ChildItem/dir, pero ls/ll/la/tree ya usan eza (sección 5), que tiene su
# propio sistema de iconos independiente de este módulo. Si algún día necesitas
# iconos en Get-ChildItem nativo, descomenta la línea de abajo.
# Import-Module Terminal-Icons -ErrorAction SilentlyContinue

# =============================================================================
# 4. CONFIGURACIÓN DE ZOXIDE (Navegación Inteligente de Frecuencia - desde caché)
# =============================================================================
$ZoxideCache = "$env:LOCALAPPDATA\zoxide_init.ps1"

if (-not (Test-Path $ZoxideCache) -and (Get-Command zoxide -ErrorAction SilentlyContinue)) {
    (zoxide init powershell --cmd cd) -join "`n" | Out-File $ZoxideCache -Encoding utf8
}
if (Test-Path $ZoxideCache) {
    . $ZoxideCache
}

# Regenerar ambos cachés manualmente cuando edites oh-my-posh.toml o actualices zoxide:
function Update-ShellCache {
    Remove-Item $OhMyPoshCache, $ZoxideCache -ErrorAction SilentlyContinue
    Write-Host "Caché eliminado. Abre una nueva terminal para regenerarlo." -ForegroundColor Green
}

# =============================================================================
# 5. ALIASES Y FUNCIONES (Clonación exacta de tu .zshrc de Fedora)
# =============================================================================
Remove-Item alias:ls -ErrorAction SilentlyContinue

# Reemplazo de comandos de listado con el estándar estructural de tu Linux
function ls { eza --icons --group-directories-first $args }
function ll { eza -lh --icons --group-directories-first $args }
function la { eza -lah --icons --group-directories-first $args }
function tree {

    # Si el usuario pasa parámetros estilo Windows (/F /A, etc.)
    # usar tree.com.
    if ($args.Count -gt 0 -and $args[0] -match '^/') {
        & "$env:SystemRoot\System32\tree.com" @args
        return
    }

    # Si no hay parámetros, usar eza (tu comportamiento habitual)
    eza `
        -T `
        -L 2 `
        --icons `
        -a `
        --git `
        --ignore-glob=".git|.gitignore|node_modules|dist|build|__pycache__" `
        @args
}
# Atajos comunes e infraestructura de persistencia muscular
Set-Alias vim nvim
Set-Alias c clear-host
Set-Alias sudo gsudo
function qq { exit }
function gallery {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )

    if ($Args.Count -gt 0) {
        switch ($Args[0]) {
            'up' { python -m pip install --upgrade gallery-dl; return }
            'update' { python -m pip install --upgrade gallery-dl; return }
        }
    }

    # Si no es 'up' ni 'update', le pasa todos los argumentos directamente a gallery-dl
    gallery-dl @Args
}

# which: réplica del comando Unix — imprime solo la ruta del ejecutable,
# en vez de la tabla ancha y con columnas mal distribuidas de Get-Command.
function which {
    param([Parameter(Mandatory)][string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        if ($cmd.CommandType -eq 'Application') { $cmd.Source }
        else { "$($cmd.Name): $($cmd.CommandType)" }
    }
    else {
        Write-Host "which: no se encontró '$Name'" -ForegroundColor Red
    }
}

# Función mkcd: Crea directorios completos y entra en ellos al instante
function mkcd ($Path) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

# cp -> Copy-Item con creación automática de directorios
#
# PowerShell trae "cp" como alias de Copy-Item.
# Eliminamos ese alias para poder definir nuestra propia función.
#
# Soporta:
#   -Recurse
#   -Force
#   -Verbose
#   -WhatIf

Remove-Item alias:cp -Force -ErrorAction SilentlyContinue

function cp {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Path,

        [Parameter(Mandatory, Position = 1)]
        [string]$Destination,

        [switch]$Recurse,
        [switch]$Force
    )

    # Detectar si el usuario utilizó -Verbose
    $verboseOn = $VerbosePreference -eq 'Continue'

    # ---------------------------------------------------------
    # 1. Si el destino ya existe
    # ---------------------------------------------------------
    if (Test-Path $Destination) {

        if ($PSCmdlet.ShouldProcess(
                $Destination,
                "Copy $($Path -join ', ')"
            )) {
            Copy-Item `
                -Path $Path `
                -Destination $Destination `
                -Recurse:$Recurse `
                -Force:$Force `
                -Verbose:$verboseOn
        }

        return
    }

    # ---------------------------------------------------------
    # 2. Determinar si el destino debe ser una carpeta
    # ---------------------------------------------------------
    #
    # Es una carpeta si:
    # - hay múltiples elementos de origen, o
    # - el destino termina en "\" o "/"
    #
    $tratarComoCarpeta =
    $Path.Count -gt 1 -or
    $Destination.EndsWith('\') -or
    $Destination.EndsWith('/')

    # ---------------------------------------------------------
    # 3. Crear la carpeta destino
    # ---------------------------------------------------------
    if ($tratarComoCarpeta) {

        if ($PSCmdlet.ShouldProcess(
                $Destination,
                "Create directory"
            )) {
            New-Item `
                -ItemType Directory `
                -Path $Destination `
                -Force `
                -Verbose:$verboseOn |
            Out-Null
        }
    }

    # ---------------------------------------------------------
    # 4. Si el destino parece ser un archivo,
    #    crear solamente su carpeta padre
    # ---------------------------------------------------------
    else {

        $parent = Split-Path $Destination -Parent

        if ($parent -and -not (Test-Path $parent)) {

            if ($PSCmdlet.ShouldProcess(
                    $parent,
                    "Create directory"
                )) {
                New-Item `
                    -ItemType Directory `
                    -Path $parent `
                    -Force `
                    -Verbose:$verboseOn |
                Out-Null
            }
        }
    }

    # ---------------------------------------------------------
    # 5. Copiar
    # ---------------------------------------------------------
    if ($PSCmdlet.ShouldProcess(
            $Destination,
            "Copy $($Path -join ', ')"
        )) {
        Copy-Item `
            -Path $Path `
            -Destination $Destination `
            -Recurse:$Recurse `
            -Force:$Force `
            -Verbose:$verboseOn
    }
}

# rm -rf real: PowerShell trae un alias nativo rm -> Remove-Item que no entiende
# flags estilo Unix (-rf, -fr, -r, -f). Quitamos ese alias (los alias tienen
# prioridad sobre las funciones del mismo nombre) y definimos una función que
# parsea los flags exactamente como lo haría bash/zsh.
Remove-Item alias:rm -Force -ErrorAction SilentlyContinue

function rm {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )

    $recurse = $false
    $force = $false
    $verbose = $false
    $paths = @()

    foreach ($a in $Args) {
        if ($a -match '^-[a-zA-Z]+$') {
            if ($a -match 'r') { $recurse = $true }
            if ($a -match 'f') { $force = $true }
            if ($a -match 'v') { $verbose = $true }
        }
        elseif ($a -eq '--recursive') { $recurse = $true }
        elseif ($a -eq '--force') { $force = $true }
        elseif ($a -eq '--verbose') { $verbose = $true }
        else { $paths += $a }
    }

    if ($paths.Count -eq 0) {
        Write-Warning "rm: falta un operando (ningún archivo o carpeta especificado)."
        return
    }

    foreach ($p in $paths) {
        if (-not (Test-Path -LiteralPath $p)) {
            if (-not $force) {
                Write-Error "rm: no se puede eliminar '$p': no existe el archivo o directorio"
            }
            continue
        }

        $removeParams = @{
            LiteralPath = $p
            Confirm     = $false
            ErrorAction = if ($force) { 'SilentlyContinue' } else { 'Continue' }
        }
        if ($recurse) { $removeParams['Recurse'] = $true }
        if ($force) { $removeParams['Force'] = $true }

        Remove-Item @removeParams

        # PowerShell a veces "termina" sin error pero deja restos si el
        # directorio tiene archivos bloqueados, muy largos, o de solo lectura.
        # Verificamos y, si sigue existiendo, forzamos con robocopy (truco
        # estándar en Windows para vaciar carpetas tercas) antes de reintentar.
        if (Test-Path -LiteralPath $p) {
            if ((Get-Item -LiteralPath $p -Force).PSIsContainer) {
                $empty = Join-Path $env:TEMP ("rm_empty_" + [guid]::NewGuid())
                New-Item -ItemType Directory -Path $empty | Out-Null
                robocopy $empty $p /MIR /NFL /NDL /NJH /NJS | Out-Null
                Remove-Item -LiteralPath $empty -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $p -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
            }
            if (Test-Path -LiteralPath $p) {
                Write-Warning "rm: '$p' no se pudo eliminar por completo (revisa permisos o archivos en uso)."
            }
            elseif ($verbose) {
                Write-Host "eliminado '$p'"
            }
        }
        elseif ($verbose) {
            Write-Host "eliminado '$p'"
        }
    }
}

# Réplica exacta de tu función fz de Fedora (Buscador + Bat Preview + NeoVim)
function fz {
    param($Directory = ".")
    if (Get-Command fd, fzf, bat, nvim -ErrorAction SilentlyContinue) {
        $file = fd --type f --hidden --exclude .git . $Directory | fzf --preview 'bat --style=numbers --color=always {} 2>$null'
        if ($file) { nvim $file }
    }
    else {
        Write-Warning "Asegúrate de tener instalados fd, fzf, bat y nvim en tu PATH."
    }
}

function zip {
    param(
        [Alias("a")]
        [switch]$All,

        [Alias("f")]
        [switch]$Folders,

        [Alias("d")]
        [switch]$Delete,

        [string]$Filter = "*"
    )

    if ($All) {
        $items = Get-ChildItem -Filter $Filter
    }
    elseif ($Folders) {
        $items = Get-ChildItem -Directory -Filter $Filter
    }
    else {
        $items = Get-ChildItem -File -Filter $Filter
    }

    foreach ($item in $items) {

        $zipName = if ($item.PSIsContainer) {
            "$($item.Name).zip"
        }
        else {
            "$($item.BaseName).zip"
        }

        7z a -tzip -mx0 $zipName $item.FullName

        if ($Delete -and $LASTEXITCODE -eq 0) {
            Remove-Item $item.FullName -Recurse:$item.PSIsContainer -Force
        }
    }
}

# =============================================================================
# 6. PSREADLINE (Sugerencias Inteligentes y Resaltado de Sintaxis)
# =============================================================================
Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView # Despliegue estilo fzf-tab
Set-PSReadLineOption -BellStyle None # Sin beep audible al completar/errar
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete # Menu de Tab estilo zsh

# Paleta cromática de comandos en consola
Set-PSReadLineOption -Colors @{
    Command   = 'Green'
    Parameter = 'Gray'
    Operator  = 'Magenta'
    Variable  = 'Cyan'
    String    = 'Yellow'
    Number    = 'Blue'
    Type      = 'Gray'
    Comment   = 'DarkGray'
}

# Filtro preventivo del historial (No almacena comandos cortos de ruido operativo)
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $ignoreList = @('ls', 'll', 'la', 'tree', 'c', 'exit', 'qq', 'history', 'clear')
    if ($ignoreList -contains $line.Trim()) { return $false }
    if ($line.StartsWith(' ')) { return $false }
    return $true
}

# =============================================================================
# 7. WIDGETS INTERACTIVOS DE FZF (Réplica de Atajos de Teclado de Linux)
# =============================================================================

# Widget Ctrl+R: Extracción de historial limpio inyectado directamente en fzf
function fzf-history-widget {
    $History = [Microsoft.PowerShell.PSConsoleReadLine]::GetHistoryItems() |
    Select-Object -Property CommandLine -Unique |
    ForEach-Object { $_.CommandLine }

    if ($History) {
        $Selected = $History | fzf --tac --layout=reverse --height=40% --border --info=inline --prompt="History > "
        if ($Selected) {
            [Microsoft.PowerShell.PSConsoleReadLine]::DeleteLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($Selected)
        }
    }
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}

# Widget Alt+T: Enumeración veloz de archivos con fd pegada en la posición del cursor
function fzf-file-widget {
    if (Get-Command fd, fzf -ErrorAction SilentlyContinue) {
        $Selected = fd --type f --hidden --exclude .git | fzf --layout=reverse --height=40% --border --info=inline --prompt="Files > "
        if ($Selected) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($Selected)
        }
    }
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}

# Registro formal de atajos de teclado en el motor de lectura de la terminal
Set-PSReadLineKeyHandler -Key 'Ctrl+r' -ScriptBlock { fzf-history-widget }
Set-PSReadLineKeyHandler -Key 'Alt+t' -ScriptBlock { fzf-file-widget }

# Búsqueda en historial optimizada con posicionamiento de cursor al final de la línea
Set-PSReadLineKeyHandler -Key UpArrow -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::HistorySearchBackward()
    [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
}

Set-PSReadLineKeyHandler -Key DownArrow -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::HistorySearchForward()
    [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
}