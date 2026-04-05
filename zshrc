# ─────────────────────────────────────────────────────────────────────────────
# POWERLEVEL10K — instant prompt
# Debe ir antes de cualquier output a consola. El bloque carga un snapshot del
# prompt desde caché para que aparezca instantáneamente mientras zsh termina
# de inicializar. Código que produzca output (e.g. sudo, confirmaciones) debe
# ir ANTES de este bloque; todo lo demás puede ir después.
# ─────────────────────────────────────────────────────────────────────────────
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ─────────────────────────────────────────────────────────────────────────────
# VARIABLES DE ENTORNO
# ─────────────────────────────────────────────────────────────────────────────
export EDITOR='nvim'
export TERMINAL='kitty'

# Opciones globales de fzf: altura, layout, borde y símbolos del prompt/cursor.
# Se aplican a cualquier invocación de fzf, incluyendo fzf-tab y fzf-history.
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --info=inline
  --prompt="❯ "
  --pointer="▶"
'

# ─────────────────────────────────────────────────────────────────────────────
# ZINIT — gestor de plugins
# ─────────────────────────────────────────────────────────────────────────────
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Descarga zinit automáticamente si no existe (primer arranque).
if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# ZINIT_NO_ALIAS=1 evita que zinit defina el alias `zi`, previniendo conflictos
# con zoxide (que también usa `zi` por defecto). Se define antes del source.
export ZINIT_NO_ALIAS=1
source "${ZINIT_HOME}/zinit.zsh"

# ─────────────────────────────────────────────────────────────────────────────
# PLUGINS
#
# Orden importante:
#   1. Powerlevel10k primero (tema del prompt, sin Turbo para evitar flicker)
#   2. Plugins de UX sin `wait` (autosuggestions visible desde el primer prompt)
#   3. Completions con `blockf` (modifica fpath; se replica vía cdreplay)
#   4. fzf-tab antes que syntax-highlighting (hookeado al sistema de completions)
#   5. zsh-syntax-highlighting al final (debe ver todos los widgets ya definidos)
#   6. Snippets de Oh-My-Zsh (aliases y funciones de conveniencia)
#   7. compinit DESPUÉS de que todos los plugins hayan modificado fpath
# ─────────────────────────────────────────────────────────────────────────────

# Prompt — carga síncrona obligatoria; Turbo causaría un prompt sin tema al inicio.
zinit ice depth=1
zinit light romkatv/powerlevel10k

# Autosuggestions — sin `wait` para que estén disponibles en el primer prompt.
# STRATEGY: primero busca en historial, luego completa con el engine de zsh.
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC=1
zinit ice lucid
zinit light zsh-users/zsh-autosuggestions

# Completions adicionales — `blockf` añade el directorio del plugin al fpath
# de forma limpia (bloqueando el método nativo). cdreplay lo registra para
# que compinit lo incluya cuando corra más adelante.
zinit ice wait lucid blockf
zinit light zsh-users/zsh-completions

# fzf-tab reemplaza el menú de completions por uno interactivo con fzf.
# Debe cargarse antes de compinit y antes de syntax-highlighting.
zinit light Aloxaf/fzf-tab

# Syntax highlighting — SIEMPRE al último entre plugins de usuario.
# Necesita que todos los demás widgets y funciones ya estén registrados.
zinit ice wait lucid
zinit light zsh-users/zsh-syntax-highlighting

# Snippets de OMZ — aliases, funciones y helpers de uso cotidiano.
# `git.zsh` debe ir antes que el plugin `git` (es su librería base).
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::dnf
zinit snippet OMZP::sudo        # Doble <Esc> antepone sudo al comando actual
zinit snippet OMZP::extract     # Alias `extract` para cualquier formato comprimido
zinit snippet OMZP::command-not-found

# ─────────────────────────────────────────────────────────────────────────────
# COMPLETIONS — inicialización
#
# compinit corre AQUÍ, después de que todos los plugins hayan modificado fpath.
# -C omite la verificación de seguridad del dumpfile para acelerar el arranque
# (zsh no revalida permisos de cada función en fpath en cada shell).
# cdreplay -q reproduce los `compdef` acumulados por zinit durante la carga
# de plugins (especialmente los registrados con `blockf`).
# ─────────────────────────────────────────────────────────────────────────────
autoload -U compinit
compinit -C
zinit cdreplay -q

# ─────────────────────────────────────────────────────────────────────────────
# ESTILOS DE COMPLETIONS
# ─────────────────────────────────────────────────────────────────────────────

# Case-insensitive: minúsculas hacen match con mayúsculas y viceversa.
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Colorea los candidatos de completions usando los mismos colores que `ls`.
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Desactiva el menú nativo de zsh; fzf-tab toma el control.
zstyle ':completion:*' menu no

