#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/components/functions/variables.sh"
source "$SCRIPT_DIR/components/functions/config.sh"
source "$SCRIPT_DIR/components/functions/checks.sh"
source "$SCRIPT_DIR/components/functions/misc.sh"
source "$SCRIPT_DIR/components/functions/locks.sh"
source "$SCRIPT_DIR/components/functions/handlers.sh"
trap 'tput cnorm' EXIT

if [ -f "$CONFIG_FILE" ]; then
	source "$CONFIG_FILE"
fi

handle_cases
handle_args "$1" "$2" "$3"

if [[ "$1" == "--help" || "$1" == "-h" || ( "$1" == "auto" && ( "$2" == "--help" || "$2" == "-h" )) ]]; then
	help
fi

check_root
check_linux
check_dependencies

initial_setup() {
	echo -e "Initializing.."
	services=("e-z" "nest" "none")
	selected=0

	find "$SCRIPT_DIR/components" -type f -exec chmod +x {} \;

	tput clear

	prev_rows=$(tput lines)
	prev_cols=$(tput cols)

	while true; do
		rows=$(tput lines)
		cols=$(tput cols)

		if [[ $rows -ne $prev_rows || $cols -ne $prev_cols ]]; then
			tput clear
			prev_rows=$rows
			prev_cols=$cols
		fi

		tput civis
		tput cup 0 0

		rows=$(tput lines)
		cols=$(tput cols)
		vpad=$(((rows - 20) / 2))
		hpad=$(((cols - 40) / 2))

		for ((i = 0; i < vpad; i++)); do echo; done

		printf "%${hpad}s" ""
		logo_setup | while IFS= read -r line; do
			printf "%${hpad}s%s\n" "" "$line"
		done
		printf "%${hpad}s" ""
		printf "       \e[36mWelcome to VNREZ Configuration\e[0m\n"
		printf "%${hpad}s" ""
		printf "Select your preferred host using arrow keys:\n"

		for i in "${!services[@]}"; do
			printf "%${hpad}s" ""
			if [[ "${services[$i]}" == "none" ]]; then
				if [[ $i -eq $selected ]]; then
					echo -e "\e[32m◆ ${services[$i]}\e[0m"
				else
					echo "◇ ${services[$i]}"
				fi
			else
				if [[ $i -eq $selected ]]; then
					echo -e "\e[32m• ${services[$i]}\e[0m"
				else
					echo "◦ ${services[$i]}"
				fi
			fi
		done

		read -rsn1 input
		case $input in
		$'\x1b')
			read -rsn2 -t 0.1 input
			if [[ $input == "[A" || $input == "[D" ]]; then
				((selected--))
				if [[ $selected -lt 0 ]]; then
					selected=$((${#services[@]} - 1))
				fi
			elif [[ $input == "[B" || $input == "[C" ]]; then 
				((selected++))
				if [[ $selected -ge ${#services[@]} ]]; then
					selected=0
				fi
			fi
			;;
		"W" | "w" | "A" | "a")
			((selected--))
			if [[ $selected -lt 0 ]]; then
				selected=$((${#services[@]} - 1))
			fi
			;;
		"S" | "s" | "D" | "d")
			((selected++))
			if [[ $selected -ge ${#services[@]} ]]; then
				selected=0
			fi
			;;
		"")
			service=${services[$selected]}
			break
			;;
		esac
	done

	tput cnorm

	if [[ "$service" != "none" ]]; then
		echo -e "\e[33mEnter your API Key for $service:\e[0m"
		echo -n "✦ ) "
		auth_token=""
		while [[ -z "$auth_token" || ${#auth_token} -lt 30 ]]; do
			while IFS= read -r -s -n1 char; do
				if [[ $char == "" ]]; then
					echo
					break
				fi
				if [[ $char == $'\x7f' ]]; then
					if [[ -n $auth_token ]]; then
						auth_token=${auth_token%?}
						echo -ne "\b \b"
					fi
				else
					auth_token+="$char"
					echo -n "*"
				fi
			done

			if [[ -z "$auth_token" ]]; then
				echo -e "\e[31mAPI Key cannot be empty!\e[0m"
			elif [[ ${#auth_token} -lt 30 ]]; then
				echo -e "\e[31mAPI Key isn't valid!\e[0m"
			fi

			if [[ -z "$auth_token" || ${#auth_token} -lt 30 ]]; then
				sleep 1
				tput cuu1
				tput el
				tput cuu1
				tput el
				tput cuu1
				tput el
				printf "\e[33mEnter your API Key for $service:\e[0m\n✦ ) "
			fi
		done
	fi

	screenshot_tools=()
	if command -v flameshot >/dev/null; then
		screenshot_tools+=("flameshot")
	fi
	if command -v grim >/dev/null; then
		screenshot_tools+=("grimshot")
	fi

	selected=0
	tput sc

	while true; do
		trap handle_resize SIGWINCH
		tput rc
		tput civis
		tput el
		echo -e "\e[33mChoose your screenshot tool:\e[0m"
		for i in "${!screenshot_tools[@]}"; do
			if [[ $i -eq $selected ]]; then
				echo -e "\e[32m• ${screenshot_tools[$i]}\e[0m"
			else
				echo "◦ ${screenshot_tools[$i]}"
			fi
		done

		read -rsn1 input
		case $input in
		$'\x1b')
			read -rsn2 -t 0.1 input
			if [[ $input == "[A" ]]; then
				((selected--))
				if [[ $selected -lt 0 ]]; then
					selected=$((${#screenshot_tools[@]} - 1))
				fi
			elif [[ $input == "[B" ]]; then
				((selected++))
				if [[ $selected -ge ${#screenshot_tools[@]} ]]; then
					selected=0
				fi
			fi
			;;
		"")
			screenshot_tool=${screenshot_tools[$selected]}
			break
			;;
		esac
	done

	if [[ "$screenshot_tool" == "grimshot" ]]; then
		grimshot=true
		if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
			echo -ne "\e[33mWould you like to use grimblast? (Y/N):\e[0m "
			tput cnorm
			read -r user_choice

			if [[ "$user_choice" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
				blast=true
			else
				blast=false
			fi
		else
			blast=false
		fi
	else
		grimshot=false
		blast=false
	fi

	if [[ "$prompt_service" == true ]]; then
		create_config "$service" "$auth_token"
		return
	fi

	if [[ ! ("$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon")) && "$XDG_SESSION_TYPE" != "x11" ]]; then
		screen_recorders=()
		if command -v wf-recorder >/dev/null; then
			screen_recorders+=("wf-recorder")
		fi
		if command -v wl-screenrec >/dev/null; then
			screen_recorders+=("wl-screenrec")
		fi

		selected=0
		tput sc

		while true; do
		trap handle_resize SIGWINCH
			tput rc
			tput civis
			tput el
			echo -e "\e[33mChoose your screen recorder:\e[0m"
			for i in "${!screen_recorders[@]}"; do
				if [[ $i -eq $selected ]]; then
					echo -e "\e[32m• ${screen_recorders[$i]}\e[0m"
				else
					echo "◦ ${screen_recorders[$i]}"
				fi
			done

			read -rsn1 input
			case $input in
			$'\x1b')
				read -rsn2 -t 0.1 input
				if [[ $input == "[A" ]]; then
					((selected--))
					if [[ $selected -lt 0 ]]; then
						selected=$((${#screen_recorders[@]} - 1))
					fi
				elif [[ $input == "[B" ]]; then
					((selected++))
					if [[ $selected -ge ${#screen_recorders[@]} ]]; then
						selected=0
					fi
				fi
				;;
			"")
				screen_recorder=${screen_recorders[$selected]}
				break
				;;
			esac
		done

		if [[ "$screen_recorder" == "wl-screenrec" ]]; then
			wlscreenrec=true
		else
			wlscreenrec=false
		fi
	fi
	tput cnorm
	if [[ ! ("$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon")) ]]; then
		echo -e "\e[33mEnter the desired FPS (default is 60):\e[0m"
		echo -n "✦ ) "
		read -r fps
		fps=${fps:-60}
		while ! [[ "$fps" =~ ^[0-9]+$ ]] || [[ $fps -gt 244 ]]; do
			echo -e "\e[31mFPS must be a number and cannot exceed 244. Please enter a valid FPS:\e[0m"
			echo -n "✦ ) "
			read -r fps
			sleep 0.1
		done
	fi

	if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
		echo -e "\e[33mDo you want to save recordings? (Y/N):\e[0m"
		echo -n "✦ ) "
		read -r save_recordings
		sleep 0.1
		if [[ "$save_recordings" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
			videosave=true
			echo -e "\e[33mEnter the directory to save files (You need to set it on Kooha too) (default is ~/Videos/Kooha) :\e[0m"
			echo -n "✦ ) "
			read -r kooha_dir
			sleep 0.1
			kooha_dir=${kooha_dir:-"~/Videos/Kooha"}
			while [[ ! -d "$kooha_dir" || "$kooha_dir" == "/" || "$kooha_dir" != "$HOME"* ]]; do
				echo -e "\e[31mInvalid directory! Please enter a valid directory path:\e[0m"
				echo -n "✦ ) "
				read -r kooha_dir
				sleep 0.1
				if [[ "$kooha_dir" == "~"* ]]; then
					kooha_dir="$HOME${kooha_dir:1}"
				fi
			done
		fi
	fi

	if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
		if [[ "$service" != "none" ]]; then
			echo -e "\e[33mDo you want to enable failsave? (Y/N):\e[0m"
			echo -n "✦ ) "
			read -r failsave_option
			sleep 0.1
			if [[ "$failsave_option" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
				failsave=true
			else
				failsave=false
			fi
		fi
	fi

	if [[ "$wlscreenrec" == false || "$XDG_SESSION_TYPE" == "x11" ]]; then
		echo -e "\e[33mEnter the desired CRF (default is 20):\e[0m"
		echo -n "✦ ) "
		read -r crf
		sleep 0.1
		crf=${crf:-20}
		while ! [[ "$crf" =~ ^[0-9]+$ ]] || [[ $crf -gt 100 ]]; do
			echo -e "\e[31mCRF must be a number and cannot exceed 100. Please enter a valid CRF:\e[0m"
			echo -n "✦ ) "
			read -r crf
			sleep 0.1
		done
	fi
	if [[ "$wlscreenrec" == false || "$XDG_SESSION_TYPE" == "x11" ]]; then
		echo -e "\e[33mEnter the desired preset (default is fast):\e[0m"
		echo -n "✦ ) "
		read -r preset
		sleep 0.1
		preset=${preset:-fast}
	fi

	if [[ "$wlscreenrec" == false || "$XDG_SESSION_TYPE" == "x11" ]]; then
		echo -e "\e[33mEnter the desired pixel format (default is yuv420p):\e[0m"
		echo -n "✦ ) "
		read -r pixelformat
		sleep 0.1
		pixelformat=${pixelformat:-yuv420p}
	fi

	if [[ "$wlscreenrec" == true ]]; then
		echo -e "\e[33mEnter the desired pixel format (default is nv12):\e[0m"
		echo -n "✦ ) "
		read -r extpixelformat
		sleep 0.1
		extpixelformat=${extpixelformat:-nv12}
	fi

	if [[ "$wlscreenrec" == false || "$XDG_SESSION_TYPE" == "x11" ]]; then
		echo -e "\e[33mEnter the desired encoder (default is libx264):\e[0m"
		echo -n "✦ ) "
		read -r encoder
		sleep 0.1
		encoder=${encoder:-libx264}
	fi

	if [[ "$wlscreenrec" == true ]]; then
		echo -e "\e[33mEnter the desired codec (default is auto):\e[0m"
		echo -n "✦ ) "
		read -r codec
		sleep 0.1
		codec=${codec:-auto}
	fi

	if [[ "$wlscreenrec" == true ]]; then
		echo -e "\e[33mEnter the desired bitrate (default is 5 mb):\e[0m"
		echo -n "✦ ) "
		read -r bitrate
		sleep 0.1
		bitrate=${bitrate:-"\"5 mb"\"}
		if [[ "$bitrate" != \"*\" ]]; then
			bitrate="\"$bitrate\""
		fi
	fi

	if [[ ! ("$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon")) ]]; then
		echo -e "\e[33mDo you want to save recordings? (Y/N):\e[0m"
		echo -n "✦ ) "
		read -r save_recordings
		sleep 0.1
		videodir=${videodir:-"~/Videos"}
		if [[ "$save_recordings" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
			videosave=true
			echo -e "\e[33mEnter the directory to save recordings (default is ~/Videos/) :\e[0m"
			echo -n "✦ ) "
			read -r videodir
			videodir=${videodir:-"~/Videos"}
			sleep 0.1
			while [[ ! -d "$videodir" || "$videodir" == "/" || "$videodir" != "$HOME"* ]]; do
				echo -e "\e[31mInvalid directory! Please enter a valid directory path:\e[0m"
				echo -n "✦ ) "
				read -r videodir
				videodir=${videodir:-"~/Videos"}
				sleep 0.1
				if [[ "$videodir" == "~"* ]]; then
					videodir="$HOME${videodir:1}"
				fi
			done
		fi

		if [[ "$service" != "none" ]]; then
			echo -e "\e[33mDo you want to enable failsave? (Y/N):\e[0m"
			echo -n "✦ ) "
			read -r failsave_option
			sleep 0.1
			if [[ "$failsave_option" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
				failsave=true
			else
				failsave=false
			fi
		fi
	fi

	if [[ "$XDG_SESSION_TYPE" == "wayland" || "$XDG_SESSION_TYPE" == "x11" ]]; then
		if [ -d "/run/systemd/system" ]; then
			echo -e "\e[33mDo you want to set up shortening now? (Y/N):\e[0m"
			echo -n "✦ ) "
			read -r setup_shortening
			sleep 0.1
			if [[ -z "$setup_shortening" || "$setup_shortening" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
				echo -e "\e[33mDo you want to have shortening notifications? (Y/N):\e[0m"
				echo -n "✦ ) "
				read -r shortener_notif
				sleep 0.1
				if [[ -z "$shortener_notif" || "$shortener_notif" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
					shortener_notif=true
				else
					shortener_notif=false
				fi
				
				echo -e "\e[33mDo you want to start the shortening service now? (Y/N):\e[0m"
				echo -n "✦ ) "
				read -r start_service
				sleep 0.1
				if [[ -z "$start_service" || "$start_service" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
					start_service=true
					"$SCRIPT_DIR/components/shortener.sh" --start &>/dev/null
					
					echo -e "\e[33mDo you want to enable the shortening service to start on boot? (Y/N):\e[0m"
					echo -n "✦ ) "
					read -r enable_service
					sleep 0.1
					if [[ -z "$enable_service" || "$enable_service" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
						enable_service=true
						"$SCRIPT_DIR/components/shortener.sh" --enable &>/dev/null
					else
						enable_service=false
					fi
				else
					start_service=false
					enable_service=false
				fi
			else
				shortener_notif=false
				start_service=false
				enable_service=false
			fi
		else
			shortener_notif=false
			start_service=false
			enable_service=false
		fi
	fi

	if [[ "$service" == "nest" ]]; then
		sleep 0.1
		echo -e "\e[1;90mDear nest.rip user, you'll have to do additional setup for the URL shortening service.\e[0m"
		sleep 0.25
		
		echo -e "\e[33mEnter domain (default: nest.rip):\e[0m"
		echo -n "✦ ) "
		read -r domain
		domain=${domain:-"nest.rip"}
		sleep 0.1
		
		echo -e "\e[33mEnter subdomain (optional):\e[0m"
		echo -n "✦ ) "
		read -r subdomain
		sleep 0.1
		
		echo -e "\e[33mEnter URL length (5-10, default: 5):\e[0m"
		echo -n "✦ ) "
		read -r length
		length=${length:-"5"}
		sleep 0.1
		while ! [[ "$length" =~ ^[5-9]$|^10$ ]]; do
			echo -e "\e[31mInvalid length. Please enter a number between 5-10:\e[0m"
			echo -n "✦ ) "
			read -r length
			length=${length:-"5"}
			sleep 0.1
		done
		
		echo -e "\e[33mEnter URL type (Normal/Invisible/Emoji, default: Normal):\e[0m"
		echo -n "✦ ) "
		read -r urltype
		urltype=${urltype:-"Normal"}
		sleep 0.1
		while ! [[ "$urltype" =~ ^(Normal|Invisible|Emoji)$ ]]; do
			echo -e "\e[31mInvalid type. Enter Normal, Invisible, or Emoji:\e[0m"
			echo -n "✦ ) "
			read -r urltype
			urltype=${urltype:-"Normal"}
			sleep 0.1
		done
	fi

	echo -e "\e[33mDo you want to save screenshots? (Y/N):\e[0m"
	echo -n "✦ ) "
	read -r save_screenshots
	sleep 0.1
	photodir=${photodir:-"~/Pictures"}
	if [[ "$save_screenshots" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
		photosave=true
		echo -e "\e[33mEnter the directory to save screenshots (default is ~/Pictures/) :\e[0m"
		echo -n "✦ ) "
		read -r photodir
		photodir=${photodir:-"~/Pictures"}
		sleep 0.1
		while [[ ! -d "$photodir" || "$photodir" == "/" || "$photodir" != "$HOME"* ]]; do
			echo -e "\e[31mInvalid directory! Please enter a valid directory path:\e[0m"
			echo -n "✦ ) "
			read -r photodir
			photodir=${photodir:-"~/Pictures"}
			sleep 0.1
			if [[ "$photodir" == "~"* ]]; then
				photodir="$HOME${photodir:1}"
			fi
		done
	fi

	create_config "$service" "$auth_token" "$fps" "$crf" "$preset" "$pixelformat" "$extpixelformat" "$wlscreenrec" "$codec" "$videodir" "$failsave" "$videosave" "$encoder" "$startnotif" "$endnotif" "$grimshot" "$blast" "$bitrate" "$shortener_notif" "$domain" "$subdomain" "$length" "$urltype" "$photosave" "$photodir"
}

if [[ "$1" == "config" || ( "$1" == "auto" && "$2" == "config" ) ]]; then
	if [[ ! -f "$CONFIG_FILE" ]]; then
		initial_setup
	fi

	if command -v xdg-open >/dev/null; then
		xdg-open "$(eval echo $CONFIG_FILE)"
	elif command -v open >/dev/null; then
		open "$(eval echo $CONFIG_FILE)"
	elif command -v nvim >/dev/null; then
		nvim "$(eval echo $CONFIG_FILE)"
	elif command -v nano >/dev/null; then
		nano "$(eval echo $CONFIG_FILE)"
	else
		echo "No suitable text editor found. Please open $(eval echo $CONFIG_FILE) manually."
	fi
	exit 0
fi

if [[ "$1" == "reinstall" || ( "$1" == "auto" && "$2" == "reinstall" ) ]]; then
	read -p "Do you want to reinstall the config file with default settings? (Y/N): " confirm
	if [[ "$confirm" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
		initial_setup
	else
		echo "Reinstallation canceled."
	fi
	exit 0
fi

if [[ ! -f "$CONFIG_FILE" && ! ( "$1" == "auto" && ( "$2" == "record" || "$2" == "shot" )) ]]; then
	initial_setup
fi

if [[ "$1" == "auto" ]] || [[ ! -f "$CONFIG_FILE" && $(command -v grim) && ! $(command -v flameshot) && "$XDG_SESSION_TYPE" != "x11" && "$XDG_CURRENT_DESKTOP" != "GNOME" && "$XDG_CURRENT_DESKTOP" != "KDE" && "$XDG_CURRENT_DESKTOP" != "COSMIC" && "$XDG_CURRENT_DESKTOP" != "X-Cinnamon" ]]; then
    grimshot=true
    if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
        blast=true
    else
        blast=false
    fi
else
    grimshot=false
    blast=false
fi

if [[ -f "$CONFIG_FILE" ]]; then
	source "$CONFIG_FILE"
	update_config
fi

if [[ -z "$1" || ( "$1" == "auto" && -z "$2" ) ]]; then
	if [[ "$service" == "none" ]]; then
		options=("record" "shot" "upload" "ǀ" "⨯")
	else
		options=("record" "shot" "upload" "shortener" "ǀ" "⨯")
	fi
	selected=0
	tput clear

	while true; do
		tput civis
		tput cup 0 0

		rows=$(tput lines)
		cols=$(tput cols)
		vpad=$(((rows - 20) / 2))
		hpad=$(((cols - ${#options[@]} * 15) / 2))
		for ((i = 0; i < vpad; i++)); do echo; done

		logo | while IFS= read -r line; do
			hpad=$(((cols - ${#line}) / 2))
			printf "%${hpad}s%s\n" "" "$line"
		done

		text="Select an option using arrow keys and press Enter:"
		hpad=$(((cols - ${#text}) / 2))
		printf "%${hpad}s" ""
		echo -e "\e[36m$text\e[0m"
		printf "%${hpad}s" ""
		line=""
		for i in "${!options[@]}"; do
			if [[ "${options[$i]}" == "⨯" ]]; then
				if [[ $i -eq $selected ]]; then
					line+="\e[32m⨯\e[0m  "
				else
					line+="⨯  "
				fi
			elif [[ "${options[$i]}" == "ǀ" ]]; then
				line+="ǀ  "
			elif [[ $i -eq $selected ]]; then
				line+="\e[32m• ${options[$i]}\e[0m  "
			else
				line+="◦ ${options[$i]}  "
			fi
		done
		echo -e "$line"

		read -rsn1 input
		case $input in
		$'\x1b')
			read -rsn2 -t 0.1 input
			if [[ $input == "[D" ]]; then
				((selected--))
				while [[ "${options[$selected]}" == "ǀ" ]]; do
					((selected--))
				done
				if [[ $selected -lt 0 ]]; then
					selected=$((${#options[@]} - 1))
				fi
			elif [[ $input == "[C" ]]; then
				((selected++))
				while [[ "${options[$selected]}" == "ǀ" ]]; do
					((selected++))
				done
				if [[ $selected -ge ${#options[@]} ]]; then
					selected=0
				fi
			fi
			;;
		"")
			choice=${options[$selected]}
			if [[ "$choice" == "⨯" ]]; then
				tput cnorm
				exit 0
			fi
			if [[ "$choice" == "upload" ]]; then
				if [[ "$service" == "none" ]]; then
					cols=$(tput cols)
					error_message="ERROR: Service is none."
					hpad=$(((cols - ${#error_message}) / 2))
					printf "%${hpad}s\033[1;5;31mERROR:\033[0m Service is none.\n"
					hpad=$(((cols - ${#text}) / 2))
					printf "%${hpad}s%s" "" "Would you like to add a service? (Y/N): "
					read -r add_service
					if [[ "$add_service" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
						prompt_service=true
						initial_setup
						exec "$0" "$@"
					fi
			else
				tput cnorm
					if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
						default_save_dir="$(eval echo $kooha_dir)"
					else
						default_save_dir="$(eval echo $videodir)"
					fi

					printf "\nEnter the file paths to upload, separated by spaces (limit is 6):\n"
					echo -n "✦"
					echo -n " ) "
					file_paths=""
					while IFS= read -r -s -n1 char; do
						if [[ $char == "" ]]; then
							echo
							break
						fi
						if [[ $char == $'\x7f' ]]; then
							if [[ -n $file_paths ]]; then
								file_paths=${file_paths%?}
								echo -ne "\b \b"
							fi
						else
							file_paths+="$char"
							echo -ne "\033[4m$char\033[0m"
						fi
					done
					IFS=' ' read -r -a paths_array <<<"$file_paths"

					for i in "${!paths_array[@]}"; do
						if [[ ! -f "${paths_array[$i]}" && "$videosave" == true ]]; then
							if [[ -f "$default_save_dir/${paths_array[$i]}" ]]; then
								paths_array[$i]="$default_save_dir/${paths_array[$i]}"
							fi
						fi
					done

					file_paths="${paths_array[*]}"

					"$SCRIPT_DIR/components/upload.sh" $file_paths
					sleep 2.5
					exec "$0" "$@"
					tput civis
				fi
			fi
			if [[ "$choice" == "↩" ]]; then
				exec "$0" "$@"
			fi
			break
			;;
		esac
	done

	tput cnorm
	if [[ "$choice" == "record" ]]; then
		if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
			base_options=("none" "gif" "abort")
		else
			base_options=("sound" "fullscreen-sound" "fullscreen" "no-sound" "gif" "abort")
		fi
	elif [[ "$choice" == "shot" ]]; then
		acquire_lock
		if command -v grim >/dev/null; then
			if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" && "$grimshot" == true && "$blast" == true ]]; then
				if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
					"$SCRIPT_DIR/components/grimblast.sh" auto "${@:2}"
				else
					"$SCRIPT_DIR/components/grimblast.sh" "${@:2}"
				fi
			elif [[ "$grimshot" == true && "$blast" == false ]]; then
				if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
					"$SCRIPT_DIR/components/grimshot.sh" auto "${@:2}"
				else
					"$SCRIPT_DIR/components/grimshot.sh" "${@:2}"
				fi
			else
				if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
					"$SCRIPT_DIR/components/flameshot.sh" auto "${@:2}"
				else
					"$SCRIPT_DIR/components/flameshot.sh" "${@:2}"
				fi
			fi
		else
			if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
				"$SCRIPT_DIR/components/flameshot.sh" auto "${@:2}"
			else
				"$SCRIPT_DIR/components/flameshot.sh" "${@:2}"
			fi
		fi
		release_lock
		exit 0
	elif [[ "$choice" == "shortener" ]]; then
		base_options=("start" "target" "stop" "enable" "disable" "logs")
	fi

	sub_options=("${base_options[@]}" "ǀ" "↩" "⨯")

	selected=0
	tput clear
	while true; do
		tput civis
		tput cup 0 0

		cols=$(tput cols)
		lines=$(tput lines)
		vpad=$(((lines - 8) / 4))
		for ((i = 0; i < vpad; i++)); do
			echo ""
		done

		logo | while IFS= read -r line; do
			hpad=$(((cols - ${#line}) / 2))
			printf "%${hpad}s%s\n" "" "$line"
		done

		text="Select a sub-option for $choice using arrow keys and press Enter:"
		hpad=$(((cols - ${#text}) / 2))
		hpad_small=$(((cols - ${#text}) / 3 + 5))
		printf "%${hpad}s" ""
		echo -e "\e[36m$text\e[0m"
		if [[ "$choice" == "record" && ! ("$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon")) ]]; then
			printf "%${hpad_small}s" ""
		else
			printf "%${hpad}s"""
		fi
		line=""
		for i in "${!sub_options[@]}"; do
			if [[ "${sub_options[$i]}" == "↩" ]]; then
				if [[ $i -eq $selected ]]; then
					line+="\e[32m↩\e[0m  "
				else
					line+="↩  "
				fi
			elif [[ "${sub_options[$i]}" == "⨯" ]]; then
				if [[ $i -eq $selected ]]; then
					line+="\e[32m⨯\e[0m  "
				else
					line+="⨯  "
				fi
			elif [[ "${sub_options[$i]}" == "ǀ" ]]; then
				line+="ǀ  "
			elif [[ $i -eq $selected ]]; then
				line+="\e[32m• ${sub_options[$i]}\e[0m  "
			else
				line+="◦ ${sub_options[$i]}  "
			fi
		done
		echo -e "$line"

		read -rsn1 input
		case $input in
		$'\x1b')
			read -rsn2 -t 0.1 input
			if [[ $input == "[D" ]]; then
				((selected--))
				while [[ "${sub_options[$selected]}" == "ǀ" ]]; do
					((selected--))
				done
				if [[ $selected -lt 0 ]]; then
					selected=$((${#sub_options[@]} - 1))
				fi
			elif [[ $input == "[C" ]]; then
				((selected++))
				while [[ "${sub_options[$selected]}" == "ǀ" ]]; do
					((selected++))
				done
				if [[ $selected -ge ${#sub_options[@]} ]]; then
					selected=0
				fi
			fi
			;;
		"")
			sub_choice=${sub_options[$selected]}
			if [[ "$sub_choice" == "⨯" ]]; then
				tput cnorm
				exit 0
			fi
			if [[ "$sub_choice" == "↩" ]]; then
				exec "$0" "$@"
			fi
			break
			;;
		esac
	done

	tput cnorm
	if [[ "$choice" == "record" ]]; then
		if [[ "$sub_choice" == "none" && "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
			sleep 0.5
			"$SCRIPT_DIR/components/record.sh" &>/dev/null
		else
			sleep 0.5
			"$SCRIPT_DIR/components/record.sh" "--$sub_choice" &>/dev/null
		fi
	elif [[ "$choice" == "shot" ]]; then
		if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" && "$grimshot" == true && "$blast" == true ]]; then
			if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
				"$SCRIPT_DIR/components/grimblast.sh" auto "${@:2}"
			else
				"$SCRIPT_DIR/components/grimblast.sh" "${@:2}"
			fi
		elif [[ "$grimshot" == true && "$blast" == false ]]; then
			if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
				"$SCRIPT_DIR/components/grimshot.sh" auto "${@:2}"
			else
				"$SCRIPT_DIR/components/grimshot.sh" "${@:2}"
			fi
		elif [[ "$grimshot" == false ]]; then
			if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
				"$SCRIPT_DIR/components/flameshot.sh" auto "${@:2}"
			else
				"$SCRIPT_DIR/components/flameshot.sh" "${@:2}"
			fi
		fi
	elif [[ "$choice" == "shortener" ]]; then
		if [[ "$sub_choice" == "target" ]]; then
			echo -e "\e[33mEnter the URL to shorten:\e[0m"
			echo -n "✦ ) "
			read -r url_to_shorten
			if [[ -n "$url_to_shorten" ]]; then
				"$SCRIPT_DIR/components/shortener.sh" "$url_to_shorten"
				sleep 2
			else
				echo -e "\e[31mNo URL provided. Operation cancelled.\e[0m"
				sleep 1.5
			fi
		else
			"$SCRIPT_DIR/components/shortener.sh" "--$sub_choice"
		fi
		sleep 0.2
		exec "$0" "$@"
	else
		if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
			"$SCRIPT_DIR/components/flameshot.sh" auto "${@:2}"
		else
			"$SCRIPT_DIR/components/flameshot.sh" "${@:2}"
		fi
	fi
	sleep 0.2
	exec "$0" "$@"
fi

if [[ "$1" == "shorten" || ( "$1" == "auto" && "$2" == "shorten" ) ]]; then
	if [[ "$1" == "auto" ]]; then
		"$SCRIPT_DIR/components/shortener.sh" "${@:3}"
	else
		"$SCRIPT_DIR/components/shortener.sh" "${@:2}"
	fi
	exit 0
fi

if [[ "$1" == "upload" || "$1" == "-u" || ( "$1" == "auto" && ( "$2" == "upload" || "$2" == "-u" )) ]]; then
	if [[ "$1" == "auto" ]]; then
		"$SCRIPT_DIR/components/upload.sh" "${@:3}"
	else
		"$SCRIPT_DIR/components/upload.sh" "${@:2}"
	fi
	exit 0
fi

if [[ "$1" == "shot" || ( "$1" == "auto" && "$2" == "shot" ) ]]; then
	acquire_lock
	if [[ "$XDG_SESSION_TYPE" == "wayland" && ( "$XDG_CURRENT_DESKTOP" != "GNOME" && "$XDG_CURRENT_DESKTOP" != "KDE" && "$XDG_CURRENT_DESKTOP" != "COSMIC" && "$XDG_CURRENT_DESKTOP" != "X-Cinnamon" ) ]]; then
		if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" && "$grimshot" == true && "$blast" == true ]]; then
			if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
				"$SCRIPT_DIR/components/grimblast.sh" auto "${@:2}"
			else
				"$SCRIPT_DIR/components/grimblast.sh" "${@:2}"
			fi
		elif [[ "$grimshot" == true && "$blast" == false ]]; then
			if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
				"$SCRIPT_DIR/components/grimshot.sh" auto "${@:2}"
			else
				"$SCRIPT_DIR/components/grimshot.sh" "${@:2}"
			fi
		elif [[ "$grimshot" == false ]]; then
			if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
				"$SCRIPT_DIR/components/flameshot.sh" auto "${@:2}"
			else
				"$SCRIPT_DIR/components/flameshot.sh" "${@:2}"
			fi
		fi
	else
		if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
			"$SCRIPT_DIR/components/flameshot.sh" auto "${@:2}"
		else
			"$SCRIPT_DIR/components/flameshot.sh" "${@:2}"
		fi
	fi
	release_lock
	exit 0
fi

if [[ "$1" == "record" || ( "$1" == "auto" && "$2" == "record" ) ]]; then
	acquire_lock
	if [[ ( "$1" == "auto" && "$2" == "--abort" ) || "$2" == "--abort" ]]; then
		if [[ "$1" == "auto" ]]; then
			"$SCRIPT_DIR/components/record.sh" "${@:3}"
		else
			"$SCRIPT_DIR/components/record.sh" "${@:2}"
		fi
	elif [[ ( "$1" == "auto" && "$2" == "record" ) || "$2" == "record" && ! -f "$CONFIG_FILE" ]]; then
		if pgrep -x ffmpeg >/dev/null || pgrep -x wf-recorder >/dev/null || pgrep -x wl-screenrec >/dev/null || pgrep -x kooha >/dev/null; then
			"$SCRIPT_DIR/components/record.sh" auto
			release_lock
			exit 0
		else
			if pgrep -x ffmpeg >/dev/null || pgrep -x wf-recorder >/dev/null || pgrep -x wl-screenrec >/dev/null || pgrep -x kooha >/dev/null; then
				"$SCRIPT_DIR/components/record.sh"
				release_lock
				exit 0
			fi
		fi
		if [[ ( "$1" == "auto" && "$2" == "record" ) || "$2" == "record" && ! -f "$CONFIG_FILE" ]]; then
			"$SCRIPT_DIR/components/record.sh" auto "${@:3}"
		fi
	else
		"$SCRIPT_DIR/components/record.sh" "${@:2}"
	fi
	release_lock
fi

exit 0
