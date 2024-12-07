#!/bin/bash -e
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/functions/variables.sh"
source "$SCRIPT_DIR/functions/checks.sh"
source "$SCRIPT_DIR/functions/misc.sh"
source "$SCRIPT_DIR/functions/core.sh"

check_dependencies
check_root

if [[ "$1" != "auto" && ! -f "$CONFIG_FILE" ]]; then
	check_variables
fi

if [[ "$1" == "auto" ]]; then
	arg="$2"
else
	arg="$1"
fi

if [[ "$arg" != "--screen" && "$arg" != "shot" && "$arg" != "--full" && "$arg" != "--gui" ]]; then
	notify-send "Invalid argument: $arg" -a "VNREZ Recorder"
	echo "Argument: \"$arg\" is not valid."
	exit 1
fi

if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
	service="none"
	shift
fi

if [[ "$1" == "--help" || "$1" == "-h" || "$2" == "--help" || "$2" == "-h" ]]; then
	help
fi

if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
	clipboard_tool="wl-copy"
else
	clipboard_tool="xclip"
fi

if [[ -z "$1" || "$1" == "--gui" || "$2" == "--gui" || -z "$2" ]]; then
	flameshot gui -r >$temp_file &
	# end-4's hyprland dotfiles detection
	if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" && -n "$(command -v pacman)" ]]; then
		if pacman -Q | grep -q 'illogical-impulse-ags'; then
			ags run-js "closeEverything();" >/dev/null 2>&1
		fi
	fi
elif [[ "$1" == "--full" || "$2" == "--full" ]]; then
	flameshot full -r >$temp_file &
elif [[ "$1" == "--screen" || "$2" == "--screen" ]]; then
	flameshot screen -r >$temp_file &
fi
wait

if [[ $(file --mime-type -b $temp_file) != "image/png" ]]; then
	rm $temp_file
	exit 1
fi

if [[ "$service" == "none" ]]; then
	notify-send "Image copied to clipboard" -a "Flameshot" -i $temp_file
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
