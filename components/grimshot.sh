SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/functions/variables.sh"
source "$SCRIPT_DIR/functions/checks.sh"
source "$SCRIPT_DIR/functions/core.sh"
source "$SCRIPT_DIR/functions/misc.sh"

check_dependencies
check_root

if [ -f "$CONFIG_FILE" ]; then
	source "$CONFIG_FILE"
fi

if [[ "$1" != "auto" && -f "$CONFIG_FILE" ]]; then
	check_variables
fi

if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
    echo "grim isn't supported on your desktop environment compositor."
    exit 1
fi

if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
	echo "grim isn't supported your compositor (x11)."
	exit 1
fi

if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
	service="none"
	endnotif="true"
	shift
fi

if [[ "$1" == "--area" || ( "$1" == "shot" && -z "$2" ) || ( "$1" == "shot" && "$2" == "--area" ) || ( "$1" == "auto" && "$2" == "shot" && -z "$3" ) ]]; then
	area=$(slurp)
	grim -g "$area" -t png "$temp_file"
	if [[ -z "$area" ]]; then
		exit 1
	fi
elif [[ "$1" == "--screen" || ( "$1" == "shot" && "$2" == "--screen" ) || ( "$1" == "auto" && "$2" == "--screen" ) || ( "$1" == "auto" && "$2" == "--screen" ) ]]; then
	grim -o "$(getactivemonitor)" -t png "$temp_file"
fi

if [[ "$service" == "none" ]]; then
	[[ "$endnotif" == true ]] && notify-send "Image copied to clipboard" -a "VNREZ" -i $temp_file
	if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
		cat $temp_file | wl-copy
	else
		cat $temp_file | xclip -sel c
	fi
	rm $temp_file
	exit 0
fi

upload_shot


rm $temp_file
exit 0
