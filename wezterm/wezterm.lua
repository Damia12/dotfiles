local wezterm = require 'wezterm'
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- =========================================================
-- 1. CONFIGURACIÓN GENERAL Y SHELL
-- =========================================================
config.default_cwd = 'C:/Users/Felipe'
-- config.default_prog = { 'powershell.exe' }
config.default_prog = { 'pwsh.exe', '-NoLogo' }
config.window_close_confirmation = 'NeverPrompt'

-- NUEVO: Historial más largo y silencio de campana
config.scrollback_lines = 10000
-- config.audible_bell = "Disabled"
-- config.visual_bell = {
--   fade_in_duration_ms = 75,
--   fade_out_duration_ms = 75,
--   target = 'CursorColor',
-- }

-- =========================================================
-- 2. APARIENCIA
-- =========================================================
config.font = wezterm.font 'MesloLGS Nerd Font'
config.font_size = 15.0
config.color_scheme = 'Eldritch'

-- --- CONFIGURACIÓN DEL CURSOR ---
config.default_cursor_style = 'BlinkingUnderline'--'SteadyBlock'--'BlinkingBar'

-- 1. Grosor (Prueba con '3px' o '4px'. El normal es '1px')
config.cursor_thickness = '2px'

-- 2. Velocidad (En milisegundos. 300 es rápido, 800 es lento)
config.cursor_blink_rate = 500 

-- (Opcional) Animación suave del parpadeo
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'

config.unicode_version = 14
config.char_select_font_size = 13.0
-- Si el cursor se ve "encima" de la letra, esto le da un respiro horizontal
config.line_height = 1.1  -- Un poco de aire vertical
config.cell_width = 1.0   -- Asegúrate que esté en 1.0 o 1.1

-- =========================================================
-- 3. VENTANA Y PESTAÑAS
-- =========================================================
config.initial_cols = 100
config.initial_rows = 25

config.window_decorations = "TITLE | RESIZE"
--config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_padding = { left = 10, right = 10, top = 10, bottom = 10 }

config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true

config.window_frame = {
  font_size = 10.5, -- Antes estaba en 0.0, por eso no veías nada
  active_titlebar_bg = '#1a1b26', 
  inactive_titlebar_bg = '#16161e',
}

-- =========================================================
-- 4. ATAJOS DE TECLADO (KEYS)
-- =========================================================
config.keys = {
  -- GESTIÓN APP
  { key = 'q', mods = 'CTRL', action = wezterm.action.QuitApplication },
  { key = 'w', mods = 'CTRL', action = wezterm.action.CloseCurrentPane { confirm = false } },
  
  -- NUEVO: Command Palette (Buscador de comandos) con Ctrl+Shift+P
  { key = 'p', mods = 'ALT', action = wezterm.action.ActivateCommandPalette },

  -- PESTAÑAS
  { key = 't', mods = 'CTRL', action = wezterm.action.SpawnTab 'DefaultDomain' },
  { key = 'Tab', mods = 'CTRL', action = wezterm.action.ActivateTabRelative(1) },
  { key = 'Tab', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateTabRelative(-1) },

  -- SPLITS (Crear divisiones)
  { key = '\\', mods = 'ALT', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '-', mods = 'ALT', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },

  -- NAVEGACIÓN PANELES (Alt + Flechas)
  { key = 'LeftArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Down' },

  -- NUEVO: REDIMENSIONAR PANELES (Alt + Shift + Flechas)
  { key = 'LeftArrow', mods = 'ALT|SHIFT', action = wezterm.action.AdjustPaneSize { 'Left', 5 } },
  { key = 'RightArrow', mods = 'ALT|SHIFT', action = wezterm.action.AdjustPaneSize { 'Right', 5 } },
  { key = 'UpArrow', mods = 'ALT|SHIFT', action = wezterm.action.AdjustPaneSize { 'Up', 5 } },
  { key = 'DownArrow', mods = 'ALT|SHIFT', action = wezterm.action.AdjustPaneSize { 'Down', 5 } },
}

-- =========================================================
-- 5. RATÓN
-- =========================================================
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
}

return config