# Preview de directorios al completar `cd` y `zoxide` con eza.
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:nvim:*' fzf-preview 'bat --color=always $realpath 2>/dev/null'
zstyle ':fzf-tab:complete:cat:*'  fzf-preview 'bat --color=always $realpath 2>/dev/null'
zstyle ':fzf-tab:complete:rm:*'   fzf-preview '[[ -d $realpath ]] && eza -1 --color=always $realpath || bat --color=always $realpath 2>/dev/null'

# ─────────────────────────────────────────────────────────────────────────────
# HISTORIAL
# ─────────────────────────────────────────────────────────────────────────────
HISTSIZE=5000
HISTFILE=~/.zsh_history   # Nombre estándar esperado por herramientas externas
SAVEHIST=$HISTSIZE

setopt appendhistory      # Añade al archivo en lugar de sobreescribir
setopt sharehistory       # Comparte historial entre sesiones abiertas
setopt hist_ignore_all_dups  # No guarda duplicados en absoluto
setopt hist_save_no_dups     # No escribe duplicados al archivo
setopt hist_ignore_space     # Líneas que empiecen con espacio no se guardan

# ─────────────────────────────────────────────────────────────────────────────
# KEYBINDINGS
# ─────────────────────────────────────────────────────────────────────────────

# Modo emacs: Ctrl-a/e para inicio/fin de línea, Ctrl-w para borrar palabra, etc.
bindkey -e
bindkey '^p' history-search-backward   # Ctrl-p: historial hacia atrás con prefijo
bindkey '^n' history-search-forward    # Ctrl-n: historial hacia adelante con prefijo
bindkey '^r' fzf-history-widget        # Ctrl-r: búsqueda fuzzy en historial (ver más abajo)
bindkey '^[[3~' delete-char            # Tecla Delete: borra carácter hacia adelante
bindkey '^[t' fzf-file-widget          # Alt-t: busca archivos con fd y pega la ruta en el cursor

# Widget Alt-t: lista archivos con fd y pega la ruta seleccionada donde esté el cursor.
# --hidden incluye dotfiles; --exclude .git evita basura interna de git.
# La función se define directamente porque fzf no está integrado vía `fzf --zsh`.
export FZF_ALT_T_COMMAND='fd --type f --hidden --exclude .git'
fzf-file-widget() {
  local file
  file=$(eval "$FZF_ALT_T_COMMAND" | fzf --prompt="Files > ")
  if [[ -n "$file" ]]; then
    LBUFFER="${LBUFFER}${file}"
  fi
  zle reset-prompt
}
zle -N fzf-file-widget

# Widget personalizado: Ctrl-r abre el historial completo en fzf.
# `fc -rl 1` lista todos los comandos en orden inverso; awk descarta el número
# de línea para que el resultado pegado sea solo el comando.
fzf-history-widget() {
  local selected
  zle -I
  selected=$(fc -rl 1 | awk '{$1=""; print substr($0,2)}' | \
    fzf --prompt="History > ")
  if [[ -n $selected ]]; then
    LBUFFER="$selected"
  fi
  zle reset-prompt
}
zle -N fzf-history-widget

# ─────────────────────────────────────────────────────────────────────────────
# ALIASES
# ─────────────────────────────────────────────────────────────────────────────

# eza reemplaza ls con iconos y directorios primero.
alias ls='eza --icons --group-directories-first'
alias ll='eza -lh --icons --group-directories-first'
alias la='eza -lah --icons --group-directories-first'
alias tree='eza --tree --icons'

alias c='clear'
alias qq='exit'

# zi está reservado para zoxide (ver abajo); este alias añade score al output.
alias zi='zoxide query -i --score'

# ─────────────────────────────────────────────────────────────────────────────
# FUNCIONES
# ─────────────────────────────────────────────────────────────────────────────

# mkcd: crea el directorio completo (con intermedios) y entra en él de una vez.
mkcd() { mkdir -p "$1" && cd "$1" }

# fz: navega archivos con fzf y abre el seleccionado en nvim.
# Acepta un directorio opcional como argumento; sin él busca en el directorio actual.
# bat provee syntax highlighting en el preview; cae en cat si no está instalado.
# fd respeta .gitignore y excluye .git automáticamente.
fz() {
  local file
  file=$(fd --type f --hidden --exclude .git . "${1:-.}" | fzf --preview 'bat --style=numbers --color=always {} 2>/dev/null || cat {}')
  [[ -n "$file" ]] && nvim "$file"
}

# ─────────────────────────────────────────────────────────────────────────────
# INTEGRACIONES
# ─────────────────────────────────────────────────────────────────────────────

# zoxide reemplaza `cd` con un navegador inteligente basado en frecuencia.
# --cmd cd sobreescribe el builtin; usa `zi` para la búsqueda interactiva.
eval "$(zoxide init --cmd cd zsh)"

# ─────────────────────────────────────────────────────────────────────────────
# POWERLEVEL10K — configuración del prompt
# Edita ~/.p10k.zsh o corre `p10k configure` para personalizar.
# ─────────────────────────────────────────────────────────────────────────────
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
