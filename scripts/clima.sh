#!/usr/bin/env bash

CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CWD/tmux.sh"
source "$CWD/icons.sh"

# Weather data reference: http://openweathermap.org/weather-conditions

TTL=$((60 * $(get_tmux_option @clima_ttl 15)))
UNIT=$(get_tmux_option @clima_unit "metric")
SHOW_ICON=$(get_tmux_option @clima_show_icon 1)
SHOW_LOCATION=$(get_tmux_option @clima_show_location 1)
CLIMA_LOCATION=$(get_tmux_option @clima_location "")

get_location_coordinates() {
    local loc_response=""
    local lat=""
    local lon=""

    if [ -z "$1" ]; then
        loc_response=$(curl --silent --max-time 10 https://ifconfig.co/json)
        if [ -n "$loc_response" ]; then
            lat=$(echo "$loc_response" | jq -r '.latitude // empty')
            lon=$(echo "$loc_response" | jq -r '.longitude // empty')
        fi
    else
        loc_response=$(curl --silent --max-time 10 "http://api.openweathermap.org/geo/1.0/direct?q=$CLIMA_LOCATION&limit=1&appid=$OPEN_WEATHER_API_KEY")
        if [ -n "$loc_response" ]; then
            lat=$(echo "$loc_response" | jq -r '.[0].lat // empty')
            lon=$(echo "$loc_response" | jq -r '.[0].lon // empty')
        fi
    fi

    # Return coordinates only if both are valid
    if [ -n "$lat" ] && [ -n "$lon" ] && [ "$lat" != "null" ] && [ "$lon" != "null" ]; then
        echo -n "$(jq -n --arg "lat" "$lat" \
            --arg "lon" "$lon" \
            '{lat: $lat, lon: $lon}')"
    else
        echo -n '{"lat": "null", "lon": "null"}'
    fi
}

clima() {
    NOW=$(date +%s)
    LAST_UPDATE_TIME=$(get_tmux_option @clima_last_update_time)
    CLIMA_LAST_LOCATION=$(get_tmux_option @clima_last_location "")
    MOD=$((NOW - LAST_UPDATE_TIME))
    SYMBOL=$(symbol "$UNIT")

    if [ -z "$LAST_UPDATE_TIME" ] || [ "$MOD" -ge "$TTL" ] || [ "$CLIMA_LOCATION" != "$CLIMA_LAST_LOCATION" ]; then
        LOCATION=$(get_location_coordinates "$CLIMA_LOCATION")
        LAT=$(echo "$LOCATION" | jq -r .lat)
        LON=$(echo "$LOCATION" | jq -r .lon)

        # Validate coordinates before making API call
        if [ "$LAT" = "null" ] || [ "$LON" = "null" ] || [ -z "$LAT" ] || [ -z "$LON" ]; then
            echo -n "$(get_tmux_option "@clima_current_value" "N/A")"
            return
        fi

        WEATHER=$(curl --silent --max-time 10 "http://api.openweathermap.org/data/2.5/weather?lat=$LAT&lon=$LON&APPID=$OPEN_WEATHER_API_KEY&units=$UNIT")

        # Validate weather response has required fields
        if [ "$?" -eq 0 ] && [ -n "$WEATHER" ]; then
            # Check if response contains valid weather data (not an error response)
            TEMP_RAW=$(echo "$WEATHER" | jq -r '.main.temp // empty')
            CATEGORY=$(echo "$WEATHER" | jq -r '.weather[0].id // empty')

            if [ -n "$TEMP_RAW" ] && [ -n "$CATEGORY" ] && [ "$TEMP_RAW" != "null" ] && [ "$CATEGORY" != "null" ]; then
                TEMP="$(echo "$TEMP_RAW" | cut -d . -f 1)$SYMBOL"
                ICON="$(icon "$CATEGORY")"
                CITY="$(echo "$WEATHER" | jq -r '.name // "Unknown"')"
                COUNTRY="$(echo "$WEATHER" | jq -r '.sys.country // ""')"
                DESCRIPTION="$(echo "$WEATHER" | jq -r '.weather[0].main // "Unknown"')"
                FEELS_LIKE_RAW="$(echo "$WEATHER" | jq -r '.main.feels_like // empty')"
                WIND_SPEED_RAW="$(echo "$WEATHER" | jq -r '.wind.speed // empty')"

                FEELS_LIKE="Feels like: $(echo "$FEELS_LIKE_RAW" | cut -d . -f 1)$SYMBOL"
                WIND_SPEED="Wind speed: ${WIND_SPEED_RAW} m/s"
                CLIMA=""

                if [ "$SHOW_LOCATION" == 1 ]; then
                    if [ -n "$COUNTRY" ]; then
                        CLIMA="$CLIMA$CITY,$COUNTRY "
                    else
                        CLIMA="$CLIMA$CITY "
                    fi
                fi

                if [ "$SHOW_ICON" == 1 ]; then
                    CLIMA="$CLIMA$ICON"
                fi

                CLIMA="$CLIMA$TEMP"

                if [ -n "$COUNTRY" ]; then
                    CLIMA_DETAILS="${CITY}, ${COUNTRY}: ${ICON} ${TEMP}, ${DESCRIPTION}, ${FEELS_LIKE}, ${WIND_SPEED}"
                else
                    CLIMA_DETAILS="${CITY}: ${ICON} ${TEMP}, ${DESCRIPTION}, ${FEELS_LIKE}, ${WIND_SPEED}"
                fi

                set_tmux_option "@clima_last_update_time" "$NOW"
                set_tmux_option "@clima_current_value" "$CLIMA"
                set_tmux_option "@clima_details_value" "$CLIMA_DETAILS"
                set_tmux_option "@clima_last_location" "$CLIMA_LOCATION"
            fi
        fi
    fi

    # Always return cached value, or fallback message if no cache exists
    echo -n "$(get_tmux_option "@clima_current_value" "N/A")"
}

clima
