help() {
	if [[ "$XDG_SESSION_TYPE" == "wayland" && "$XDG_CURRENT_DESKTOP" != "GNOME" && "$XDG_CURRENT_DESKTOP" != "KDE" && "$XDG_CURRENT_DESKTOP" != "COSMIC" && "$XDG_CURRENT_DESKTOP" != "X-Cinnamon" && "$XDG_SESSION_TYPE" != "X11" && "$grimshot" == true && "$blast" == false ]]; then
		echo ""
		echo "OPTIONS:"
		echo "  --help, -h             Show this help message and exit"
		echo "  config                 Open the configuration file in the default text editor"
		echo "  reinstall              Reinstall the configuration file with default settings"
		echo "  upload, -u             Upload specified video files (mp4, mkv, webm, gif)"
		echo "  auto                   Run with default settings without using a config file"
		echo ""
		echo "shot [--freeze]:" 
		echo "  --output               Make a screenshot of the current output"
		echo "  --area                 Make a selected region screenshot"
		echo ""
		echo "record:"
		echo "  --sound                Record a selected region with sound"
		echo "  --fullscreen-sound     Record the entire screen with sound"
		echo "  --fullscreen           Record the entire screen without sound"
		echo "  --no-sound, (none)     Record a selected region without sound"
		echo "  --gif                  Record a selected region and convert to GIF"
		echo "  --abort                Abort the current recording"
		show_shorten_help
		exit 0
	fi

	if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" && "$grimshot" == true && "$blast" == true ]]; then
		echo "Usage: vnrez(.sh) [CASE] [ARGUMENTS]"
		echo ""
		echo "OPTIONS:"
		echo "  --help, -h             Show this help message and exit"
		echo "  config                 Open the configuration file in the default text editor"
		echo "  reinstall              Reinstall the configuration file with default settings"
		echo "  upload, -u             Upload specified video files (mp4, mkv, webm, gif)"
		echo "  auto                   Run with default settings without using a config file"
		echo ""
		echo "shot [--notify] [--cursor] [--freeze] [--wait N] [--scale <scale>]:" 
		echo "  --output               Make a screenshot of the current output"
		echo "  --screen               Make a screenshot of the current screen"
		echo "  --area                 Make a selected region screenshot"
		echo "  --active               Make a screenshot of the current active window"
		echo ""
		echo "record:"
		echo "  --sound                Record a selected region with sound"
		echo "  --fullscreen-sound     Record the entire screen with sound"
		echo "  --fullscreen           Record the entire screen without sound"
		echo "  --no-sound, (none)     Record a selected region without sound"
		echo "  --gif                  Record a selected region and convert to GIF"
		echo "  --abort                Abort the current recording"
		show_shorten_help
		exit 0
	fi

	if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
		echo "Usage: vnrez(.sh) [CASE] [ARGUMENTS]"
		echo ""
		echo "OPTIONS:"
		echo "  --help                 Show this help message and exit"
		echo "  config                 Open the configuration file in the default text editor"
		echo "  reinstall              Reinstall the configuration file with default settings"
		echo "  upload, -u             Upload specified video files (mp4, mkv, webm, gif)"
		echo "  auto                   Run with default settings without using a config file"
		echo ""
		echo "shot:"
		echo "  --gui                  Make a selection screenshot"
		echo "  --full                 Make a fullscreen screenshot of all monitors"
		echo "  --screen               Make a screenshot of the current screen"
		echo ""
		echo "record:"
		echo "  (none)                 Start a normal recording with Kooha"
		echo "  --gif                  Record a Video and convert to GIF"
		echo "  --abort                Abort the current recording"
		echo ""
		echo "Note: This record help message is specific to Wayland sessions on GNOME and KDE."
		show_shorten_help
		exit 0
	fi

	if [[ "$XDG_SESSION_TYPE" == "wayland" && "$XDG_CURRENT_DESKTOP" != "GNOME" && "$XDG_CURRENT_DESKTOP" != "KDE" && "$XDG_CURRENT_DESKTOP" != "COSMIC" && "$XDG_CURRENT_DESKTOP" != "X-Cinnamon" ]]; then
		echo "Usage: vnrez(.sh) [CASE] [ARGUMENTS]"
		echo ""
		echo "OPTIONS:"
		echo "  --help, -h             Show this help message and exit"
		echo "  config                 Open the configuration file in the default text editor"
		echo "  reinstall              Reinstall the configuration file with default settings"
		echo "  upload, -u             Upload specified video files (mp4, mkv, webm, gif)"
		echo "  auto                   Run with default settings without using a config file"
		echo ""
		echo "shot:"
		echo "  --gui                  Make a selection screenshot"
		echo "  --full                 Make a fullscreen screenshot of all monitors"
		echo "  --screen               Make a screenshot of the current screen"
		echo ""
		echo "record:"
		echo "  --sound                Record a selected region with sound"
		echo "  --fullscreen-sound     Record the entire screen with sound"
		echo "  --fullscreen           Record the entire screen without sound"
		echo "  --no-sound, (none)     Record a selected region without sound"
		echo "  --gif                  Record a selected region and convert to GIF"
		echo "  --abort                Abort the current recording"
		show_shorten_help
		exit 0
	fi
}

