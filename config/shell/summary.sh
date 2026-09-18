case $- in
    *i*)
        if [[ -n ${KITTY_WINDOW_ID:-} && -z ${QUICKSHELL_SUMMARY_SHOWN:-} ]] && command -v fastfetch >/dev/null 2>&1; then
            quickshell_summary_config="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/quickshell.jsonc"
            if [[ -r "$quickshell_summary_config" ]]; then
                QUICKSHELL_SUMMARY_SHOWN=1
                command fastfetch --config "$quickshell_summary_config"
            fi
            unset quickshell_summary_config
        fi
        ;;
esac