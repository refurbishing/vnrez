#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/functions/variables.sh"
source "$SCRIPT_DIR/functions/checks.sh"
source "$SCRIPT_DIR/functions/core.sh" 

if [ -f "$CONFIG_FILE" ]; then
	source "$CONFIG_FILE"
fi

manage_service() {
    check_systemd
    
   case $1 in
        --start)
            if systemctl --user is-active "$SERVICE_NAME" &>/dev/null; then
                echo "Service is already running"
            else
                if [ ! -f "$SERVICE_FILE" ]; then
                    create_service
                fi
                mkdir -p "$HOME/.config/systemd/user"
                if systemctl --user start "$SERVICE_NAME"; then
                    echo "Service started successfully"
                else
                    echo "Failed to start service. Check logs with: systemctl --user status $SERVICE_NAME"
                    exit 1
                fi
            fi
            ;;
        --stop)
            systemctl --user stop "$SERVICE_NAME"
            echo "Service stopped"
            ;;
        --enable)
            if [ ! -f "$SERVICE_FILE" ]; then
                create_service
            fi
            systemctl --user enable "$SERVICE_NAME"
            echo "Service enabled to start on boot"
            ;;
        --disable)
            systemctl --user disable "$SERVICE_NAME"
            echo "Service disabled and won't start on boot"
            ;;
        --logs)
            journalctl --user -u "$SERVICE_NAME" $2
            ;;
        *) echo "Invalid command: $1"; exit 1 ;;
    esac
    exit 0
}

create_service() {
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=VNREZ URL Shortener Service
After=network.target

[Service]
WorkingDirectory=$SCRIPT_DIR
ExecStart=$SCRIPT_DIR/shortener.sh --daemon
Restart=on-failure
Environment="DISPLAY=:0"
Environment="XAUTHORITY=%h/.Xauthority"

[Install] 
WantedBy=default.target
EOF
    systemctl --user daemon-reload
}


case $1 in
    --start|--stop|--enable|--disable|--logs) 
        if [ "$1" = "--logs" ] && [ -n "$2" ]; then
            manage_service $1 "$2"
        else
            manage_service $1
        fi
        ;;
    --daemon)
        create_service
        last_original_url=""
        last_shortened_url=""
        while true; do
            current_clip=""
            if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
                current_clip=$(wl-paste 2>/dev/null || echo "")
            else
                current_clip=$(xclip -selection clipboard -o 2>/dev/null || echo "")
            fi
            
            if [ -n "$current_clip" ] && [[ $current_clip =~ ^https?:// ]] && 
               [ "$current_clip" != "$last_original_url" ] && 
               [ "$current_clip" != "$last_shortened_url" ] && 
               [ "$service" != "none" ]; then
                
                result=$(shorten_url "$current_clip")
                if [ $? -eq 0 ] && [ -n "$result" ]; then
                    last_shortened_url=$(echo "$result" | tail -n1)
                    last_original_url="$current_clip"
                    sleep 5
                else
                    sleep 2
                fi
            fi
            sleep 1
        done
        ;;
    *)
        if [ -z "$1" ]; then
            printf "\033[1;5;31mERROR:\033[0m No URL or Argument provided\n"
            exit 1
        elif [[ $1 =~ ^https?:// ]]; then
            shorten_url "$1"
        elif [[ $1 =~ ^[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+$ ]]; then
            shorten_url "https://$1"
        else
            printf "\033[1;5;31mERROR:\033[0m Invalid argument or malformed URL: \033[1;34m$1\033[0m\n"
            printf "       URLs must be a valid domain or start with \033[1;34m\033[7mhttps://\033[0m\n"
            exit 1
        fi
        ;;
esac
