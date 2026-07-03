-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

config.color_scheme = 'Brewer (dark) (terminal.sexy)'

config.font = wezterm.font("MesloLGS Nerd Font Mono")
config.font_size = 17

config.enable_tab_bar = true

-- Send left Option as Alt so tmux M- bindings and Claude Code Option shortcuts work
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = true

-- Tab titles: always the directory name, never program-set titles
-- (tmux windows show the session topic; WezTerm tabs show WHERE)
wezterm.on("format-tab-title", function(tab)
	local title = tab.active_pane.title
	local cwd = tab.active_pane.current_working_dir
	if cwd then
		local path = type(cwd) == "userdata" and cwd.file_path or tostring(cwd)
		path = path:gsub("^file://[^/]*", ""):gsub("/+$", "")
		local base = path:match("([^/]+)$")
		if base and #base > 0 then
			title = base
		end
	end
	return string.format(" %d: %s ", tab.tab_index + 1, title)
end)

config.window_decorations = "RESIZE"

config.window_background_opacity = 0.7
config.macos_window_background_blur = 5

-- and finally, return the configuration to wezterm
return config
