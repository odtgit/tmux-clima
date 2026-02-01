#!/usr/bin/env bash

CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CWD/scripts/tmux.sh"

weather_script="#($CWD/scripts/clima.sh)"
weather_tag="\#{clima}"

interpolate() {
    local option="$1"
    local value
    value="$(get_tmux_option "$option")"
    local interpolated="${value/$weather_tag/$weather_script}"
    set_tmux_option "$option" "$interpolated"
}

main() {
    # Initialize cache immediately so weather data is available on first load
    "$CWD/scripts/clima.sh" > /dev/null

    # Interpolate #{clima} in status-right
    interpolate "status-right"

    # Interpolate #{clima} in catppuccin variables if they exist
    interpolate "@catppuccin_clima_text"

    # Bind key to show weather details
    tmux bind-key -T prefix W show-options -gqv @clima_details_value
}

main
