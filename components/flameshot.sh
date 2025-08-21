#!/bin/bash -e
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/functions/variables.sh"
source "$SCRIPT_DIR/functions/checks.sh"
source "$SCRIPT_DIR/functions/misc.sh"
source "$SCRIPT_DIR/functions/core.sh"

if [ -f "$CONFIG_FILE" ]; then
	source "$CONFIG_FILE"
fi

check_dependencies
check_root

if [[ "$1" != "auto" && -f "$CONFIG_FILE" ]]; then
	check_variables
fi

if [[ -n "$handle_auto" && "$handle_auto" != "--screen" && "$handle_auto" != "shot" && "$handle_auto" != "--full" && "$handle_auto" != "--gui" ]]; then
	notify-send "Invalid Argument: $handle_auto" -a "VNREZ Recorder"
	echo "Argument: \"$handle_auto\" is not valid."
	exit 1
fi

if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
	service="none"
	endnotif="true"
	shift
fi

if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
	clipboard_tool="wl-copy -n"
else
	clipboard_tool="xclip -rmlastnl"
fi

if [[ -z "$1" || "$1" == "--gui" || "$2" == "--gui" || (-z "$2" || "$1" == "auto") ]]; then
	flameshot gui -r >$temp_file &
	# end-4's hyprland dotfiles detection
	if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" && -n "$(command -v pacman)" ]]; then
		if pacman -Q | grep -q 'illogical-impulse-gnome'; then
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
	[[ "$endnotif" == true ]] && notify-send "Image copied to clipboard" -a "Flameshot" -i $temp_file
	if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
		cat $temp_file | wl-copy -n
	else
		cat $temp_file | xclip -sel c -rmlastnl
	fi
	rm $temp_file
	exit 0
fi

upload_shot

rm $temp_file
exit 0
