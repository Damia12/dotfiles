@echo off
REM Corre despues de desplegar el grupo "oh-my-posh_windows" (via `tuckr set oh-my-posh`).
REM oh-my-posh.toml pide JetBrainsMono Nerd Font. Sin ella, los glifos del prompt
REM se ven como cuadros o signos de interrogacion: no es solo un icono, es todo.
REM
REM Es .cmd y no .sh ni .ps1 porque Tuckr en Windows lanza los hooks con `cmd /c`
REM (hooks.rs:78-80 del crate). Probado: un .sh se abre en una ventana de Git Bash
REM aparte sin que Tuckr espere ni vea si fallo (exit 0 siempre), y un .ps1 abre el
REM Bloc de notas y se queda colgado. Solo .cmd/.bat corren en la misma consola y
REM devuelven su exit code.
REM
REM Equivalente de Hooks/kitty_linux/post.sh, que hace lo mismo en Linux con fc-list.
REM Como aquel, avisa y sale con 0: no bloquea el despliegue.

REM Las fuentes pueden estar en la carpeta del sistema o en la del usuario. winget
REM (DEVCOM.JetBrainsMonoNerdFont) y el instalador manual usan la del usuario.
dir /b "%WINDIR%\Fonts\JetBrainsMono*" >nul 2>&1 && exit /b 0
dir /b "%LOCALAPPDATA%\Microsoft\Windows\Fonts\JetBrainsMono*" >nul 2>&1 && exit /b 0

echo AVISO: no se encontro 'JetBrainsMono Nerd Font' instalada. 1>&2
echo        oh-my-posh.toml la da por sentada. Instalala con: 1>&2
echo          winget install DEVCOM.JetBrainsMonoNerdFont 1>&2
echo        y luego ponla como fuente en Windows Terminal. 1>&2
exit /b 0
