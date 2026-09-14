@echo off
REM Corre despues de desplegar el grupo "powershell_windows" (via `tuckr set powershell`).
REM El perfil da por sentado que oh-my-posh y ccstatusline estan en el PATH, y que la
REM Execution Policy deja cargar perfiles. Si es Restricted, PowerShell arranca SIN el
REM perfil y no avisa: la terminal aparece sin prompt ni alias, y sin ningun error.
REM
REM Es .cmd por la misma razon que Hooks/oh-my-posh_windows/post.cmd (ver ahi).
REM Como los hooks de Linux, avisa y sale con 0: no bloquea el despliegue.

REM --- 1. Binarios que el perfil invoca al arrancar
for %%b in (oh-my-posh ccstatusline) do (
    where %%b >nul 2>&1 || echo AVISO: '%%b' no esta en el PATH. El perfil lo usa al arrancar. 1>&2
)

REM --- 2. Execution Policy
REM Se limpia PSModulePath antes de llamar a powershell. Si tuckr se lanzo desde
REM pwsh 7, powershell 5.1 hereda las rutas de modulos de la 7 y no puede cargar
REM Microsoft.PowerShell.Security, y Get-ExecutionPolicy falla con "module could
REM not be loaded". Con PSModulePath vacio, 5.1 vuelve a sus rutas por defecto.
set "PSModulePath="
set "POLICY="
for /f "usebackq delims=" %%p in (`powershell -NoProfile -Command "Get-ExecutionPolicy"`) do set "POLICY=%%p"

if "%POLICY%"=="" (
    echo AVISO: no pude leer la Execution Policy. 1>&2
    exit /b 0
)
if /i "%POLICY%"=="Restricted" (
    echo AVISO: la Execution Policy es Restricted. El perfil de PowerShell no va a cargar. 1>&2
    echo        Arreglalo desde PowerShell con: 1>&2
    echo          Set-ExecutionPolicy RemoteSigned -Scope CurrentUser 1>&2
)
exit /b 0
