local wezterm = require 'wezterm'
local act = wezterm.action

local config = wezterm.config_builder()

config.font = wezterm.font("BlexMono Nerd Font")
config.font_size = 13

config.color_scheme = 'Dracula'

config.window_decorations = "RESIZE"
config.window_background_opacity = 0.80
config.macos_window_background_blur = 10

config.enable_tab_bar = false

config.keys = {
  {
    key = 'k',
    mods = 'CMD',
    action = act.Multiple {
      act.ClearScrollback 'ScrollbackAndViewport',
      act.SendKey { key = 'L', mods = 'CTRL' },
    },
  },
  {
    key = '"',
    mods = 'LEADER',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = '%',
    mods = 'LEADER',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'j', -- or DownArrow
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection('Down'),
  },
  {
    key = 'k', -- or UpArrow
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection('Up'),
  },
  {
    key = 'x',
    mods = 'LEADER',
    action = wezterm.action.CloseCurrentPane { confirm = true },
  },
  {
    key = 'h', -- or LeftArrow
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection('Left'),
  },
  {
    key = 'l', -- or RightArrow
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection('Right'),
  },
}

config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

config.disable_default_key_bindings = false

return config
