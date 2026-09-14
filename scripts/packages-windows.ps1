#Requires -Version 5.1
<#
    Inventario de software instalado "a mano" con el tiempo, fuera de lo que
    bootstrap-windows.ps1 instala a proposito. Equivalente Windows de
    scripts/packages-linux.sh: mismas secciones donde aplican (cargo, npm, pip,
    VS Code), winget en lugar de dnf/flatpak/snap, y dos propias de Windows
    (modulos de PowerShell y Chocolatey, que UniGetUI usa por debajo).

    Es un documento para leer y comparar, no para reinstalar. Para eso existe
    `winget export -o paquetes.json` + `winget import`, que es otra cosa.

    Uso:
      .\scripts\packages-windows.ps1 | Out-File -Encoding utf8 scripts\packages-snapshot-windows.txt

    Se vuelve obsoleto con el tiempo: regenerar antes de confiar en el.
#>

$ErrorActionPreference = 'Continue'

function Write-Seccion {
    param([string] $Titulo)
    ""
    "# $Titulo"
}

# Corre $Accion solo si $Cmd responde; si no, deja constancia en vez de romper.
function Invoke-Si {
    param([string] $Cmd, [scriptblock] $Accion)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue)
    {
        & $Accion
    }
    else
    {
        "($Cmd no instalado)"
    }
}

"# Paquetes de winget ($(Get-Date -Format 'yyyy-MM-dd'))"
# Solo lo gestionado por winget, como `dnf repoquery --userinstalled` en Linux.
# Sin --source saldria tambien todo lo instalado a mano o por la Store.
Invoke-Si winget { winget list --source winget 2>$null }

Write-Seccion "Binarios de cargo"
Invoke-Si cargo { cargo install --list }

Write-Seccion "Paquetes globales de npm"
Invoke-Si npm { npm list -g --depth=0 }

Write-Seccion "Paquetes de pip"
Invoke-Si pip { pip list 2>$null }

Write-Seccion "Extensiones de VS Code"
Invoke-Si code { code --list-extensions }

Write-Seccion "Modulos de PowerShell (Install-Module)"
$modulos = Get-InstalledModule -ErrorAction SilentlyContinue
if ($modulos)
{
    $modulos | ForEach-Object { "$($_.Name) $($_.Version)" }
}
else
{
    "(ninguno)"
}

Write-Seccion "Chocolatey"
# --limit-output: solo "nombre|version", sin el banner ni las validaciones.
Invoke-Si choco {
    $lista = choco list --limit-output 2>$null
    if ($lista) { $lista } else { "(ninguno)" }
}
