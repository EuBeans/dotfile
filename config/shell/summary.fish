if status is-interactive; and set -q KITTY_WINDOW_ID; and not set -q QUICKSHELL_SUMMARY_SHOWN; and command -q fastfetch
    set -l config_home "$HOME/.config"
    if set -q XDG_CONFIG_HOME; and test -n "$XDG_CONFIG_HOME"
        set config_home "$XDG_CONFIG_HOME"
    end
    set -l summary_config "$config_home/fastfetch/quickshell.jsonc"
    if test -r "$summary_config"
        set -g QUICKSHELL_SUMMARY_SHOWN 1
        command fastfetch --config "$summary_config"
    end
end