getactivemonitor() {
	if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
		active_monitor=$(xdpyinfo | grep dimensions | awk '{print $2}')
	elif [[ "$XDG_SESSION_TYPE" == "wayland" && "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
		active_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
	else
		active_monitor=$(wlr-randr --json | jq -r '.[] | select(.enabled == true) | .name')
	fi
	echo "$active_monitor"
}

logo() {
	cat <<"EOF"
                                                   
                                                   
 ███     ███ ███ ███   ██ ████    ███     █████ ███
  ███   ███   ███  ███  ███     ██   ███       ███ 
   ███ ███    ███  ███  ███    █████████     ███   
    █████     ███  ███  ███    ██           ███    
     ███     ████  ███ ████      █████    █████████
                                                   

EOF
}

logo_setup() {
	cat <<"EOF"
                                          
▄▄▄▄ ▄▄▄ ▄▄ ▄▄▄   ▄▄▄ ▄▄    ▄▄▄▄  ▄▄▄▄▄▄  
 ▀█▄  █   ██  ██   ██▀ ▀▀ ▄█▄▄▄██ ▀  ▄█▀  
  ▀█▄█    ██  ██   ██     ██       ▄█▀    
   ▀█    ▄██▄ ██▄ ▄██▄     ▀█▄▄▄▀ ██▄▄▄▄█ 
                                                   
EOF
}

spinner() {
	local pid=$1
	local delay=0.1
	local spinstr='|/-\\'
	tput civis && stty -echo
	tput sc
	while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
		local temp=${spinstr#?}
		tput rc
		printf "\033[36;6m[${spinstr:0:1}]\033[0m"
		spinstr=$temp${spinstr%"$temp"}
		sleep $delay
	done
	tput rc
	tput el
	stty echo && tput cnorm
}

get_name() {
	name=$(getent passwd "$(whoami)" | cut -d ':' -f 5 | cut -d ',' -f 1)
	if [[ -z "$name" ]]; then
		name=$(whoami)
	fi
	echo "$name"
}

handle_resize() {
	tput clear
	prev_rows=$(tput lines)
	prev_cols=$(tput cols)
}

show_shorten_help() {
	if [ -d "/run/systemd/system" ] || [ "$service" != "none" ]; then
		echo ""
		echo "shorten:"
		echo "  --start                Start the shortening service"
		echo "  --stop                 Stop the shortening service"
		echo "  --enable               Enable the shortening service to start on boot"
		echo "  --disable              Disable the shortening service from starting on boot"
		echo "  --logs                 Show the logs of the shortening service"
	fi
	echo ""
}
