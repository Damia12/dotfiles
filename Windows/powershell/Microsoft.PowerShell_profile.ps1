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
# 2. CONFIGURACIÓN DEL PROMPT (Oh My Posh - Carga Directa)
# =============================================================================
Remove-Item env:POSH_THEME -ErrorAction SilentlyContinue
$ThemePath = 'C:\Users\Felipe\.config\oh-my-posh\oh-my-posh.toml'
if (Test-Path $ThemePath) {
    oh-my-posh init pwsh --config $ThemePath | Invoke-Expression
}
# =============================================================================
# 3. MÓDULOS DE COMPLEMENTO
# =============================================================================
Import-Module Terminal-Icons -ErrorAction SilentlyContinue

# =============================================================================
# 4. CONFIGURACIÓN DE ZOXIDE (Navegación Inteligente de Frecuencia)
# =============================================================================
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression ((zoxide init powershell --cmd cd) -join "`n")
}

# =============================================================================
# 5. ALIASES Y FUNCIONES (Clonación exacta de tu .zshrc de Fedora)
# =============================================================================
Remove-Item alias:ls -ErrorAction SilentlyContinue

# Reemplazo de comandos de listado con el estándar estructural de tu Linux
function ls { eza --icons --group-directories-first $args }
function ll { eza -lh --icons --group-directories-first $args }
function la { eza -lah --icons --group-directories-first $args }
function tree { eza -T -L 2 --icons -a --git --ignore-glob=".git|.gitignore|node_modules|dist|build|__pycache__" $args }

# Atajos comunes e infraestructura de persistencia muscular
Set-Alias vim nvim
Set-Alias c clear-host
Set-Alias sudo gsudo
function qq { exit }

# Función mkcd: Crea directorios completos y entra en ellos al instante
function mkcd ($Path) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
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

# =============================================================================
# 6. PSREADLINE (Sugerencias Inteligentes y Resaltado de Sintaxis)
# =============================================================================
Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView # Despliegue estilo fzf-tab

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
        [array]::Reverse($History)
        $Selected = $History | fzf --layout=reverse --height=40% --border --info=inline --prompt="History > "
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